const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const AWSXRay = require("aws-xray-sdk");
const { captureAWSv3Client } = AWSXRay;

// ─── AWS Clients ──────────────────────────────────────────────────────────────
// captureAWSv3Client wraps S3Client so every PutObjectCommand appears as a
// subsegment in X-Ray automatically — duration, status, and errors included.
const s3 = captureAWSv3Client(
    new S3Client({
        region: process.env.MEDIA_BUCKET_REGION || process.env.AWS_REGION || "us-east-1"
    })
);

const BUCKET = process.env.MEDIA_BUCKET;
const EXPIRY = Number(process.env.UPLOAD_EXPIRY_SECONDS || 300);

// ─── Cold Start Detection ─────────────────────────────────────────────────────
// Module-level flag — stays false after the first invocation in this
// execution environment. Annotated on root segment so you can filter all
// cold start traces in X-Ray: Annotations.coldStart = true
let isColdStart = true;

// ─── Allowed Content Types ────────────────────────────────────────────────────
// Explicitly whitelist what can be uploaded. Without this, any contentType
// can be requested — including application/javascript, text/html, etc.
// which could be used to serve malicious content from your S3 bucket.
const ALLOWED_CONTENT_TYPES = new Set([
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "image/svg+xml",
    "video/mp4",
    "video/webm",
    "application/pdf"
]);

// ─── Utilities ────────────────────────────────────────────────────────────────
function getHeader(headers = {}, key) {
    const lower = key.toLowerCase();
    const match = Object.keys(headers).find((k) => k.toLowerCase() === lower);
    return match ? headers[match] : undefined;
}

function makeLogger(base = {}) {
    return (level, message, extra = {}) => {
        console.log(
            JSON.stringify({
                level,
                message,
                timestamp: new Date().toISOString(),
                ...base,
                ...extra
            })
        );
    };
}

function classifyError(err) {
    if (err.name === "NoSuchBucket")
        return { statusCode: 503, message: "Storage unavailable" };
    if (err.name === "ProvisionedThroughputExceededException" || err.name === "RequestLimitExceeded")
        return { statusCode: 503, message: "Service temporarily unavailable, please retry" };
    return { statusCode: 500, message: "Internal server error" };
}

const getExtension = (fileName = "", contentType = "") => {
    const fromName = String(fileName).split(".").pop();
    if (fromName && fromName !== fileName) return fromName.toLowerCase();
    if (contentType.includes("/")) {
        const fromType = contentType.split("/")[1];
        if (fromType) return fromType.toLowerCase();
    }
    return "jpg";
};

// ─── X-Ray Helpers ────────────────────────────────────────────────────────────
// Wraps an async fn in a named subsegment.
// correlationId stamped as annotation on every subsegment — enables:
//   X-Ray filter: Annotations.correlationId = "abc-123"
// to surface the complete trace for a single request.
async function withSubsegment(name, annotations = {}, fn, correlationId) {
    const segment = AWSXRay.resolveSegment();
    const sub = segment.addNewSubsegment(name);

    // correlationId first — always present even if annotations loop throws
    if (correlationId) {
        sub.addAnnotation("correlationId", correlationId);
    }

    for (const [k, v] of Object.entries(annotations)) {
        sub.addAnnotation(k, v);
    }

    try {
        const result = await fn(sub);
        sub.close();
        return result;
    } catch (err) {
        sub.addError(err); // marks node red in X-Ray service map
        sub.close();
        throw err;         // propagate so classifyError() in handler handles it
    }
}

// Stamps annotations and metadata on the Lambda root segment.
// Annotations = indexed, searchable in X-Ray console.
// Metadata = rich context, visible when inspecting a specific trace.
// try/catch intentional — resolveSegment() throws outside Lambda traced
// context (unit tests, local runs). Tracing never fails a request.
function annotateRootSegment(annotations = {}, metadata = {}) {
    try {
        const segment = AWSXRay.resolveSegment();
        for (const [k, v] of Object.entries(annotations)) {
            segment.addAnnotation(k, v);
        }
        if (Object.keys(metadata).length > 0) {
            segment.addMetadata("requestContext", metadata);
        }
    } catch (_) {}
}

// ─── Handler ──────────────────────────────────────────────────────────────────
exports.handler = async (event) => {
    const method = event.httpMethod;
    const path = event.resource;
    const body = event.body ? JSON.parse(event.body) : {};
    const authorID = event.requestContext?.authorizer?.claims?.sub;
    const requestId = event?.requestContext?.requestId;
    const correlationId =
        getHeader(event?.headers, "x-correlation-id") || requestId || randomUUID();
    const startedAt = Date.now();

    // Capture before flipping — guarantees correct value regardless of
    // whether an early return or throw happens before isColdStart = false
    const coldStart = isColdStart;
    isColdStart = false;

    const log = makeLogger({
        service: "admin_media_upload",
        environment: process.env.NODE_ENV,
        functionVersion: process.env.AWS_LAMBDA_FUNCTION_VERSION,
        requestId,
        correlationId,
        method,
        path
    });

    // ── Annotate root segment ─────────────────────────────────────────────────
    // authorID is annotated so you can filter all upload traces for a specific
    // author: Annotations.authorID = "user-123"
    // Useful for investigating abuse or quota enforcement.
    annotateRootSegment(
        {
            correlationId,
            service: "admin-media-upload",
            environment: process.env.NODE_ENV ?? "unknown",
            route: `${method} ${path}`,
            authorID: authorID ?? "unknown",
            coldStart,
        },
        {
            requestId,
            userAgent: getHeader(event?.headers, "user-agent") ?? null,
            bucket: BUCKET,
        }
    );

    let result;

    try {
        log("INFO", "request_start", {
            coldStart,
            authorID,
            userAgent: getHeader(event?.headers, "user-agent") || null
        });

        if (method !== "POST" || path !== "/admin/media/upload_url") {
            log("WARN", "route_not_found", { statusCode: 404 });
            result = response(404, { message: "Route not found" });
            return attachCorrelation(result, correlationId);
        }

        result = await generateUploadUrl(body, authorID, { log, correlationId });
        return attachCorrelation(result, correlationId);

    } catch (err) {
        const { statusCode, message } = classifyError(err);
        log("ERROR", "request_failed", {
            errorType: err?.name,
            errorMessage: err?.message,
            statusCode,
            durationMs: Date.now() - startedAt
        });
        result = response(statusCode, { message });
        return attachCorrelation(result, correlationId);

    } finally {
        log("INFO", "request_end", {
            statusCode: result?.statusCode,
            durationMs: Date.now() - startedAt
        });
    }
};

// ─── Core Logic ───────────────────────────────────────────────────────────────
async function generateUploadUrl(body, authorID, { log, correlationId } = {}) {
    const { fileName, contentType, folder = "media" } = body;

    // Validate before entering subsegment — these are input validation failures,
    // not infrastructure failures, so they don't need X-Ray fault marking
    if (!contentType) {
        log("WARN", "presign_missing_content_type", { authorID });
        return response(400, { message: "contentType is required" });
    }

    if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
        log("WARN", "presign_disallowed_content_type", { contentType, authorID });
        return response(400, { message: `contentType "${contentType}" is not allowed` });
    }

    const extension = getExtension(fileName, contentType);
    const objectKey = `${folder}/${randomUUID()}.${extension}`;

    return withSubsegment(
        "generateUploadUrl",
        {
            authorID: authorID ?? "unknown",
            contentType,
            folder,
        },
        async (sub) => {
            log("INFO", "presign_start", {
                contentType,
                extension,
                folder,
                objectKey,
                expiresIn: EXPIRY,
                authorID
            });

            // objectKey and extension as annotations — searchable in X-Ray.
            // Lets you find the trace for a specific uploaded file if a user
            // reports an issue with a particular media key.
            sub.addAnnotation("extension", extension);
            sub.addAnnotation("objectKey", objectKey);
            sub.addAnnotation("expiresIn", EXPIRY);

            // ── Presign subsegment ────────────────────────────────────────────
            // getSignedUrl does NOT make a network call — it generates a URL
            // locally using the credentials and request metadata. We wrap it in
            // a subsegment anyway so it appears in the trace timeline and we can
            // measure CPU time spent on signing (typically <5ms, useful baseline).
            let uploadUrl;
            await withSubsegment(
                "s3.presignPutObject",
                { contentType, objectKey },
                async (presignSub) => {
                    const command = new PutObjectCommand({
                        Bucket: BUCKET,
                        Key: objectKey,
                        ContentType: contentType
                    });

                    uploadUrl = await getSignedUrl(s3, command, { expiresIn: EXPIRY });

                    // Do NOT log or annotate the full uploadUrl — it contains a
                    // signed credential. Log only the metadata needed for tracing.
                    // Do NOT annotate bucket name on the subsegment — it is
                    // already on the root segment metadata and is not searchable
                    // data we need to filter on.
                    presignSub.addAnnotation("expiry", EXPIRY);
                    presignSub.addMetadata("presign", {
                        objectKey,
                        contentType,
                        bucket: BUCKET,
                        expiresIn: EXPIRY,
                        // Annotate URL length as a sanity check — a very short URL
                        // indicates signing failed silently (should never happen
                        // but useful to have in a trace if it does)
                        urlLength: uploadUrl?.length ?? 0,
                    });
                },
                correlationId
            );

            log("INFO", "presign_success", {
                objectKey,
                contentType,
                expiresIn: EXPIRY,
                authorID,
                correlationId
            });

            return response(200, {
                uploadUrl,
                objectKey,
                key: objectKey,
                expiresIn: EXPIRY
            });
        },
        correlationId
    );
}

// ─── Response Helpers ─────────────────────────────────────────────────────────
function response(statusCode, body) {
    return {
        statusCode,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers":
                "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token,x-correlation-id",
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
        },
        body: JSON.stringify(body)
    };
}

function attachCorrelation(resp, correlationId) {
    return {
        ...resp,
        headers: { ...resp.headers, "x-correlation-id": correlationId }
    };
}
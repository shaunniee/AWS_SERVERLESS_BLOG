const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const { captureAWSv3Client } = require("aws-xray-sdk");

// ─── AWS Clients ──────────────────────────────────────────────────────────────
const s3 = captureAWSv3Client(
    new S3Client({
        region: process.env.MEDIA_BUCKET_REGION || process.env.AWS_REGION || "us-east-1"
    })
);

const BUCKET = process.env.MEDIA_BUCKET;
const EXPIRY = Number(process.env.UPLOAD_EXPIRY_SECONDS || 300);

// ─── Cold Start Detection ─────────────────────────────────────────────────────
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
    if (err.name === "NoSuchBucket") {
        return { statusCode: 503, message: "Storage unavailable" };
    }
    if (
        err.name === "ProvisionedThroughputExceededException" ||
        err.name === "RequestLimitExceeded"
    ) {
        return { statusCode: 503, message: "Service temporarily unavailable, please retry" };
    }
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

    const log = makeLogger({
        service: "admin_media_upload",
        requestId,
        correlationId,
        method,
        path
    });

    let result;

    try {
        log("INFO", "request_start", {
            coldStart: isColdStart,
            authorID,
            userAgent: getHeader(event?.headers, "user-agent") || null
        });
        isColdStart = false;

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

    if (!contentType) {
        log("WARN", "presign_missing_content_type", { authorID });
        return response(400, { message: "contentType is required" });
    }

    // Reject disallowed content types before ever hitting S3.
    // Prevents abuse of the presigned URL to upload arbitrary file types.
    if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
        log("WARN", "presign_disallowed_content_type", { contentType, authorID });
        return response(400, { message: `contentType "${contentType}" is not allowed` });
    }

    const extension = getExtension(fileName, contentType);
    const objectKey = `${folder}/${randomUUID()}.${extension}`;

    log("INFO", "presign_start", {
        contentType,
        extension,
        folder,
        objectKey,
        expiresIn: EXPIRY,
        authorID
    });

    const command = new PutObjectCommand({
        Bucket: BUCKET,
        Key: objectKey,
        ContentType: contentType
    });

    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: EXPIRY });

    // Do not log the full uploadUrl — it contains a signed credential.
    // Log only the metadata needed to trace issues.
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
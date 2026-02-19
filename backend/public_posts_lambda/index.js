const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
    DynamoDBDocumentClient,
    QueryCommand,
    GetCommand
} = require("@aws-sdk/lib-dynamodb");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
const AWSXRay = require("aws-xray-sdk");
const { captureAWSv3Client } = AWSXRay;

// ─── AWS Clients ──────────────────────────────────────────────────────────────
const client = captureAWSv3Client(new DynamoDBClient({}));
const ddb = DynamoDBDocumentClient.from(client);

const TABLE = process.env.POSTS_TABLE;

// ─── Cold Start Detection ─────────────────────────────────────────────────────
// Module-level flag — stays false after the first invocation in this
// execution environment. Lets you measure cold start frequency in Logs Insights:
//   filter coldStart = true | stats count(*) by bin(1h)
let isColdStart = true;

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

// ─── Error Classifier ─────────────────────────────────────────────────────────
function classifyError(err) {
    if (err.name === "ResourceNotFoundException")
        return { statusCode: 503, message: "Database resource unavailable" };
    if (err.name === "ProvisionedThroughputExceededException" || err.name === "RequestLimitExceeded")
        return { statusCode: 503, message: "Service temporarily unavailable, please retry" };
    if (err.name === "ValidationException")
        return { statusCode: 400, message: "Invalid request data" };
    return { statusCode: 500, message: "Internal server error" };
}

// ─── X-Ray Helpers ────────────────────────────────────────────────────────────
// Wraps an async fn in a named subsegment.
// correlationId is stamped as an annotation on every subsegment so you can
// filter the full trace in X-Ray with a single query:
//   Annotations.correlationId = "abc-123"
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
        throw err;
    }
}

// Stamps annotations and metadata on the Lambda root segment.
// Called once at the top of every handler invocation.
// Try/catch is intentional — resolveSegment() throws outside Lambda traced
// context (unit tests, local runs). Tracing is never worth failing a request.
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
    const postId = event.pathParameters?.postId;
    const query = event.queryStringParameters || {};
    const requestId = event?.requestContext?.requestId;
    const correlationId =
        getHeader(event?.headers, "x-correlation-id") || requestId || randomUUID();
    const startedAt = Date.now();
    const coldStart = isColdStart;
    isColdStart = false;

    const log = makeLogger({
        service: "public_blog_posts",
        environment: process.env.NODE_ENV,
        functionVersion: process.env.AWS_LAMBDA_FUNCTION_VERSION,
        requestId,
        correlationId,
        method,
        path
    });

    const ctx = { log, correlationId };

    // ── Annotate root segment ─────────────────────────────────────────────────
    // Annotations are indexed — filterable in X-Ray console.
    // Metadata is rich context — visible when inspecting a specific trace.
    // Public Lambda has no authorID (unauthenticated) so we annotate route only.
    annotateRootSegment(
        {
            correlationId,
            service: "public-blog-posts",
            environment: process.env.NODE_ENV ?? "unknown",
            route: `${method} ${path}`,
            coldStart,
        },
        {
            requestId,
            postId: postId ?? null,
            userAgent: getHeader(event?.headers, "user-agent") ?? null,
            hasPaginationCursor: !!query.lastKey,
            limit: query.limit ?? null,
        }
    );

    let result;

    try {
        log("INFO", "request_start", {
            coldStart,
            postId: postId || null,
            userAgent: getHeader(event?.headers, "user-agent") || null,
            hasPaginationCursor: !!query.lastKey,
            limit: query.limit || null
        });

        if (method === "GET" && path === "/posts")
            result = await listPublishedPosts(query, ctx);
        else if (method === "GET" && path === "/posts/{postId}")
            result = await getPublishedPost(postId, ctx);
        else {
            log("WARN", "route_not_found", { statusCode: 404 });
            result = response(404, { message: "Route not found" });
        }

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

// ─── Route Handlers ───────────────────────────────────────────────────────────

async function listPublishedPosts(query, { log, correlationId } = {}) {
    const limit = query.limit ? Number(query.limit) : 10;

    if (isNaN(limit) || limit < 1 || limit > 100) {
        log("WARN", "list_posts_invalid_limit", { limit: query.limit });
        return response(400, { message: "limit must be a number between 1 and 100" });
    }

    let lastKey;
    if (query.lastKey) {
        try {
            lastKey = JSON.parse(Buffer.from(query.lastKey, "base64").toString());
        } catch (err) {
            log("WARN", "list_posts_invalid_cursor", { errorMessage: err.message });
            return response(400, { message: "Invalid pagination cursor" });
        }
    }

    return withSubsegment("listPublishedPosts", {}, async (sub) => {
        log("INFO", "list_posts_start", { limit, hasCursor: !!lastKey });

        // Annotate pagination state — useful for spotting clients sending
        // bad cursors repeatedly or abnormal page size patterns
        sub.addAnnotation("limit", limit);
        sub.addAnnotation("hasCursor", !!lastKey);

        let result;
        await withSubsegment("ddb.queryPublished", {}, async (ddbSub) => {
            result = await ddb.send(
                new QueryCommand({
                    TableName: TABLE,
                    IndexName: "publishedAtIndex",
                    KeyConditionExpression: "#s = :published",
                    ExpressionAttributeNames: { "#s": "status" },
                    ExpressionAttributeValues: { ":published": "PUBLISHED" },
                    ScanIndexForward: false,
                    Limit: limit,
                    ExclusiveStartKey: lastKey
                })
            );

            const count = result.Items?.length ?? 0;
            const hasNextPage = !!result.LastEvaluatedKey;

            // Annotate DDB result on the inner subsegment so you can see
            // query result counts alongside DDB latency in the same span
            ddbSub.addAnnotation("resultCount", count);
            ddbSub.addAnnotation("hasNextPage", hasNextPage);
        }, correlationId);

        const count = result.Items?.length ?? 0;
        const hasNextPage = !!result.LastEvaluatedKey;

        sub.addAnnotation("resultCount", count);
        sub.addAnnotation("hasNextPage", hasNextPage);

        log("INFO", "list_posts_success", { count, hasNextPage, limit });

        // Warn on empty result — could indicate a broken index or
        // no published posts. Surfaced in Logs Insights error queries.
        if (count === 0) {
            log("WARN", "list_posts_empty", {});
        }

        return response(200, {
            items: result.Items || [],
            nextKey: hasNextPage
                ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString("base64")
                : null
        });
    }, correlationId);
}

async function getPublishedPost(postId, { log, correlationId } = {}) {
    if (!postId) {
        log("WARN", "get_post_missing_id");
        return response(400, { message: "postId is required" });
    }

    return withSubsegment("getPublishedPost", { postID: postId }, async (sub) => {
        log("INFO", "get_post_start", { postID: postId });

        let result;
        await withSubsegment("ddb.getItem", { postID: postId }, async () => {
            result = await ddb.send(
                new GetCommand({ TableName: TABLE, Key: { postID: postId } })
            );
        }, correlationId);

        if (!result.Item) {
            // Annotate miss so you can filter in X-Ray:
            // Annotations.found = false — useful for spotting broken links
            // or clients requesting non-existent posts repeatedly
            sub.addAnnotation("found", false);
            sub.addAnnotation("reason", "not_found");
            log("WARN", "get_post_not_found", { postID: postId });
            return response(404, { message: "Post not found" });
        }

        if (result.Item.status !== "PUBLISHED") {
            // Don't leak post existence — return 404 same as above.
            // Separate reason annotation lets you distinguish draft/archived
            // access attempts from genuinely missing posts in X-Ray Analytics.
            sub.addAnnotation("found", false);
            sub.addAnnotation("reason", "not_published");
            sub.addAnnotation("actualStatus", result.Item.status);
            log("WARN", "get_post_not_published", {
                postID: postId,
                status: result.Item.status
            });
            return response(404, { message: "Post not found" });
        }

        sub.addAnnotation("found", true);
        sub.addAnnotation("authorID", result.Item.authorID);
        sub.addMetadata("post", {
            postID: postId,
            publishedAt: result.Item.publishedAt ?? null,
            authorID: result.Item.authorID ?? null,
        });

        log("INFO", "get_post_success", { postID: postId });
        return response(200, result.Item);
    }, correlationId);
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
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
            "Cache-Control": "public, max-age=60"
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
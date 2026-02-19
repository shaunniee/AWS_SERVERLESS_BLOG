const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
    DynamoDBDocumentClient,
    QueryCommand,
    GetCommand
} = require("@aws-sdk/lib-dynamodb");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const { captureAWSv3Client } = require("aws-xray-sdk");

// ─── AWS Clients ──────────────────────────────────────────────────────────────
const client = captureAWSv3Client(new DynamoDBClient({}));
const ddb = DynamoDBDocumentClient.from(client);

const TABLE = process.env.POSTS_TABLE;

// ─── Cold Start Detection ─────────────────────────────────────────────────────
// Module-level flag — stays false after the first invocation in this
// execution environment. Lets you measure cold start frequency and latency
// separately in CloudWatch Logs Insights.
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
    if (err.name === "ResourceNotFoundException") {
        return { statusCode: 503, message: "Database resource unavailable" };
    }
    if (
        err.name === "ProvisionedThroughputExceededException" ||
        err.name === "RequestLimitExceeded"
    ) {
        return { statusCode: 503, message: "Service temporarily unavailable, please retry" };
    }
    if (err.name === "ValidationException") {
        return { statusCode: 400, message: "Invalid request data" };
    }
    return { statusCode: 500, message: "Internal server error" };
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

    const log = makeLogger({
        service: "public_blog_posts",
        requestId,
        correlationId,
        method,
        path
    });

    const ctx = { log, correlationId };

    // Capture result so we can log statusCode in finally
    let result;

    try {
        log("INFO", "request_start", {
            coldStart: isColdStart,
            postId: postId || null,
            userAgent: getHeader(event?.headers, "user-agent") || null,
            // Log pagination cursor presence (not the value — it encodes DB keys)
            hasPaginationCursor: !!query.lastKey,
            limit: query.limit || null
        });
        isColdStart = false;

        if (method === "GET" && path === "/posts") {
            result = await listPublishedPosts(query, ctx);
        } else if (method === "GET" && path === "/posts/{postId}") {
            result = await getPublishedPost(postId, ctx);
        } else {
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

    // Validate limit to avoid runaway queries
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

    log("INFO", "list_posts_start", { limit, hasCursor: !!lastKey });

    const result = await ddb.send(
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

    log("INFO", "list_posts_success", { count, hasNextPage, limit });

    // Warn if we're consistently returning 0 results — could indicate
    // a broken index or no published posts exist
    if (count === 0) {
        log("WARN", "list_posts_empty", {});
    }

    return response(200, {
        items: result.Items || [],
        nextKey: hasNextPage
            ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString("base64")
            : null
    });
}

async function getPublishedPost(postId, { log, correlationId } = {}) {
    if (!postId) {
        log("WARN", "get_post_missing_id");
        return response(400, { message: "postId is required" });
    }

    log("INFO", "get_post_start", { postID: postId });

    // ⚠️  NOTE: The original implementation uses a Query on the GSI with a
    // FilterExpression for postID. This is inefficient — it scans the entire
    // GSI partition for PUBLISHED posts and then filters in memory.
    // GetItem on the primary key is the correct approach here.
    // Keeping GetItem below. If you need to enforce "only return if PUBLISHED"
    // add a ConditionExpression check after fetching.
    const result = await ddb.send(
        new GetCommand({ TableName: TABLE, Key: { postID: postId } })
    );

    if (!result.Item) {
        log("WARN", "get_post_not_found", { postID: postId });
        return response(404, { message: "Post not found" });
    }

    if (result.Item.status !== "PUBLISHED") {
        // Don't leak that the post exists — return 404 same as above
        log("WARN", "get_post_not_published", { postID: postId, status: result.Item.status });
        return response(404, { message: "Post not found" });
    }

    log("INFO", "get_post_success", { postID: postId });
    return response(200, result.Item);
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
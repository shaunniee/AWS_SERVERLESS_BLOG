const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
    DynamoDBDocumentClient,
    PutCommand,
    GetCommand,
    UpdateCommand,
    QueryCommand,
    DeleteCommand
} = require("@aws-sdk/lib-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Automatically traces every DynamoDB + EventBridge call with duration/errors.
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const { captureAWSv3Client } = require("aws-xray-sdk");

// ─── AWS Clients ──────────────────────────────────────────────────────────────
const client = captureAWSv3Client(new DynamoDBClient({}));
const ddb = DynamoDBDocumentClient.from(client);
const eventbridge = captureAWSv3Client(new EventBridgeClient({}));

const TABLE = process.env.POSTS_TABLE;

// ─── Utilities ────────────────────────────────────────────────────────────────
const now = () => Date.now();

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
// Maps DynamoDB exception names to meaningful HTTP status codes.
// Prevents ConditionalCheckFailedException (business logic) from becoming a 500
// alongside actual infrastructure failures — keeps alarms and logs actionable.
function classifyError(err) {
    if (err.name === "ConditionalCheckFailedException") {
        return { statusCode: 409, message: "Post is not in a valid state for this operation" };
    }
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

// ─── Media Key Helpers ────────────────────────────────────────────────────────
const normalizeObjectKey = (value = "") => String(value).replace(/^\/+/, "").trim();

const extractMediaKeysFromContent = (content = "") => {
    const regex = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi;
    const keys = [];
    let match;
    while ((match = regex.exec(content)) !== null) {
        const src = normalizeObjectKey(match[1] || "");
        const isAbsolute =
            src.startsWith("http://") ||
            src.startsWith("https://") ||
            src.startsWith("data:");
        if (src && !isAbsolute) keys.push(src);
    }
    return keys;
};

const buildMediaKeys = (data = {}) => {
    const inlineKeys = extractMediaKeysFromContent(data.content || "");
    const providedKeys = Array.isArray(data.mediaKeys)
        ? data.mediaKeys.map((value) => normalizeObjectKey(value)).filter(Boolean)
        : [];
    const mainImageKey = normalizeObjectKey(data.mainImageKey || "");
    return Array.from(
        new Set([...providedKeys, ...inlineKeys, ...(mainImageKey ? [mainImageKey] : [])])
    );
};

// ─── Handler ──────────────────────────────────────────────────────────────────
async function handler(event) {
    const method = event.httpMethod;
    const path = event.resource;
    const postId = event.pathParameters?.postId;
    const body = event.body ? JSON.parse(event.body) : {};
    const authorID = event.requestContext.authorizer.claims.sub;
    const requestId = event?.requestContext?.requestId;
    const correlationId =
        getHeader(event?.headers, "x-correlation-id") || requestId || randomUUID();
    const startedAt = Date.now();

    const log = makeLogger({
        service: "admin_blog_posts",
        requestId,
        correlationId,
        method,
        path
    });

    // ctx is passed to every route handler so they all share the same
    // correlationId and log instance — keeping all log lines tied together.
    const ctx = { log, correlationId };

    try {
        log("INFO", "request_start");

        if (method === "POST"   && path === "/admin/posts")             return attachCorrelation(await createPost(body, authorID, ctx), correlationId);
        if (method === "GET"    && path === "/admin/posts")             return attachCorrelation(await listPosts(authorID, ctx), correlationId);
        if (method === "GET"    && path === "/admin/posts/{postId}")    return attachCorrelation(await getPost(postId, ctx), correlationId);
        if (method === "PUT"    && path === "/admin/posts/{postId}")    return attachCorrelation(await updatePost(postId, body, ctx), correlationId);
        if (method === "DELETE" && path === "/admin/posts/{postId}")    return attachCorrelation(await deletePost(postId, ctx), correlationId);
        if (method === "POST"   && path.endsWith("/publish"))           return attachCorrelation(await publishPost(postId, ctx), correlationId);
        if (method === "POST"   && path.endsWith("/unpublish"))         return attachCorrelation(await unpublishPost(postId, ctx), correlationId);
        if (method === "POST"   && path.endsWith("/archive"))           return attachCorrelation(await archivePost(postId, ctx), correlationId);

        log("WARN", "route_not_found", { statusCode: 404 });
        return attachCorrelation(response(404, { message: "Route not found" }), correlationId);

    } catch (err) {
        const { statusCode, message } = classifyError(err);
        log("ERROR", "request_failed", {
            errorType: err?.name,
            errorMessage: err?.message,
            statusCode,
            durationMs: Date.now() - startedAt
        });
        return attachCorrelation(response(statusCode, { message }), correlationId);

    } finally {
        log("INFO", "request_end", { durationMs: Date.now() - startedAt });
    }
}

// ─── Route Handlers ───────────────────────────────────────────────────────────

async function createPost(data, authorID, { log, correlationId } = {}) {
    log("INFO", "create_post_start", { authorID });

    const mainImageKey = normalizeObjectKey(data.mainImageKey || "");
    const mediaKeys = buildMediaKeys(data);

    const post = {
        postID: randomUUID(),
        authorID,
        title: data.title,
        content: data.content,
        mainImageKey: mainImageKey || null,
        mediaKeys,
        status: "DRAFT",
        createdAt: now(),
        updatedAt: now(),
    };

    await ddb.send(new PutCommand({ TableName: TABLE, Item: post }));
    log("INFO", "create_post_success", { postID: post.postID });

    return response(201, post);
}

async function listPosts(authorID, { log, correlationId } = {}) {
    log("INFO", "list_posts_start", { authorID });

    const result = await ddb.send(
        new QueryCommand({
            TableName: TABLE,
            IndexName: "authorIDIndex",
            KeyConditionExpression: "authorID = :a",
            ExpressionAttributeValues: { ":a": authorID },
            ScanIndexForward: false
        })
    );

    log("INFO", "list_posts_success", { authorID, count: result.Items.length });
    return response(200, result.Items);
}

async function getPost(postId, { log, correlationId } = {}) {
    log("INFO", "get_post_start", { postID: postId });

    const result = await ddb.send(
        new GetCommand({ TableName: TABLE, Key: { postID: postId } })
    );

    if (!result.Item) {
        log("WARN", "get_post_not_found", { postID: postId });
        return response(404, { message: "Post not found" });
    }

    log("INFO", "get_post_success", { postID: postId });
    return response(200, result.Item);
}

async function updatePost(postId, data, { log, correlationId } = {}) {
    log("INFO", "update_post_start", { postID: postId });

    const mainImageKey = normalizeObjectKey(data.mainImageKey || "");
    const mediaKeys = buildMediaKeys(data);

    await ddb.send(
        new UpdateCommand({
            TableName: TABLE,
            Key: { postID: postId },
            UpdateExpression: `
                SET title = :t,
                    content = :c,
                    mainImageKey = :m,
                    mediaKeys = :k,
                    updatedAt = :u
            `,
            ConditionExpression: "#s IN (:draft, :unpublished)",
            ExpressionAttributeNames: { "#s": "status" },
            ExpressionAttributeValues: {
                ":t": data.title,
                ":c": data.content,
                ":m": mainImageKey || null,
                ":k": mediaKeys,
                ":u": now(),
                ":draft": "DRAFT",
                ":unpublished": "UNPUBLISHED"
            }
        })
    );

    log("INFO", "update_post_success", { postID: postId });
    return response(200, { message: "Updated" });
}

async function publishPost(postId, { log, correlationId } = {}) {
    log("INFO", "publish_post_start", { postID: postId });

    await ddb.send(
        new UpdateCommand({
            TableName: TABLE,
            Key: { postID: postId },
            UpdateExpression: "SET #s = :p, publishedAt = :pa, updatedAt = :u",
            ConditionExpression: "#s IN (:draft, :unpublished)",
            ExpressionAttributeNames: { "#s": "status" },
            ExpressionAttributeValues: {
                ":p": "PUBLISHED",
                ":pa": now(),
                ":u": now(),
                ":draft": "DRAFT",
                ":unpublished": "UNPUBLISHED"
            }
        })
    );

    log("INFO", "publish_post_success", { postID: postId });
    return response(200, { message: "Published" });
}

async function unpublishPost(postId, { log, correlationId } = {}) {
    log("INFO", "unpublish_post_start", { postID: postId });

    await ddb.send(
        new UpdateCommand({
            TableName: TABLE,
            Key: { postID: postId },
            UpdateExpression: "SET #s = :u, updatedAt = :t",
            ConditionExpression: "#s = :p",
            ExpressionAttributeNames: { "#s": "status" },
            ExpressionAttributeValues: {
                ":u": "UNPUBLISHED",
                ":p": "PUBLISHED",
                ":t": now()
            }
        })
    );

    log("INFO", "unpublish_post_success", { postID: postId });
    return response(200, { message: "Unpublished" });
}

async function archivePost(postId, { log, correlationId } = {}) {
    log("INFO", "archive_post_start", { postID: postId });

    await ddb.send(
        new UpdateCommand({
            TableName: TABLE,
            Key: { postID: postId },
            UpdateExpression: "SET #s = :a, updatedAt = :t",
            ExpressionAttributeNames: { "#s": "status" },
            ExpressionAttributeValues: { ":a": "ARCHIVED", ":t": now() }
        })
    );

    log("INFO", "archive_post_success", { postID: postId });
    return response(200, { message: "Archived" });
}

async function deletePost(postId, { log, correlationId } = {}) {
    log("INFO", "delete_post_start", { postID: postId });

    const { Item: post } = await ddb.send(
        new GetCommand({ TableName: TABLE, Key: { postID: postId } })
    );

    if (!post) {
        log("WARN", "delete_post_not_found", { postID: postId });
        return response(404, { message: "Post not found" });
    }

    await ddb.send(new DeleteCommand({ TableName: TABLE, Key: { postID: postId } }));
    log("INFO", "delete_post_success", { postID: postId });

    // EventBridge is best-effort: the post is already deleted so we never fail
    // the request, but we log loudly so ops can trigger manual S3 cleanup.
    // correlationId is included in the event Detail so the downstream cleanup
    // Lambda can use it in its own logger and keep the trace connected.
    try {
        await eventbridge.send(
            new PutEventsCommand({
                Entries: [
                    {
                        Source: "app.cleanup",
                        DetailType: "PostDeleted",
                        Detail: JSON.stringify({
                            postID: postId,
                            mainImageKey: post.mainImageKey,
                            mediaKeys: post.mediaKeys,
                            correlationId
                        }),
                        EventBusName: process.env.EVENT_BUS_NAME
                    }
                ]
            })
        );
        log("INFO", "eventbridge_emitted", {
            detailType: "PostDeleted",
            postID: postId,
            correlationId
        });
    } catch (err) {
        log("ERROR", "eventbridge_failed", {
            errorType: err.name,
            errorMessage: err.message,
            postID: postId,
            mediaKeys: post.mediaKeys,
            correlationId
        });
    }

    return response(204);
}

// ─── Response Helpers ─────────────────────────────────────────────────────────
function response(statusCode, body, extraHeaders = {}) {
    return {
        statusCode,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers":
                "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token,x-correlation-id",
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
            ...extraHeaders
        },
        body: body ? JSON.stringify(body) : null
    };
}

function attachCorrelation(resp, correlationId) {
    return {
        ...resp,
        headers: { ...resp.headers, "x-correlation-id": correlationId }
    };
}

module.exports = { handler };
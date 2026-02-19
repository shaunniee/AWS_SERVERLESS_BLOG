const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, GetCommand, UpdateCommand, QueryCommand, DeleteCommand } = require("@aws-sdk/lib-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Automatically traces every DynamoDB + EventBridge call with duration/errors.
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const AWSXRay = require("aws-xray-sdk");
const { captureAWSv3Client } = AWSXRay;

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
        ...extra,
      })
    );
  };
}

// ─── Error Classifier ─────────────────────────────────────────────────────────
// Maps DynamoDB exception names to meaningful HTTP status codes.
// Prevents ConditionalCheckFailedException (business logic) from becoming a 500
// alongside actual infrastructure failures — keeps alarms and logs actionable.
function classifyError(err) {
  if (err.name === "ConditionalCheckFailedException")
    return { statusCode: 409, message: "Post is not in a valid state for this operation" };
  if (err.name === "ResourceNotFoundException")
    return { statusCode: 503, message: "Database resource unavailable" };
  if (err.name === "ProvisionedThroughputExceededException" || err.name === "RequestLimitExceeded")
    return { statusCode: 503, message: "Service temporarily unavailable, please retry" };
  if (err.name === "ValidationException")
    return { statusCode: 400, message: "Invalid request data" };
  return { statusCode: 500, message: "Internal server error" };
}

// ─── X-Ray Helpers ────────────────────────────────────────────────────────────
// Wraps an async fn in a named subsegment on the current segment.
//
// correlationId is stamped as an annotation on every subsegment so you can
// filter the complete nested waterfall for a single request in X-Ray console:
//   Annotations.correlationId = "abc-123"
//
// Annotations  → indexed, searchable (strings/numbers/booleans only)
// Metadata     → richer context (any JSON, not indexed)
//
// On error, sub.addError() marks the subsegment as faulted before re-throwing
// so the X-Ray service map correctly colours the node red.
async function withSubsegment(name, annotations = {}, fn, correlationId) {
  const segment = AWSXRay.resolveSegment();
  const sub = segment.addNewSubsegment(name);

  // correlationId first so it's always present even if annotations throws
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
    sub.addError(err); // marks subsegment as faulted in service map
    sub.close();
    throw err;         // propagate so classifyError() in handler() handles it
  }
}

// ─── Media Key Helpers ────────────────────────────────────────────────────────
const normalizeObjectKey = (value = "") => String(value).replace(/^\/+/, "").trim();

const extractMediaKeysFromContent = (content = "") => {
  const regex = /]+src=["']([^"']+)["'][^>]*>/gi;
  const keys = [];
  let match;
  while ((match = regex.exec(content)) !== null) {
    const src = normalizeObjectKey(match[1] || "");
    const isAbsolute =
      src.startsWith("http://") || src.startsWith("https://") || src.startsWith("data:");
    if (src && !isAbsolute) keys.push(src);
  }
  return keys;
};

const buildMediaKeys = (data = {}) => {
  const inlineKeys = extractMediaKeysFromContent(data.content || "");
  const providedKeys = Array.isArray(data.mediaKeys)
    ? data.mediaKeys.map((v) => normalizeObjectKey(v)).filter(Boolean)
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

  const log = makeLogger({ service: "admin_blog_posts", requestId, correlationId, method, path });

  // ctx is passed to every route handler so they all share the same
  // correlationId and log instance — keeping all log lines tied together.
  const ctx = { log, correlationId };

  // ── Annotate the root Lambda segment so every trace is filterable by
  //    route, correlationId, and authorID in the X-Ray console.
  try {
    const rootSegment = AWSXRay.resolveSegment();
    rootSegment.addAnnotation("route", `${method} ${path}`);
    rootSegment.addAnnotation("correlationId", correlationId);
    rootSegment.addAnnotation("authorID", authorID);
    rootSegment.addMetadata("requestContext", {
      requestId,
      correlationId,
      method,
      path,
      postId: postId ?? null,
    });
  } catch (_) {
    // resolveSegment() throws outside a traced context (unit tests, CI).
    // Safe to swallow — tracing is non-critical infrastructure.
  }

  try {
    log("INFO", "request_start");

    if (method === "POST" && path === "/admin/posts")
      return attachCorrelation(await createPost(body, authorID, ctx), correlationId);
    if (method === "GET" && path === "/admin/posts")
      return attachCorrelation(await listPosts(authorID, ctx), correlationId);
    if (method === "GET" && path === "/admin/posts/{postId}")
      return attachCorrelation(await getPost(postId, ctx), correlationId);
    if (method === "PUT" && path === "/admin/posts/{postId}")
      return attachCorrelation(await updatePost(postId, body, ctx), correlationId);
    if (method === "DELETE" && path === "/admin/posts/{postId}")
      return attachCorrelation(await deletePost(postId, ctx), correlationId);
    if (method === "POST" && path.endsWith("/publish"))
      return attachCorrelation(await publishPost(postId, ctx), correlationId);
    if (method === "POST" && path.endsWith("/unpublish"))
      return attachCorrelation(await unpublishPost(postId, ctx), correlationId);
    if (method === "POST" && path.endsWith("/archive"))
      return attachCorrelation(await archivePost(postId, ctx), correlationId);

    log("WARN", "route_not_found", { statusCode: 404 });
    return attachCorrelation(response(404, { message: "Route not found" }), correlationId);
  } catch (err) {
    const { statusCode, message } = classifyError(err);
    log("ERROR", "request_failed", {
      errorType: err?.name,
      errorMessage: err?.message,
      statusCode,
      durationMs: Date.now() - startedAt,
    });
    return attachCorrelation(response(statusCode, { message }), correlationId);
  } finally {
    log("INFO", "request_end", { durationMs: Date.now() - startedAt });
  }
}

// ─── Route Handlers ───────────────────────────────────────────────────────────

async function createPost(data, authorID, { log, correlationId } = {}) {
  return withSubsegment("createPost", { authorID }, async (sub) => {
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

    await withSubsegment("ddb.putPost", { postID: post.postID }, async () => {
      await ddb.send(new PutCommand({ TableName: TABLE, Item: post }));
    }, correlationId);

    sub.addAnnotation("postID", post.postID);
    sub.addMetadata("post", {
      postID: post.postID,
      title: post.title,
      mediaKeyCount: mediaKeys.length,
    });

    log("INFO", "create_post_success", { postID: post.postID });
    return response(201, post);
  }, correlationId);
}

async function listPosts(authorID, { log, correlationId } = {}) {
  return withSubsegment("listPosts", { authorID }, async (sub) => {
    log("INFO", "list_posts_start", { authorID });

    let result;
    await withSubsegment("ddb.queryByAuthor", { authorID }, async () => {
      result = await ddb.send(
        new QueryCommand({
          TableName: TABLE,
          IndexName: "authorIDIndex",
          KeyConditionExpression: "authorID = :a",
          ExpressionAttributeValues: { ":a": authorID },
          ScanIndexForward: false,
        })
      );
    }, correlationId);

    sub.addMetadata("result", { count: result.Items.length });
    log("INFO", "list_posts_success", { authorID, count: result.Items.length });
    return response(200, result.Items);
  }, correlationId);
}

async function getPost(postId, { log, correlationId } = {}) {
  return withSubsegment("getPost", { postID: postId }, async (sub) => {
    log("INFO", "get_post_start", { postID: postId });

    let result;
    await withSubsegment("ddb.getPost", { postID: postId }, async () => {
      result = await ddb.send(
        new GetCommand({ TableName: TABLE, Key: { postID: postId } })
      );
    }, correlationId);

    if (!result.Item) {
      sub.addAnnotation("found", false);
      log("WARN", "get_post_not_found", { postID: postId });
      return response(404, { message: "Post not found" });
    }

    sub.addAnnotation("found", true);
    log("INFO", "get_post_success", { postID: postId });
    return response(200, result.Item);
  }, correlationId);
}

async function updatePost(postId, data, { log, correlationId } = {}) {
  return withSubsegment("updatePost", { postID: postId }, async (sub) => {
    log("INFO", "update_post_start", { postID: postId });

    const mainImageKey = normalizeObjectKey(data.mainImageKey || "");
    const mediaKeys = buildMediaKeys(data);

    sub.addMetadata("update", { mediaKeyCount: mediaKeys.length, hasMainImage: !!mainImageKey });

    await withSubsegment("ddb.updatePost", { postID: postId }, async () => {
      await ddb.send(
        new UpdateCommand({
          TableName: TABLE,
          Key: { postID: postId },
          UpdateExpression: `SET title = :t, content = :c, mainImageKey = :m, mediaKeys = :k, updatedAt = :u`,
          ConditionExpression: "#s IN (:draft, :unpublished)",
          ExpressionAttributeNames: { "#s": "status" },
          ExpressionAttributeValues: {
            ":t": data.title,
            ":c": data.content,
            ":m": mainImageKey || null,
            ":k": mediaKeys,
            ":u": now(),
            ":draft": "DRAFT",
            ":unpublished": "UNPUBLISHED",
          },
        })
      );
    }, correlationId);

    log("INFO", "update_post_success", { postID: postId });
    return response(200, { message: "Updated" });
  }, correlationId);
}

async function publishPost(postId, { log, correlationId } = {}) {
  return withSubsegment("publishPost", { postID: postId }, async () => {
    log("INFO", "publish_post_start", { postID: postId });

    await withSubsegment("ddb.publishPost", { postID: postId }, async () => {
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
            ":unpublished": "UNPUBLISHED",
          },
        })
      );
    }, correlationId);

    log("INFO", "publish_post_success", { postID: postId });
    return response(200, { message: "Published" });
  }, correlationId);
}

async function unpublishPost(postId, { log, correlationId } = {}) {
  return withSubsegment("unpublishPost", { postID: postId }, async () => {
    log("INFO", "unpublish_post_start", { postID: postId });

    await withSubsegment("ddb.unpublishPost", { postID: postId }, async () => {
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
            ":t": now(),
          },
        })
      );
    }, correlationId);

    log("INFO", "unpublish_post_success", { postID: postId });
    return response(200, { message: "Unpublished" });
  }, correlationId);
}

async function archivePost(postId, { log, correlationId } = {}) {
  return withSubsegment("archivePost", { postID: postId }, async () => {
    log("INFO", "archive_post_start", { postID: postId });

    await withSubsegment("ddb.archivePost", { postID: postId }, async () => {
      await ddb.send(
        new UpdateCommand({
          TableName: TABLE,
          Key: { postID: postId },
          UpdateExpression: "SET #s = :a, updatedAt = :t",
          ExpressionAttributeNames: { "#s": "status" },
          ExpressionAttributeValues: { ":a": "ARCHIVED", ":t": now() },
        })
      );
    }, correlationId);

    log("INFO", "archive_post_success", { postID: postId });
    return response(200, { message: "Archived" });
  }, correlationId);
}

async function deletePost(postId, { log, correlationId } = {}) {
  return withSubsegment("deletePost", { postID: postId }, async (sub) => {
    log("INFO", "delete_post_start", { postID: postId });

    let post;
    await withSubsegment("ddb.getPost", { postID: postId }, async () => {
      const { Item } = await ddb.send(
        new GetCommand({ TableName: TABLE, Key: { postID: postId } })
      );
      post = Item;
    }, correlationId);

    if (!post) {
      sub.addAnnotation("found", false);
      log("WARN", "delete_post_not_found", { postID: postId });
      return response(404, { message: "Post not found" });
    }

    await withSubsegment("ddb.deletePost", { postID: postId }, async () => {
      await ddb.send(new DeleteCommand({ TableName: TABLE, Key: { postID: postId } }));
    }, correlationId);

    log("INFO", "delete_post_success", { postID: postId });

    // EventBridge is best-effort: the post is already deleted so we never fail
    // the request, but we log loudly so ops can trigger manual S3 cleanup.
    // correlationId is included in the event Detail so the downstream cleanup
    // Lambda can use it in its own logger and keep the trace connected.
    try {
      await withSubsegment(
        "eventbridge.putEvents",
        { postID: postId, detailType: "PostDeleted" },
        async (ebSub) => {
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
                    correlationId,
                  }),
                  EventBusName: process.env.EVENT_BUS_NAME,
                },
              ],
            })
          );
          ebSub.addMetadata("event", {
            postID: postId,
            mediaKeyCount: post.mediaKeys?.length ?? 0,
          });
        },
        correlationId
      );

      log("INFO", "eventbridge_emitted", {
        detailType: "PostDeleted",
        postID: postId,
        correlationId,
      });
    } catch (err) {
      // EventBridge subsegment already recorded the error via addError() in
      // withSubsegment — no need to re-annotate here. Just log for ops.
      log("ERROR", "eventbridge_failed", {
        errorType: err.name,
        errorMessage: err.message,
        postID: postId,
        mediaKeys: post.mediaKeys,
        correlationId,
      });
    }

    return response(204);
  }, correlationId);
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
      ...extraHeaders,
    },
    body: body ? JSON.stringify(body) : null,
  };
}

function attachCorrelation(resp, correlationId) {
  return {
    ...resp,
    headers: { ...resp.headers, "x-correlation-id": correlationId },
  };
}

module.exports = { handler };
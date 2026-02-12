const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  UpdateCommand,
  QueryCommand,
  DeleteCommand
} = require("@aws-sdk/lib-dynamodb");
const { randomUUID } = require("crypto");

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);

const TABLE = process.env.POSTS_TABLE;

const now = () => Date.now();

const normalizeObjectKey = (value = "") => String(value).replace(/^\/+/, "").trim();

const extractMediaKeysFromContent = (content = "") => {
  const regex = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi;
  const keys = [];
  let match;

  while ((match = regex.exec(content)) !== null) {
    const src = normalizeObjectKey(match[1] || "");
    const isAbsolute = src.startsWith("http://") || src.startsWith("https://") || src.startsWith("data:");
    if (src && !isAbsolute) {
      keys.push(src);
    }
  }

  return keys;
};

const buildMediaKeys = (data = {}) => {
  const inlineKeys = extractMediaKeysFromContent(data.content || "");
  const providedKeys = Array.isArray(data.mediaKeys)
    ? data.mediaKeys.map((value) => normalizeObjectKey(value)).filter(Boolean)
    : [];
  const mainImageKey = normalizeObjectKey(data.mainImageKey || "");

  return Array.from(new Set([...providedKeys, ...inlineKeys, ...(mainImageKey ? [mainImageKey] : [])]));
};

async function handler(event) {
  try {
    const method = event.httpMethod;
    const path = event.resource;
    const postId = event.pathParameters?.postId;
    const body = event.body ? JSON.parse(event.body) : {};
    const authorID = event.requestContext.authorizer.claims.sub;

    // ROUTER
    if (method === "POST" && path === "/admin/posts") return await createPost(body, authorID);
    if (method === "GET" && path === "/admin/posts") return await listPosts(authorID);
    if (method === "GET" && path === "/admin/posts/{postId}") return await getPost(postId);
    if (method === "PUT" && path === "/admin/posts/{postId}") return await updatePost(postId, body);
    if (method === "DELETE" && path === "/admin/posts/{postId}") return await deletePost(postId);
    if (method === "POST" && path.endsWith("/publish")) return await publishPost(postId);
    if (method === "POST" && path.endsWith("/unpublish")) return await unpublishPost(postId);
    if (method === "POST" && path.endsWith("/archive")) return await archivePost(postId);

    return response(404, { message: "Route not found" });
  } catch (err) {
    console.error(err);
    return response(500, { message: err.message });
  }
}

async function createPost(data, authorID) {
  const mainImageKey = normalizeObjectKey(data.mainImageKey || "");
  const mediaKeys = buildMediaKeys(data);

  const post = {
    postID: randomUUID(),
    authorID: authorID,
    title: data.title,
    content: data.content,
    mainImageKey: mainImageKey || null,
    mediaKeys,
    status: "DRAFT",
    createdAt: now(),
    updatedAt: now(),
  };

  await ddb.send(new PutCommand({ TableName: TABLE, Item: post }));

  return response(201, post);
}

async function listPosts(authorID) {
  const result = await ddb.send(
    new QueryCommand({
      TableName: TABLE,
      IndexName: "authorIDIndex",
      KeyConditionExpression: "authorID = :a",
      ExpressionAttributeValues: { ":a": authorID },
      ScanIndexForward: false
    })
  );

  return response(200, result.Items);
}

async function getPost(postId) {
  const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { postID: postId } }));

  if (!result.Item) return response(404, { message: "Post not found" });

  return response(200, result.Item);
}

async function updatePost(postId, data) {
  const mainImageKey = normalizeObjectKey(data.mainImageKey || "");
  const mediaKeys = buildMediaKeys(data);

  await ddb.send(new UpdateCommand({
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
  ExpressionAttributeNames: {
    "#s": "status"
  },
  ExpressionAttributeValues: {
    ":t": data.title,
    ":c": data.content,
    ":m": mainImageKey || null,
    ":k": mediaKeys,
    ":u": now(),
    ":draft": "DRAFT",
    ":unpublished": "UNPUBLISHED"
  }
}));

  return response(200, { message: "Updated" });
}

async function publishPost(postId) {
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

  return response(200, { message: "Published" });
}

async function unpublishPost(postId) {
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

  return response(200, { message: "Unpublished" });
}

async function archivePost(postId) {
  await ddb.send(
    new UpdateCommand({
      TableName: TABLE,
      Key: { postID: postId },
      UpdateExpression: "SET #s = :a, updatedAt = :t",
      ExpressionAttributeNames: { "#s": "status" },
      ExpressionAttributeValues: { ":a": "ARCHIVED", ":t": now() }
    })
  );

  return response(200, { message: "Archived" });
}

async function deletePost(postId) {
  await ddb.send(new DeleteCommand({ TableName: TABLE, Key: { postID: postId } }));
  return response(204);
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token",
      "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS"
    },
    body: body ? JSON.stringify(body) : null
  };
}

// Export the Lambda handler
module.exports = { handler };

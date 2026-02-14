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

async function handler(event) {
  try {
    const method = event.httpMethod;
    const path = event.resource;
    const postId = event.pathParameters?.postId;
    const body = event.body ? JSON.parse(event.body) : {};
    const authorID = event.requestContext.authorizer.claims.sub;
    const idempotencyKey = body.idempotencyKey || null;

    // ROUTER
    if (method === "POST" && path === "/admin/posts") {
      return await createPost(body, authorID, idempotencyKey);
    }

    if (method === "GET" && path === "/admin/posts") {
      return await listPosts(authorID);
    }

    if (method === "GET" && path === "/admin/posts/{postId}") {
      return await getPost(postId);
    }

    if (method === "PUT" && path === "/admin/posts/{postId}") {
      return await updatePost(postId, body);
    }

    if (method === "DELETE" && path === "/admin/posts/{postId}") {
      return await deletePost(postId);
    }

    if (method === "POST" && path.endsWith("/publish")) {
      return await publishPost(postId);
    }

    if (method === "POST" && path.endsWith("/unpublish")) {
      return await unpublishPost(postId);
    }

    if (method === "POST" && path.endsWith("/archive")) {
      return await archivePost(postId);
    }

    return response(404, { message: "Route not found" });

  } catch (err) {
    console.error(err);
    return response(500, { message: err.message });
  }
}

async function createPost(data, authorID, idempotencyKey) {
  if (idempotencyKey) {
    // Check if a post with this idempotency key already exists
    const existing = await ddb.send(new QueryCommand({
      TableName: TABLE,
      IndexName: "idempotencyKeyIndex",
      KeyConditionExpression: "idempotencyKey = :key",
      ExpressionAttributeValues: { ":key": idempotencyKey },
      Limit: 1
    }));

    if (existing.Items && existing.Items.length > 0) {
      return response(200, existing.Items[0]);
    }
  }

  const post = {
    postID: randomUUID(),
    authorID,
    title: data.title,
    content: data.content,
    status: "DRAFT",
    createdAt: now(),
    updatedAt: now(),
    idempotencyKey: idempotencyKey || null
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
  const result = await ddb.send(
    new GetCommand({ TableName: TABLE, Key: { postID: postId } })
  );

  if (!result.Item) return response(404, { message: "Post not found" });

  return response(200, result.Item);
}

async function updatePost(postId, data) {
  await ddb.send(
    new UpdateCommand({
      TableName: TABLE,
      Key: { postID: postId },
      UpdateExpression: `
        SET title = :t,
            content = :c,
            updatedAt = :u
      `,
      ConditionExpression: "#s IN (:draft, :unpublished)",
      ExpressionAttributeNames: { "#s": "status" },
      ExpressionAttributeValues: {
        ":t": data.title,
        ":c": data.content,
        ":u": now(),
        ":draft": "DRAFT",
        ":unpublished": "UNPUBLISHED"
      }
    })
  );

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
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : null
  };
}

module.exports = { handler };

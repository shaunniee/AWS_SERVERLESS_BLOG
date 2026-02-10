import {
  DynamoDBClient
} from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  UpdateCommand,
  QueryCommand,
  DeleteCommand
} from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "crypto";

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);

const TABLE = process.env.POSTS_TABLE;

const now = () => new Date().toISOString();

export const handler = async (event) => {
  try {
    const method = event.httpMethod;
    const path = event.resource;
    const postId = event.pathParameters?.postId;
    const body = event.body ? JSON.parse(event.body) : {};
    const authorID = event.requestContext.authorizer.claims.sub;

    // ROUTER
    if (method === "POST" && path === "/admin/posts") {
      return createPost(body, authorID);
    }

    if (method === "GET" && path === "/admin/posts") {
      return listPosts(authorID);
    }

    if (method === "GET" && path === "/admin/posts/{postId}") {
      return getPost(postId);
    }

    if (method === "PUT" && path === "/admin/posts/{postId}") {
      return updatePost(postId, body);
    }

    if (method === "DELETE" && path === "/admin/posts/{postId}") {
      return deletePost(postId);
    }

    if (method === "POST" && path.endsWith("/publish")) {
      return publishPost(postId);
    }

    if (method === "POST" && path.endsWith("/unpublish")) {
      return unpublishPost(postId);
    }

    if (method === "POST" && path.endsWith("/archive")) {
      return archivePost(postId);
    }

    return response(404, { message: "Route not found" });

  } catch (err) {
    console.error(err);
    return response(500, { message: err.message });
  }
};

async function createPost(data, authorID) {
  const post = {
    postId: randomUUID(),
    authorID,
    title: data.title,
    content: data.content,
    status: "DRAFT",
    createdAt: now(),
    updatedAt: now(),
    publishedAt: null
  };

  await ddb.send(new PutCommand({
    TableName: TABLE,
    Item: post
  }));

  return response(201, post);
}


async function listPosts(authorID) {
  const result = await ddb.send(new QueryCommand({
    TableName: TABLE,
    IndexName: "authorIDIndex",
    KeyConditionExpression: "authorID = :a",
    ExpressionAttributeValues: {
      ":a": authorID
    },
    ScanIndexForward: false
  }));

  return response(200, result.Items);
}


async function getPost(postId) {
  const result = await ddb.send(new GetCommand({
    TableName: TABLE,
    Key: { postId }
  }));

  if (!result.Item) {
    return response(404, { message: "Post not found" });
  }

  return response(200, result.Item);
}

async function updatePost(postId, data) {
  await ddb.send(new UpdateCommand({
    TableName: TABLE,
    Key: { postId },
    UpdateExpression: `
      SET title = :t,
          content = :c,
          updatedAt = :u
    `,
    ConditionExpression: "status IN (:draft, :unpublished)",
    ExpressionAttributeValues: {
      ":t": data.title,
      ":c": data.content,
      ":u": now(),
      ":draft": "DRAFT",
      ":unpublished": "UNPUBLISHED"
    }
  }));

  return response(200, { message: "Updated" });
}

async function publishPost(postId) {
  await ddb.send(new UpdateCommand({
    TableName: TABLE,
    Key: { postId },
    UpdateExpression: `
      SET #s = :p,
          publishedAt = :pa,
          updatedAt = :u
    `,
    ConditionExpression: "#s IN (:draft, :unpublished)",
    ExpressionAttributeNames: {
      "#s": "status"
    },
    ExpressionAttributeValues: {
      ":p": "PUBLISHED",
      ":pa": now(),
      ":u": now(),
      ":draft": "DRAFT",
      ":unpublished": "UNPUBLISHED"
    }
  }));

  return response(200, { message: "Published" });
}


async function unpublishPost(postId) {
  await ddb.send(new UpdateCommand({
    TableName: TABLE,
    Key: { postId },
    UpdateExpression: `
      SET #s = :u,
          updatedAt = :t
    `,
    ConditionExpression: "#s = :p",
    ExpressionAttributeNames: {
      "#s": "status"
    },
    ExpressionAttributeValues: {
      ":u": "UNPUBLISHED",
      ":p": "PUBLISHED",
      ":t": now()
    }
  }));

  return response(200, { message: "Unpublished" });
}


async function archivePost(postId) {
  await ddb.send(new UpdateCommand({
    TableName: TABLE,
    Key: { postId },
    UpdateExpression: `
      SET #s = :a,
          updatedAt = :t
    `,
    ExpressionAttributeNames: {
      "#s": "status"
    },
    ExpressionAttributeValues: {
      ":a": "ARCHIVED",
      ":t": now()
    }
  }));

  return response(200, { message: "Archived" });
}


async function deletePost(postId) {
  await ddb.send(new DeleteCommand({
    TableName: TABLE,
    Key: { postId }
  }));

  return response(204);
}


function response(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : null
  };
}

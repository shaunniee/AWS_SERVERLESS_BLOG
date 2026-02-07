const {
  DynamoDBClient,
  PutItemCommand,
  GetItemCommand,
  UpdateItemCommand,
  DeleteItemCommand
} = require("@aws-sdk/client-dynamodb");

const { randomUUID } = require("crypto");

const client = new DynamoDBClient({});
const TABLE = process.env.POSTS_TABLE;

const now = () => Math.floor(Date.now() / 1000);

exports.handler = async (event) => {
  try {
    const method = event.httpMethod;
    const path = event.resource;
    const postId = event.pathParameters?.id;
    const body = event.body ? JSON.parse(event.body) : {};

    // CREATE
    if (method === "POST" && path === "/admin/posts") {
      return createPost(body, event);
    }

    // UPDATE
    if (method === "PUT" && path === "/admin/posts/{id}") {
      return updatePost(postId, body);
    }

    // PUBLISH
    if (method === "POST" && path === "/admin/posts/{id}/publish") {
      return changeStatus(postId, "PUBLISHED");
    }

    // UNPUBLISH
    if (method === "POST" && path === "/admin/posts/{id}/unpublish") {
      return changeStatus(postId, "UNPUBLISHED");
    }

    // ARCHIVE
    if (method === "POST" && path === "/admin/posts/{id}/archive") {
      return changeStatus(postId, "ARCHIVED");
    }

    // DELETE
    if (method === "DELETE" && path === "/admin/posts/{id}") {
      return deletePost(postId);
    }

    return response(404, "Route not found");
  } catch (err) {
    console.error(err);
    return response(500, "Internal server error");
  }
};

/////////////////////
// Handlers
/////////////////////

async function createPost(body, event) {
  if (!body.title || !body.content) {
    return response(400, "title and content required");
  }

  const postId = randomUUID();
  const timestamp = now();

  const item = {
    PostID: { S: postId },
    Title: { S: body.title },
    Content: { S: body.content },
    Status: { S: "DRAFT" },
    AuthorID: { S: event.requestContext.authorizer.claims.sub },
    CreatedAt: { N: timestamp.toString() },
    EditedAt: { N: timestamp.toString() }
  };

  if (body.mainImageKey) {
    item.MainImageKey = { S: body.mainImageKey };
  }

  if (Array.isArray(body.imageKeys)) {
    item.ImageKeys = {
      L: body.imageKeys.map(k => ({ S: k }))
    };
  }

  await client.send(new PutItemCommand({
    TableName: TABLE,
    Item: item
  }));

  return response(201, { postId });
}

async function updatePost(postId, body) {
  if (!postId) return response(400, "PostID required");

  const existing = await getPost(postId);
  if (!existing) return response(404, "Post not found");
  if (existing.Status.S === "ARCHIVED") {
    return response(400, "Archived posts cannot be edited");
  }

  const updates = [];
  const values = {};
  const names = {};

  setIf(body.title, "Title", body.title, updates, names, values, "S");
  setIf(body.content, "Content", body.content, updates, names, values, "S");
  setIf(body.mainImageKey, "MainImageKey", body.mainImageKey, updates, names, values, "S");

  if (Array.isArray(body.imageKeys)) {
    names["#ImageKeys"] = "ImageKeys";
    values[":ImageKeys"] = {
      L: body.imageKeys.map(k => ({ S: k }))
    };
    updates.push("#ImageKeys = :ImageKeys");
  }

  names["#EditedAt"] = "EditedAt";
  values[":EditedAt"] = { N: now().toString() };
  updates.push("#EditedAt = :EditedAt");

  await client.send(new UpdateItemCommand({
    TableName: TABLE,
    Key: { PostID: { S: postId } },
    UpdateExpression: "SET " + updates.join(", "),
    ExpressionAttributeNames: names,
    ExpressionAttributeValues: values
  }));

  return response(200, "Post updated");
}

async function changeStatus(postId, newStatus) {
  if (!postId) return response(400, "PostID required");

  const existing = await getPost(postId);
  if (!existing) return response(404, "Post not found");

  if (existing.Status.S === "ARCHIVED") {
    return response(400, "Archived posts cannot change status");
  }

  const updates = [
    "#Status = :Status",
    "#EditedAt = :EditedAt"
  ];

  const names = {
    "#Status": "Status",
    "#EditedAt": "EditedAt"
  };

  const values = {
    ":Status": { S: newStatus },
    ":EditedAt": { N: now().toString() }
  };

  if (
    newStatus === "PUBLISHED" &&
    !existing.PublishedAt
  ) {
    updates.push("#PublishedAt = :PublishedAt");
    names["#PublishedAt"] = "PublishedAt";
    values[":PublishedAt"] = { N: now().toString() };
  }

  await client.send(new UpdateItemCommand({
    TableName: TABLE,
    Key: { PostID: { S: postId } },
    UpdateExpression: "SET " + updates.join(", "),
    ExpressionAttributeNames: names,
    ExpressionAttributeValues: values
  }));

  return response(200, `Post ${newStatus.toLowerCase()}`);
}

async function deletePost(postId) {
  if (!postId) return response(400, "PostID required");

  await client.send(new DeleteItemCommand({
    TableName: TABLE,
    Key: { PostID: { S: postId } }
  }));

  // later: emit EventBridge event for image cleanup

  return response(200, "Post deleted");
}

/////////////////////
// Helpers
/////////////////////

async function getPost(postId) {
  const res = await client.send(new GetItemCommand({
    TableName: TABLE,
    Key: { PostID: { S: postId } }
  }));
  return res.Item;
}

function setIf(value, name, raw, updates, names, values, type) {
  if (!value) return;
  names[`#${name}`] = name;
  values[`:${name}`] = { [type]: raw };
  updates.push(`#${name} = :${name}`);
}

function response(code, body) {
  return {
    statusCode: code,
    body: JSON.stringify(body)
  };
}
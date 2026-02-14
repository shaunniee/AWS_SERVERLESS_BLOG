const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  QueryCommand,
  GetCommand
} = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);

const TABLE = process.env.POSTS_TABLE;

exports.handler = async (event) => {
  try {
    const method = event.httpMethod;
    const path = event.resource;
    const postId = event.pathParameters?.postId;
    const query = event.queryStringParameters || {};

    // ROUTER
    if (method === "GET" && path === "/posts") {
      return listPublishedPosts(query);
    }

    if (method === "GET" && path === "/posts/{postId}") {
      return getPublishedPost(postId);
    }

    return response(404, { message: "Route not found" });
  } catch (err) {
    console.error("Error in public read Lambda:", err);
    return response(500, { message: "Internal server error" });
  }
};

async function listPublishedPosts(query) {
  const limit = query.limit ? Number(query.limit) : 10;
  const lastKey = query.lastKey
    ? JSON.parse(Buffer.from(query.lastKey, "base64").toString())
    : undefined;

  const result = await ddb.send(
    new QueryCommand({
      TableName: TABLE,
      IndexName: "publishedAtIndex",
      KeyConditionExpression: "#s = :published",
      ExpressionAttributeNames: {
        "#s": "status"
      },
      ExpressionAttributeValues: {
        ":published": "PUBLISHED"
      },
      ScanIndexForward: false, // newest first
      Limit: limit,
      ExclusiveStartKey: lastKey
    })
  );

  return response(200, {
    items: result.Items || [],
    nextKey: result.LastEvaluatedKey
      ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString("base64")
      : null
  });
}


async function getPublishedPost(postId) {
  if (!postId) {
    return response(400, { message: "postId is required" });
  }

  const result = await ddb.send(
    new QueryCommand({
      TableName: TABLE,
      IndexName: "publishedAtIndex",
      KeyConditionExpression: "#s = :published",
      FilterExpression: "postID = :pid",
      ExpressionAttributeNames: {
        "#s": "status"
      },
      ExpressionAttributeValues: {
        ":published": "PUBLISHED",
        ":pid": postId
      },
      Limit: 1
    })
  );

  if (!result.Items || result.Items.length === 0) {
    return response(404, { message: "Post not found" });
  }

  return response(200, result.Items[0]);
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
      "Cache-Control": "public, max-age=60" // CloudFront friendly
    },
    body: JSON.stringify(body)
  };
}

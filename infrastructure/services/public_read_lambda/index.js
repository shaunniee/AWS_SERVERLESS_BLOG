import { DynamoDBClient, GetItemCommand, ScanCommand } from "@aws-sdk/client-dynamodb";

const client = new DynamoDBClient({});

export const handler = async (event) => {
  console.log("Public read lambda invoked with event:", JSON.stringify(event));
  // try {
  //   if (event.pathParameters && event.pathParameters.postId) {
  //     // GET /posts/{postId}
  //     const postId = event.pathParameters.postId;
  //     const result = await client.send(new GetItemCommand({
  //       TableName: process.env.POSTS_TABLE,
  //       Key: { postId: { S: postId } }
  //     }));

  //     if (!result.Item || result.Item.status.S !== "published") {
  //       return { statusCode: 404, body: JSON.stringify({ message: "Post not found" }) };
  //     }

  //     return { statusCode: 200, body: JSON.stringify(result.Item) };

  //   } else {
  //     // GET /posts → list all published posts
  //     const result = await client.send(new ScanCommand({
  //       TableName: process.env.POSTS_TABLE,
  //       FilterExpression: "status = :status",
  //       ExpressionAttributeValues: { ":status": { S: "published" } }
  //     }));

  //     return { statusCode: 200, body: JSON.stringify(result.Items) };
  //   }

  // } catch (err) {
  //   console.error(err);
  //   return { statusCode: 500, body: JSON.stringify({ message: "Internal server error" }) };
  // }
};
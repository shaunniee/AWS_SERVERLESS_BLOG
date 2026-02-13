const { S3Client, DeleteObjectsCommand } = require("@aws-sdk/client-s3");

const s3 = new S3Client({ region: process.env.AWS_REGION });
const BUCKET = process.env.MEDIA_BUCKET;

async function handler(event) {
  try {
    const detail = event.detail || {};
    const postId = detail.postID;
    if (!postId) return response(400, { message: "Missing postID in event detail" });

    const keysToDelete = [
      ...(detail.mainImageKey ? [detail.mainImageKey] : []),
      ...(Array.isArray(detail.mediaKeys) ? detail.mediaKeys : [])
    ];

    if (keysToDelete.length === 0) {
      console.log(`No media to delete for postID: ${postId}`);
      return response(200, { message: "No media found to delete" });
    }

    const deleteParams = {
      Bucket: BUCKET,
      Delete: {
        Objects: keysToDelete.map((Key) => ({ Key })),
        Quiet: true
      }
    };
    await s3.send(new DeleteObjectsCommand(deleteParams));

    console.log(`Deleted media for postID: ${postId}`, keysToDelete);
    return response(200, { message: "Media deleted successfully", deleted: keysToDelete });
  } catch (err) {
    console.error(err);
    return response(500, { message: err.message });
  }
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  };
}

module.exports = { handler };

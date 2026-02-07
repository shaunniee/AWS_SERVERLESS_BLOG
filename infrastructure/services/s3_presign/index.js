const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { randomUUID } = require("crypto");

const s3 = new S3Client({});
const BUCKET = process.env.MEDIA_BUCKET;

exports.handler = async (event) => {
  try {
    const body = JSON.parse(event.body || "{}");

    if (!body.postId || !body.contentType) {
      return response(400, "postId and contentType are required");
    }

    // Optional safety check
    if (!body.contentType.startsWith("image/")) {
      return response(400, "Only image uploads are allowed");
    }

    const extension = body.contentType.split("/")[1];
    const key = `posts/${body.postId}/${randomUUID()}.${extension}`;

    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      ContentType: body.contentType
    });

    const uploadUrl = await getSignedUrl(s3, command, {
      expiresIn: 300 // 5 minutes
    });

    return {
      statusCode: 200,
      body: JSON.stringify({
        uploadUrl,
        key
      })
    };
  } catch (err) {
    console.error(err);
    return response(500, "Failed to generate upload URL");
  }
};

function response(statusCode, message) {
  return {
    statusCode,
    body: JSON.stringify({ message })
  };
}
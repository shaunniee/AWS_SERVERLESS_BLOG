const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { randomUUID } = require("crypto");

const s3 = new S3Client({});

const BUCKET = process.env.MEDIA_BUCKET;
const EXPIRY = Number(process.env.UPLOAD_EXPIRY_SECONDS || 300);

const getExtension = (fileName = "", contentType = "") => {
  const fromName = String(fileName).split(".").pop();
  if (fromName && fromName !== fileName) return fromName.toLowerCase();

  if (contentType.includes("/")) {
    const fromType = contentType.split("/")[1];
    if (fromType) return fromType.toLowerCase();
  }

  return "jpg";
};

exports.handler = async (event) => {
  try {
    const method = event.httpMethod;
    const path = event.resource;
    const body = event.body ? JSON.parse(event.body) : {};

    // Only allow admin upload route
    if (method !== "POST" || path !== "/admin/media/upload_url") {
      return response(404, { message: "Route not found" });
    }

    const {
      fileName,
      contentType,
      folder = "media"
    } = body;

    if (!contentType) {
      return response(400, { message: "contentType is required" });
    }

    const extension = getExtension(fileName, contentType);
    const objectKey = `${folder}/${randomUUID()}.${extension}`;

    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: objectKey,
      ContentType: contentType
    });

    const uploadUrl = await getSignedUrl(s3, command, {
      expiresIn: EXPIRY
    });

    return response(200, {
      uploadUrl,
      objectKey,
      key: objectKey,
      expiresIn: EXPIRY
    });

  } catch (err) {
    console.error("Presign upload error:", err);
    return response(500, { message: err.message });
  }
};

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
    },
    body: JSON.stringify(body)
  };
}

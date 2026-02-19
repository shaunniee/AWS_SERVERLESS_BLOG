const { S3Client, DeleteObjectsCommand } = require("@aws-sdk/client-s3");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const { captureAWSv3Client } = require("aws-xray-sdk");

// ─── AWS Clients ──────────────────────────────────────────────────────────────
const s3 = captureAWSv3Client(
    new S3Client({
        region: process.env.MEDIA_BUCKET_REGION || process.env.AWS_REGION || "us-east-1"
    })
);

const BUCKET = process.env.MEDIA_BUCKET;

// ─── Cold Start Detection ─────────────────────────────────────────────────────
let isColdStart = true;

// ─── Utilities ────────────────────────────────────────────────────────────────
function makeLogger(base = {}) {
    return (level, message, extra = {}) => {
        console.log(
            JSON.stringify({
                level,
                message,
                timestamp: new Date().toISOString(),
                ...base,
                ...extra
            })
        );
    };
}

// ─── Handler ──────────────────────────────────────────────────────────────────
async function handler(event) {
    const detail = event.detail || {};

    // Inherit correlationId from the upstream admin Lambda that fired PostDeleted.
    // Falls back to EventBridge's own event.id, then a fresh UUID.
    const correlationId = detail.correlationId || event.id || randomUUID();
    const startedAt = Date.now();

    const log = makeLogger({
        service: "media_cleanup",
        correlationId,
        eventSource: event.source || null,
        eventDetailType: event["detail-type"] || null
    });

    try {
        log("INFO", "cleanup_start", {
            coldStart: isColdStart,
            postID: detail.postID || null
        });
        isColdStart = false;

        // Validate — a missing postID means the upstream event is malformed.
        // Don't re-throw, retrying won't fix a structural problem.
        if (!detail.postID) {
            log("ERROR", "cleanup_invalid_event", {
                missingFields: ["postID"],
                correlationId
            });
            return { status: "invalid_event" };
        }

        const postId = detail.postID;

        const keysToDelete = [
            ...(detail.mainImageKey ? [detail.mainImageKey] : []),
            ...(Array.isArray(detail.mediaKeys) ? detail.mediaKeys : [])
        ];

        // Deduplicate in case mainImageKey also appears in mediaKeys
        const uniqueKeys = [...new Set(keysToDelete)];

        if (uniqueKeys.length === 0) {
            log("INFO", "cleanup_no_media", { postID: postId });
            return { status: "no_media" };
        }

        log("INFO", "cleanup_deleting", {
            postID: postId,
            keyCount: uniqueKeys.length,
            correlationId
        });

        const result = await s3.send(
            new DeleteObjectsCommand({
                Bucket: BUCKET,
                Delete: {
                    Objects: uniqueKeys.map((Key) => ({ Key })),
                    Quiet: false  // Changed from true so S3 returns per-key results
                                  // allowing us to detect and log partial failures
                }
            })
        );

        // S3 DeleteObjects is partial — it can succeed overall but silently
        // fail on individual keys. With Quiet: false we get back Deleted and
        // Errors arrays so we can log exactly what failed.
        const deletedCount = result.Deleted?.length ?? 0;
        const errors = result.Errors || [];

        if (errors.length > 0) {
            log("ERROR", "cleanup_partial_failure", {
                postID: postId,
                deletedCount,
                failedCount: errors.length,
                failedKeys: errors.map((e) => ({ key: e.Key, code: e.Code, message: e.Message })),
                correlationId
            });
        } else {
            log("INFO", "cleanup_success", {
                postID: postId,
                deletedCount,
                durationMs: Date.now() - startedAt,
                correlationId
            });
        }

        return { status: "ok", deletedCount, failedCount: errors.length };

    } catch (err) {
        log("ERROR", "cleanup_failed", {
            errorType: err?.name,
            errorMessage: err?.message,
            postID: detail.postID || null,
            durationMs: Date.now() - startedAt,
            correlationId
        });

        // Re-throw so EventBridge retries — S3 errors are likely transient
        throw err;
    } finally {
        log("INFO", "cleanup_end", { durationMs: Date.now() - startedAt });
    }
}

module.exports = { handler };
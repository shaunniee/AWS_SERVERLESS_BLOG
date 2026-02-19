const { S3Client, DeleteObjectsCommand } = require("@aws-sdk/client-s3");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const AWSXRay = require("aws-xray-sdk");
const { captureAWSv3Client } = AWSXRay;

// ─── AWS Clients ──────────────────────────────────────────────────────────────
// captureAWSv3Client wraps S3Client so every DeleteObjectsCommand appears as a
// subsegment in X-Ray automatically — duration, status, and errors included.
const s3 = captureAWSv3Client(
    new S3Client({
        region: process.env.MEDIA_BUCKET_REGION || process.env.AWS_REGION || "us-east-1"
    })
);

const BUCKET = process.env.MEDIA_BUCKET;

// ─── Cold Start Detection ─────────────────────────────────────────────────────
// Annotated on root segment — filter all cold start traces in X-Ray:
//   Annotations.coldStart = true
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

// ─── X-Ray Helpers ────────────────────────────────────────────────────────────
// Wraps an async fn in a named subsegment.
// correlationId stamped as annotation on every subsegment — enables:
//   X-Ray filter: Annotations.correlationId = "abc-123"
// to surface the complete cross-service trace in one query, linking this
// cleanup Lambda back to the admin Lambda that emitted PostDeleted.
async function withSubsegment(name, annotations = {}, fn, correlationId) {
    const segment = AWSXRay.resolveSegment();
    const sub = segment.addNewSubsegment(name);

    // correlationId first — always present even if annotations loop throws
    if (correlationId) {
        sub.addAnnotation("correlationId", correlationId);
    }

    for (const [k, v] of Object.entries(annotations)) {
        sub.addAnnotation(k, v);
    }

    try {
        const result = await fn(sub);
        sub.close();
        return result;
    } catch (err) {
        sub.addError(err); // marks node red in X-Ray service map
        sub.close();
        throw err;         // re-throw so EventBridge retries transient S3 errors
    }
}

// Stamps annotations and metadata on the Lambda root segment.
// try/catch intentional — resolveSegment() throws outside Lambda traced
// context (unit tests, local runs). Tracing never fails a cleanup.
function annotateRootSegment(annotations = {}, metadata = {}) {
    try {
        const segment = AWSXRay.resolveSegment();
        for (const [k, v] of Object.entries(annotations)) {
            segment.addAnnotation(k, v);
        }
        if (Object.keys(metadata).length > 0) {
            segment.addMetadata("requestContext", metadata);
        }
    } catch (_) {}
}

// ─── Handler ──────────────────────────────────────────────────────────────────
async function handler(event) {
    const detail = event.detail || {};

    // Inherit correlationId from the upstream admin Lambda that fired PostDeleted.
    // Falls back to EventBridge's own event.id, then a fresh UUID.
    // This single ID links the cleanup trace back to the admin Lambda trace
    // in X-Ray: Annotations.correlationId = "abc-123" shows both.
    const correlationId = detail.correlationId || event.id || randomUUID();
    const startedAt = Date.now();

    // Capture before flipping — guarantees correct value regardless of
    // whether an early return or throw happens before isColdStart = false
    const coldStart = isColdStart;
    isColdStart = false;

    const log = makeLogger({
        service: "media_cleanup",
        environment: process.env.NODE_ENV,
        functionVersion: process.env.AWS_LAMBDA_FUNCTION_VERSION,
        correlationId,
        eventSource: event.source || null,
        eventDetailType: event["detail-type"] || null
    });

    // ── Annotate root segment ─────────────────────────────────────────────────
    // postID annotated so you can filter all cleanup traces for a specific post:
    //   Annotations.postID = "abc-123"
    // Useful when a user reports their deleted post still has media accessible.
    // detailType annotated for consistency with notification Lambda —
    // both are EventBridge-triggered and share the same annotation pattern.
    annotateRootSegment(
        {
            correlationId,
            service: "media-cleanup",
            environment: process.env.NODE_ENV ?? "unknown",
            detailType: event["detail-type"] ?? "unknown",
            source: event.source ?? "unknown",
            postID: detail.postID ?? null,
            coldStart,
        },
        {
            eventId: event.id ?? null,
            bucket: BUCKET,
            mainImageKey: detail.mainImageKey ?? null,
            mediaKeyCount: Array.isArray(detail.mediaKeys) ? detail.mediaKeys.length : 0,
        }
    );

    try {
        log("INFO", "cleanup_start", {
            coldStart,
            postID: detail.postID || null
        });

        // ── Validate event ────────────────────────────────────────────────────
        // Wrapped in a subsegment so structural event failures are visible
        // separately from S3 failures in X-Ray. A faulted validateEvent
        // subsegment with Annotations.valid = false means the upstream
        // producer (admin Lambda) has a bug — distinct from a faulted
        // s3.deleteObjects which means S3 is having issues.
        let postId;
        let uniqueKeys;
        await withSubsegment("validateEvent", {}, async (sub) => {
            const valid = !!detail.postID;
            sub.addAnnotation("valid", valid);

            if (!valid) {
                sub.addMetadata("validation", { missingFields: ["postID"] });
            }

            postId = detail.postID;

            const keysToDelete = [
                ...(detail.mainImageKey ? [detail.mainImageKey] : []),
                ...(Array.isArray(detail.mediaKeys) ? detail.mediaKeys : [])
            ];

            // Deduplicate in case mainImageKey also appears in mediaKeys
            uniqueKeys = [...new Set(keysToDelete)];

            sub.addAnnotation("keyCount", uniqueKeys.length);
            sub.addAnnotation("hasMainImageKey", !!detail.mainImageKey);
        }, correlationId);

        if (!postId) {
            // Log as ERROR — a missing postID means the upstream producer has
            // a bug. Not re-throwing because retrying won't fix a structural
            // event payload problem — it would just exhaust the retry budget.
            log("ERROR", "cleanup_invalid_event", {
                missingFields: ["postID"],
                correlationId
            });
            return { status: "invalid_event" };
        }

        if (uniqueKeys.length === 0) {
            log("INFO", "cleanup_no_media", { postID: postId });
            return { status: "no_media" };
        }

        log("INFO", "cleanup_deleting", {
            postID: postId,
            keyCount: uniqueKeys.length,
            correlationId
        });

        // ── S3 delete subsegment ──────────────────────────────────────────────
        // Outer subsegment captures total cleanup time including chunking logic.
        // Inner s3.deleteObjects subsegments (one per chunk) capture per-batch
        // S3 latency. SDK adds a third level automatically via captureAWSv3Client.
        // Three levels: cleanupMedia → s3.deleteObjects (chunk N) → SDK S3 call.
        let totalDeleted = 0;
        let totalErrors = [];

        await withSubsegment(
            "cleanupMedia",
            { postID: postId, keyCount: uniqueKeys.length },
            async (sub) => {
                // S3 DeleteObjects handles up to 1000 keys per call.
                // Chunk in case a post has many media keys.
                const chunks = chunkArray(uniqueKeys, 1000);

                sub.addAnnotation("chunkCount", chunks.length);
                sub.addMetadata("keys", {
                    // Do NOT store actual key values in metadata if they
                    // contain user-identifiable paths. Store count only.
                    keyCount: uniqueKeys.length,
                    chunkCount: chunks.length,
                    postID: postId,
                });

                for (const [i, chunk] of chunks.entries()) {
                    await withSubsegment(
                        "s3.deleteObjects",
                        { postID: postId, chunk: i, keyCount: chunk.length },
                        async (s3Sub) => {
                            const result = await s3.send(
                                new DeleteObjectsCommand({
                                    Bucket: BUCKET,
                                    Delete: {
                                        Objects: chunk.map((Key) => ({ Key })),
                                        // Quiet: false so S3 returns per-key Deleted
                                        // and Errors arrays — critical for detecting
                                        // partial failures that don't throw
                                        Quiet: false
                                    }
                                })
                            );

                            const deletedCount = result.Deleted?.length ?? 0;
                            const chunkErrors = result.Errors || [];

                            totalDeleted += deletedCount;
                            totalErrors = [...totalErrors, ...chunkErrors];

                            // Annotate per-chunk result on the inner subsegment
                            // so you can see which specific chunk had errors in
                            // the X-Ray waterfall — not just that errors occurred
                            s3Sub.addAnnotation("deletedCount", deletedCount);
                            s3Sub.addAnnotation("errorCount", chunkErrors.length);

                            if (chunkErrors.length > 0) {
                                // Mark subsegment with error details in metadata —
                                // key names are safe here (not PII), and having
                                // exact failed keys in the trace is critical for
                                // manual cleanup if S3 cleanup partially fails.
                                s3Sub.addMetadata("s3Errors", {
                                    errors: chunkErrors.map((e) => ({
                                        key: e.Key,
                                        code: e.Code,
                                        message: e.Message
                                    }))
                                });
                            }
                        },
                        correlationId
                    );
                }

                // Roll up totals onto outer subsegment after all chunks complete
                sub.addAnnotation("totalDeleted", totalDeleted);
                sub.addAnnotation("totalErrors", totalErrors.length);

                // Partial failure is a fault — mark it so the cleanupMedia node
                // appears red in the service map even though no exception was thrown.
                // S3 partial failures are silent without this explicit fault marking.
                if (totalErrors.length > 0) {
                    sub.addError(new Error(
                        `S3 partial failure: ${totalErrors.length} key(s) failed to delete`
                    ));
                }
            },
            correlationId
        );

        // ── Log outcome ───────────────────────────────────────────────────────
        if (totalErrors.length > 0) {
            log("ERROR", "cleanup_partial_failure", {
                postID: postId,
                deletedCount: totalDeleted,
                failedCount: totalErrors.length,
                failedKeys: totalErrors.map((e) => ({
                    key: e.Key,
                    code: e.Code,
                    message: e.Message
                })),
                correlationId
            });
        } else {
            log("INFO", "cleanup_success", {
                postID: postId,
                deletedCount: totalDeleted,
                durationMs: Date.now() - startedAt,
                correlationId
            });
        }

        return { status: "ok", deletedCount: totalDeleted, failedCount: totalErrors.length };

    } catch (err) {
        log("ERROR", "cleanup_failed", {
            errorType: err?.name,
            errorMessage: err?.message,
            postID: detail.postID || null,
            durationMs: Date.now() - startedAt,
            correlationId
        });

        // Re-throw so EventBridge retries — S3 errors are likely transient.
        // Structural event validation errors are handled above and never
        // reach this point.
        throw err;

    } finally {
        log("INFO", "cleanup_end", { durationMs: Date.now() - startedAt });
    }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
function chunkArray(arr, size) {
    const chunks = [];
    for (let i = 0; i < arr.length; i += size) {
        chunks.push(arr.slice(i, i + size));
    }
    return chunks;
}

module.exports = { handler };
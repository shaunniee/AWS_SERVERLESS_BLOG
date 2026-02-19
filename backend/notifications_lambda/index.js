const { SESClient, SendEmailCommand } = require("@aws-sdk/client-ses");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const AWSXRay = require("aws-xray-sdk");
const { captureAWSv3Client } = AWSXRay;

// ─── AWS Clients ──────────────────────────────────────────────────────────────
// captureAWSv3Client wraps SESClient so every SendEmailCommand appears as a
// subsegment in X-Ray automatically — duration, status, and errors included.
const ses = captureAWSv3Client(new SESClient({}));

const FROM = process.env.FROM_EMAIL;
const TO = process.env.TO_EMAIL;

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

// ─── Input Validator ──────────────────────────────────────────────────────────
// EventBridge events can arrive with missing or malformed fields if the
// upstream producer has a bug. Validating early gives a clear log message
// instead of SES throwing a cryptic error about a missing address.
function validateDetail(detail = {}) {
    const missing = ["name", "email", "message"].filter((f) => !detail[f]);
    if (missing.length > 0) {
        return { valid: false, missing };
    }
    return { valid: true };
}

// ─── X-Ray Helpers ────────────────────────────────────────────────────────────
// Wraps an async fn in a named subsegment.
// correlationId stamped as annotation on every subsegment — enables:
//   X-Ray filter: Annotations.correlationId = "abc-123"
// to surface the complete cross-service trace in one query.
// This Lambda is EventBridge-triggered so the correlationId comes from
// event.detail.correlationId — the same ID stamped by the upstream producer.
// That single ID links this trace back to the Admin Lambda that fired the event.
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
        throw err;         // re-throw so EventBridge retries transient failures
    }
}

// Stamps annotations and metadata on the Lambda root segment.
// try/catch intentional — resolveSegment() throws outside Lambda traced
// context (unit tests, local runs). Tracing never fails a request.
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
exports.handler = async (event) => {
    const detail = event.detail || {};

    // Prefer the correlationId embedded by the upstream producer so the full
    // trace is linked across services in X-Ray and Logs Insights.
    // Fall back to EventBridge's own event.id, then a fresh UUID.
    const correlationId = detail.correlationId || event.id || randomUUID();
    const startedAt = Date.now();

    // Capture before flipping — guarantees correct value regardless of
    // whether an early return or throw happens before isColdStart = false
    const coldStart = isColdStart;
    isColdStart = false;

    const log = makeLogger({
        service: "lead_notification",
        environment: process.env.NODE_ENV,
        functionVersion: process.env.AWS_LAMBDA_FUNCTION_VERSION,
        correlationId,
        eventSource: event.source || null,
        eventDetailType: event["detail-type"] || null,
        eventBusName: event.eventBusName || null
    });

    // ── Annotate root segment ─────────────────────────────────────────────────
    // correlationId on root segment links this Lambda's trace to the upstream
    // producer's trace in the X-Ray service map.
    // detailType annotated so you can filter all traces of a specific event
    // type: Annotations.detailType = "LeadSubmitted"
    annotateRootSegment(
        {
            correlationId,
            service: "lead-notification",
            environment: process.env.NODE_ENV ?? "unknown",
            detailType: event["detail-type"] ?? "unknown",
            source: event.source ?? "unknown",
            coldStart,
        },
        {
            eventId: event.id ?? null,
            eventBusName: event.eventBusName ?? null,
            hasName: !!detail.name,
            hasMessage: !!detail.message,
            // Masked email in metadata — safe to store, useful for tracing
            // a specific lead's notification without PII in annotations
            leadEmail: maskEmail(detail.email),
        }
    );

    try {
        log("INFO", "notification_start", {
            coldStart,
            leadEmail: maskEmail(detail.email),
            hasName: !!detail.name,
            hasMessage: !!detail.message
        });

        // ── Validate event ────────────────────────────────────────────────────
        // Wrapped in its own subsegment so validation failures are visible in
        // the X-Ray timeline. A faulted validateEvent subsegment with
        // Annotations.valid = false means the upstream producer has a bug —
        // distinct from a faulted ses.sendEmail which means SES is having issues.
        let validationResult;
        await withSubsegment("validateEvent", {}, async (sub) => {
            const { valid, missing } = validateDetail(detail);
            validationResult = { valid, missing };

            sub.addAnnotation("valid", valid);
            if (!valid) {
                // addMetadata for the missing fields list — arrays can't be
                // annotations (not string/number/boolean) so metadata is correct
                sub.addMetadata("validation", { missingFields: missing });
            }
        }, correlationId);

        if (!validationResult.valid) {
            // Log as ERROR — a missing field means the upstream producer has a
            // bug. Not re-throwing because retrying won't fix a structural event
            // payload problem — it would just exhaust the retry budget.
            log("ERROR", "notification_invalid_event", {
                missingFields: validationResult.missing,
                correlationId
            });
            return { status: "invalid_event", missingFields: validationResult.missing };
        }

        // ── Send email ────────────────────────────────────────────────────────
        await withSubsegment(
            "sendLeadNotification",
            {
                detailType: event["detail-type"] ?? "unknown",
                source: event.source ?? "unknown",
            },
            async (sub) => {
                const subject = `New Lead: ${detail.name}`;
                const bodyHtml = buildEmailHtml(detail);

                log("INFO", "notification_sending", {
                    from: FROM,
                    to: TO,
                    subject,
                    correlationId
                });

                // ── SES send subsegment ───────────────────────────────────────
                // captureAWSv3Client creates this subsegment automatically but
                // wrapping it explicitly lets us add annotations alongside the
                // SDK-level subsegment — you see both in the X-Ray waterfall:
                //   sendLeadNotification (your subsegment, annotations here)
                //     └── SES SendEmail (SDK subsegment, duration + status)
                await withSubsegment(
                    "ses.sendEmail",
                    {
                        // Do NOT annotate TO or FROM email addresses —
                        // annotations are indexed and stored long-term.
                        // Email addresses are PII — keep them in logs only
                        // where retention is controlled and access is audited.
                        isSandbox: process.env.SES_SANDBOX === "true",
                    },
                    async (sesSub) => {
                        await ses.send(
                            new SendEmailCommand({
                                Source: FROM,
                                Destination: { ToAddresses: [TO] },
                                Message: {
                                    Subject: { Data: subject, Charset: "UTF-8" },
                                    Body: { Html: { Data: bodyHtml, Charset: "UTF-8" } }
                                }
                            })
                        );

                        // Metadata only — not annotations — for PII fields
                        sesSub.addMetadata("email", {
                            from: FROM,
                            // Masked recipient — confirms routing without storing
                            // full address in X-Ray trace (30 day retention,
                            // accessible to anyone with GetTraceSummaries IAM)
                            to: maskEmail(TO),
                            subject,
                        });
                    },
                    correlationId
                );

                sub.addAnnotation("emailSent", true);
                sub.addMetadata("result", {
                    durationMs: Date.now() - startedAt,
                });
            },
            correlationId
        );

        log("INFO", "notification_sent", {
            durationMs: Date.now() - startedAt,
            correlationId
        });

        return { status: "ok" };

    } catch (err) {
        log("ERROR", "notification_failed", {
            errorType: err?.name,
            errorMessage: err?.message,
            durationMs: Date.now() - startedAt,
            correlationId,
            // SES-specific failure modes — surface them clearly in logs
            // so ops can distinguish throttle (retry will help) from
            // sandbox block (config fix needed) without opening X-Ray
            isSesThrottle: err?.name === "ThrottlingException",
            isSandboxBlock: err?.name === "MessageRejected",
        });

        // Re-throw so EventBridge retries with its configured retry policy.
        // Only transient errors (SES throttle, network blip) benefit from retry.
        // Structural event validation errors are handled above — they never
        // reach this point.
        throw err;
    }
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Masks email to j***@example.com for safe logging and tracing.
// Used in logs (CloudWatch) and metadata (X-Ray) but never in annotations —
// even masked emails are PII-adjacent and should not be indexed long-term.
function maskEmail(email = "") {
    if (!email || !email.includes("@")) return null;
    const [local, domain] = email.split("@");
    return `${local[0]}***@${domain}`;
}

function buildEmailHtml(detail) {
    // Escape HTML to prevent injection if detail fields contain < > & characters
    const escape = (str = "") =>
        String(str)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");

    return `
        <h2>New Lead Received</h2>
        <p><strong>Name:</strong> ${escape(detail.name)}</p>
        <p><strong>Email:</strong> ${escape(detail.email)}</p>
        <p><strong>Message:</strong></p>
        <p>${escape(detail.message)}</p>
    `;
}
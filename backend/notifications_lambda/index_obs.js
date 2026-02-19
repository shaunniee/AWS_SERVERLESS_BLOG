const { SESClient, SendEmailCommand } = require("@aws-sdk/client-ses");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const { captureAWSv3Client } = require("aws-xray-sdk");

// ─── AWS Clients ──────────────────────────────────────────────────────────────
const ses = captureAWSv3Client(new SESClient({}));

const FROM = process.env.FROM_EMAIL;
const TO = process.env.TO_EMAIL;

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

// ─── Handler ──────────────────────────────────────────────────────────────────
exports.handler = async (event) => {
    const detail = event.detail || {};

    // Prefer the correlationId embedded by the upstream producer (e.g. the
    // admin Lambda that fired the event) so the full trace is tied together
    // across both services in CloudWatch Logs Insights.
    // Fall back to EventBridge's own event.id, then a fresh UUID.
    const correlationId = detail.correlationId || event.id || randomUUID();
    const startedAt = Date.now();

    const log = makeLogger({
        service: "lead_notification",
        correlationId,
        // EventBridge metadata — useful for finding the exact event in the
        // EventBridge console if you need to replay or debug it
        eventSource: event.source || null,
        eventDetailType: event["detail-type"] || null,
        eventBusName: event.eventBusName || null
    });

    try {
        log("INFO", "notification_start", {
            coldStart: isColdStart,
            // Log that a lead arrived and from which source, but not the
            // lead's personal details (name, message) — keeps PII out of logs.
            // Email is partially masked so you can verify routing without
            // storing a full address in CloudWatch.
            leadEmail: maskEmail(detail.email),
            hasName: !!detail.name,
            hasMessage: !!detail.message
        });
        isColdStart = false;

        // Validate before doing anything — a bad event should fail fast and
        // loudly rather than sending a malformed email or crashing in SES.
        const { valid, missing } = validateDetail(detail);
        if (!valid) {
            // Log as ERROR so this triggers alarms — a missing field means
            // the upstream producer has a bug that needs fixing.
            // We do NOT re-throw here because retrying won't fix a structural
            // problem with the event payload — it would just waste retries.
            log("ERROR", "notification_invalid_event", {
                missingFields: missing,
                correlationId
            });
            return { status: "invalid_event", missingFields: missing };
        }

        const subject = `New Lead: ${detail.name}`;
        const bodyHtml = buildEmailHtml(detail);

        log("INFO", "notification_sending", {
            from: FROM,
            to: TO,
            subject,
            correlationId
        });

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
            // SES-specific: rate limiting and sandbox restrictions are the most
            // common causes of failure — surface them clearly
            isSesThrottle: err?.name === "ThrottlingException",
            isSandboxBlock: err?.name === "MessageRejected"
        });

        // Re-throw so EventBridge retries with its configured retry policy.
        // Only transient errors (SES throttle, network blip) benefit from retry.
        // Structural event errors are handled above and don't reach this point.
        throw err;
    }
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Masks email to j***@example.com for safe logging
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
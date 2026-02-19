const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
    DynamoDBDocumentClient,
    PutCommand,
    GetCommand,
    QueryCommand,
    ScanCommand
} = require("@aws-sdk/lib-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const { randomUUID } = require("crypto");

// ─── X-Ray ────────────────────────────────────────────────────────────────────
// Requires: npm install aws-xray-sdk
// Requires: TracingConfig: Active on the Lambda function
const AWSXRay = require("aws-xray-sdk");
const { captureAWSv3Client } = AWSXRay;

// ─── AWS Clients ──────────────────────────────────────────────────────────────
// captureAWSv3Client wraps both clients so every DDB and EventBridge call
// appears as a subsegment in X-Ray automatically — duration, status, errors.
const client = captureAWSv3Client(new DynamoDBClient({}));
const ddb = DynamoDBDocumentClient.from(client);
const eb = captureAWSv3Client(new EventBridgeClient({}));

const TABLE = process.env.LEADS_TABLE;
const EVENT_BUS = process.env.LEADS_EVENT_BUS;

// ─── Cold Start Detection ─────────────────────────────────────────────────────
// Annotated on root segment — filter all cold start traces in X-Ray:
//   Annotations.coldStart = true
let isColdStart = true;

// ─── Utilities ────────────────────────────────────────────────────────────────
const now = () => new Date().toISOString();

function getHeader(headers = {}, key) {
    const lower = key.toLowerCase();
    const match = Object.keys(headers).find((k) => k.toLowerCase() === lower);
    return match ? headers[match] : undefined;
}

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

// ─── Error Classifier ─────────────────────────────────────────────────────────
function classifyError(err) {
    if (err.name === "ConditionalCheckFailedException")
        return { statusCode: 409, message: "Lead already exists" };
    if (err.name === "ResourceNotFoundException")
        return { statusCode: 503, message: "Database resource unavailable" };
    if (err.name === "ProvisionedThroughputExceededException" || err.name === "RequestLimitExceeded")
        return { statusCode: 503, message: "Service temporarily unavailable, please retry" };
    if (err.name === "ValidationException")
        return { statusCode: 400, message: "Invalid request data" };
    return { statusCode: 500, message: "Internal server error" };
}

// ─── Input Validator ──────────────────────────────────────────────────────────
function validateLeadInput(data = {}) {
    const missing = ["name", "email", "message"].filter((f) => !data[f]);
    if (missing.length > 0) {
        return { valid: false, missing };
    }
    return { valid: true };
}

// ─── X-Ray Helpers ────────────────────────────────────────────────────────────
// Wraps an async fn in a named subsegment.
// correlationId stamped as annotation on every subsegment — enables:
//   X-Ray filter: Annotations.correlationId = "abc-123"
// to surface the complete trace for a single request including the downstream
// notification Lambda that receives the LeadCreated EventBridge event.
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
        throw err;         // propagate so classifyError() in handler handles it
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
    const method = event.httpMethod;
    const path = event.resource;
    const body = event.body ? JSON.parse(event.body) : {};
    const requestId = event?.requestContext?.requestId;
    const correlationId =
        getHeader(event?.headers, "x-correlation-id") || requestId || randomUUID();
    const startedAt = Date.now();

    // Capture before flipping — guarantees correct value regardless of
    // whether an early return or throw happens before isColdStart = false
    const coldStart = isColdStart;
    isColdStart = false;

    const log = makeLogger({
        service: "leads",
        environment: process.env.NODE_ENV,
        functionVersion: process.env.AWS_LAMBDA_FUNCTION_VERSION,
        requestId,
        correlationId,
        method,
        path
    });

    const ctx = { log, correlationId };

    // ── Annotate root segment ─────────────────────────────────────────────────
    // This Lambda handles both public lead creation (POST /leads) and
    // admin lead listing (GET /admin/leads) — route annotation distinguishes
    // them in X-Ray without needing separate Lambdas.
    annotateRootSegment(
        {
            correlationId,
            service: "leads",
            environment: process.env.NODE_ENV ?? "unknown",
            route: `${method} ${path}`,
            coldStart,
        },
        {
            requestId,
            userAgent: getHeader(event?.headers, "user-agent") ?? null,
        }
    );

    let result;

    try {
        log("INFO", "request_start", {
            coldStart,
            userAgent: getHeader(event?.headers, "user-agent") || null
        });

        if (method === "POST" && path === "/leads")
            result = await createLead(body, ctx);
        else if (method === "GET" && path === "/admin/leads")
            result = await listLeads(ctx);
        else {
            log("WARN", "route_not_found", { statusCode: 404 });
            result = response(404, { message: "Route not found" });
        }

        return attachCorrelation(result, correlationId);

    } catch (err) {
        const { statusCode, message } = classifyError(err);
        log("ERROR", "request_failed", {
            errorType: err?.name,
            errorMessage: err?.message,
            statusCode,
            durationMs: Date.now() - startedAt
        });
        result = response(statusCode, { message });
        return attachCorrelation(result, correlationId);

    } finally {
        log("INFO", "request_end", {
            statusCode: result?.statusCode,
            durationMs: Date.now() - startedAt
        });
    }
};

// ─── Route Handlers ───────────────────────────────────────────────────────────

async function createLead(data, { log, correlationId } = {}) {
    // Validate before entering subsegment — input validation failures are not
    // infrastructure failures and should not create faulted subsegments in
    // the X-Ray service map. A 400 is expected behaviour, not a fault.
    const { valid, missing } = validateLeadInput(data);
    if (!valid) {
        log("WARN", "create_lead_invalid_input", { missingFields: missing });
        return response(400, { message: `Missing required fields: ${missing.join(", ")}` });
    }

    return withSubsegment("createLead", {}, async (sub) => {
        log("INFO", "create_lead_start");

        const lead = {
            leadID: randomUUID(),
            name: data.name,
            email: data.email,
            message: data.message,
            status: "NEW",
            createdAt: now()
        };

        // leadID annotated after generation so it's visible on the subsegment
        // alongside the full createLead duration — useful for finding the exact
        // DDB record when investigating a failed lead creation.
        sub.addAnnotation("leadID", lead.leadID);

        // Do NOT annotate email — email is PII, annotations are indexed
        // long-term. Masked email goes in metadata only.
        sub.addMetadata("lead", {
            leadID: lead.leadID,
            maskedEmail: maskEmail(lead.email),
            status: lead.status,
            createdAt: lead.createdAt,
        });

        // ── DDB put subsegment ────────────────────────────────────────────────
        await withSubsegment("ddb.putLead", { leadID: lead.leadID }, async () => {
            await ddb.send(new PutCommand({ TableName: TABLE, Item: lead }));
        }, correlationId);

        log("INFO", "create_lead_success", { leadID: lead.leadID });

        // ── EventBridge — best-effort ─────────────────────────────────────────
        // Lead is already saved so we never fail the request over an
        // EventBridge error. emitLeadCreatedEvent has its own try/catch
        // and subsegment — EventBridge failures fault independently without
        // affecting the createLead subsegment in the service map.
        await emitLeadCreatedEvent(lead, { log, correlationId });

        log("INFO", "create_lead_response", {
            leadID: lead.leadID,
            maskedEmail: maskEmail(lead.email)
        });

        return response(201, lead);
    }, correlationId);
}

async function listLeads({ log, correlationId } = {}) {
    return withSubsegment("listLeads", {}, async (sub) => {
        log("INFO", "list_leads_start");

        let result;
        await withSubsegment("ddb.scanLeads", {}, async (ddbSub) => {
            result = await ddb.send(new ScanCommand({ TableName: TABLE }));

            const count = result.Items?.length ?? 0;

            // Annotate count on the inner DDB subsegment — lets you see scan
            // result volume alongside DDB latency in the same X-Ray span.
            // Also useful for spotting unexpectedly large scans that could
            // indicate the table has grown beyond what Scan can handle.
            ddbSub.addAnnotation("resultCount", count);
        }, correlationId);

        const count = result.Items?.length ?? 0;

        sub.addAnnotation("resultCount", count);

        log("INFO", "list_leads_success", { count });

        if (count === 0) {
            log("WARN", "list_leads_empty");
        }

        return response(200, result.Items || []);
    }, correlationId);
}

// ─── EventBridge ──────────────────────────────────────────────────────────────

async function emitLeadCreatedEvent(lead, { log, correlationId } = {}) {
    // Best-effort: wrapped in try/catch so EventBridge failures never bubble
    // up to createLead. The subsegment is inside the try so a failure faults
    // the eventbridge subsegment in the service map — the createLead subsegment
    // stays green, clearly showing the lead was saved but notification failed.
    try {
        await withSubsegment(
            "eventbridge.putEvents",
            {
                detailType: "LeadCreated",
                leadID: lead.leadID,
            },
            async (sub) => {
                await eb.send(
                    new PutEventsCommand({
                        Entries: [
                            {
                                Source: "app.leads",
                                DetailType: "LeadCreated",
                                EventBusName: EVENT_BUS,
                                Detail: JSON.stringify({
                                    leadID: lead.leadID,
                                    name: lead.name,
                                    email: lead.email,
                                    message: lead.message,
                                    // correlationId in event Detail connects
                                    // this Lambda's trace to the downstream
                                    // notification Lambda's trace in X-Ray
                                    correlationId
                                })
                            }
                        ]
                    })
                );

                sub.addMetadata("event", {
                    leadID: lead.leadID,
                    detailType: "LeadCreated",
                    // Do NOT put email or message in metadata here —
                    // EventBridge subsegment metadata is stored in X-Ray traces
                    // which have 30-day retention and broader IAM access
                    // than CloudWatch Logs. Keep PII in logs only.
                });

                log("INFO", "eventbridge_emitted", {
                    detailType: "LeadCreated",
                    leadID: lead.leadID,
                    correlationId
                });
            },
            correlationId
        );
    } catch (err) {
        // EventBridge subsegment already recorded the error via addError()
        // in withSubsegment — no need to re-annotate here. Log loudly so
        // ops can see the notification failure without opening X-Ray.
        log("ERROR", "eventbridge_failed", {
            errorType: err.name,
            errorMessage: err.message,
            leadID: lead.leadID,
            correlationId
        });
        // Do not re-throw — lead is saved, notification failure is non-fatal
    }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Masks email to j***@example.com for safe logging and tracing.
// Used in logs and metadata but never in annotations —
// annotations are indexed long-term and should not contain PII.
function maskEmail(email = "") {
    if (!email || !email.includes("@")) return null;
    const [local, domain] = email.split("@");
    return `${local[0]}***@${domain}`;
}

function response(statusCode, body) {
    return {
        statusCode,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers":
                "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token,x-correlation-id",
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
        },
        body: body ? JSON.stringify(body) : null
    };
}

function attachCorrelation(resp, correlationId) {
    return {
        ...resp,
        headers: { ...resp.headers, "x-correlation-id": correlationId }
    };
}
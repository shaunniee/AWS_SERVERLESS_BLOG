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
const { captureAWSv3Client } = require("aws-xray-sdk");

// ─── AWS Clients ──────────────────────────────────────────────────────────────
const client = captureAWSv3Client(new DynamoDBClient({}));
const ddb = DynamoDBDocumentClient.from(client);
const eb = captureAWSv3Client(new EventBridgeClient({}));

const TABLE = process.env.LEADS_TABLE;
const EVENT_BUS = process.env.LEADS_EVENT_BUS;

// ─── Cold Start Detection ─────────────────────────────────────────────────────
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
    if (err.name === "ConditionalCheckFailedException") {
        return { statusCode: 409, message: "Lead already exists" };
    }
    if (err.name === "ResourceNotFoundException") {
        return { statusCode: 503, message: "Database resource unavailable" };
    }
    if (
        err.name === "ProvisionedThroughputExceededException" ||
        err.name === "RequestLimitExceeded"
    ) {
        return { statusCode: 503, message: "Service temporarily unavailable, please retry" };
    }
    if (err.name === "ValidationException") {
        return { statusCode: 400, message: "Invalid request data" };
    }
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

// ─── Handler ──────────────────────────────────────────────────────────────────
exports.handler = async (event) => {
    const method = event.httpMethod;
    const path = event.resource;
    const body = event.body ? JSON.parse(event.body) : {};
    const requestId = event?.requestContext?.requestId;
    const correlationId =
        getHeader(event?.headers, "x-correlation-id") || requestId || randomUUID();
    const startedAt = Date.now();

    const log = makeLogger({
        service: "leads",
        requestId,
        correlationId,
        method,
        path
    });

    const ctx = { log, correlationId };

    let result;

    try {
        log("INFO", "request_start", {
            coldStart: isColdStart,
            userAgent: getHeader(event?.headers, "user-agent") || null
        });
        isColdStart = false;

        if (method === "POST" && path === "/leads") {
            result = await createLead(body, ctx);
        } else if (method === "GET" && path === "/admin/leads") {
            result = await listLeads(ctx);
        } else {
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
    // Validate input before touching DynamoDB or EventBridge
    const { valid, missing } = validateLeadInput(data);
    if (!valid) {
        log("WARN", "create_lead_invalid_input", { missingFields: missing });
        return response(400, { message: `Missing required fields: ${missing.join(", ")}` });
    }

    log("INFO", "create_lead_start");

    const lead = {
        leadID: randomUUID(),
        name: data.name,
        email: data.email,
        message: data.message,
        status: "NEW",
        createdAt: now()
    };

    await ddb.send(new PutCommand({ TableName: TABLE, Item: lead }));
    log("INFO", "create_lead_success", { leadID: lead.leadID });

    // Emit event — best-effort, same pattern as deletePost in the admin Lambda.
    // Lead is already saved so we never fail the request over an EventBridge error,
    // but we log loudly so the notification failure is visible.
    await emitLeadCreatedEvent(lead, { log, correlationId });

    // Mask PII in the response log — don't echo full email back into logs
    log("INFO", "create_lead_response", {
        leadID: lead.leadID,
        maskedEmail: maskEmail(lead.email)
    });

    return response(201, lead);
}

async function listLeads({ log, correlationId } = {}) {
    log("INFO", "list_leads_start");

    const result = await ddb.send(new ScanCommand({ TableName: TABLE }));

    const count = result.Items?.length ?? 0;
    log("INFO", "list_leads_success", { count });

    if (count === 0) {
        log("WARN", "list_leads_empty");
    }

    return response(200, result.Items || []);
}

// ─── EventBridge ──────────────────────────────────────────────────────────────

async function emitLeadCreatedEvent(lead, { log, correlationId } = {}) {
    try {
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
                            correlationId  // downstream consumer (SES notification Lambda)
                                           // picks this up and carries the trace forward
                        })
                    }
                ]
            })
        );
        log("INFO", "eventbridge_emitted", {
            detailType: "LeadCreated",
            leadID: lead.leadID,
            correlationId
        });
    } catch (err) {
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

// Masks email to j***@example.com for safe logging
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
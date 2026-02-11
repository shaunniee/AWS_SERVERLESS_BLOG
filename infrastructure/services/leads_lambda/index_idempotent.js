const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, QueryCommand, ScanCommand } = require("@aws-sdk/lib-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const { randomUUID } = require("crypto");

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);
const eb = new EventBridgeClient({});

const TABLE = process.env.LEADS_TABLE;
const now = () => new Date().toISOString();

exports.handler = async (event) => {
  try {
    const method = event.httpMethod;
    const path = event.resource;
    const body = event.body ? JSON.parse(event.body) : {};
    const leadId = event.pathParameters?.leadId;

    // Routes
    if (method === "POST" && path === "/leads") return createLead(body);
    if (method === "GET" && path === "/admin/leads") return listLeads();

    return response(404, { message: "Route not found" });
  } catch (err) {
    console.error("Error in leads Lambda:", err);
    return response(500, { message: err.message });
  }
};

// Create a new lead with idempotency support
async function createLead(data) {
  const idempotencyKey = data.idempotencyKey || null;

  if (idempotencyKey) {
    // Check GSI "idempotencyKeyIndex" if lead already exists
    const existing = await ddb.send(new QueryCommand({
      TableName: TABLE,
      IndexName: "idempotencyKeyIndex",
      KeyConditionExpression: "idempotencyKey = :key",
      ExpressionAttributeValues: { ":key": idempotencyKey },
      Limit: 1
    }));

    if (existing.Items && existing.Items.length > 0) {
      return response(200, existing.Items[0]);
    }
  }

  const lead = {
    leadID: randomUUID(),
    name: data.name,
    email: data.email,
    message: data.message,
    status: "NEW",
    createdAt: now(),
    idempotencyKey: idempotencyKey || null
  };

  await ddb.send(new PutCommand({ TableName: TABLE, Item: lead }));
  
  await emitLeadCreatedEvent(lead);

  return response(201, lead);
}

// List all leads (simple scan for learning purposes)
async function listLeads() {
  const result = await ddb.send(new ScanCommand({ TableName: TABLE }));
  return response(200, result.Items || []);
}

// Send EventBridge event when a lead is created
async function emitLeadCreatedEvent(lead) {
  await eb.send(new PutEventsCommand({
    Entries: [
      {
        Source: "app.leads",
        DetailType: "LeadCreated",
        Detail: JSON.stringify({
          leadID: lead.leadID,
          name: lead.name,
          email: lead.email,
          message: lead.message
        })
      }
    ]
  }));
}

// Standard JSON response
function response(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : null
  };
}

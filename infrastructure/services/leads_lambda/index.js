const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand } = require("@aws-sdk/lib-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");

const eb = new EventBridgeClient({});

const { randomUUID } = require("crypto");

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);

const TABLE = process.env.LEADS_TABLE;
const EVENT_BUS = process.env.LEADS_EVENT_BUS;
const now = () => new Date().toISOString();

exports.handler = async (event) => {
  try {
    const method = event.httpMethod;
    const path = event.resource; // API Gateway resource path
    const leadId = event.pathParameters?.leadId;
    const body = event.body ? JSON.parse(event.body) : {};

    // Routes
    if (method === "POST" && path === "/leads") {
      return createLead(body);
    }

    if (method === "GET" && path === "/admin/leads") {
      return listLeads();
    }

    return response(404, { message: "Route not found" });

  } catch (err) {
    console.error("Error in leads Lambda:", err);
    return response(500, { message: err.message });
  }
};

// Create a new lead
async function createLead(data) {
  const lead = {
    leadID: randomUUID(),
    name: data.name,
    email: data.email,
    message: data.message,
    status: "NEW",
    createdAt: now()
  };

  await ddb.send(new PutCommand({
    TableName: TABLE,
    Item: lead
  }));
  
  await emitLeadCreatedEvent(lead);

  return response(201, lead);
}

// List all leads (simple scan for learning project)
const { ScanCommand } = require("@aws-sdk/lib-dynamodb");

async function listLeads() {
  const result = await ddb.send(new ScanCommand({
    TableName: TABLE
  }));

  return response(200, result.Items || []);
}

async function emitLeadCreatedEvent(lead) {
  await eb.send(new PutEventsCommand({
    Entries: [
      {
        Source: "app.leads",
        DetailType: "LeadCreated",
        EventBusName: EVENT_BUS,
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
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
    },
    body: body ? JSON.stringify(body) : null
  };
}

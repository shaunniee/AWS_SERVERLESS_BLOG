const { SESClient, SendEmailCommand } = require("@aws-sdk/client-ses");

const ses = new SESClient({});

const FROM = process.env.FROM_EMAIL;
const TO = process.env.TO_EMAIL;

exports.handler = async (event) => {
  try {
    // EventBridge always delivers array-like events
    const detail = event.detail;

    const subject = `New Lead: ${detail.name}`;
    const bodyHtml = `
      <h2>New Lead Received</h2>
      <p><strong>Name:</strong> ${detail.name}</p>
      <p><strong>Email:</strong> ${detail.email}</p>
      <p><strong>Message:</strong></p>
      <p>${detail.message}</p>
    `;

    await ses.send(new SendEmailCommand({
      Source: FROM,
      Destination: {
        ToAddresses: [TO]
      },
      Message: {
        Subject: {
          Data: subject,
          Charset: "UTF-8"
        },
        Body: {
          Html: {
            Data: bodyHtml,
            Charset: "UTF-8"
          }
        }
      }
    }));

    return { status: "ok" };

  } catch (err) {
    console.error("Notification error:", err);
    throw err; // Let EventBridge retry
  }
};

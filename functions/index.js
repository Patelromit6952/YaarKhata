const functions = require("firebase-functions");
const {google} = require("googleapis");
const admin = require("firebase-admin");
const path = require("path");

// Load service account JSON
const serviceAccount = require(path.join(__dirname, "service-account.json"));

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const PROJECT_ID = serviceAccount.project_id;
const MESSAGING_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const SCOPES = [MESSAGING_SCOPE];

/**
 * Get access token for Firebase messaging
 * @return {string} Access token
 */
async function getAccessToken() {
  const jwtClient = new google.auth.JWT(
      serviceAccount.client_email,
      null,
      serviceAccount.private_key,
      SCOPES,
      null,
  );
  const tokens = await jwtClient.authorize();
  return tokens.access_token;
}

// Cloud Function to send notification
exports.sendNotification = functions.https.onCall(async (data, context) => {
  try {
    const accessToken = await getAccessToken();

    const message = {
      message: {
        token: data.fcmToken,
        notification: {
          title: data.title,
          body: data.body,
        },
        data: data.data || {},
      },
    };

    const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(message),
        },
    );

    const result = await res.json();
    return {success: true, result};
  } catch (err) {
    console.error("Error sending notification:", err);
    return {success: false, error: err.message};
  }
});

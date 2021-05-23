import * as functions from "firebase-functions";
import * as request from "request-promise-native";
import * as admin from "firebase-admin";

// // Start writing Firebase Functions
// // https://firebase.google.com/docs/functions/typescript

admin.initializeApp();

export const inviteSent = functions.firestore.document("/invites/{userId}/invites/{teammateId}").onWrite(async (change, context) => {
    let teammateMap;
    let teammateName;
    let fcmToken;

    // Retrieve the user who will be receiving the notification
    await admin.firestore().collection("users").doc(context.params.userId).get().then(async (doc) => {
        functions.logger.log("Retrieved user with uid: " + doc.ref.id);

        // Retrieve the teammate who sent the invite
        await admin.firestore().collection("users").doc(context.params.teammateId).get().then((tDoc) => {
            // Get the teammates name
            teammateMap = tDoc.data();
            teammateName = teammateMap != undefined ? teammateMap["display_name"] : "Someone";
            fcmToken = teammateMap != undefined ? teammateMap["fcm_token"] : null;
        });
    }).catch((err) => {
        functions.logger.log("Error fetching firestore users collection: " + err);
        return null;
    });

    if (fcmToken != null) {
        const data = {
            "notification": {
                "body": teammateName + " has sent you an invite",
                "title": "Teammate challenge!",
            }, 
            "priority": "high", 
            "data": {
                "click_action": "FLUTTER_NOTIFICATION_CLICK", 
                "id": "1", 
                "status": "done",
            }, 
            "to": fcmToken,
        };
    
        request({
            url: "https://fcm.googleapis.com/fcm/send",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `key=${functions.config().messagingservice.key}`,
            },
            body: data,
        });
    }
});
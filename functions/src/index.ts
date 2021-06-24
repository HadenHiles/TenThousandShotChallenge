import * as functions from "firebase-functions";
import * as request from "request-promise-native";
import * as admin from "firebase-admin";

// // Start writing Firebase Functions
// // https://firebase.google.com/docs/functions/typescript

admin.initializeApp();

export const inviteSent = functions.firestore.document("/invites/{userId}/invites/{teammateId}").onWrite(async (change, context) => {
    let user;
    let teammate;
    let teammateName;
    let fcmToken: string | null;

    // Retrieve the user who will be receiving the notification
    await admin.firestore().collection("users").doc(context.params.userId).get().then(async (doc) => {
        user = doc.data();
        fcmToken = user != undefined ? user.fcm_token : null;
        let data = {
            "notification": {
                "body": "Someone has sent you a teammate invite.",
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

        if (fcmToken != null) {
            // Retrieve the teammate who sent the invite
            await admin.firestore().collection("users").doc(context.params.teammateId).get().then((tDoc) => {
                // Get the teammates name
                teammate = tDoc.data();
                teammateName = teammate != undefined ? teammate.display_name : "Someone";
                data.notification.body = `${teammateName} has sent you an invite.`;

                functions.logger.log("Sending notification with data: " + JSON.stringify(data));
                
                request({
                    url: "https://fcm.googleapis.com/fcm/send",
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": `key=${functions.config().messagingservice.key}`,
                    },
                    body: JSON.stringify(data),
                });
            }).catch((err) => {
                functions.logger.log("Error fetching firestore users (teammate) collection: " + err);
            });
        } else {
            functions.logger.log("fcm_token not found");
        }
    }).catch((err) => {
        functions.logger.log("Error fetching firestore users collection: " + err);
        return null;
    });
});

export const inviteAccepted = functions.firestore.document("/teammates/{userId}/teammates/{teammateId}").onWrite(async (change, context) => {
    let user;
    let teammate;
    let teammateName;
    let fcmToken: string | null;

    // Retrieve the user who will be receiving the notification
    await admin.firestore().collection("users").doc(context.params.teammateId).get().then(async (doc) => {
        user = doc.data();
        fcmToken = user != undefined ? user.fcm_token : null;
        let data = {
            "notification": {
                "body": "Someone has accepted your teammate invite.",
                "title": "Teammate challenge accepted!",
            }, 
            "priority": "high", 
            "data": {
                "click_action": "FLUTTER_NOTIFICATION_CLICK", 
                "id": "1", 
                "status": "done",
            }, 
            "to": fcmToken,
        };

        if (fcmToken != null) {
            // Retrieve the teammate who accepted the invite
            await admin.firestore().collection("users").doc(context.params.userId).get().then((tDoc) => {
                // Get the teammates name
                teammate = tDoc.data();
                teammateName = teammate != undefined ? teammate.display_name : "Someone";
                data.notification.body = `${teammateName} has accepted your invite.`;

                functions.logger.log("Sending notification with data: " + JSON.stringify(data));
                
                request({
                    url: "https://fcm.googleapis.com/fcm/send",
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": `key=${functions.config().messagingservice.key}`,
                    },
                    body: JSON.stringify(data),
                });
            }).catch((err) => {
                functions.logger.log("Error fetching firestore users (teammate) collection: " + err);
            });
        } else {
            functions.logger.log("fcm_token not found");
        }
    }).catch((err) => {
        functions.logger.log("Error fetching firestore users collection: " + err);
        return null;
    });
});

// export const userSignUp = functions.auth.user().onCreate(async (user) => {
//     var uDoc = admin.firestore().collection('users').doc(user.uid);
//     await uDoc.get().then((u) => {
//         if (!u.exists) {
//         // Update/add the user's display name to firestore
//         uDoc.set({
//             'display_name_lowercase': user.displayName?.toLowerCase(),
//             'display_name': user.displayName,
//             'email': user.email,
//             'photo_url': user.photoURL,
//             'public': true,
//             'fcm_token': null,
//         });
//         }
//     });
// });
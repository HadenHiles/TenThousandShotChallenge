import * as functions from "firebase-functions";
import * as request from "request-promise-native";
import * as admin from "firebase-admin";

// // Start writing Firebase Functions
// // https://firebase.google.com/docs/functions/typescript

admin.initializeApp();

export const inviteSent = functions.firestore.document("/invites/{userId}/invites/{teammateId}").onCreate(async (change, context) => {
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

export const inviteAccepted = functions.firestore.document("/teammates/{userId}/teammates/{teammateId}").onCreate(async (change, context) => {
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

// Update the iteration timestamp for caching purposes any time a new session is created
// Send teammates(friends) a notification to inspire some friendly competition
export const sessionCreated = functions.firestore.document("/iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}").onCreate(async (change, context) => {
    // Update the according iteration timestamp (updated_at)
    await admin.firestore().collection(`/iterations/${context.params.userId}/iterations`).doc(`${context.params.iterationId}`).update({'updated_at': admin.firestore.Timestamp.fromDate(new Date(Date.now()))}).then((_) => true).catch((err) => {
        functions.logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });

    // Send friends notifications

    let user : any;
    let friendNotifications : boolean = false;
    let session : any;
    let teammates : any[];
    let fcmToken: string | null;

    // Retrieve the user who will be receiving the notification
    await admin.firestore().collection("users").doc(context.params.userId).get().then(async (doc) => {
        user = doc.data();
        fcmToken = user != undefined ? user.fcm_token : null;
        
        await admin.firestore().collection(`/iterations/${context.params.userId}/iterations/${context.params.iterationId}/sessions`).doc(`${context.params.sessionId}`).get().then(async (sDoc) => {
            session = sDoc.data();
            let data : any;
            
            if (session != null) {
                data = {
                    "notification": {
                        "body": "${user.display_name} just finished shooting!",
                        "title": "${user.display_name} just took ${session.total} shots! (${session.total_wrist}W, ${session.total_snap}SN, ${session.total_slap}SL, ${session.total_backhand}B)",
                    }, 
                    "priority": "high",
                    "data": {
                        "click_action": "FLUTTER_NOTIFICATION_CLICK", 
                        "id": "1", 
                        "status": "done",
                    }, 
                    "to": fcmToken,
                };
            } else {
                data = {
                    "notification": {
                        "body": "${user.display_name} just finished shooting",
                        "title": "Look out! ${user.display_name} is a shooting machine!",
                    }, 
                    "priority": "high", 
                    "data": {
                        "click_action": "FLUTTER_NOTIFICATION_CLICK",
                        "id": "1", 
                        "status": "done",
                    }, 
                    "to": fcmToken,
                };
            }

            if (fcmToken != null && user! != null) {
                // Retrieve the teammate who accepted the invite
                await admin.firestore().collection(`teammates/${context.params.userId}/teammates`).get().then((tDoc) => {
                    // Get the players teammates
                    teammates = tDoc.docs;

                    teammates.forEach((teammate) => {
                        teammate = teammate.data();
                        friendNotifications = teammate != undefined ? teammate.friend_notifications : false;

                        if (friendNotifications) {
                            data.notification.body = getFriendNotificationMessage(teammate.display_name, user!.display_name);

                            functions.logger.debug("Sending notification with data: " + JSON.stringify(data));
                            
                            request({
                                url: "https://fcm.googleapis.com/fcm/send",
                                method: "POST",
                                headers: {
                                    "Content-Type": "application/json",
                                    "Authorization": `key=${functions.config().messagingservice.key}`,
                                },
                                body: JSON.stringify(data),
                            });
                        }
                    });
                }).catch((err) => {
                    functions.logger.error("Error fetching teammate collection: " + err);
                });
            } else {
                functions.logger.warn("fcm_token not found");
            }
        }).catch((err) => {
            functions.logger.error("Error fetching shooting session: " + err);
            return null;
        });
    }).catch((err) => {
        functions.logger.error("Error fetching user: " + err);
        return null;
    });
});

// Update the iteration timestamp for caching purposes any time a session is updated
export const sessionUpdated = functions.firestore.document("/iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}").onUpdate(async (change, context) => {
    // Retrieve the user who will be receiving the notification
    await admin.firestore().collection(`/iterations/${context.params.userId}/iterations`).doc(`${context.params.iterationId}`).update({'updated_at': admin.firestore.Timestamp.fromDate(new Date(Date.now()))}).then((_) => true).catch((err) => {
        functions.logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });
});

// Update the iteration timestamp for caching purposes any time a session is deleted
export const sessionDeleted = functions.firestore.document("/iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}").onDelete(async (change, context) => {
    // Retrieve the user who will be receiving the notification
    await admin.firestore().collection(`/iterations/${context.params.userId}/iterations`).doc(`${context.params.iterationId}`).update({'updated_at': admin.firestore.Timestamp.fromDate(new Date(Date.now()))}).then((_) => true).catch((err) => {
        functions.logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });
});

function getFriendNotificationMessage(playerName : string, teammateName : string) : string {
    var messageTypeIndex = Math.floor(Math.random()*3) + 1;
    switch (messageTypeIndex) {
        case 0:
            var messageIndex = Math.floor(Math.random()*(motivationalMessages.length - 1)) + 1;
            return motivationalMessages[messageIndex].replace("${playerName}", playerName).replace("${teammateName}", teammateName);
        case 1:
            var messageIndex = Math.floor(Math.random()*(teasingMessages.length - 1)) + 1;
            return teasingMessages[messageIndex].replace("${playerName}", playerName).replace("${teammateName}", teammateName);
        case 2:
            var messageIndex = Math.floor(Math.random()*(razzingMessages.length - 1)) + 1;
            return razzingMessages[messageIndex].replace("${playerName}", playerName).replace("${teammateName}", teammateName);
        default:
            var messageIndex = Math.floor(Math.random()*(friendlyMessages.length - 1)) + 1;
            return friendlyMessages[messageIndex].replace("${playerName}", playerName).replace("${teammateName}", teammateName);
    }
}

// Teammate Notification Messages (generated with help from Google Gemini AI)
const motivationalMessages = [
  "Hey ${teammateName}, looks like someone's slacking while ${playerName} lights up the net! Get out there and join the party!",
  "Feeling inspired by ${playerName}'s shot? Grab your stick and show them what you've got!",
  "${playerName} is on FIRE! Don't let them steal all the glory! Get out there and score some of your own!",
  "Is ${playerName} trying to win this challenge ALL ALONE? Get on the ice and show them some teamwork!",
  "Taking notes, ${teammateName}? ${playerName} is setting the bar high!",
  "Just a friendly reminder, ${teammateName}: GOALS require SHOTS! Get out there and make it happen!",
  "Feeling intimidated by ${playerName}'s shot selection? Don't be! Just grab your stick and focus on your own game!",
  "Looking a little rusty, ${teammateName}? Maybe ${playerName}'s got a contagious case of \"hot stick\"! Get out there and catch it!",
  "${playerName} is making it look easy! Think you can keep up? Get out there and prove it!",
  "Breaking news, ${playerName} is on a shooting rampage! The ice needs more targets! Get out there, ${teammateName}, and be a teammate!"
];

const teasingMessages = [
  "Uh oh, ${teammateName}! Looks like ${playerName} is lighting the lamp without you, better get out there and start shooting!",
  "Someone's gotta take ${playerName}'s stick away! They're taking all the shots! Better get out there and steal some of the glory!",
  "Hey ${teammateName}, saving all your energy for the post-game celebrations? This is a shooting CHALLENGE, remember?",
  "Looks like ${playerName} found the fountain of youth... and it involves a puck and a net! Get out there and show them you're still the GOAT!",
  "Fun fact, ${playerName} is averaging 20 shots per minute. Just sayin', ${teammateName}.",
  "Theory, the more shots ${playerName} takes, the stronger their wifi signal gets. Maybe you should get out there and improve yours too, ${teammateName}?",
  "Warning, letting ${playerName} take all the shots may result in spontaneous celebrations. Get out there and join the party, ${teammateName}!"
];

const razzingMessages = [
  "Target acquired, ${playerName} has set their sights on the net... and maybe your reputation as the team's top shooter? Get out there and defend your title!",
  "Breaking news, ${playerName} is on a TEAR! Get out there before they forget what their teammates look like!",
  "Friendly competition turning into a ROUT? Get out there and remind ${playerName} who's boss, ${teammateName}!",
  "Looks like someone's got a case of \"shotgun fever\"! Don't worry, ${teammateName}, there are plenty of pucks to go around!",
  "Easy there, ${playerName}! Save some shots for the rest of us mortals!",
  "Is ${playerName} training for the Olympics... or just trying to win this little challenge? Get out there and show them what real competition looks like!",
  "Theory, the faster ${playerName} shoots, the faster practice ends. Get out there and make it happen... for the sake of everyone's sanity!",
  "Breaking news, ${playerName} has declared themselves the official goalie tormentor. Get out there and show them some mercy, ${teammateName}!",
  "Looks like ${playerName} is putting on a one-man show! Get out there and turn it into a TEAM effort, ${teammateName}!",
  "Someone call the fire department! ${playerName}'s on a shooting rampage!"
];

const friendlyMessages = [
  "Is that the sound of the net SINGING, or is it just ${playerName}'s shots getting more impressive? Get out there and show them some competition, ${teammateName}!",
  "Breaking news: ${playerName} has filed a formal complaint about the lack of competition. Get your sticks ready, team!",
  "Hey ${teammateName}, careful not to get caught in the slipstream of ${playerName}'s shots! They're on a TEAR!",
  "Looks like ${playerName} found their power button! Get out there and show them what yours looks like, ${teammateName}!",
  "Someone get a sharpshooter badge for ${playerName}! They're on fire! (Don't worry, the nets are fireproof... mostly.)",
  "Ruh roh! Looks like ${playerName} is having a monopoly on the net! Get out there and break the bank, ${teammateName}!", 
  "PSA: There's plenty of net to go around! Share the love, ${playerName} (and ${teammateName})!",
  "Just saw a puck with ${playerName}'s name on it circling the net. Get out there and claim yours, ${teammateName}!",
  "Is ${playerName} auditioning for a slap shot competition or just practicing? Either way, get out there and steal the show!",
  "Warning: Letting ${playerName} take all the shots may result in an inflated ego. Get out there and keep them grounded, ${teammateName}!",
  "Theory: The more pucks ${playerName} shoots, the faster their skating gets. Get out there and test that theory, ${teammateName}!",
  "Breaking news: ${playerName} has been promoted to team mascot... unless someone else steps up their shot game! Get out there, ${teammateName}!",
  "Is this target practice or a shooting competition, ${playerName}? Get out there and show some mercy to the goalies!", 
  "Looks like someone's got a case of the \"shotgun blues\" and they're taking it out on the nets! Get out there and show them some fancy stickwork, ${teammateName}!",
  "Is ${playerName} channeling their inner superhero? All they need is a cape to complete the look! Get out there and show them your own moves, ${teammateName}!"
];

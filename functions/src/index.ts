import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as https from "https";
import { google } from "googleapis";

const PROJECT_ID = 'ten-thousand-puck-challenge';
const HOST = 'fcm.googleapis.com';
const PATH = '/v1/projects/' + PROJECT_ID + '/messages:send';
const MESSAGING_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const SCOPES = [MESSAGING_SCOPE];

function getAccessToken() {
  return new Promise(function(resolve, reject) {
    const key = require('../service-account.json');
    const jwtClient = new google.auth.JWT(
      key.client_email,
      undefined,
      key.private_key,
      SCOPES,
      undefined
    );
    jwtClient.authorize(function(err: any, tokens: any) {
      if (err) {
        reject(err);
        return;
      }
      resolve(tokens.access_token);
    });
  });
}

/**
 * Send HTTP request to FCM with given message.
 *
 * @param {object} fcmMessage will make up the body of the request.
 */
function sendFcmMessage(fcmMessage: any) {
  getAccessToken().then(function(accessToken) {
    const options = {
      hostname: HOST,
      path: PATH,
      method: 'POST',
      // [START use_access_token]
      headers: {
        'Authorization': 'Bearer ' + accessToken
      }
      // [END use_access_token]
    };

    const request = https.request(options, function(resp: any) {
      resp.setEncoding('utf8');
      resp.on('data', function(data : any) {
        functions.logger.log('Message sent to Firebase for delivery, response:');
        functions.logger.log(data);
      });
    });

    request.on('error', function(err: any) {
      functions.logger.log('Unable to send message to Firebase');
      functions.logger.error(err);
    });

    request.write(JSON.stringify(fcmMessage));
    request.end();
  });
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

// // Start writing Firebase Functions
// // https://firebase.google.com/docs/functions/typescript

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
            "message": {
                "token": fcmToken,
                "notification": {
                    "body": "Someone has sent you a teammate invite.",
                    "title": "Teammate challenge!",
                }
            },
        };

        if (fcmToken != null) {
            // Retrieve the teammate who sent the invite
            await admin.firestore().collection("users").doc(context.params.teammateId).get().then((tDoc) => {
                // Get the teammates name
                teammate = tDoc.data();
                teammateName = teammate != undefined ? teammate.display_name : "Someone";
                data.message.notification.body = `${teammateName} has sent you an invite.`;

                functions.logger.log("Sending notification with data: " + JSON.stringify(data));

                sendFcmMessage(data);
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
            "message": {
                "token": fcmToken,
                "notification": {
                    "body": "Someone has accepted your teammate invite.",
                    "title": "Teammate challenge accepted!",
                }
            },
        };

        if (fcmToken != null) {
            // Retrieve the teammate who accepted the invite
            await admin.firestore().collection("users").doc(context.params.userId).get().then((tDoc) => {
                // Get the teammates name
                teammate = tDoc.data();
                teammateName = teammate != undefined ? teammate.display_name : "Someone";
                data.message.notification.body = `${teammateName} has accepted your invite.`;

                functions.logger.log("Sending notification with data: " + JSON.stringify(data));

                sendFcmMessage(data);
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

// Update the iteration timestamp for caching purposes any time a new session is created
// Send teammates(friends) a notification to inspire some friendly competition
export const sessionCreated = functions.firestore.document("/iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}").onCreate(async (change, context) => {
    // Update the according iteration timestamp (updated_at)
    await admin.firestore().collection(`/iterations/${context.params.userId}/iterations`).doc(context.params.iterationId).update({ 'updated_at': admin.firestore.Timestamp.fromDate(new Date(Date.now())) }).then(async (_) => {
        // Send friends notifications
        let user: any;
        let session: any;
        let teammates: any[];

        // Retrieve the user who will be receiving the notification
        await admin.firestore().collection("users").doc(context.params.userId).get().then(async (doc) => {
            user = doc.data();

            await admin.firestore().collection(`/iterations/${context.params.userId}/iterations/${context.params.iterationId}/sessions`).doc(context.params.sessionId).get().then(async (sDoc) => {
                session = sDoc.data();
                let data: any;

                if (session != null) {
                    data = {
                        "message": {
                            "data": {
                                "body": `${user.display_name} just finished shooting!`,
                                "title": `${user.display_name} just took ${session.total} shots!`,
                                "click_action": "FLUTTER_NOTIFICATION_CLICK"
                            }
                        },
                    };
                } else {
                    data = {
                        "message": {
                            "data": {
                                "body": `${user.display_name} just finished shooting`,
                            "title": `Look out! ${user.display_name} is a shooting machine!`,
                                "click_action": "FLUTTER_NOTIFICATION_CLICK"
                            }
                        },
                    };
                }

                if (user! != null && user.friend_notifications == true) {
                    // Retrieve the teammate who accepted the invite
                    await admin.firestore().collection(`teammates/${context.params.userId}/teammates`).get().then(async (tDoc) => {
                        // Get the players teammates
                        teammates = tDoc.docs;

                        teammates.forEach(async (t) => {
                            let teammate = t.data();
                            await admin.firestore().collection("users").doc(t.id).get().then(async (tmDoc) => {
                                let friend = tmDoc.data();
                                let friendNotifications = friend!.friend_notifications != undefined ? friend!.friend_notifications : false;
                                let fcmToken = teammate.fcm_token != undefined ? teammate.fcm_token : null;
                                //functions.logger.debug("attempting send notification to teammate: " + teammate.display_name + "\nfcm_token: " + fcmToken + "\nfriend_notifications: " + friendNotifications);

                                if (friendNotifications && fcmToken != null) {
                                    data.notification.body = getFriendNotificationMessage(user!.display_name, teammate.display_name);
                                    data.message.token = fcmToken;

                                    functions.logger.debug("Sending notification with data: " + JSON.stringify(data));

                                    sendFcmMessage(data);
                                }
                            });
                        });

                        return true;
                    }).catch((err) => {
                        functions.logger.error("Error fetching teammate collection: " + err);
                        return null;
                    });

                    return true;
                } else {
                    functions.logger.warn("fcm_token not found");
                    return null;
                }
            }).catch((err) => {
                functions.logger.error("Error fetching shooting session: " + err);
                return null;
            });
        }).catch((err) => {
            functions.logger.error("Error fetching user: " + err);
            return null;
        });
    }).catch((err) => {
        functions.logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });


});

// Update the iteration timestamp for caching purposes any time a session is updated
export const sessionUpdated = functions.firestore.document("/iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}").onUpdate(async (change, context) => {
    // Retrieve the user who will be receiving the notification
    await admin.firestore().collection(`/iterations/${context.params.userId}/iterations`).doc(`${context.params.iterationId}`).update({ 'updated_at': admin.firestore.Timestamp.fromDate(new Date(Date.now())) }).then((_) => true).catch((err) => {
        functions.logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });
});

// Update the iteration timestamp for caching purposes any time a session is deleted
export const sessionDeleted = functions.firestore.document("/iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}").onDelete(async (change, context) => {
    // Retrieve the user who will be receiving the notification
    await admin.firestore().collection(`/iterations/${context.params.userId}/iterations`).doc(`${context.params.iterationId}`).update({ 'updated_at': admin.firestore.Timestamp.fromDate(new Date(Date.now())) }).then((_) => true).catch((err) => {
        functions.logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });
});

function getFriendNotificationMessage(playerName: string, teammateName: string): string {
    var messageTypeIndex = Math.floor(Math.random() * 3) + 1;
    switch (messageTypeIndex) {
        case 0:
            var messageIndex = Math.floor(Math.random() * (motivationalMessages.length - 1)) + 1;
            return motivationalMessages[messageIndex].replace("${playerName}", playerName).replace("${teammateName}", teammateName);
        case 1:
            var messageIndex = Math.floor(Math.random() * (teasingMessages.length - 1)) + 1;
            return teasingMessages[messageIndex].replace("${playerName}", playerName).replace("${teammateName}", teammateName);
        case 2:
            var messageIndex = Math.floor(Math.random() * (razzingMessages.length - 1)) + 1;
            return razzingMessages[messageIndex].replace("${playerName}", playerName).replace("${teammateName}", teammateName);
        default:
            var messageIndex = Math.floor(Math.random() * (friendlyMessages.length - 1)) + 1;
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

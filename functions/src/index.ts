import { onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { initializeApp, applicationDefault } from "firebase-admin/app";
import * as https from "https";
import { google } from "googleapis";

const PROJECT_ID = 'ten-thousand-puck-challenge';
const HOST = 'fcm.googleapis.com';
const PATH = '/v1/projects/' + PROJECT_ID + '/messages:send';
const MESSAGING_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const SCOPES = [MESSAGING_SCOPE];

function getAccessToken() {
    return new Promise(function (resolve, reject) {
        const key = require('../service-account.json');
        const jwtClient = new google.auth.JWT(
            key.client_email,
            undefined,
            key.private_key,
            SCOPES,
            undefined
        );
        jwtClient.authorize(function (err: any, tokens: any) {
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
    getAccessToken().then(function (accessToken) {
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

        const request = https.request(options, function (resp: any) {
            resp.setEncoding('utf8');
            resp.on('data', function (data: any) {
                logger.log('Message sent to Firebase for delivery, response:');
                logger.log(data);
            });
        });

        request.on('error', function (err: any) {
            logger.log('Unable to send message to Firebase');
            logger.error(err);
        });

        request.write(JSON.stringify(fcmMessage));
        request.end();
    });
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

// // Start writing Firebase Functions
// // https://firebase.google.com/docs/functions/typescript

export const inviteSent = onDocumentCreated({ document: "invites/{userId}/invites/{teammateId}" }, async (event) => {
    const context = event;
    let user;
    let teammate;
    let teammateName;
    let fcmToken: string | null;

    // Retrieve the user who will be receiving the notification
    await db.collection("users").doc(context.params.userId).get().then(async (doc) => {
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
            await db.collection("users").doc(context.params.teammateId).get().then((tDoc) => {
                // Get the teammates name
                teammate = tDoc.data();
                teammateName = teammate != undefined ? teammate.display_name : "Someone";
                data.message.notification.body = `${teammateName} has sent you an invite.`;

                logger.log("Sending notification with data: " + JSON.stringify(data));

                sendFcmMessage(data);
            }).catch((err) => {
                logger.log("Error fetching firestore users (teammate) collection: " + err);
            });
        } else {
            logger.log("fcm_token not found");
        }
    }).catch((err) => {
        logger.log("Error fetching firestore users collection: " + err);
        return null;
    });
});

export const inviteAccepted = onDocumentCreated({ document: "teammates/{userId}/teammates/{teammateId}" }, async (event) => {
    const context = event;
    let user;
    let teammate;
    let teammateName;
    let fcmToken: string | null;

    // Retrieve the user who will be receiving the notification
    await db.collection("users").doc(context.params.teammateId).get().then(async (doc) => {
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
            await db.collection("users").doc(context.params.userId).get().then((tDoc) => {
                // Get the teammates name
                teammate = tDoc.data();
                teammateName = teammate != undefined ? teammate.display_name : "Someone";
                data.message.notification.body = `${teammateName} has accepted your invite.`;

                logger.log("Sending notification with data: " + JSON.stringify(data));

                sendFcmMessage(data);
            }).catch((err) => {
                logger.log("Error fetching firestore users (teammate) collection: " + err);
            });
        } else {
            logger.log("fcm_token not found");
        }
    }).catch((err) => {
        logger.log("Error fetching firestore users collection: " + err);
        return null;
    });
});

// Update the iteration timestamp for caching purposes any time a new session is created
// Send teammates(friends) a notification to inspire some friendly competition
export const sessionCreated = onDocumentCreated({ document: "iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}" }, async (event) => {
    const context = event;
    // Update the according iteration timestamp (updated_at)
    await db.collection(`iterations/${context.params.userId}/iterations`).doc(context.params.iterationId).update({ 'updated_at': new Date(Date.now()) }).then(async (_) => {
        // Send friends notifications
        let user: any;
        let session: any;
        let teammates: any[];

        // Retrieve the user who will be receiving the notification
        await db.collection("users").doc(context.params.userId).get().then(async (doc) => {
            user = doc.data();

            await db.collection(`iterations/${context.params.userId}/iterations/${context.params.iterationId}/sessions`).doc(context.params.sessionId).get().then(async (sDoc) => {
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
                    await db.collection(`teammates/${context.params.userId}/teammates`).get().then(async (tDoc) => {
                        // Get the players teammates
                        teammates = tDoc.docs;

                        teammates.forEach(async (t) => {
                            let teammate = t.data();
                            await db.collection("users").doc(t.id).get().then(async (tmDoc) => {
                                let friend = tmDoc.data();
                                let friendNotifications = friend!.friend_notifications != undefined ? friend!.friend_notifications : false;
                                let fcmToken = teammate.fcm_token != undefined ? teammate.fcm_token : null;
                                //functions.logger.debug("attempting send notification to teammate: " + teammate.display_name + "\nfcm_token: " + fcmToken + "\nfriend_notifications: " + friendNotifications);

                                if (friendNotifications && fcmToken != null) {
                                    data.notification.body = getFriendNotificationMessage(user!.display_name, teammate.display_name);
                                    data.message.token = fcmToken;

                                    logger.debug("Sending notification with data: " + JSON.stringify(data));

                                    sendFcmMessage(data);
                                }
                            });
                        });

                        return true;
                    }).catch((err) => {
                        logger.error("Error fetching teammate collection: " + err);
                        return null;
                    });

                    return true;
                } else {
                    logger.warn("fcm_token not found");
                    return null;
                }
            }).catch((err) => {
                logger.error("Error fetching shooting session: " + err);
                return null;
            });
        }).catch((err) => {
            logger.error("Error fetching user: " + err);
            return null;
        });
    }).catch((err) => {
        logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });


});

// Update the iteration timestamp for caching purposes any time a session is updated
export const sessionUpdated = onDocumentUpdated({ document: "iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}" }, async (event) => {
    const context = event;
    // Retrieve the user who will be receiving the notification
    await db.collection(`iterations/${context.params.userId}/iterations`).doc(`${context.params.iterationId}`).update({ 'updated_at': new Date(Date.now()) }).then((_) => true).catch((err) => {
        logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });
});

// Update the iteration timestamp for caching purposes any time a session is deleted
export const sessionDeleted = onDocumentDeleted({ document: "iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}" }, async (event) => {
    const context = event;
    // Retrieve the user who will be receiving the notification
    await db.collection(`iterations/${context.params.userId}/iterations`).doc(`${context.params.iterationId}`).update({ 'updated_at': new Date(Date.now()) }).then((_) => true).catch((err) => {
        logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
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

// Helper: Get start of current week (Monday 12am EST)
function getWeekStartEST(): Date {
    const now = new Date();
    // Convert to EST
    const estOffset = -5 * 60; // EST is UTC-5
    const utc = now.getTime() + (now.getTimezoneOffset() * 60000);
    const estDate = new Date(utc + (estOffset * 60000));
    // Find Monday
    const day = estDate.getDay();
    const diff = estDate.getDate() - day + (day === 0 ? -6 : 1); // adjust when day is sunday
    const monday = new Date(estDate.setDate(diff));
    monday.setHours(0, 0, 0, 0);
    return monday;
}

// Main scheduled function
export const assignWeeklyAchievements = onSchedule({ schedule: '0 5 * * 1', timeZone: 'America/New_York' }, async (event) => {
    const weekStart = getWeekStartEST();
    try {
        const usersSnap = await db.collection('users').get();
        for (const userDoc of usersSnap.docs) {
            const userId = userDoc.id;
            // TODO: Remove this line for production
            if (userId !== 'L5sRMTzi6OQfW86iK62todmS7Gz2' && userId !== 'bNyNJya3uwaNjH4eA8XWZcfZjYl2') continue; // Only update test user for now
            const userData = userDoc.data();
            const playerAge = userData.age || 18;

            // --- Delete incomplete achievements from previous week ---
            const achievementsSnap = await db.collection('users').doc(userId).collection('achievements').where('completed', '==', false).where('time_frame', '==', 'week').get();
            const deletePromises: Promise<any>[] = [];
            achievementsSnap.forEach(doc => {
                deletePromises.push(doc.ref.delete());
            });
            await Promise.all(deletePromises);

            // --- Use summary stats from /users/{userId}/stats/weekly ---
            const statsDoc = await db.collection('users').doc(userId).collection('stats').doc('weekly').get();
            if (!statsDoc.exists) continue;
            const stats = statsDoc.data() || {};
            const shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
            const shotCounts: { [key: string]: number } = stats.total_shots || { wrist: 0, snap: 0, slap: 0, backhand: 0 };
            const sessionMeta: { date: any }[] = (stats.sessions || []).map((s: any) => ({ date: s.date }));
            const sessionShotCounts: { [key: string]: number[] } = {};
            const sessionAccuracies: { [key: string]: number[] } = {};
            for (const type of shotTypes) {
                sessionShotCounts[type] = (stats.sessions || []).map((s: any) => s.shots?.[type] ?? 0);
                sessionAccuracies[type] = (stats.sessions || []).map((s: any) => {
                    const shots = s.shots?.[type] ?? 0;
                    const hits = s.targets_hit?.[type] ?? 0;
                    return shots > 0 ? (hits / shots) * 100 : 0;
                });
            }

            // --- RevenueCat Firestore Extension: Check if user is pro (new field structure) ---
            let isPro = false;
            try {
                // Extension now writes entitlements directly to user document
                // Check for entitlements.pro and valid expiry
                const entitlements = userData.entitlements || {};
                const pro = entitlements.pro || {};
                if (pro && typeof pro.expires_date === 'string') {
                    const expires = new Date(pro.expires_date);
                    if (expires > new Date()) {
                        isPro = true;
                    }
                }
            } catch (e) {
                isPro = false;
            }

            // --- Assignment Logic Ported from Dart ---
            // Difficulty mapping for each age group
            const difficultyMap: { [key: string]: string[] } = {
                u7: ['Easy', 'Medium', 'Hard'],
                u9: ['Easy', 'Medium', 'Hard'],
                u11: ['Easy', 'Medium', 'Hard'],
                u13: ['Easy', 'Medium', 'Hard', 'Hardest'],
                u15: ['Easy', 'Medium', 'Hard', 'Hardest'],
                u18: ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
                adult: ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
            };

            // Age group logic
            let ageGroup = 'adult';
            if (playerAge < 7) ageGroup = 'u7';
            else if (playerAge < 9) ageGroup = 'u9';
            else if (playerAge < 11) ageGroup = 'u11';
            else if (playerAge < 13) ageGroup = 'u13';
            else if (playerAge < 15) ageGroup = 'u15';
            else if (playerAge < 18) ageGroup = 'u18';

            // Tunable variables for hockey age groups
            const maxShotsPerSession: { [key: string]: number } = {
                u7: 15, u9: 20, u11: 25, u13: 30, u15: 40, u18: 50, adult: 60
            };

            // Achievement templates (full migration from Dart)
            const templates: any[] = [
                // --- Quantity based ---
                { id: 'qty_wrist_easy', style: 'quantity', title: 'Wrist Shot Week', description: 'Take 30 wrist shots this week. You can spread them out over any sessions!', shotType: 'wrist', goalType: 'count', goalValue: 30, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'qty_snap_hard', style: 'quantity', title: 'Snap Shot Challenge', description: 'Take 60 snap shots this week. You can do it in any session(s)!', shotType: 'snap', goalType: 'count', goalValue: 60, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'qty_backhand_hardest', style: 'quantity', title: 'Backhand Mastery', description: 'Take 100 backhands this week. You can split them up however you want!', shotType: 'backhand', goalType: 'count', goalValue: 100, difficulty: 'Hardest', proLevel: false, isBonus: false },
                { id: 'qty_slap_impossible', style: 'quantity', title: 'Slap Shot Marathon', description: 'Take 200 slap shots this week. Spread them out over the week!', shotType: 'slap', goalType: 'count', goalValue: 200, difficulty: 'Impossible', proLevel: false, isBonus: true },
                // --- n shots for x sessions in a row ---
                { id: 'wrist_20_three_sessions', style: 'quantity', title: 'Wrist Shot Consistency', description: 'Take at least 20 wrist shots for any 3 sessions in a row this week. You can keep trying until you get it!', shotType: 'wrist', goalType: 'count_per_session', goalValue: 20, sessions: 3, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'snap_15_two_sessions', style: 'quantity', title: 'Snap Shot Streak', description: 'Take at least 15 snap shots for any 2 sessions in a row this week. Keep working at it!', shotType: 'snap', goalType: 'count_per_session', goalValue: 15, sessions: 2, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'backhand_10_four_sessions', style: 'quantity', title: 'Backhand Streak', description: 'Take at least 10 backhands for any 4 sessions in a row this week. You can keep trying until you get it!', shotType: 'backhand', goalType: 'count_per_session', goalValue: 10, sessions: 4, difficulty: 'Hard', proLevel: false, isBonus: false },
                // --- Creative/Generic ---
                { id: 'chip_shot_king', style: 'fun', title: 'Chip Shot King', description: 'Alternate forehand (snap) and backhand shots for an entire shooting session. Try to keep the number of snap and backhand shots within 1 of each other!', shotType: 'mixed', goalType: 'alternate', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
                { id: 'variety_master', style: 'fun', title: 'Variety Master', description: 'Take at least 5 of each shot type (wrist, snap, backhand, slap) in a single session this week.', shotType: 'all', goalType: 'variety', goalValue: 5, difficulty: 'Medium', proLevel: false, isBonus: true },
                // --- More Fun Templates ---
                { id: 'fun_celebration_easy', style: 'fun', title: 'Celebration Station', description: 'Come up with a new goal celebration and use it after every session this week!', shotType: '', goalType: 'celebration', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: true },
                { id: 'fun_coach_hard', style: 'fun', title: 'Coach’s Tip', description: 'Ask your coach or parent for a tip and try to use it in your next session.', shotType: '', goalType: 'coach_tip', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
                { id: 'fun_video_medium', style: 'fun', title: 'Video Star', description: 'Record a video of your best shot and share it with a friend or coach.', shotType: '', goalType: 'video', goalValue: 1, difficulty: 'Medium', proLevel: false, isBonus: true },
                { id: 'fun_trickshot_hard', style: 'fun', title: 'Trick Shot Showdown', description: 'Invent a new trick shot and attempt it in a session this week.', shotType: '', goalType: 'trickshot', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
                { id: 'fun_teamwork_easy', style: 'fun', title: 'Teamwork Makes the Dream Work', description: 'Help a teammate or sibling with their shooting this week.', shotType: '', goalType: 'teamwork', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: true },
                // --- Accuracy based (pro) ---
                { id: 'acc_wrist_easy', style: 'accuracy', title: 'Wrist Shot Precision', description: 'Achieve 60% accuracy on wrist shots in any 2 sessions in a row this week. Keep trying until you get it!', shotType: 'wrist', goalType: 'accuracy', targetAccuracy: 60.0, sessions: 2, difficulty: 'Easy', proLevel: true, isBonus: false },
                { id: 'acc_snap_hard', style: 'accuracy', title: 'Snap Shot Sniper', description: 'Achieve 70% accuracy on snap shots in any 3 sessions in a row this week. You can keep working at it all week!', shotType: 'snap', goalType: 'accuracy', targetAccuracy: 70.0, sessions: 3, difficulty: 'Hard', proLevel: true, isBonus: false },
                { id: 'acc_backhand_hardest', style: 'accuracy', title: 'Backhand Bullseye', description: 'Achieve 80% accuracy on backhands in any 4 sessions in a row this week. Don\'t give up if you miss early!', shotType: 'backhand', goalType: 'accuracy', targetAccuracy: 80.0, sessions: 4, difficulty: 'Hardest', proLevel: true, isBonus: false },
                { id: 'acc_slap_impossible', style: 'accuracy', title: 'Slap Shot Sharpshooter', description: 'Achieve 90% accuracy on slap shots in any 5 sessions in a row this week. You have all week to get there!', shotType: 'slap', goalType: 'accuracy', targetAccuracy: 90.0, sessions: 5, difficulty: 'Impossible', proLevel: true, isBonus: true },
                // --- Ratio based ---
                { id: 'ratio_backhand_wrist_easy', style: 'ratio', title: 'Backhand Booster', description: 'Take 2 backhands for every 1 wrist shot you take this week.', shotType: 'backhand', goalType: 'ratio', goalValue: 2, secondaryValue: 1, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'ratio_backhand_snap_hard', style: 'ratio', title: 'Backhand vs Snap', description: 'Take 3 backhands for every 1 snap shot you take this week.', shotType: 'backhand', goalType: 'ratio', goalValue: 3, secondaryValue: 1, difficulty: 'Hard', proLevel: false, isBonus: false },
                // --- Consistency ---
                { id: 'consistency_daily_easy', style: 'consistency', title: 'Daily Shooter', description: 'Shoot pucks every day this week, but if you miss a day, just start your streak again! Stay motivated!', shotType: '', goalType: 'streak', goalValue: 7, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'consistency_sessions_hard', style: 'consistency', title: 'Session Grinder', description: 'Complete 5 shooting sessions this week. If you miss a day, you can still finish strong!', shotType: '', goalType: 'sessions', goalValue: 5, difficulty: 'Hard', proLevel: false, isBonus: false },
                // --- Progress ---
                { id: 'progress_wrist_improve_easy', style: 'progress', title: 'Wrist Shot Progress', description: 'Improve your wrist shot accuracy by 5% this week. Progress counts, even if it takes a few tries!', shotType: 'wrist', goalType: 'improvement', improvement: 5, difficulty: 'Easy', proLevel: true, isBonus: false },
                { id: 'progress_snap_improve_hard', style: 'progress', title: 'Snap Shot Progress', description: 'Improve your snap shot accuracy by 10% this week. You can keep working at it all week!', shotType: 'snap', goalType: 'improvement', improvement: 10, difficulty: 'Hard', proLevel: true, isBonus: false },
                // --- Creative/Fun ---
                { id: 'fun_trickshot_easy', style: 'fun', title: 'Trick Shot Time', description: 'Attempt to master a trick shot in your next session.', shotType: '', goalType: 'attempt', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'fun_friend_hard', style: 'fun', title: 'Bring a Friend', description: 'Invite a friend to join your next shooting session.', shotType: '', goalType: 'invite', goalValue: 1, difficulty: 'Medium', proLevel: false, isBonus: false },
            ];

            // Difficulty mapping for templates
            const allowed = difficultyMap[ageGroup] || ['Easy'];
            // Map 'Impossible' and 'Hardest' for younger groups
            function mapDifficulty(template: any) {
                let mapped = template.difficulty;
                if (['u7', 'u9', 'u11'].includes(ageGroup) && (template.difficulty === 'Hardest' || template.difficulty === 'Impossible')) {
                    mapped = 'Hard';
                } else if (['u13', 'u15'].includes(ageGroup) && template.difficulty === 'Impossible') {
                    mapped = 'Hardest';
                }
                return mapped;
            }

            // Prioritize under-practiced shot types
            const shotsThreshold = maxShotsPerSession[ageGroup] || 30;
            const underPracticed = Object.keys(shotCounts).filter(key => shotCounts[key] < shotsThreshold);

            // Filter eligible templates
            let eligible = templates.filter(t => allowed.includes(mapDifficulty(t)) && (isPro ? t.proLevel === true : t.proLevel !== true));

            // Shuffle eligible
            eligible = eligible.sort(() => Math.random() - 0.5);

            // Assign up to 3 achievements, prioritizing under-practiced types and session-based logic
            const assigned: any[] = [];
            const usedStyles = new Set<string>();
            for (const template of eligible) {
                if (assigned.length >= 3) break;
                // Session-based logic for count_per_session, accuracy, streak, etc.
                let meetsCriteria = false;
                if (template.goalType === 'count_per_session' && typeof template.sessions === 'number' && typeof template.goalValue === 'number') {
                    // Find streaks of sessions meeting count
                    const counts = sessionShotCounts[template.shotType] || [];
                    let streak = 0;
                    for (const c of counts) {
                        if (c >= template.goalValue) streak++;
                        else streak = 0;
                        if (streak >= template.sessions) { meetsCriteria = true; break; }
                    }
                } else if (template.goalType === 'accuracy' && typeof template.sessions === 'number' && typeof template.targetAccuracy === 'number') {
                    // Find streaks of sessions meeting accuracy
                    const accs = sessionAccuracies[template.shotType] || [];
                    let streak = 0;
                    for (const a of accs) {
                        if (a >= template.targetAccuracy) streak++;
                        else streak = 0;
                        if (streak >= template.sessions) { meetsCriteria = true; break; }
                    }
                } else if (template.goalType === 'variety' && typeof template.goalValue === 'number') {
                    // At least goalValue of each shot type in a single session
                    for (let i = 0; i < sessionMeta.length; i++) {
                        let allMet = true;
                        for (const type of shotTypes) {
                            if ((sessionShotCounts[type][i] || 0) < template.goalValue) { allMet = false; break; }
                        }
                        if (allMet) { meetsCriteria = true; break; }
                    }
                } else if (template.goalType === 'count' && typeof template.goalValue === 'number') {
                    // Total count for shot type
                    if (shotCounts[template.shotType] >= template.goalValue) meetsCriteria = true;
                } else if (template.goalType === 'ratio' && typeof template.goalValue === 'number' && typeof template.secondaryValue === 'number') {
                    // Ratio of shot types
                    // Use secondaryType if present, else default to 'wrist'
                    const secondaryType = (template as any).secondaryType || 'wrist';
                    const primary = shotCounts[template.shotType] || 0;
                    const secondary = shotCounts[secondaryType] || 0;
                    if (secondary > 0 && (primary / secondary) >= (template.goalValue / template.secondaryValue)) meetsCriteria = true;
                } else if (template.goalType === 'streak' && typeof template.goalValue === 'number') {
                    // Sessions on consecutive days
                    let streak = 1;
                    let lastDate: number | null = null;
                    for (const doc of sessionMeta) {
                        const data = doc;
                        let dateObj = data['date'];
                        if (dateObj && typeof dateObj.toDate === 'function') dateObj = dateObj.toDate();
                        const date = dateObj instanceof Date ? dateObj.getTime() : (typeof dateObj === 'number' ? dateObj : null);
                        if (!date) continue;
                        if (!lastDate) { lastDate = date; continue; }
                        const diff = Math.abs((lastDate - date) / (1000 * 60 * 60 * 24));
                        if (diff === 1) streak++;
                        else streak = 1;
                        lastDate = date;
                        if (streak >= template.goalValue) { meetsCriteria = true; break; }
                    }
                } else if (template.goalType === 'sessions' && typeof template.goalValue === 'number') {
                    // Number of sessions in the week
                    if (sessionMeta.length >= template.goalValue) meetsCriteria = true;
                } else if (template.goalType === 'improvement' && typeof template.improvement === 'number') {
                    // Compare first and last session accuracy
                    const accs = sessionAccuracies[template.shotType] || [];
                    if (accs.length >= 2 && (accs[accs.length - 1] - accs[0]) >= template.improvement) meetsCriteria = true;
                } else {
                    // Fun/creative goals: always eligible
                    meetsCriteria = true;
                }
                // Only assign if criteria met
                if (meetsCriteria) {
                    if (underPracticed.length && underPracticed.includes(template.shotType)) {
                        assigned.push(template);
                        usedStyles.add(template.goalType);
                    } else if (usedStyles.size < 3 && !usedStyles.has(template.goalType)) {
                        assigned.push(template);
                        usedStyles.add(template.goalType);
                    }
                }
            }
            // Fallback: fill with random eligible if not enough, but ensure unique styles
            while (assigned.length < 3 && eligible.length) {
                const next = eligible.pop();
                if (next && !usedStyles.has(next.style)) {
                    assigned.push(next);
                    usedStyles.add(next.style);
                }
            }

            // Format for Firestore
            const achievements = assigned.map(t => ({
                id: t.id,
                title: t.title,
                description: t.description,
                completed: false,
                dateAssigned: Timestamp.fromDate(weekStart),
                dateCompleted: null,
                time_frame: 'week',
                userId,
            }));
            // Write achievements to Firestore
            for (const achievement of achievements) {
                await db.collection('users').doc(userId).collection('achievements').add(achievement);
            }
        }
    } catch (error) {
        logger.error('Error assigning weekly achievements:', error);
    }
});

// HTTP-triggered version for live testing
export const testAssignWeeklyAchievements = onRequest(async (req, res) => {
    const weekStart = getWeekStartEST();
    try {
        const usersSnap = await db.collection('users').get();
        for (const userDoc of usersSnap.docs) {
            const userId = userDoc.id;
            // TODO: Remove this line for production
            if (userId !== 'L5sRMTzi6OQfW86iK62todmS7Gz2' && userId !== 'bNyNJya3uwaNjH4eA8XWZcfZjYl2') continue; // Only update test user for now
            const userData = userDoc.data();
            const playerAge = userData.age || 18;

            // --- Delete incomplete achievements from previous week ---
            const achievementsSnap = await db.collection('users').doc(userId).collection('achievements').where('completed', '==', false).where('time_frame', '==', 'week').get();
            const deletePromises: Promise<any>[] = [];
            achievementsSnap.forEach(doc => {
                deletePromises.push(doc.ref.delete());
            });
            await Promise.all(deletePromises);

            // --- Use summary stats from /users/{userId}/stats/weekly ---
            const statsDoc = await db.collection('users').doc(userId).collection('stats').doc('weekly').get();
            if (!statsDoc.exists) continue;
            const stats = statsDoc.data() || {};
            const shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
            const shotCounts: { [key: string]: number } = stats.total_shots || { wrist: 0, snap: 0, slap: 0, backhand: 0 };
            const sessionMeta: { date: any }[] = (stats.sessions || []).map((s: any) => ({ date: s.date }));
            const sessionShotCounts: { [key: string]: number[] } = {};
            const sessionAccuracies: { [key: string]: number[] } = {};
            for (const type of shotTypes) {
                sessionShotCounts[type] = (stats.sessions || []).map((s: any) => s.shots?.[type] ?? 0);
                sessionAccuracies[type] = (stats.sessions || []).map((s: any) => {
                    const shots = s.shots?.[type] ?? 0;
                    const hits = s.targets_hit?.[type] ?? 0;
                    return shots > 0 ? (hits / shots) * 100 : 0;
                });
            }

            // --- RevenueCat Firestore Extension: Check if user is pro (new field structure) ---
            let isPro = false;
            try {
                // Extension now writes entitlements directly to user document
                // Check for entitlements.pro and valid expiry
                const entitlements = userData.entitlements || {};
                const pro = entitlements.pro || {};
                if (pro && typeof pro.expires_date === 'string') {
                    const expires = new Date(pro.expires_date);
                    if (expires > new Date()) {
                        isPro = true;
                    }
                }
            } catch (e) {
                isPro = false;
            }

            // --- Assignment Logic Ported from Dart ---
            // Difficulty mapping for each age group
            const difficultyMap: { [key: string]: string[] } = {
                u7: ['Easy', 'Medium', 'Hard'],
                u9: ['Easy', 'Medium', 'Hard'],
                u11: ['Easy', 'Medium', 'Hard'],
                u13: ['Easy', 'Medium', 'Hard', 'Hardest'],
                u15: ['Easy', 'Medium', 'Hard', 'Hardest'],
                u18: ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
                adult: ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
            };

            // Age group logic
            let ageGroup = 'adult';
            if (playerAge < 7) ageGroup = 'u7';
            else if (playerAge < 9) ageGroup = 'u9';
            else if (playerAge < 11) ageGroup = 'u11';
            else if (playerAge < 13) ageGroup = 'u13';
            else if (playerAge < 15) ageGroup = 'u15';
            else if (playerAge < 18) ageGroup = 'u18';

            // Tunable variables for hockey age groups
            const maxShotsPerSession: { [key: string]: number } = {
                u7: 15, u9: 20, u11: 25, u13: 30, u15: 40, u18: 50, adult: 60
            };

            // Achievement templates (full migration from Dart)
            const templates: any[] = [
                // --- Quantity based ---
                { id: 'qty_wrist_easy', style: 'quantity', title: 'Wrist Shot Week', description: 'Take 30 wrist shots this week. You can spread them out over any sessions!', shotType: 'wrist', goalType: 'count', goalValue: 30, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'qty_snap_hard', style: 'quantity', title: 'Snap Shot Challenge', description: 'Take 60 snap shots this week. You can do it in any session(s)!', shotType: 'snap', goalType: 'count', goalValue: 60, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'qty_backhand_hardest', style: 'quantity', title: 'Backhand Mastery', description: 'Take 100 backhands this week. You can split them up however you want!', shotType: 'backhand', goalType: 'count', goalValue: 100, difficulty: 'Hardest', proLevel: false, isBonus: false },
                { id: 'qty_slap_impossible', style: 'quantity', title: 'Slap Shot Marathon', description: 'Take 200 slap shots this week. Spread them out over the week!', shotType: 'slap', goalType: 'count', goalValue: 200, difficulty: 'Impossible', proLevel: false, isBonus: true },
                // --- n shots for x sessions in a row ---
                { id: 'wrist_20_three_sessions', style: 'quantity', title: 'Wrist Shot Consistency', description: 'Take at least 20 wrist shots for any 3 sessions in a row this week. You can keep trying until you get it!', shotType: 'wrist', goalType: 'count_per_session', goalValue: 20, sessions: 3, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'snap_15_two_sessions', style: 'quantity', title: 'Snap Shot Streak', description: 'Take at least 15 snap shots for any 2 sessions in a row this week. Keep working at it!', shotType: 'snap', goalType: 'count_per_session', goalValue: 15, sessions: 2, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'backhand_10_four_sessions', style: 'quantity', title: 'Backhand Streak', description: 'Take at least 10 backhands for any 4 sessions in a row this week. You can keep trying until you get it!', shotType: 'backhand', goalType: 'count_per_session', goalValue: 10, sessions: 4, difficulty: 'Hard', proLevel: false, isBonus: false },
                // --- Creative/Generic ---
                { id: 'chip_shot_king', style: 'fun', title: 'Chip Shot King', description: 'Alternate forehand (snap) and backhand shots for an entire shooting session. Try to keep the number of snap and backhand shots within 1 of each other!', shotType: 'mixed', goalType: 'alternate', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
                { id: 'variety_master', style: 'fun', title: 'Variety Master', description: 'Take at least 5 of each shot type (wrist, snap, backhand, slap) in a single session this week.', shotType: 'all', goalType: 'variety', goalValue: 5, difficulty: 'Medium', proLevel: false, isBonus: true },
                // --- More Fun Templates ---
                { id: 'fun_celebration_easy', style: 'fun', title: 'Celebration Station', description: 'Come up with a new goal celebration and use it after every session this week!', shotType: '', goalType: 'celebration', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: true },
                { id: 'fun_coach_hard', style: 'fun', title: 'Coach’s Tip', description: 'Ask your coach or parent for a tip and try to use it in your next session.', shotType: '', goalType: 'coach_tip', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
                { id: 'fun_video_medium', style: 'fun', title: 'Video Star', description: 'Record a video of your best shot and share it with a friend or coach.', shotType: '', goalType: 'video', goalValue: 1, difficulty: 'Medium', proLevel: false, isBonus: true },
                { id: 'fun_trickshot_hard', style: 'fun', title: 'Trick Shot Showdown', description: 'Invent a new trick shot and attempt it in a session this week.', shotType: '', goalType: 'trickshot', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
                { id: 'fun_teamwork_easy', style: 'fun', title: 'Teamwork Makes the Dream Work', description: 'Help a teammate or sibling with their shooting this week.', shotType: '', goalType: 'teamwork', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: true },
                // --- Accuracy based (pro) ---
                { id: 'acc_wrist_easy', style: 'accuracy', title: 'Wrist Shot Precision', description: 'Achieve 60% accuracy on wrist shots in any 2 sessions in a row this week. Keep trying until you get it!', shotType: 'wrist', goalType: 'accuracy', targetAccuracy: 60.0, sessions: 2, difficulty: 'Easy', proLevel: true, isBonus: false },
                { id: 'acc_snap_hard', style: 'accuracy', title: 'Snap Shot Sniper', description: 'Achieve 70% accuracy on snap shots in any 3 sessions in a row this week. You can keep working at it all week!', shotType: 'snap', goalType: 'accuracy', targetAccuracy: 70.0, sessions: 3, difficulty: 'Hard', proLevel: true, isBonus: false },
                { id: 'acc_backhand_hardest', style: 'accuracy', title: 'Backhand Bullseye', description: 'Achieve 80% accuracy on backhands in any 4 sessions in a row this week. Don\'t give up if you miss early!', shotType: 'backhand', goalType: 'accuracy', targetAccuracy: 80.0, sessions: 4, difficulty: 'Hardest', proLevel: true, isBonus: false },
                { id: 'acc_slap_impossible', style: 'accuracy', title: 'Slap Shot Sharpshooter', description: 'Achieve 90% accuracy on slap shots in any 5 sessions in a row this week. You have all week to get there!', shotType: 'slap', goalType: 'accuracy', targetAccuracy: 90.0, sessions: 5, difficulty: 'Impossible', proLevel: true, isBonus: true },
                // --- Ratio based ---
                { id: 'ratio_backhand_wrist_easy', style: 'ratio', title: 'Backhand Booster', description: 'Take 2 backhands for every 1 wrist shot you take this week.', shotType: 'backhand', goalType: 'ratio', goalValue: 2, secondaryValue: 1, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'ratio_backhand_snap_hard', style: 'ratio', title: 'Backhand vs Snap', description: 'Take 3 backhands for every 1 snap shot you take this week.', shotType: 'backhand', goalType: 'ratio', goalValue: 3, secondaryValue: 1, difficulty: 'Hard', proLevel: false, isBonus: false },
                // --- Consistency ---
                { id: 'consistency_daily_easy', style: 'consistency', title: 'Daily Shooter', description: 'Shoot pucks every day this week, but if you miss a day, just start your streak again! Stay motivated!', shotType: '', goalType: 'streak', goalValue: 7, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'consistency_sessions_hard', style: 'consistency', title: 'Session Grinder', description: 'Complete 5 shooting sessions this week. If you miss a day, you can still finish strong!', shotType: '', goalType: 'sessions', goalValue: 5, difficulty: 'Hard', proLevel: false, isBonus: false },
                // --- Progress ---
                { id: 'progress_wrist_improve_easy', style: 'progress', title: 'Wrist Shot Progress', description: 'Improve your wrist shot accuracy by 5% this week. Progress counts, even if it takes a few tries!', shotType: 'wrist', goalType: 'improvement', improvement: 5, difficulty: 'Easy', proLevel: true, isBonus: false },
                { id: 'progress_snap_improve_hard', style: 'progress', title: 'Snap Shot Progress', description: 'Improve your snap shot accuracy by 10% this week. You can keep working at it all week!', shotType: 'snap', goalType: 'improvement', improvement: 10, difficulty: 'Hard', proLevel: true, isBonus: false },
                // --- Creative/Fun ---
                { id: 'fun_trickshot_easy', style: 'fun', title: 'Trick Shot Time', description: 'Attempt to master a trick shot in your next session.', shotType: '', goalType: 'attempt', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'fun_friend_hard', style: 'fun', title: 'Bring a Friend', description: 'Invite a friend to join your next shooting session.', shotType: '', goalType: 'invite', goalValue: 1, difficulty: 'Medium', proLevel: false, isBonus: false },
            ];

            // Difficulty mapping for templates
            const allowed = difficultyMap[ageGroup] || ['Easy'];
            // Map 'Impossible' and 'Hardest' for younger groups
            function mapDifficulty(template: any) {
                let mapped = template.difficulty;
                if (['u7', 'u9', 'u11'].includes(ageGroup) && (template.difficulty === 'Hardest' || template.difficulty === 'Impossible')) {
                    mapped = 'Hard';
                } else if (['u13', 'u15'].includes(ageGroup) && template.difficulty === 'Impossible') {
                    mapped = 'Hardest';
                }
                return mapped;
            }

            // Prioritize under-practiced shot types
            const shotsThreshold = maxShotsPerSession[ageGroup] || 30;
            const underPracticed = Object.keys(shotCounts).filter(key => shotCounts[key] < shotsThreshold);

            // Filter eligible templates
            let eligible = templates.filter(t => allowed.includes(mapDifficulty(t)) && (isPro ? t.proLevel === true : t.proLevel !== true));

            // Shuffle eligible
            eligible = eligible.sort(() => Math.random() - 0.5);

            // Assign up to 3 achievements, prioritizing under-practiced types and session-based logic
            const assigned: any[] = [];
            const usedStyles = new Set<string>();
            for (const template of eligible) {
                if (assigned.length >= 3) break;
                // Session-based logic for count_per_session, accuracy, streak, etc.
                let meetsCriteria = false;
                if (template.goalType === 'count_per_session' && typeof template.sessions === 'number' && typeof template.goalValue === 'number') {
                    // Find streaks of sessions meeting count
                    const counts = sessionShotCounts[template.shotType] || [];
                    let streak = 0;
                    for (const c of counts) {
                        if (c >= template.goalValue) streak++;
                        else streak = 0;
                        if (streak >= template.sessions) { meetsCriteria = true; break; }
                    }
                } else if (template.goalType === 'accuracy' && typeof template.sessions === 'number' && typeof template.targetAccuracy === 'number') {
                    // Find streaks of sessions meeting accuracy
                    const accs = sessionAccuracies[template.shotType] || [];
                    let streak = 0;
                    for (const a of accs) {
                        if (a >= template.targetAccuracy) streak++;
                        else streak = 0;
                        if (streak >= template.sessions) { meetsCriteria = true; break; }
                    }
                } else if (template.goalType === 'variety' && typeof template.goalValue === 'number') {
                    // At least goalValue of each shot type in a single session
                    for (let i = 0; i < sessionMeta.length; i++) {
                        let allMet = true;
                        for (const type of shotTypes) {
                            if ((sessionShotCounts[type][i] || 0) < template.goalValue) { allMet = false; break; }
                        }
                        if (allMet) { meetsCriteria = true; break; }
                    }
                } else if (template.goalType === 'count' && typeof template.goalValue === 'number') {
                    // Total count for shot type
                    if (shotCounts[template.shotType] >= template.goalValue) meetsCriteria = true;
                } else if (template.goalType === 'ratio' && typeof template.goalValue === 'number' && typeof template.secondaryValue === 'number') {
                    // Ratio of shot types
                    // Use secondaryType if present, else default to 'wrist'
                    const secondaryType = (template as any).secondaryType || 'wrist';
                    const primary = shotCounts[template.shotType] || 0;
                    const secondary = shotCounts[secondaryType] || 0;
                    if (secondary > 0 && (primary / secondary) >= (template.goalValue / template.secondaryValue)) meetsCriteria = true;
                } else if (template.goalType === 'streak' && typeof template.goalValue === 'number') {
                    // Sessions on consecutive days
                    let streak = 1;
                    let lastDate: number | null = null;
                    for (const doc of sessionMeta) {
                        const data = doc;
                        let dateObj = data['date'];
                        if (dateObj && typeof dateObj.toDate === 'function') dateObj = dateObj.toDate();
                        const date = dateObj instanceof Date ? dateObj.getTime() : (typeof dateObj === 'number' ? dateObj : null);
                        if (!date) continue;
                        if (!lastDate) { lastDate = date; continue; }
                        const diff = Math.abs((lastDate - date) / (1000 * 60 * 60 * 24));
                        if (diff === 1) streak++;
                        else streak = 1;
                        lastDate = date;
                        if (streak >= template.goalValue) { meetsCriteria = true; break; }
                    }
                } else if (template.goalType === 'sessions' && typeof template.goalValue === 'number') {
                    // Number of sessions in the week
                    if (sessionMeta.length >= template.goalValue) meetsCriteria = true;
                } else if (template.goalType === 'improvement' && typeof template.improvement === 'number') {
                    // Compare first and last session accuracy
                    const accs = sessionAccuracies[template.shotType] || [];
                    if (accs.length >= 2 && (accs[accs.length - 1] - accs[0]) >= template.improvement) meetsCriteria = true;
                } else {
                    // Fun/creative goals: always eligible
                    meetsCriteria = true;
                }
                // Only assign if criteria met
                if (meetsCriteria) {
                    if (underPracticed.length && underPracticed.includes(template.shotType)) {
                        assigned.push(template);
                        usedStyles.add(template.goalType);
                    } else if (usedStyles.size < 3 && !usedStyles.has(template.goalType)) {
                        assigned.push(template);
                        usedStyles.add(template.goalType);
                    }
                }
            }
            // Fallback: fill with random eligible if not enough, but ensure unique styles
            while (assigned.length < 3 && eligible.length) {
                const next = eligible.pop();
                if (next && !usedStyles.has(next.style)) {
                    assigned.push(next);
                    usedStyles.add(next.style);
                }
            }

            // Format for Firestore
            const achievements = assigned.map(t => ({
                id: t.id,
                title: t.title,
                description: t.description,
                completed: false,
                dateAssigned: Timestamp.fromDate(weekStart),
                dateCompleted: null,
                time_frame: 'week',
                userId,
            }));
            // Write achievements to Firestore
            for (const achievement of achievements) {
                await db.collection('users').doc(userId).collection('achievements').add(achievement);
            }
        }

        res.status(200).send('assignWeeklyAchievements executed successfully');
    } catch (error) {
        logger.error('Error assigning weekly achievements:', error);
        const errorMessage = typeof error === 'object' && error !== null && 'message' in error ? (error as { message: string }).message : String(error);
        res.status(200).send('assignWeeklyAchievements failed: ' + errorMessage);
    }
});
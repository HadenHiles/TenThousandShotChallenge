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
    // Update the iteration timestamp
    await db.collection(`iterations/${context.params.userId}/iterations`).doc(`${context.params.iterationId}`).update({ 'updated_at': new Date(Date.now()) }).catch((err) => {
        logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });

    // --- Recalculate and write summary stats to /users/{userId}/stats/weekly ---
    try {
        const sessionsSnap = await db.collection(`iterations/${context.params.userId}/iterations/${context.params.iterationId}/sessions`).orderBy('date', 'desc').get();
        let recentSessions = [];
        let seasonTotalShots = 0;
        let seasonTotalShotsWithAccuracy = 0;
        let seasonTargetsHit = 0;
        let shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
        let seasonShotTypeTotals = { wrist: 0, snap: 0, slap: 0, backhand: 0 };
        let seasonTargetsHitType = { wrist: 0, snap: 0, slap: 0, backhand: 0 };
        let seasonAccuracyType = { wrist: 0.0, snap: 0.0, slap: 0.0, backhand: 0.0 };

        let sessionCount = 0;
        for (const sessionDoc of sessionsSnap.docs) {
            const s = sessionDoc.data();
            if (sessionCount < 10) {
                recentSessions.push({
                    date: s.date,
                    shots: {
                        wrist: s.total_wrist || 0,
                        snap: s.total_snap || 0,
                        slap: s.total_slap || 0,
                        backhand: s.total_backhand || 0
                    },
                    targets_hit: {
                        wrist: s.wrist_targets_hit || 0,
                        snap: s.snap_targets_hit || 0,
                        slap: s.slap_targets_hit || 0,
                        backhand: s.backhand_targets_hit || 0
                    }
                });
            }
            sessionCount++;
            seasonTotalShots += typeof s.total === 'number' ? s.total : 0;
            seasonShotTypeTotals.wrist += typeof s.total_wrist === 'number' ? s.total_wrist : 0;
            seasonShotTypeTotals.snap += typeof s.total_snap === 'number' ? s.total_snap : 0;
            seasonShotTypeTotals.slap += typeof s.total_slap === 'number' ? s.total_slap : 0;
            seasonShotTypeTotals.backhand += typeof s.total_backhand === 'number' ? s.total_backhand : 0;

            // Only include sessions with any targets_hit for accuracy stats
            const hasAccuracy = (s.wrist_targets_hit || 0) > 0 || (s.snap_targets_hit || 0) > 0 || (s.slap_targets_hit || 0) > 0 || (s.backhand_targets_hit || 0) > 0;
            if (hasAccuracy) {
                seasonTotalShotsWithAccuracy += typeof s.total === 'number' ? s.total : 0;
                seasonTargetsHitType.wrist += typeof s.wrist_targets_hit === 'number' ? s.wrist_targets_hit : 0;
                seasonTargetsHitType.snap += typeof s.snap_targets_hit === 'number' ? s.snap_targets_hit : 0;
                seasonTargetsHitType.slap += typeof s.slap_targets_hit === 'number' ? s.slap_targets_hit : 0;
                seasonTargetsHitType.backhand += typeof s.backhand_targets_hit === 'number' ? s.backhand_targets_hit : 0;
            }
        }

        seasonTargetsHit = Object.values(seasonTargetsHitType).reduce((a, b) => a + b, 0);
        // Calculate accuracy per shot type (only for sessions with accuracy)
        for (const type of shotTypes) {
            let shots = 0;
            let hits = seasonTargetsHitType[type as keyof typeof seasonTargetsHitType];
            for (const sessionDoc of sessionsSnap.docs) {
                const s = sessionDoc.data();
                const hasAccuracy = (s.wrist_targets_hit || 0) > 0 || (s.snap_targets_hit || 0) > 0 || (s.slap_targets_hit || 0) > 0 || (s.backhand_targets_hit || 0) > 0;
                if (hasAccuracy) {
                    if (type === 'wrist') shots += typeof s.total_wrist === 'number' ? s.total_wrist : 0;
                    if (type === 'snap') shots += typeof s.total_snap === 'number' ? s.total_snap : 0;
                    if (type === 'slap') shots += typeof s.total_slap === 'number' ? s.total_slap : 0;
                    if (type === 'backhand') shots += typeof s.total_backhand === 'number' ? s.total_backhand : 0;
                }
            }
            seasonAccuracyType[type as keyof typeof seasonAccuracyType] = shots > 0 ? (hits / shots) * 100.0 : 0.0;
        }
        const seasonAccuracy = seasonTotalShotsWithAccuracy > 0 ? (seasonTargetsHit / seasonTotalShotsWithAccuracy) * 100.0 : 0.0;

        // Write summary stats to /users/{userId}/stats/weekly
        const statsRef = db.collection('users').doc(context.params.userId).collection('stats').doc('weekly');
        await statsRef.set({
            week_start: getWeekStartEST(),
            total_sessions: sessionsSnap.docs.length,
            total_shots: seasonShotTypeTotals,
            targets_hit: seasonTargetsHitType,
            accuracy: seasonAccuracyType,
            season_total_shots: seasonTotalShots,
            season_total_shots_with_accuracy: seasonTotalShotsWithAccuracy,
            season_targets_hit: seasonTargetsHit,
            season_accuracy: seasonAccuracy,
            sessions: recentSessions
        });
    } catch (e) {
        logger.error('Error updating weekly stats after session deletion:', e);
    }
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
export const assignWeeklyAchievements = onSchedule({ schedule: '0 5 * * 1', timeZone: 'America/New_York', timeoutSeconds: 1200 }, async (event) => {
    // TODO: copy code from onRequest version once all dev is complete
});

// HTTP-triggered version for live testing
export const testAssignWeeklyAchievements = onRequest(async (req, res) => {
    const weekStart = getWeekStartEST();
    try {
        const now = new Date();
        const FIFTEEN_DAYS_MS = 15 * 24 * 60 * 60 * 1000;
        const fifteenDaysAgo = new Date(now.getTime() - FIFTEEN_DAYS_MS);
        const fifteenDaysAgoISO = fifteenDaysAgo.toISOString();
        const usersSnap = await db.collection('users').where('last_seen', '>=', fifteenDaysAgoISO).get();
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
            const sessionShotCounts: { [key: string]: number[] } = {};
            const sessionAccuracies: { [key: string]: number[] } = {};
            for (const type of shotTypes) {
                sessionShotCounts[type] = (stats.sessions || []).map((s: any) => s.shots?.[type] ?? 0);
                // Only include sessions with targets_hit for this shot type in accuracy calculations
                const sessionsWithAccuracy = (stats.sessions || []).filter((s: any) => s.targets_hit && typeof s.targets_hit[type] === 'number');
                sessionAccuracies[type] = sessionsWithAccuracy.map((s: any) => {
                    const shots = s.shots?.[type] ?? 0;
                    const hits = s.targets_hit?.[type] ?? 0;
                    return shots > 0 ? (hits / shots) * 100 : 0;
                });

                // Calculate season totals
                // All shots for this shot type (season)
                const seasonTotalShots = (stats.sessions || []).reduce((sum: number, s: any) => sum + (s.shots?.[type] ?? 0), 0);
                // Only shots from sessions with accuracy tracking (season)
                const seasonTotalShotsWithAccuracy = sessionsWithAccuracy.reduce((sum: number, s: any) => sum + (s.shots?.[type] ?? 0), 0);
                // Attach to stats for later use if needed
                if (!stats._seasonTotals) stats._seasonTotals = {};
                stats._seasonTotals[type] = {
                    all: seasonTotalShots,
                    withAccuracy: seasonTotalShotsWithAccuracy
                };
            }

            // --- RevenueCat Firestore Extension: Check if user is pro (new field structure) ---
            let isPro = false;
            try {
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
            const difficultyMap: { [key: string]: string[] } = {
                u7: ['Easy', 'Medium', 'Hard'],
                u9: ['Easy', 'Medium', 'Hard'],
                u11: ['Easy', 'Medium', 'Hard'],
                u13: ['Easy', 'Medium', 'Hard', 'Hardest'],
                u15: ['Easy', 'Medium', 'Hard', 'Hardest'],
                u18: ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
                adult: ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
            };

            let ageGroup = 'adult';
            if (playerAge < 7) ageGroup = 'u7';
            else if (playerAge < 9) ageGroup = 'u9';
            else if (playerAge < 11) ageGroup = 'u11';
            else if (playerAge < 13) ageGroup = 'u13';
            else if (playerAge < 15) ageGroup = 'u15';
            else if (playerAge < 18) ageGroup = 'u18';

            // Achievement templates (full migration from Dart)
            let templates: any[] = [
                // --- Quantity based ---
                { id: 'qty_wrist_easy', style: 'quantity', title: 'Wrist Shot Week', description: 'Take 30 wrist shots. You can spread them out over any sessions!', shotType: 'wrist', goalType: 'count', goalValue: 30, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'qty_snap_hard', style: 'quantity', title: 'Snap Shot Challenge', description: 'Take 60 snap shots. You can do it in any session(s)!', shotType: 'snap', goalType: 'count', goalValue: 60, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'qty_backhand_hardest', style: 'quantity', title: 'Backhand Mastery', description: 'Take 100 backhands. You can split them up however you want!', shotType: 'backhand', goalType: 'count', goalValue: 100, difficulty: 'Hardest', proLevel: false, isBonus: false },
                { id: 'qty_slap_impossible', style: 'quantity', title: 'Slap Shot Marathon', description: 'Take 200 slap shots. Spread them out over the week!', shotType: 'slap', goalType: 'count', goalValue: 200, difficulty: 'Impossible', proLevel: false, isBonus: false },
                { id: 'qty_mixed_medium', style: 'quantity', title: 'Mix It Up', description: 'Take at least 20 shots of each type (wrist, snap, backhand, slap).', shotType: 'all', goalType: 'count', goalValue: 20, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'qty_lefty_easy', style: 'quantity', title: 'Lefty Challenge', description: 'Take 25 shots with your non-dominant hand.', shotType: 'any', goalType: 'count', goalValue: 25, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'qty_speed_50', style: 'quantity', title: 'Speed Demon', description: 'Take 50 shots in under 10 minutes in a single session.', shotType: 'any', goalType: 'count_time', goalValue: 50, timeLimit: 10, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'qty_ambidextrous_30', style: 'quantity', title: 'Ambidextrous Ace', description: 'Take 15 shots with each hand in one session.', shotType: 'any', goalType: 'count_each_hand', goalValue: 15, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'qty_rapidfire_20', style: 'quantity', title: 'Rapid Fire', description: 'Take 20 shots in 60 seconds or less.', shotType: 'any', goalType: 'count_time', goalValue: 20, timeLimit: 1, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'qty_balanced_40', style: 'quantity', title: 'Balanced Attack', description: 'Take 10 wrist, 10 snap, 10 backhand, and 10 slap shots.', shotType: 'all', goalType: 'count', goalValue: 10, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'qty_evening_25', style: 'quantity', title: 'Evening Shooter', description: 'Take 25 shots after 7pm in a single session.', shotType: 'any', goalType: 'count_evening', goalValue: 25, difficulty: 'Easy', proLevel: false, isBonus: false },
                // --- n shots for x sessions in a row ---
                { id: 'wrist_20_three_sessions', style: 'quantity', title: 'Wrist Shot Consistency', description: 'Take at least 20 wrist shots for any 3 sessions in a row. You can keep trying until you get it!', shotType: 'wrist', goalType: 'count_per_session', goalValue: 20, sessions: 3, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'snap_15_two_sessions', style: 'quantity', title: 'Snap Shot Streak', description: 'Take at least 15 snap shots for any 2 sessions in a row. Keep working at it!', shotType: 'snap', goalType: 'count_per_session', goalValue: 15, sessions: 2, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'backhand_10_four_sessions', style: 'quantity', title: 'Backhand Streak', description: 'Take at least 10 backhands for any 4 sessions in a row. You can keep trying until you get it!', shotType: 'backhand', goalType: 'count_per_session', goalValue: 10, sessions: 4, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'slap_15_three_sessions', style: 'quantity', title: 'Slap Shot Consistency', description: 'Take at least 15 slap shots for any 3 sessions in a row.', shotType: 'slap', goalType: 'count_per_session', goalValue: 15, sessions: 3, difficulty: 'Medium', proLevel: false, isBonus: false },
                // --- Creative/Generic ---
                { id: 'fun_celebration_easy', style: 'fun', title: 'Celebration Station', description: 'Come up with a new goal celebration and use it after every session!', shotType: '', goalType: 'celebration', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: true },
                { id: 'fun_coach_hard', style: 'fun', title: 'Coach\'s Tip', description: 'Ask your coach or parent for a tip and try to use it in your next session.', shotType: '', goalType: 'coach_tip', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
                { id: 'fun_video_medium', style: 'fun', title: 'Video Star', description: 'Record a video of your best shot and share it with a friend or coach.', shotType: '', goalType: 'video', goalValue: 1, difficulty: 'Medium', proLevel: false, isBonus: true },
                { id: 'fun_trickshot_hard', style: 'fun', title: 'Trick Shot Showdown', description: 'Invent a new trick shot and attempt it in a session.', shotType: '', goalType: 'trickshot', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
                { id: 'fun_teamwork_easy', style: 'fun', title: 'Teamwork Makes the Dream Work', description: 'Help a teammate or sibling with their shooting.', shotType: '', goalType: 'teamwork', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: true },
                { id: 'fun_music_easy', style: 'fun', title: 'Music Motivation', description: 'Create a playlist and shoot to your favorite songs.', shotType: '', goalType: 'music', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: true },
                { id: 'social_share_easy', style: 'fun', title: 'Share the Love', description: 'Share your progress on social media or with a friend.', shotType: '', goalType: 'share', goalValue: 1, difficulty: 'Easy', proLevel: false, isBonus: true },
                { id: 'social_challenge_medium', style: 'fun', title: 'Challenge a Friend', description: 'Challenge a friend to a shooting contest.', shotType: '', goalType: 'challenge_friend', goalValue: 1, difficulty: 'Medium', proLevel: false, isBonus: true },
                { id: 'social_teamwork_hard', style: 'fun', title: 'Teamwork Triumph', description: 'Complete a team shooting drill with at least 2 teammates.', shotType: '', goalType: 'teamwork_drill', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
                // --- Accuracy based (pro) ---
                { id: 'acc_wrist_70', style: 'accuracy', title: 'Wrist Wizard', description: 'Achieve 70% accuracy on wrist shots in a single session.', shotType: 'wrist', goalType: 'accuracy', targetAccuracy: 70.0, sessions: 1, difficulty: 'Medium', proLevel: true, isBonus: false, isStreak: false },
                { id: 'acc_snap_80', style: 'accuracy', title: 'Snap Supreme', description: 'Achieve 80% accuracy on snap shots in a single session.', shotType: 'snap', goalType: 'accuracy', targetAccuracy: 80.0, sessions: 1, difficulty: 'Hard', proLevel: true, isBonus: false, isStreak: false },
                { id: 'acc_backhand_60', style: 'accuracy', title: 'Backhand Bull', description: 'Achieve 60% accuracy on backhands in any 2 sessions.', shotType: 'backhand', goalType: 'accuracy', targetAccuracy: 60.0, sessions: 2, difficulty: 'Easy', proLevel: true, isBonus: false, isStreak: false },
                { id: 'acc_slap_75', style: 'accuracy', title: 'Slap Shot Specialist', description: 'Achieve 55% accuracy on slap shots in any 2 sessions.', shotType: 'slap', goalType: 'accuracy', targetAccuracy: 55.0, sessions: 2, difficulty: 'Medium', proLevel: true, isBonus: false, isStreak: false },
                { id: 'acc_variety_60', style: 'accuracy', title: 'Variety Accuracy', description: 'Achieve at least 60% accuracy on all shot types in a single session.', shotType: 'all', goalType: 'accuracy_variety', targetAccuracy: 60.0, sessions: 1, difficulty: 'Hard', proLevel: true, isBonus: false, isStreak: false },
                { id: 'acc_morning_ace', style: 'accuracy', title: 'Morning Ace', description: 'Achieve 65% accuracy in a morning session (before 10am).', shotType: 'any', goalType: 'accuracy_morning', targetAccuracy: 65.0, sessions: 1, difficulty: 'Medium', proLevel: true, isBonus: false, isStreak: false },
                { id: 'acc_wrist_easy', style: 'accuracy', title: 'Wrist Shot Precision', description: 'Achieve 60% accuracy on wrist shots in any 2 sessions in a row. Keep trying until you get it!', shotType: 'wrist', goalType: 'accuracy', targetAccuracy: 60.0, sessions: 2, difficulty: 'Easy', proLevel: true, isBonus: false, isStreak: true },
                { id: 'acc_snap_hard', style: 'accuracy', title: 'Snap Shot Sniper', description: 'Achieve 70% accuracy on snap shots in any 3 sessions in a row. You can keep working at it all week!', shotType: 'snap', goalType: 'accuracy', targetAccuracy: 70.0, sessions: 3, difficulty: 'Hard', proLevel: true, isBonus: false, isStreak: true },
                { id: 'acc_backhand_hardest', style: 'accuracy', title: 'Backhand Bullseye', description: 'Achieve 80% accuracy on backhands in any 4 sessions in a row. Don\'t give up if you miss early!', shotType: 'backhand', goalType: 'accuracy', targetAccuracy: 80.0, sessions: 4, difficulty: 'Hardest', proLevel: true, isBonus: false, isStreak: true },
                { id: 'acc_slap_impossible', style: 'accuracy', title: 'Slap Shot Sharpshooter', description: 'Achieve 90% accuracy on slap shots in any 5 sessions in a row. You have all week to get there!', shotType: 'slap', goalType: 'accuracy', targetAccuracy: 90.0, sessions: 5, difficulty: 'Impossible', proLevel: true, isBonus: false, isStreak: true },
                { id: 'acc_variety_medium', style: 'accuracy', title: 'All-Around Sniper', description: 'Achieve at least 50% accuracy on all shot types in a single session.', shotType: 'all', goalType: 'accuracy_variety', targetAccuracy: 50.0, sessions: 1, difficulty: 'Medium', proLevel: true, isBonus: false, isStreak: false },
                // --- Ratio based ---
                { id: 'ratio_snap_slap_2to1', style: 'ratio', title: 'Snap to Slap', description: 'Take 2 snap shots for every 1 slap shot.', shotType: 'snap', shotTypeComparison: 'slap', primaryType: 'snap', secondaryType: 'slap', goalType: 'ratio', goalValue: 2, secondaryValue: 1, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'ratio_even_steven', style: 'ratio', title: 'Even Steven', description: 'Take an equal number of wrist and backhand shots.', shotType: 'wrist', shotTypeComparison: 'backhand', primaryType: 'wrist', secondaryType: 'backhand', goalType: 'ratio_equal', goalValue: 1, secondaryValue: 1, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'ratio_backhand_wrist_easy', style: 'ratio', title: 'Backhand Booster', description: 'Take 2 backhands for every 1 wrist shot you take.', shotType: 'backhand', shotTypeComparison: 'wrist', primaryType: 'backhand', secondaryType: 'wrist', goalType: 'ratio', goalValue: 2, secondaryValue: 1, difficulty: 'Easy', proLevel: false, isBonus: false },
                { id: 'ratio_backhand_snap_hard', style: 'ratio', title: 'Backhand vs Snap', description: 'Take 3 backhands for every 1 snap shot you take.', shotType: 'backhand', shotTypeComparison: 'snap', primaryType: 'backhand', secondaryType: 'snap', goalType: 'ratio', goalValue: 3, secondaryValue: 1, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'ratio_slap_snap_medium', style: 'ratio', title: 'Slap vs Snap', description: 'Take 2 slap shots for every 1 snap shot you take.', shotType: 'slap', shotTypeComparison: 'snap', primaryType: 'slap', secondaryType: 'snap', goalType: 'ratio', goalValue: 2, secondaryValue: 1, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'variety_master', style: 'ratio', title: 'Variety Master', description: 'Take at least 5 of each shot type (wrist, snap, backhand, slap) in a single session.', shotType: 'all', shotTypeComparison: '', primaryType: 'all', secondaryType: '', goalType: 'variety', goalValue: 5, difficulty: 'Medium', proLevel: false, isBonus: false },
                // --- Consistency ---
                { id: 'consistency_earlybird', style: 'consistency', title: 'Early Bird', description: 'Complete a shooting session before 7am three times.', shotType: '', goalType: 'early_sessions', goalValue: 3, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'consistency_nightowl', style: 'consistency', title: 'Night Owl', description: 'Complete a shooting session after 5pm two times.', shotType: '', goalType: 'late_sessions', goalValue: 2, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'consistency_doubleheader', style: 'consistency', title: 'Double Header', description: 'Complete two shooting sessions in one day.', shotType: '', goalType: 'double_sessions', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'consistency_weekendwarrior', style: 'consistency', title: 'Weekend Warrior', description: 'Complete a session on both Saturday and Sunday.', shotType: '', goalType: 'weekend_sessions', goalValue: 2, difficulty: 'Medium', proLevel: false, isBonus: false },
                { id: 'consistency_streak_five', style: 'consistency', title: 'Five Alive', description: 'Complete a streak of 5 days in a row with at least one session each day.', shotType: '', goalType: 'streak', goalValue: 5, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'consistency_daily_easy', style: 'consistency', title: 'Daily Shooter', description: 'Shoot pucks every day.', shotType: '', goalType: 'streak', goalValue: 7, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'consistency_sessions_hard', style: 'consistency', title: 'Session Grinder', description: 'Complete 5 shooting sessions. If you miss a day, you can still finish strong!', shotType: '', goalType: 'sessions', goalValue: 5, difficulty: 'Hard', proLevel: false, isBonus: false },
                { id: 'consistency_morning_medium', style: 'consistency', title: 'Morning Warrior', description: 'Complete 3 morning shooting sessions (before 10am).', shotType: '', goalType: 'morning_sessions', goalValue: 3, difficulty: 'Medium', proLevel: false, isBonus: false },
                // --- Progress ---
                { id: 'progress_wrist_improve_easy', style: 'progress', title: 'Wrist Shot Progress', description: 'Improve your wrist shot accuracy by 5%. Progress counts, even if it takes a few tries!', shotType: 'wrist', goalType: 'improvement', improvement: 5, difficulty: 'Easy', proLevel: true, isBonus: false },
                { id: 'progress_snap_improve_hard', style: 'progress', title: 'Snap Shot Progress', description: 'Improve your snap shot accuracy by 10%. You can keep working at it all week!', shotType: 'snap', goalType: 'improvement', improvement: 10, difficulty: 'Hard', proLevel: true, isBonus: false },
                { id: 'progress_backhand_improve_medium', style: 'progress', title: 'Backhand Progress', description: 'Improve your backhand accuracy by 7%.', shotType: 'backhand', goalType: 'improvement', improvement: 7, difficulty: 'Medium', proLevel: true, isBonus: false },
                { id: 'progress_slap_improve_medium', style: 'progress', title: 'Slap Shot Progress', description: 'Improve your slap shot accuracy by 8%.', shotType: 'slap', goalType: 'improvement', improvement: 8, difficulty: 'Medium', proLevel: true, isBonus: false },
                { id: 'progress_variety_improve_hard', style: 'progress', title: 'All-Around Progress', description: 'Improve your accuracy by at least 5% on all shot types.', shotType: 'all', goalType: 'improvement_variety', improvement: 5, difficulty: 'Hard', proLevel: true, isBonus: false },
                { id: 'progress_streak_3days', style: 'progress', title: 'Three Day Streak', description: 'Improve your accuracy on any shot type for 3 days in a row.', shotType: 'any', goalType: 'improvement_streak', improvement: 1, days: 3, difficulty: 'Medium', proLevel: true, isBonus: false },
                { id: 'progress_evening_improve', style: 'progress', title: 'Evening Improver', description: 'Improve your overall accuracy by 6%.', shotType: 'any', goalType: 'improvement_evening', improvement: 6, difficulty: 'Medium', proLevel: true, isBonus: false },
                { id: 'progress_target_hits', style: 'progress', title: 'Target Hitter', description: 'Hit 100 targets.', shotType: 'any', goalType: 'target_hits_increase', improvement: 100, difficulty: 'Easy', proLevel: true, isBonus: false },
                { id: 'progress_consistency_sessions', style: 'progress', title: 'Consistent Improver', description: 'Improve your accuracy in at least 4 different sessions.', shotType: 'any', goalType: 'improvement_sessions', improvement: 1, sessions: 4, difficulty: 'Hard', proLevel: true, isBonus: false },
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

            // --- Skill-based substitutions ---
            // Calculate user skill metrics
            // Average accuracy per shot type
            const avgAccuracies: { [key: string]: number } = {};
            const avgShotsPerSession: { [key: string]: number } = {};
            for (const type of shotTypes) {
                const accArr = sessionAccuracies[type] || [];
                avgAccuracies[type] = accArr.length ? accArr.reduce((a, b) => a + b, 0) / accArr.length : 0;
                const shotsArr = sessionShotCounts[type] || [];
                avgShotsPerSession[type] = shotsArr.length ? shotsArr.reduce((a, b) => a + b, 0) / shotsArr.length : 0;
            }

            // Helper: substitute values in a template
            function substituteTemplate(tmpl: any): any {
                let t = { ...tmpl };
                // --- Find weakest/lagging shot type ---
                let weakestType = null;
                let lowestAcc = Infinity;
                for (const type of Object.keys(avgAccuracies)) {
                    if (avgAccuracies[type] < lowestAcc && avgAccuracies[type] > 0) {
                        lowestAcc = avgAccuracies[type];
                        weakestType = type;
                    }
                }
                let laggingType = null;
                let lowestShots = Infinity;
                for (const type of Object.keys(avgShotsPerSession)) {
                    if (avgShotsPerSession[type] < lowestShots && avgShotsPerSession[type] > 0) {
                        lowestShots = avgShotsPerSession[type];
                        laggingType = type;
                    }
                }

                // --- Accuracy ---
                if (t.style === 'accuracy' && t.shotType && t.targetAccuracy) {
                    // Only substitute for wrist, snap, backhand, slap
                    if (['wrist', 'snap', 'backhand', 'slap'].includes(t.shotType) && weakestType && t.shotType !== weakestType) {
                        t.shotType = weakestType;
                        t.title = `${weakestType.charAt(0).toUpperCase() + weakestType.slice(1)} Accuracy Focus`;
                    }
                    // Calculate session accuracy for each session in weekly stats
                    let sessionAccuracies: number[] = [];
                    if (stats.sessions && Array.isArray(stats.sessions)) {
                        for (const s of stats.sessions) {
                            const shots = s.shots?.[t.shotType] ?? 0;
                            const hits = s.targets_hit?.[t.shotType] ?? 0;
                            if (shots > 0) {
                                sessionAccuracies.push((hits / shots) * 100);
                            }
                        }
                    }
                    // Use average or bump for target
                    let avg = sessionAccuracies.length ? sessionAccuracies.reduce((a, b) => a + b, 0) / sessionAccuracies.length : 0;
                    let bump = (t.sessions && t.sessions > 1) ? 2.5 : 5.0;
                    let newTarget = Math.round((avg + bump) * 10) / 10;
                    t.targetAccuracy = Math.max(t.targetAccuracy, Math.min(newTarget, 100));
                    t.description = `Achieve ${t.targetAccuracy}% accuracy on ${t.shotType} shots${t.sessions ? ` in ${t.sessions} session${t.sessions > 1 ? 's' : ''}` : ''}.`;
                }
                // --- Quantity ---
                if (t.style === 'quantity' && t.shotType && t.goalValue) {
                    // Only substitute for wrist, snap, backhand, slap
                    if (['wrist', 'snap', 'backhand', 'slap'].includes(t.shotType) && laggingType && t.shotType !== laggingType) {
                        t.shotType = laggingType;
                        t.title = `${laggingType.charAt(0).toUpperCase() + laggingType.slice(1)} Shot Challenge`;
                    }
                    let avg = avgShotsPerSession[t.shotType] || 0;
                    let percent = avg < 20 ? 0.20 : avg < 50 ? 0.10 : 0.05;
                    let bump = Math.ceil(avg * percent);
                    let maxBump = 100;
                    t.goalValue = Math.max(t.goalValue, Math.min(Math.ceil(avg + bump), Math.ceil(avg + maxBump)));
                    t.description = `Take ${t.goalValue} ${t.shotType} shots${t.sessions ? ` in ${t.sessions} session${t.sessions > 1 ? 's' : ''}` : ''}.`;
                }
                // --- Quantity per session streak ---
                if (t.style === 'quantity' && t.goalType === 'count_per_session' && t.shotType && t.goalValue) {
                    // Only substitute for wrist, snap, backhand, slap
                    if (['wrist', 'snap', 'backhand', 'slap'].includes(t.shotType) && laggingType && t.shotType !== laggingType) {
                        t.shotType = laggingType;
                        t.title = `${laggingType.charAt(0).toUpperCase() + laggingType.slice(1)} Consistency Streak`;
                    }
                    let avg = avgShotsPerSession[t.shotType] || 0;
                    let bump = Math.ceil(avg * 0.10);
                    t.goalValue = Math.max(t.goalValue, Math.ceil(avg + bump));
                    t.description = `Take at least ${t.goalValue} ${t.shotType} shots for any ${t.sessions} session${t.sessions > 1 ? 's' : ''} in a row.`;
                }
                // --- Ratio ---
                if (t.style === 'ratio' && t.primaryType && t.secondaryType && t.goalValue && t.secondaryValue) {
                    // Only substitute for wrist, snap, backhand, slap
                    if (['wrist', 'snap', 'backhand', 'slap'].includes(t.primaryType) && laggingType && t.primaryType !== laggingType) {
                        t.primaryType = laggingType;
                    }
                    if (['wrist', 'snap', 'backhand', 'slap'].includes(t.secondaryType) && weakestType && t.secondaryType !== weakestType) {
                        t.secondaryType = weakestType;
                    }
                    let primaryAvg = avgShotsPerSession[t.primaryType] || 0;
                    let secondaryAvg = avgShotsPerSession[t.secondaryType] || 0;
                    if (secondaryAvg < primaryAvg * 0.5) {
                        t.goalValue = Math.max(t.goalValue, 2);
                        t.secondaryValue = Math.max(t.secondaryValue, 1);
                    }
                    t.description = `Take ${t.goalValue} ${t.primaryType} shots for every ${t.secondaryValue} ${t.secondaryType} shot.`;
                }
                // --- Progress ---
                if (t.style === 'progress' && t.shotType && t.improvement) {
                    let bump = t.improvement;
                    t.description = t.goalType === 'improvement_variety'
                        ? `Improve your accuracy by at least ${bump}% on all shot types.`
                        : `Improve your ${t.shotType} accuracy by ${bump}%. Progress counts, even if it takes a few tries!`;
                }
                // --- Consistency ---
                if (t.style === 'consistency' && t.goalType && t.goalValue) {
                    // For streaks, sessions, etc.
                    if (t.goalType === 'streak') {
                        t.description = `Complete a streak of ${t.goalValue} days in a row with at least one session each day.`;
                    } else if (t.goalType === 'sessions') {
                        t.description = `Complete ${t.goalValue} shooting sessions. If you miss a day, you can still finish strong!`;
                    } else if (t.goalType === 'early_sessions') {
                        t.description = `Complete a shooting session before 7am ${t.goalValue} time${t.goalValue > 1 ? 's' : ''}.`;
                    } else if (t.goalType === 'late_sessions') {
                        t.description = `Complete a shooting session after 9pm ${t.goalValue} time${t.goalValue > 1 ? 's' : ''}.`;
                    } else if (t.goalType === 'double_sessions') {
                        t.description = `Complete two shooting sessions in one day, ${t.goalValue} time${t.goalValue > 1 ? 's' : ''}.`;
                    } else if (t.goalType === 'weekend_sessions') {
                        t.description = `Complete a session on both Saturday and Sunday.`;
                    } else if (t.goalType === 'morning_sessions') {
                        t.description = `Complete ${t.goalValue} morning shooting sessions (before 10am).`;
                    } else if (t.goalType === 'lunch_sessions') {
                        t.description = `Complete ${t.goalValue} sessions on your lunch break.`;
                    }
                }
                // --- Target hits (progress) ---
                if (t.style === 'progress' && t.goalType === 'target_hits_increase' && t.improvement) {
                    t.description = `Hit ${t.improvement} targets.`;
                }
                // --- Progress streak ---
                if (t.style === 'progress' && t.goalType === 'improvement_streak' && t.improvement && t.days) {
                    t.description = `Improve your accuracy on any shot type for ${t.days} days in a row.`;
                }
                // --- Progress sessions ---
                if (t.style === 'progress' && t.goalType === 'improvement_sessions' && t.improvement && t.sessions) {
                    t.description = `Improve your accuracy in at least ${t.sessions} different sessions.`;
                }
                // --- Progress evening ---
                if (t.style === 'progress' && t.goalType === 'improvement_evening' && t.improvement) {
                    t.description = `Improve your overall accuracy by ${t.improvement}%.`;
                }
                // --- Fun/social (default: leave as is) ---
                return t;
            }

            // Filter eligible templates
            let eligible = templates.filter(t => allowed.includes(mapDifficulty(t)) && (isPro ? true : t.proLevel !== true));
            eligible = eligible.sort(() => Math.random() - 0.5);

            // --- Assign a variety of difficulties if possible ---
            const assigned: any[] = [];
            const usedTemplates = new Set();
            const usedShotTypeCombos = new Set();

            // 1. Always include one 'fun' style template if available
            const funTemplates = eligible.filter(t => t.style === 'fun');
            if (funTemplates.length > 0) {
                const fun = substituteTemplate(funTemplates[Math.floor(Math.random() * funTemplates.length)]);
                assigned.push(fun);
                usedTemplates.add(fun.id + '|' + (fun.shotType || 'any'));
                usedShotTypeCombos.add(fun.style + '|' + (fun.shotType || 'any'));
            }

            // 2. Try to assign templates of different difficulties
            const difficulties = ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'];
            const alreadyAssignedDifficulties = new Set(assigned.map(t => t.difficulty));
            const nonFunTemplates = eligible.filter(t => t.style !== 'fun');
            for (const diff of difficulties) {
                if (assigned.length >= 4) break;
                const candidates = nonFunTemplates.filter(t => t.difficulty === diff && !alreadyAssignedDifficulties.has(diff));
                if (candidates.length > 0) {
                    const template = substituteTemplate(candidates[Math.floor(Math.random() * candidates.length)]);
                    const comboKey = template.id + '|' + (template.shotType || 'any');
                    if (!usedTemplates.has(comboKey)) {
                        assigned.push(template);
                        usedTemplates.add(comboKey);
                        usedShotTypeCombos.add(template.style + '|' + (template.shotType || 'any'));
                        alreadyAssignedDifficulties.add(diff);
                    }
                }
            }

            // 3. If not enough, fill with random eligible (excluding fun/social already assigned)
            let fallbackPool = [...nonFunTemplates];
            while (assigned.length < 4 && fallbackPool.length) {
                const next = substituteTemplate(fallbackPool.pop());
                const comboKey = next.id + '|' + (next.shotType || 'any');
                if (!usedTemplates.has(comboKey)) {
                    assigned.push(next);
                    usedTemplates.add(comboKey);
                    usedShotTypeCombos.add(next.style + '|' + (next.shotType || 'any'));
                }
            }

            // Format for Firestore: include all template fields
            const achievements = assigned.slice(0, 4).map(t => ({
                ...t,
                completed: false,
                dateAssigned: Timestamp.fromDate(weekStart),
                dateCompleted: null,
                time_frame: 'week',
                userId,
            }));
            for (const achievement of achievements) {
                await db.collection('users').doc(userId).collection('achievements').add(achievement);
            }
        }
        logger.info('assignWeeklyAchievements executed successfully.');
        res.status(200).send('assignWeeklyAchievements executed successfully:');
    } catch (error) {
        logger.error('Error assigning weekly achievements:', error);
        const errorMessage = typeof error === 'object' && error !== null && 'message' in error ? (error as { message: string }).message : String(error);
        res.status(200).send('assignWeeklyAchievements failed: ' + errorMessage);
    }
});
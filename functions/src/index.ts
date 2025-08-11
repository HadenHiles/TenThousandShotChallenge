import * as admin from "firebase-admin";
import { onRequest, onCall } from "firebase-functions/v2/https";
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
    await db.collection(`iterations/${context.params.userId}/iterations`).doc(context.params.iterationId).update({ 'updated_at': new Date(Date.now()) });

    // --- Recalculate and write summary stats to /users/{userId}/stats/weekly ---
    try {
        const weekStart = getWeekStartEST();
        const sessionsSnap = await db.collection(`iterations/${context.params.userId}/iterations/${context.params.iterationId}/sessions`).orderBy('date', 'desc').get();
        let recentSessions = [];
        let seasonTotalShots = 0;
        let seasonTotalShotsWithAccuracy = 0;
        let seasonTargetsHit = 0;
        let shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
        let seasonShotTypeTotals = { wrist: 0, snap: 0, slap: 0, backhand: 0 };
        let seasonTargetsHitType = { wrist: 0, snap: 0, slap: 0, backhand: 0 };
        let seasonAccuracyType = { wrist: 0.0, snap: 0.0, slap: 0.0, backhand: 0.0 };

        for (const sessionDoc of sessionsSnap.docs) {
            const s = sessionDoc.data();
            // Only include sessions from the current week (on or after weekStart)
            let sessionDate = s.date;
            let jsDate = null;
            if (sessionDate && sessionDate.toDate) jsDate = sessionDate.toDate();
            else if (sessionDate instanceof Date) jsDate = sessionDate;
            if (jsDate && jsDate >= weekStart) {
                // Normalize duration to minutes if available
                let durationMinutes: number | null = null;
                if (typeof s.duration === 'number') {
                    durationMinutes = s.duration;
                } else if (typeof s.duration_seconds === 'number') {
                    durationMinutes = s.duration_seconds / 60.0;
                } else if (typeof s.duration_ms === 'number') {
                    durationMinutes = s.duration_ms / 60000.0;
                } else if (s.start_time && s.end_time) {
                    const start = s.start_time.toDate ? s.start_time.toDate() : (s.start_time instanceof Date ? s.start_time : null);
                    const end = s.end_time.toDate ? s.end_time.toDate() : (s.end_time instanceof Date ? s.end_time : null);
                    if (start && end) {
                        durationMinutes = (end.getTime() - start.getTime()) / 60000.0;
                    }
                }
                recentSessions.push({
                    date: s.date,
                    duration: durationMinutes,
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
        logger.error('Error updating weekly stats after session creation:', e);
    }

    // Call achievement logic after stats/weekly is updated
    let createdSession: any = null;
    try {
        createdSession = (await db.collection(`iterations/${context.params.userId}/iterations/${context.params.iterationId}/sessions`).doc(context.params.sessionId).get()).data();
    } catch (err) {
        logger.error('Error loading session for achievement update:', err);
    }
    if (createdSession) {
        try {
            await updateAchievementsAfterSessionChange(context.params.userId, createdSession);
        } catch (err) {
            logger.error('Error updating achievements after session creation:', err);
        }
    }

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
});

// Update the iteration timestamp for caching purposes any time a session is updated
export const sessionUpdated = onDocumentUpdated({ document: "iterations/{userId}/iterations/{iterationId}/sessions/{sessionId}" }, async (event) => {
    const context = event;
    // Retrieve the user who will be receiving the notification
    await db.collection(`iterations/${context.params.userId}/iterations`).doc(`${context.params.iterationId}`).update({ 'updated_at': new Date(Date.now()) }).then((_) => true).catch((err) => {
        logger.log(`Error updating cache timestamp for iteration: ${context.params.iterationId}` + err);
        return null;
    });

    // Call achievement logic after stats/weekly is updated
    let session: any = null;
    try {
        session = (await db.collection(`iterations/${context.params.userId}/iterations/${context.params.iterationId}/sessions`).doc(context.params.sessionId).get()).data();
    } catch (e) {
        logger.error('Error fetching session after update:', e);
    }
    if (session) {
        try {
            await updateAchievementsAfterSessionChange(context.params.userId, session);
        } catch (err) {
            logger.error('Error updating achievements after session update:', err);
        }
    }
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
        const weekStart = getWeekStartEST();
        const sessionsSnap = await db.collection(`iterations/${context.params.userId}/iterations/${context.params.iterationId}/sessions`).orderBy('date', 'desc').get();
        let recentSessions = [];
        let seasonTotalShots = 0;
        let seasonTotalShotsWithAccuracy = 0;
        let seasonTargetsHit = 0;
        let shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
        let seasonShotTypeTotals = { wrist: 0, snap: 0, slap: 0, backhand: 0 };
        let seasonTargetsHitType = { wrist: 0, snap: 0, slap: 0, backhand: 0 };
        let seasonAccuracyType = { wrist: 0.0, snap: 0.0, slap: 0.0, backhand: 0.0 };

        for (const sessionDoc of sessionsSnap.docs) {
            const s = sessionDoc.data();
            // Only include sessions from the current week (on or after weekStart)
            let sessionDate = s.date;
            let jsDate = null;
            if (sessionDate && sessionDate.toDate) jsDate = sessionDate.toDate();
            else if (sessionDate instanceof Date) jsDate = sessionDate;
            if (jsDate && jsDate >= weekStart) {
                // Normalize duration to minutes if available
                let durationMinutes: number | null = null;
                if (typeof s.duration === 'number') {
                    durationMinutes = s.duration;
                } else if (typeof s.duration_seconds === 'number') {
                    durationMinutes = s.duration_seconds / 60.0;
                } else if (typeof s.duration_ms === 'number') {
                    durationMinutes = s.duration_ms / 60000.0;
                } else if (s.start_time && s.end_time) {
                    const start = s.start_time.toDate ? s.start_time.toDate() : (s.start_time instanceof Date ? s.start_time : null);
                    const end = s.end_time.toDate ? s.end_time.toDate() : (s.end_time instanceof Date ? s.end_time : null);
                    if (start && end) {
                        durationMinutes = (end.getTime() - start.getTime()) / 60000.0;
                    }
                }
                recentSessions.push({
                    date: s.date,
                    duration: durationMinutes,
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

    // Call achievement logic after stats/weekly is updated
    try {
        await updateAchievementsAfterSessionDelete(context.params.userId);
    } catch (err) {
        logger.error('Error updating achievements after session deletion:', err);
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

// Helper: Check if achievement is completed based on achievement criteria, using stats/weekly
async function checkAchievementCompletion(userId: string, achievement: any, stats?: any): Promise<boolean> {
    // If stats not provided, fetch it
    let statsData = stats;
    if (!statsData) {
        const statsDoc = await db.collection('users').doc(userId).collection('stats').doc('weekly').get();
        statsData = (statsDoc && statsDoc.exists && statsDoc.data()) ? statsDoc.data() : {};
    }
    // Fetch user's timezone (default to America/Toronto)
    let userTimezone = 'America/Toronto';
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        const userData = userDoc.exists ? userDoc.data() : undefined;
        if (userData && typeof userData.timezone === 'string' && userData.timezone.length > 0) {
            userTimezone = userData.timezone;
        }
    } catch (e) {
        // fallback to default
    }
    const sessions: any[] = Array.isArray(statsData.sessions) ? statsData.sessions : [];
    const style = achievement.style;
    const goalType = achievement.goalType;
    const shotType = achievement.shotType || achievement.primaryType || 'any';
    const secondaryType = achievement.shotTypeComparison || achievement.secondaryType || '';
    const goalValue = typeof achievement.goalValue === 'number' ? achievement.goalValue : 1;
    const secondaryValue = typeof achievement.secondaryValue === 'number' ? achievement.secondaryValue : 1;
    const requiredSessions = typeof achievement.sessions === 'number' ? achievement.sessions : 1;
    const targetAccuracy = typeof achievement.targetAccuracy === 'number' ? achievement.targetAccuracy : 100.0;
    const improvement = typeof achievement.improvement === 'number' ? achievement.improvement : 1.0;
    // Helper: get session time
    function getSessionTime(s: any) {
        if (!s || !s.date) return null;
        if (s.date.toDate) return s.date.toDate();
        if (s.date instanceof Date) return s.date;
        return null;
    }

    // Helper: Convert a Date to the user's timezone (or default)
    function toUserTimezone(date: Date | null): Date | null {
        if (!date) return null;
        // Use Intl.DateTimeFormat to get the correct hour/minute in user's timezone
        const options = { timeZone: userTimezone, hour12: false, year: 'numeric' as const, month: 'numeric' as const, day: 'numeric' as const, hour: 'numeric' as const, minute: 'numeric' as const, second: 'numeric' as const };
        const parts = new Intl.DateTimeFormat('en-US', options).formatToParts(date);
        const get = (type: string) => parseInt(parts.find(p => p.type === type)?.value || '0', 10);
        return new Date(
            get('year'),
            get('month') - 1,
            get('day'),
            get('hour'),
            get('minute'),
            get('second')
        );
    }
    // QUANTITY
    if (style === 'quantity') {
        // Only count sessions after dateAssigned (or week start)
        let cutoff = null;
        if (achievement.dateAssigned && achievement.dateAssigned.toDate) {
            cutoff = achievement.dateAssigned.toDate();
        } else if (statsData.week_start && statsData.week_start.toDate) {
            cutoff = statsData.week_start.toDate();
        }
        // Convert cutoff to user's timezone for accurate comparison
        const userTzCutoff = cutoff ? toUserTimezone(cutoff) : null;
        const relevantSessions = userTzCutoff
            ? sessions.filter((s: any) => {
                const dt = toUserTimezone(getSessionTime(s));
                return dt && (dt >= userTzCutoff);
            })
            : sessions;

        if (goalType === 'count_per_session') {
            // At least goalValue shots in requiredSessions consecutive sessions
            let metList = relevantSessions.map((s: any) => (s.shots?.[shotType] || 0) >= goalValue ? 1 : 0);
            let streak = 0;
            for (let i = 0; i < metList.length; i++) {
                if (metList[i] === 1) {
                    streak++;
                    if (streak >= requiredSessions) return true;
                } else {
                    streak = 0;
                }
            }
            return false;
        } else if (goalType === 'count_evening') {
            // Mark complete if there is at least one session after 7pm in user's timezone with at least goalValue shots
            for (const s of relevantSessions) {
                const dt = toUserTimezone(getSessionTime(s));
                if (dt && dt.getHours() >= 19) {
                    let shotCount = 0;
                    if (shotType === 'any') {
                        if (s.shots && typeof s.shots === 'object') {
                            for (const v of Object.values(s.shots)) {
                                if (typeof v === 'number') shotCount += v;
                            }
                        }
                    } else {
                        shotCount = s.shots?.[shotType] || 0;
                    }
                    if (shotCount >= goalValue) {
                        return true;
                    }
                }
            }
            return false;
        } else if (goalType === 'count_time') {
            // Take goalValue total shots (any types) in under timeLimit minutes in a single session
            const timeLimit = achievement.timeLimit || 10;
            for (const s of relevantSessions) {
                // Accept duration in minutes (preferred) or seconds/ms fallbacks
                let durationMinutes: number | null = null;
                if (typeof s.duration === 'number') {
                    durationMinutes = s.duration;
                } else if (typeof s.duration_seconds === 'number') {
                    durationMinutes = s.duration_seconds / 60.0;
                } else if (typeof s.duration_ms === 'number') {
                    durationMinutes = s.duration_ms / 60000.0;
                }
                if (durationMinutes !== null && durationMinutes <= timeLimit) {
                    let sum = 0;
                    for (const v of Object.values(s.shots || {})) {
                        if (typeof v === 'number') sum += v as number;
                    }
                    if (sum >= goalValue) return true;
                }
            }
            return false;
        } else if (shotType === 'all') {
            // For 'all', must have at least goalValue of each type (wrist, snap, slap, backhand) summed across all relevant sessions
            const types = ['wrist', 'snap', 'slap', 'backhand'];
            const totals: { [key: string]: number } = { wrist: 0, snap: 0, slap: 0, backhand: 0 };
            for (const s of relevantSessions) {
                const shots = typeof s.shots === 'object' && s.shots !== null ? s.shots : {};
                for (const t of types) {
                    if (typeof shots[t] === 'number') {
                        totals[t] += shots[t];
                    }
                }
            }
            return types.every(t => totals[t] >= goalValue);
        } else if (shotType === 'any') {
            // Sum all types
            let sum = 0;
            for (const s of relevantSessions) {
                if (s.shots && typeof s.shots === 'object') {
                    for (const v of Object.values(s.shots)) {
                        if (typeof v === 'number') sum += v;
                    }
                }
            }
            return sum >= goalValue;
        } else {
            // Specific shot type
            let count = 0;
            for (const s of relevantSessions) {
                count += s.shots?.[shotType] || 0;
            }
            return count >= goalValue;
        }
    }
    // ACCURACY
    if (style === 'accuracy') {
        const isStreak = achievement.isStreak === true;
        // Only count sessions after dateAssigned (or week_start)
        let cutoff = null;
        if (achievement.dateAssigned && achievement.dateAssigned.toDate) {
            cutoff = achievement.dateAssigned.toDate();
        } else if (statsData.week_start && statsData.week_start.toDate) {
            cutoff = statsData.week_start.toDate();
        }
        // Convert cutoff to user's timezone for accurate comparison
        const userTzCutoff = cutoff ? toUserTimezone(cutoff) : null;
        const relevantSessions = userTzCutoff
            ? sessions.filter((s: any) => {
                const dt = toUserTimezone(getSessionTime(s));
                return dt && (dt >= userTzCutoff);
            })
            : sessions;

        // Helper: get per-session accuracy for the relevant goalType/shotType
        function getSessionAccuracy(s: any): number {
            // Prefer explicit accuracy field if present
            const accMap = s.accuracy || {};
            // If accuracy is present and valid, use it
            if (shotType === 'any') {
                const types = ['wrist', 'snap', 'slap', 'backhand'];
                let sum = 0, count = 0;
                for (const t of types) {
                    if (typeof accMap[t] === 'number') { sum += accMap[t]; count++; }
                    else if (s.targets_hit && s.shots && typeof s.targets_hit[t] === 'number' && typeof s.shots[t] === 'number' && s.shots[t] > 0) {
                        sum += (s.targets_hit[t] / s.shots[t]) * 100;
                        count++;
                    }
                }
                return count > 0 ? sum / count : 0;
            } else {
                if (typeof accMap[shotType] === 'number') {
                    return accMap[shotType];
                } else if (s.targets_hit && s.shots && typeof s.targets_hit[shotType] === 'number' && typeof s.shots[shotType] === 'number' && s.shots[shotType] > 0) {
                    return (s.targets_hit[shotType] / s.shots[shotType]) * 100;
                } else {
                    return 0;
                }
            }
        }

        if (goalType === 'accuracy_variety') {
            // Must hit targetAccuracy for all types in a single session
            const types = ['wrist', 'snap', 'slap', 'backhand'];
            for (const s of relevantSessions) {
                const accMap = s.accuracy || {};
                if (types.every(t => typeof accMap[t] === 'number' && accMap[t] >= targetAccuracy)) {
                    return true;
                }
            }
            return false;
        } else if (goalType === 'accuracy_morning') {
            // Morning session (before 10am in user's timezone) with required accuracy
            for (const s of relevantSessions) {
                const dt = toUserTimezone(getSessionTime(s));
                if (dt && dt.getHours() < 10) {
                    const acc = getSessionAccuracy(s);
                    if (acc >= targetAccuracy) {
                        return true;
                    }
                }
            }
            return false;
        } else {
            // Standard accuracy achievements (single or multiple sessions)
            let sessionAccuracies = [];
            let sessionHasShots = [];
            for (const s of relevantSessions) {
                const shots = s.shots?.[shotType] ?? 0;
                sessionHasShots.push(shots > 0);
                sessionAccuracies.push(getSessionAccuracy(s));
            }
            if (isStreak && requiredSessions > 1) {
                // Look for any sequence of requiredSessions consecutive sessions (with shots > 0) meeting accuracy
                for (let i = 0; i <= sessionAccuracies.length - requiredSessions; i++) {
                    let allMet = true;
                    for (let j = 0; j < requiredSessions; j++) {
                        if (!sessionHasShots[i + j] || sessionAccuracies[i + j] < targetAccuracy) {
                            allMet = false;
                            break;
                        }
                    }
                    if (allMet) {
                        return true;
                    }
                }
                return false;
            } else if (requiredSessions > 1) {
                // Non-streak: count up to requiredSessions sessions (with shots > 0) meeting accuracy
                let metCount = 0;
                for (let i = 0; i < sessionAccuracies.length && metCount < requiredSessions; i++) {
                    if (sessionHasShots[i] && sessionAccuracies[i] >= targetAccuracy) {
                        metCount++;
                    }
                }
                return metCount >= requiredSessions;
            } else {
                // Single session required
                for (let i = 0; i < sessionAccuracies.length; i++) {
                    if (sessionHasShots[i] && sessionAccuracies[i] >= targetAccuracy) {
                        return true;
                    }
                }
                return false;
            }
        }
    }
    // CONSISTENCY
    if (style === 'consistency') {
        // Only count sessions after dateAssigned (or week start)
        let cutoff = null;
        if (achievement.dateAssigned && achievement.dateAssigned.toDate) {
            cutoff = achievement.dateAssigned.toDate();
        } else if (statsData.week_start && statsData.week_start.toDate) {
            cutoff = statsData.week_start.toDate();
        }
        // Convert cutoff to user's timezone for accurate comparison
        const userTzCutoff = cutoff ? toUserTimezone(cutoff) : null;
        const relevantSessions = userTzCutoff
            ? sessions.filter((s: any) => {
                const dt = toUserTimezone(getSessionTime(s));
                return dt && (dt >= userTzCutoff);
            })
            : sessions;

        if (goalType === 'weekend_sessions') {
            // Must have at least one session on both Saturday and Sunday (user's timezone)
            let days = new Set<number>(relevantSessions.map((s: any) => {
                const dt = toUserTimezone(getSessionTime(s));
                return dt ? dt.getDay() : null;
            }).filter((d: number | null) => d !== null) as number[]);
            // Saturday = 6, Sunday = 0
            const hasSaturday = days.has(6);
            const hasSunday = days.has(0);
            // Only mark complete if both are present
            return hasSaturday && hasSunday;
        } else if (goalType === 'streak') {
            // Longest streak of consecutive days with sessions (user's timezone)
            let uniqueDays = Array.from(new Set<number>(relevantSessions.map((s: any) => {
                const dt = toUserTimezone(getSessionTime(s));
                return dt ? new Date(dt.getFullYear(), dt.getMonth(), dt.getDate()).getTime() : null;
            }).filter((d: number | null) => d !== null) as number[])).sort((a, b) => a - b);
            let longestStreak = 0, currentStreak = 0, prevDay: number | null = null;
            for (const day of uniqueDays) {
                if (prevDay === null || day - prevDay === 86400000) { // 1 day in ms
                    currentStreak++;
                    if (currentStreak > longestStreak) longestStreak = currentStreak;
                } else {
                    currentStreak = 1;
                }
                prevDay = day;
            }
            // Only mark complete if streak meets or exceeds goalValue
            return longestStreak >= goalValue;
        } else if (goalType === 'early_sessions') {
            // Must have at least goalValue sessions before 7am (user's timezone)
            let count = relevantSessions.filter((s: any) => {
                const dt = toUserTimezone(getSessionTime(s));
                return dt && dt.getHours() < 7;
            }).length;
            return count >= goalValue;
        } else if (goalType === 'double_sessions') {
            // Must have at least goalValue days with 2+ sessions
            let dayCounts: { [key: string]: number } = {};
            for (const s of relevantSessions) {
                const dt = getSessionTime(s);
                if (dt) {
                    const key = `${dt.getFullYear()}-${dt.getMonth()}-${dt.getDate()}`;
                    dayCounts[key] = (dayCounts[key] || 0) + 1;
                }
            }
            let doubleDays = Object.values(dayCounts).filter((v: number) => v >= 2).length;
            return doubleDays >= goalValue;
        } else if (goalType === 'morning_sessions') {
            // Must have at least goalValue sessions before 10am (user's timezone)
            let count = relevantSessions.filter((s: any) => {
                const dt = toUserTimezone(getSessionTime(s));
                return dt && dt.getHours() < 10;
            }).length;
            return count >= goalValue;
        } else if (goalType === 'sessions') {
            // Must have at least goalValue total sessions after cutoff
            return relevantSessions.length >= goalValue;
        } else {
            // Default fallback: total sessions
            return relevantSessions.length >= goalValue;
        }
    }
    // PROGRESS
    if (style === 'progress') {
        // Only count sessions after dateAssigned (or week start)
        let cutoff = null;
        if (achievement.dateAssigned && achievement.dateAssigned.toDate) {
            cutoff = achievement.dateAssigned.toDate();
        } else if (statsData.week_start && statsData.week_start.toDate) {
            cutoff = statsData.week_start.toDate();
        }
        // Convert cutoff to user's timezone for accurate comparison
        const userTzCutoff = cutoff ? toUserTimezone(cutoff) : null;
        const relevantSessions = userTzCutoff
            ? sessions.filter((s: any) => {
                const dt = toUserTimezone(getSessionTime(s));
                return dt && (dt >= userTzCutoff);
            })
            : sessions;

        if (goalType === 'improvement') {
            // Overall season_accuracy must meet improvement
            const seasonAccuracy = typeof statsData.season_accuracy === 'number' ? statsData.season_accuracy : 0;
            return seasonAccuracy >= improvement;
        } else if (goalType === 'improvement_variety') {
            // Improve accuracy by X% on all shot types
            const types = ['wrist', 'snap', 'slap', 'backhand'];
            let metTypes = 0;
            for (const t of types) {
                const acc = typeof statsData[`season_accuracy_${t}`] === 'number' ? statsData[`season_accuracy_${t}`] : 0;
                if (acc >= improvement) metTypes++;
            }
            return metTypes === types.length;
        } else if (goalType === 'improvement_evening') {
            // Improve accuracy in evening sessions (after 7pm)
            let metCount = 0, total = 0;
            for (const s of relevantSessions) {
                const dt = toUserTimezone(getSessionTime(s));
                if (dt && dt.getHours() >= 19 && s.accuracy) {
                    let acc = 0;
                    if (shotType === 'any') {
                        const values = Object.values(s.accuracy).filter((v: any) => typeof v === 'number') as number[];
                        acc = values.reduce((a: number, b: number) => a + b, 0) / (values.length || 1);
                    } else {
                        acc = typeof s.accuracy[shotType] === 'number' ? s.accuracy[shotType] : 0;
                    }
                    if (acc >= improvement) metCount++;
                    total++;
                }
            }
            return total > 0 && metCount === total;
        } else if (goalType === 'target_hits_increase') {
            // Hit X targets
            const hits = typeof statsData.season_targets_hit === 'number' ? statsData.season_targets_hit : 0;
            return hits >= improvement;
        } else if (goalType === 'improvement_sessions') {
            // Improve accuracy in at least N sessions
            let metCount = 0;
            for (const s of relevantSessions) {
                let acc = 0;
                if (s.accuracy) {
                    if (shotType === 'any') {
                        const values = Object.values(s.accuracy).filter((v: any) => typeof v === 'number') as number[];
                        acc = values.reduce((a: number, b: number) => a + b, 0) / (values.length || 1);
                    } else {
                        acc = typeof s.accuracy[shotType] === 'number' ? s.accuracy[shotType] : 0;
                    }
                }
                if (acc >= improvement) metCount++;
            }
            return metCount >= requiredSessions;
        } else {
            // Default: overall season_accuracy
            const seasonAccuracy = typeof statsData.season_accuracy === 'number' ? statsData.season_accuracy : 0;
            return seasonAccuracy >= improvement;
        }
    }
    // RATIO
    if (style === 'ratio') {
        // Only count sessions after dateAssigned (or week start)
        let cutoff = null;
        if (achievement.dateAssigned && achievement.dateAssigned.toDate) {
            cutoff = achievement.dateAssigned.toDate();
        } else if (statsData.week_start && statsData.week_start.toDate) {
            cutoff = statsData.week_start.toDate();
        }
        // Convert cutoff to user's timezone for accurate comparison
        const userTzCutoff = cutoff ? toUserTimezone(cutoff) : null;
        const relevantSessions = userTzCutoff
            ? sessions.filter((s: any) => {
                const dt = toUserTimezone(getSessionTime(s));
                return dt && (dt >= userTzCutoff);
            })
            : sessions;

        if (goalType === 'variety') {
            // Must have at least goalValue of each shot type in a single session
            const types = ['wrist', 'snap', 'slap', 'backhand'];
            for (const s of relevantSessions) {
                const shots = s.shots || {};
                if (types.every(t => (shots[t] || 0) >= goalValue)) {
                    return true;
                }
            }
            return false;
        } else if (goalType === 'ratio' || goalType === 'ratio_equal') {
            // Aggregate all sessions in the week to determine the ratio
            let primaryCount = 0, secondaryCount = 0;
            for (const s of relevantSessions) {
                const shots = s.shots || {};
                // Support multi-type (e.g. 'wrist+snap')
                if (shotType && shotType.includes('+')) {
                    for (const t of shotType.split('+')) {
                        primaryCount += shots[t] || 0;
                    }
                } else {
                    primaryCount += shots[shotType] || 0;
                }
                if (secondaryType && secondaryType.includes('+')) {
                    for (const t of secondaryType.split('+')) {
                        secondaryCount += shots[t] || 0;
                    }
                } else {
                    secondaryCount += shots[secondaryType] || 0;
                }
            }
            if (goalType === 'ratio_equal') {
                // Must be exactly equal and nonzero
                return primaryCount === secondaryCount && primaryCount > 0;
            } else {
                // e.g. 2:1 means primary/secondary >= 2, both must be nonzero
                return secondaryCount > 0 && primaryCount > 0 && (primaryCount / secondaryCount) >= (goalValue / secondaryValue);
            }
        }
    }
    // FUN/SOCIAL/OTHER: always return false (manual completion)
    if (style === 'fun' || style === 'social') {
        return false;
    }
    return false;
}



// Achievement logic as regular functions
async function updateAchievementsAfterSessionChange(userId: string, session: any) {
    // Get all weekly achievements for user
    const achievementsSnap = await db.collection('users').doc(userId).collection('achievements').get();
    // Debug logging removed
    const batch = db.batch();
    const statsDoc = await db.collection('users').doc(userId).collection('stats').doc('weekly').get();
    const stats = (statsDoc && statsDoc.exists && statsDoc.data()) ? statsDoc.data() : {};
    for (const doc of achievementsSnap.docs) {
        const achievement = doc.data();
        const completed = await checkAchievementCompletion(userId, achievement, stats);
        if (completed && !achievement.completed) {
            batch.update(doc.ref, { completed: true, completed_at: require('firebase-admin').firestore.FieldValue.serverTimestamp() });
        } else if (!completed && achievement.completed) {
            batch.update(doc.ref, { completed: false, completed_at: null });
        }
    }
    await batch.commit();
}

async function updateAchievementsAfterSessionDelete(userId: string) {
    // On delete, re-check all achievements (could un-complete if needed)
    const achievementsSnap = await db.collection('users').doc(userId).collection('achievements').get();
    // Use the sessions array from stats/weekly
    const statsDoc = await db.collection('users').doc(userId).collection('stats').doc('weekly').get();
    const stats = (statsDoc && statsDoc.exists && statsDoc.data()) ? statsDoc.data() : {};
    const batch = db.batch();
    for (const doc of achievementsSnap.docs) {
        const achievement = doc.data();
        if (achievement.completed) {
            // Re-check if achievement is still completed
            const stillCompleted = await checkAchievementCompletion(userId, achievement, stats);
            if (!stillCompleted) {
                batch.update(doc.ref, { completed: false, completed_at: null });
            }
        }
    }
    await batch.commit();
}

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
    await assignAchievements(false, []);
});

// HTTP-triggered version for live testing
export const testAssignWeeklyAchievements = onRequest(async (req, res) => {
    // Set to true for testing every type of achievement, false for normal weekly run
    // In test mode, only userIds in req.body.userIds (array of strings) will be processed
    // let result = await assignAchievements(true, req.body.userIds || ['L5sRMTzi6OQfW86iK62todmS7Gz2', 'bNyNJya3uwaNjH4eA8XWZcfZjYl2']);
    let result = await assignAchievements(false, []);
    if (result.success) {
        res.status(200).send(result.message || 'Achievements assigned successfully');
    } else {
        res.status(500).send(result.message || 'Failed to assign achievements.');
    }
});

const templates: any[] = [
    // --- Quantity based ---
    { id: 'qty_wrist_easy', style: 'quantity', title: 'Wrist Shot Week', description: 'Take 30 wrist shots. You can spread them out over any sessions!', shotType: 'wrist', goalType: 'count', goalValue: 30, difficulty: 'Easy', proLevel: false, isBonus: false },
    { id: 'qty_snap_hard', style: 'quantity', title: 'Snap Shot Challenge', description: 'Take 60 snap shots. You can do it in any session(s)!', shotType: 'snap', goalType: 'count', goalValue: 60, difficulty: 'Hard', proLevel: false, isBonus: false },
    { id: 'qty_backhand_hardest', style: 'quantity', title: 'Backhand Mastery', description: 'Take 100 backhands. You can split them up however you want!', shotType: 'backhand', goalType: 'count', goalValue: 100, difficulty: 'Hardest', proLevel: false, isBonus: false },
    { id: 'qty_slap_impossible', style: 'quantity', title: 'Slap Shot Marathon', description: 'Take 200 slap shots. Spread them out over the week!', shotType: 'slap', goalType: 'count', goalValue: 200, difficulty: 'Impossible', proLevel: false, isBonus: false },
    { id: 'qty_mixed_medium', style: 'quantity', title: 'Mix It Up', description: 'Take at least 20 shots of each type (wrist, snap, backhand, slap).', shotType: 'all', goalType: 'count', goalValue: 20, difficulty: 'Medium', proLevel: false, isBonus: false },
    { id: 'qty_lefty_easy', style: 'quantity', title: 'Lefty Challenge', description: 'Take 25 shots with your non-dominant hand.', shotType: 'any', goalType: 'count', goalValue: 25, difficulty: 'Easy', proLevel: false, isBonus: false },
    { id: 'qty_speed_50', style: 'quantity', title: 'Speed Demon', description: 'Take 50 shots in under 10 minutes in a single session.', shotType: 'any', goalType: 'count_time', goalValue: 50, timeLimit: 10, difficulty: 'Medium', proLevel: false, isBonus: false },
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
    { id: 'social_teamwork_hard', style: 'fun', title: 'Teamwork Triumph', description: 'Shoot pucks with at least 2 teammates.', shotType: '', goalType: 'teamwork_drill', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: true },
    // --- Accuracy based (pro) ---
    { id: 'acc_wrist_70', style: 'accuracy', title: 'Wrist Wizard', description: 'Achieve 70% accuracy on wrist shots in a single session.', shotType: 'wrist', goalType: 'accuracy', targetAccuracy: 70.0, sessions: 1, difficulty: 'Medium', proLevel: true, isBonus: false, isStreak: false },
    { id: 'acc_snap_80', style: 'accuracy', title: 'Snap Supreme', description: 'Achieve 80% accuracy on snap shots in a single session.', shotType: 'snap', goalType: 'accuracy', targetAccuracy: 80.0, sessions: 1, difficulty: 'Hard', proLevel: true, isBonus: false, isStreak: false },
    { id: 'acc_backhand_60', style: 'accuracy', title: 'Backhand Bull', description: 'Achieve 60% accuracy on backhands in any 2 sessions.', shotType: 'backhand', goalType: 'accuracy', targetAccuracy: 60.0, sessions: 2, difficulty: 'Easy', proLevel: true, isBonus: false, isStreak: false },
    { id: 'acc_slap_75', style: 'accuracy', title: 'Slap Shot Specialist', description: 'Achieve 55% accuracy on slap shots in any 2 sessions.', shotType: 'slap', goalType: 'accuracy', targetAccuracy: 55.0, sessions: 2, difficulty: 'Medium', proLevel: true, isBonus: false, isStreak: false },
    { id: 'acc_morning_ace', style: 'accuracy', title: 'Morning Ace', description: 'Achieve 65% accuracy in a morning session (before 10am).', shotType: 'any', goalType: 'accuracy_morning', targetAccuracy: 65.0, sessions: 1, difficulty: 'Medium', proLevel: true, isBonus: false, isStreak: false },
    { id: 'acc_wrist_easy', style: 'accuracy', title: 'Wrist Shot Precision', description: 'Achieve 60% accuracy on wrist shots in any 2 sessions in a row. Keep trying until you get it!', shotType: 'wrist', goalType: 'accuracy', targetAccuracy: 60.0, sessions: 2, difficulty: 'Easy', proLevel: true, isBonus: false, isStreak: true },
    { id: 'acc_snap_hard', style: 'accuracy', title: 'Snap Shot Sniper', description: 'Achieve 70% accuracy on snap shots in any 3 sessions in a row. You can keep working at it all week!', shotType: 'snap', goalType: 'accuracy', targetAccuracy: 70.0, sessions: 3, difficulty: 'Hard', proLevel: true, isBonus: false, isStreak: true },
    { id: 'acc_backhand_hardest', style: 'accuracy', title: 'Backhand Bullseye', description: 'Achieve 80% accuracy on backhands in any 4 sessions in a row. Don\'t give up if you miss early!', shotType: 'backhand', goalType: 'accuracy', targetAccuracy: 80.0, sessions: 4, difficulty: 'Hardest', proLevel: true, isBonus: false, isStreak: true },
    { id: 'acc_slap_impossible', style: 'accuracy', title: 'Slap Shot Sharpshooter', description: 'Achieve 90% accuracy on slap shots in any 5 sessions in a row. You have all week to get there!', shotType: 'slap', goalType: 'accuracy', targetAccuracy: 90.0, sessions: 5, difficulty: 'Impossible', proLevel: true, isBonus: false, isStreak: true },
    // --- Ratio based ---
    { id: 'ratio_snap_slap_2to1', style: 'ratio', title: 'Snap to Slap', description: 'Take 2 snap shots for every 1 slap shot.', shotType: 'snap', shotTypeComparison: 'slap', primaryType: 'snap', secondaryType: 'slap', goalType: 'ratio', goalValue: 2, secondaryValue: 1, difficulty: 'Medium', proLevel: false, isBonus: false },
    { id: 'ratio_even_steven', style: 'ratio', title: 'Even Steven', description: 'Take an equal number of wrist and backhand shots.', shotType: 'wrist', shotTypeComparison: 'backhand', primaryType: 'wrist', secondaryType: 'backhand', goalType: 'ratio_equal', goalValue: 1, secondaryValue: 1, difficulty: 'Easy', proLevel: false, isBonus: false },
    { id: 'ratio_backhand_wrist_easy', style: 'ratio', title: 'Backhand Booster', description: 'Take 2 backhands for every 1 wrist shot you take.', shotType: 'backhand', shotTypeComparison: 'wrist', primaryType: 'backhand', secondaryType: 'wrist', goalType: 'ratio', goalValue: 2, secondaryValue: 1, difficulty: 'Easy', proLevel: false, isBonus: false },
    { id: 'ratio_backhand_snap_hard', style: 'ratio', title: 'Backhand vs Snap', description: 'Take 3 backhands for every 1 snap shot you take.', shotType: 'backhand', shotTypeComparison: 'snap', primaryType: 'backhand', secondaryType: 'snap', goalType: 'ratio', goalValue: 3, secondaryValue: 1, difficulty: 'Hard', proLevel: false, isBonus: false },
    { id: 'ratio_slap_snap_medium', style: 'ratio', title: 'Slap vs Snap', description: 'Take 2 slap shots for every 1 snap shot you take.', shotType: 'slap', shotTypeComparison: 'snap', primaryType: 'slap', secondaryType: 'snap', goalType: 'ratio', goalValue: 2, secondaryValue: 1, difficulty: 'Medium', proLevel: false, isBonus: false },
    { id: 'variety_master', style: 'quantity', title: 'Variety Master', description: 'Take at least 5 of each shot type (wrist, snap, backhand, slap) in a single session.', shotType: 'all', shotTypeComparison: '', primaryType: 'all', secondaryType: '', goalType: 'variety', goalValue: 5, difficulty: 'Medium', proLevel: false, isBonus: false },
    // --- Consistency ---
    { id: 'consistency_earlybird', style: 'consistency', title: 'Early Bird', description: 'Complete a shooting session before 7am three times.', shotType: '', goalType: 'early_sessions', goalValue: 3, difficulty: 'Hard', proLevel: false, isBonus: false },
    { id: 'consistency_doubleheader', style: 'consistency', title: 'Double Header', description: 'Complete two shooting sessions in one day.', shotType: '', goalType: 'double_sessions', goalValue: 1, difficulty: 'Hard', proLevel: false, isBonus: false },
    { id: 'consistency_weekendwarrior', style: 'consistency', title: 'Weekend Warrior', description: 'Complete a session on both Saturday and Sunday.', shotType: '', goalType: 'weekend_sessions', goalValue: 2, difficulty: 'Medium', proLevel: false, isBonus: false },
    { id: 'consistency_streak_five', style: 'consistency', title: 'Five Alive', description: 'Shoot pucks at least 5 days this week.', shotType: '', goalType: 'streak', goalValue: 5, difficulty: 'Hard', proLevel: false, isBonus: false },
    { id: 'consistency_daily_easy', style: 'consistency', title: 'Daily Shooter', description: 'Shoot pucks every day.', shotType: '', goalType: 'streak', goalValue: 7, difficulty: 'Hard', proLevel: false, isBonus: false },
    { id: 'consistency_sessions_hard', style: 'consistency', title: 'Session Grinder', description: 'Complete 5 shooting sessions. If you miss a day, you can still finish strong!', shotType: '', goalType: 'sessions', goalValue: 5, difficulty: 'Hard', proLevel: false, isBonus: false },
    { id: 'consistency_morning_medium', style: 'consistency', title: 'Morning Warrior', description: 'Complete 3 morning shooting sessions (before 10am).', shotType: '', goalType: 'morning_sessions', goalValue: 3, difficulty: 'Medium', proLevel: false, isBonus: false },
    // --- Progress ---
    { id: 'progress_wrist_improve_easy', style: 'progress', title: 'Wrist Shot Progress', description: 'Improve your wrist shot accuracy by 5%. Progress counts, even if it takes a few tries!', shotType: 'wrist', goalType: 'improvement', improvement: 5, difficulty: 'Easy', proLevel: true, isBonus: false },
    { id: 'progress_snap_improve_hard', style: 'progress', title: 'Snap Shot Progress', description: 'Improve your snap shot accuracy by 10%. You can keep working at it all week!', shotType: 'snap', goalType: 'improvement', improvement: 10, difficulty: 'Hard', proLevel: true, isBonus: false },
    { id: 'progress_target_hits', style: 'progress', title: 'Target Hitter', description: 'Hit 100 targets.', shotType: 'any', goalType: 'target_hits_increase', improvement: 100, difficulty: 'Easy', proLevel: true, isBonus: false },
];

async function assignAchievements(test: Boolean, userIds: Array<string>, options?: { forceUsers?: string[] }): Promise<any> {
    const weekStart = getWeekStartEST();
    try {
        const now = new Date();
        const FIFTEEN_DAYS_MS = 15 * 24 * 60 * 60 * 1000;
        const fifteenDaysAgo = new Date(now.getTime() - FIFTEEN_DAYS_MS);
        // Determine which users to process
        let userDocs: Array<{ id: string, data: () => any }>;
        if (options && Array.isArray(options.forceUsers) && options.forceUsers.length > 0) {
            // Force process these specific users regardless of last_seen
            const forced: Array<{ id: string, data: () => any }> = [];
            for (const uid of options.forceUsers) {
                const doc = await db.collection('users').doc(uid).get();
                if (doc.exists) {
                    forced.push({ id: doc.id, data: () => doc.data() });
                }
            }
            userDocs = forced;
        } else {
            const usersSnap = await db.collection('users').where('last_seen', '>=', fifteenDaysAgo).get();
            userDocs = usersSnap.docs.map(d => ({ id: d.id, data: () => d.data() }));
        }

        for (const userDoc of userDocs) {
            const userId = userDoc.id;
            if (test && !userIds.includes(userId)) continue; // Only update test users for test function calls
            const userData = userDoc.data();
            const playerAge = userData.age || 18;

            // --- Gather all achievements for metrics (before deleting) ---
            const allAchievementsSnap = await db.collection('users').doc(userId).collection('achievements').where('time_frame', '==', 'week').get();
            const allAchievements = allAchievementsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
            // Count total completed (including bonus) for this week
            const completedThisWeek = allAchievements.filter(a => (a as any).completed === true).length;
            // Count non-bonus achievements assigned this week
            const nonBonusThisWeek = allAchievements.filter(a => !(a as any).isBonus);
            // Count non-bonus completed this week
            const nonBonusCompletedThisWeek = nonBonusThisWeek.filter(a => (a as any).completed === true).length;
            // Fetch previous streak and total from stats/history
            const historyDoc = await db.collection('users').doc(userId).collection('stats').doc('history').get();
            let history = historyDoc.exists ? historyDoc.data() || {} : {};
            let prevStreak = history.weeklyAllCompletedStreak || 0;
            let prevTotal = history.totalAchievementsCompleted || 0;
            let weeklyAllCompletedStreak = prevStreak;
            if (nonBonusThisWeek.length > 0 && nonBonusCompletedThisWeek === nonBonusThisWeek.length) {
                weeklyAllCompletedStreak = prevStreak + 1;
            } else {
                weeklyAllCompletedStreak = 0;
            }
            // totalAchievementsCompleted is a running total (previous + new completions this week)
            const totalAchievementsCompleted = prevTotal + completedThisWeek;
            const updatedHistory = {
                totalAchievementsCompleted,
                weeklyAllCompletedStreak
            };
            await db.collection('users').doc(userId).collection('stats').doc('history').set(updatedHistory, { merge: true });

            // --- Move completed achievements to stats/history/completed_achievements before deleting ---
            const movePromises: Promise<any>[] = [];
            const completedAchievements = allAchievementsSnap.docs.filter(doc => (doc.data() as any).completed === true);
            const completedAchievementsCollection = db.collection('users').doc(userId).collection('stats').doc('history').collection('completed_achievements');
            for (const doc of completedAchievements) {
                // Save the achievement data with its original Firestore ID for traceability
                const achievementData = doc.data();
                // Optionally, add a timestamp for when it was archived
                achievementData.archivedAt = new Date();
                movePromises.push(
                    completedAchievementsCollection.doc(doc.id).set(achievementData, { merge: true })
                );
            }
            await Promise.all(movePromises);

            // --- Delete all previous week achievements (completed and incomplete) ---
            const deletePromises: Promise<any>[] = [];
            allAchievementsSnap.forEach(doc => {
                deletePromises.push(doc.ref.delete());
            });
            await Promise.all(deletePromises);

            // --- Reset swapCount at the start of the week ---
            const swapMetaRef = db.collection('users').doc(userId).collection('meta').doc('achievementSwaps');
            await swapMetaRef.set({ swapCount: 0 }, { merge: true });

            // --- Use summary stats from /users/{userId}/stats/weekly ---
            // (re-load stats for use below)
            const statsDoc = await db.collection('users').doc(userId).collection('stats').doc('weekly').get();
            let stats = statsDoc.exists ? statsDoc.data() || {} : {};
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
                    if (["wrist", "snap", "backhand", "slap"].includes(t.shotType) && weakestType && t.shotType !== weakestType) {
                        t.shotType = weakestType;
                        t.title = `${weakestType.charAt(0).toUpperCase() + weakestType.slice(1)} Accuracy Focus`;
                    }
                    // Ensure isStreak is set correctly for streak templates
                    if (typeof t.isStreak !== 'boolean') {
                        t.isStreak = false;
                    }
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
                    let avg = sessionAccuracies.length ? sessionAccuracies.reduce((a, b) => a + b, 0) / sessionAccuracies.length : 0;
                    let bump = (t.sessions && t.sessions > 1) ? 2.5 : 5.0;
                    let reasonableMin = 25;
                    let templateDefault = t.targetAccuracy;
                    let rawTarget = avg + bump;
                    let roundedTarget = Math.round(rawTarget / 2) * 2;
                    if (rawTarget < templateDefault) {
                        t.targetAccuracy = Math.max(reasonableMin, Math.min(roundedTarget, templateDefault));
                    } else {
                        t.targetAccuracy = Math.min(Math.max(templateDefault, roundedTarget), 100);
                    }
                    let sessionPhrase = '';
                    if (t.sessions) {
                        if (t.isStreak === true) {
                            sessionPhrase = ` in any ${t.sessions} consecutive session${t.sessions > 1 ? 's' : ''}`;
                        } else {
                            sessionPhrase = ` in any ${t.sessions} session${t.sessions > 1 ? 's' : ''}`;
                        }
                    }
                    // Linguistically correct shot type phrases
                    function shotTypeLabel(type: string) {
                        if (type === 'backhand') return 'backhands';
                        if (type === 'wrist') return 'wrist shots';
                        if (type === 'snap') return 'snap shots';
                        if (type === 'slap') return 'slap shots';
                        if (type === 'all') return 'all shot types';
                        if (type === 'any') return '';
                        return type;
                    }
                    let shotTypePhrase = shotTypeLabel(t.shotType);
                    if (t.shotType === 'any') {
                        t.description = t.isStreak
                            ? `Achieve ${t.targetAccuracy}% accuracy in any${sessionPhrase}.`
                            : `Achieve ${t.targetAccuracy}% accuracy in any${sessionPhrase}.`;
                    } else {
                        t.description = t.isStreak
                            ? `Achieve ${t.targetAccuracy}% accuracy on ${shotTypePhrase}${sessionPhrase}.`
                            : `Achieve ${t.targetAccuracy}% accuracy on ${shotTypePhrase}${sessionPhrase}.`;
                    }
                }
                // --- Quantity ---
                if (t.style === 'quantity' && t.goalValue) {
                    // Only substitute for wrist, snap, backhand, slap
                    if (["wrist", "snap", "backhand", "slap"].includes(t.shotType) && laggingType && t.shotType !== laggingType) {
                        t.shotType = laggingType;
                        t.title = `${laggingType.charAt(0).toUpperCase() + laggingType.slice(1)} Shot Challenge`;
                    }
                    // Linguistically correct shot type phrases
                    function shotTypeLabel(type: string) {
                        if (type === 'backhand') return 'backhands';
                        if (type === 'wrist') return 'wrist shots';
                        if (type === 'snap') return 'snap shots';
                        if (type === 'slap') return 'slap shots';
                        if (type === 'all') return 'all shot types';
                        if (type === 'any') return 'shots';
                        return type;
                    }
                    if (t.goalType === 'count_per_session') {
                        t.description = `Take at least ${t.goalValue} ${shotTypeLabel(t.shotType)} for any ${t.sessions} session${t.sessions > 1 ? 's' : ''} in a row.`;
                    } else if (t.goalType === 'count_evening') {
                        t.description = `Take ${t.goalValue} ${shotTypeLabel(t.shotType)} after 7pm in a single session.`;
                    } else if (t.goalType === 'count_time') {
                        t.description = `Take ${t.goalValue} ${shotTypeLabel(t.shotType)} in under ${t.timeLimit || 10} minute${(t.timeLimit || 10) > 1 ? 's' : ''} in a single session.`;
                    } else if (t.shotType === 'all') {
                        t.description = `Take at least ${t.goalValue} of each shot type (wrist, snap, backhand, slap) this week.`;
                    } else if (t.shotType === 'any') {
                        t.description = `Take ${t.goalValue} shots (any type) this week.`;
                    } else {
                        t.description = `Take ${t.goalValue} ${shotTypeLabel(t.shotType)} this week.`;
                    }
                }
                // --- Ratio ---
                if (t.style === 'ratio' && t.goalValue && t.secondaryValue) {
                    // Always use the originally assigned types for description
                    function shotTypeLabel(type: string, count: number) {
                        if (type === 'backhand') return count === 1 ? 'backhand' : 'backhands';
                        if (type === 'wrist') return count === 1 ? 'wrist shot' : 'wrist shots';
                        if (type === 'snap') return count === 1 ? 'snap shot' : 'snap shots';
                        if (type === 'slap') return count === 1 ? 'slap shot' : 'slap shots';
                        if (type === 'all') return 'all shot types';
                        if (type === 'any') return count === 1 ? 'shot' : 'shots';
                        return count === 1 ? type : type + 's';
                    }
                    const descPrimary = t.shotType || t.primaryType || '';
                    const descSecondary = t.shotTypeComparison || t.secondaryType || '';
                    const primaryLabel = shotTypeLabel(descPrimary, t.goalValue);
                    const secondaryLabel = shotTypeLabel(descSecondary, t.secondaryValue);
                    t.description = `Take ${t.goalValue} ${primaryLabel} for every ${t.secondaryValue} ${secondaryLabel}.`;
                }
                // --- Progress ---
                if (t.style === 'progress' && t.shotType && t.improvement) {
                    // Skill-based substitution for progress
                    // Only substitute for wrist, snap, backhand, slap
                    if (["wrist", "snap", "backhand", "slap"].includes(t.shotType) && weakestType && t.shotType !== weakestType) {
                        t.shotType = weakestType;
                        t.title = `${weakestType.charAt(0).toUpperCase() + weakestType.slice(1)} Progress`;
                    }
                    // Personalize improvement value based on user's average accuracy
                    let avg = avgAccuracies[t.shotType] || 0;
                    let bump = t.improvement;
                    // If user is below 40% accuracy, set a lower improvement target, else use template or a small bump
                    if (avg > 0 && avg < 40) {
                        bump = Math.max(2, Math.round((40 - avg) / 4));
                    } else if (avg >= 40 && avg < 60) {
                        bump = Math.max(t.improvement, 3);
                    } else if (avg >= 60) {
                        bump = Math.max(t.improvement, 2);
                    }
                    t.improvement = bump;
                    t.description = t.goalType === 'improvement_variety'
                        ? `Improve your accuracy by at least ${bump}% on all shot types.`
                        : `Improve your ${t.shotType} accuracy by ${bump}%. Progress counts, even if it takes a few tries!`;
                }
                // --- Consistency ---
                if (t.style === 'consistency' && t.goalType && t.goalValue) {
                    // Skill-based substitution for consistency
                    // Only substitute for wrist, snap, backhand, slap if shotType is present
                    if (["wrist", "snap", "backhand", "slap"].includes(t.shotType) && laggingType && t.shotType !== laggingType) {
                        t.shotType = laggingType;
                        t.title = `${laggingType.charAt(0).toUpperCase() + laggingType.slice(1)} Consistency`;
                    }
                    // Personalize goalValue based on user's average sessions or shots
                    let avgSessions = stats.sessions ? stats.sessions.length : 0;
                    // For streaks, set goalValue to at least 2 or 3 if user is active, else use template
                    if (t.goalType === 'streak') {
                        if (avgSessions >= 5) {
                            t.goalValue = Math.max(t.goalValue, 5);
                        } else if (avgSessions >= 3) {
                            t.goalValue = Math.max(t.goalValue, 3);
                        }
                        t.description = `Complete a ${t.goalValue} day shooting streak.`;
                    } else if (t.goalType === 'sessions') {
                        if (avgSessions > 0) {
                            t.goalValue = Math.max(t.goalValue, Math.ceil(avgSessions * 1.2));
                        }
                        t.description = `Complete ${t.goalValue} shooting sessions this week.`;
                    } else if (t.goalType === 'early_sessions') {
                        t.description = `Complete a shooting session before 7am ${t.goalValue} time${t.goalValue > 1 ? 's' : ''}.`;
                    } else if (t.goalType === 'double_sessions') {
                        t.description = `Complete two shooting sessions in one day, ${t.goalValue} time${t.goalValue > 1 ? 's' : ''}.`;
                    } else if (t.goalType === 'weekend_sessions') {
                        t.description = `Complete a session on both Saturday and Sunday.`;
                    } else if (t.goalType === 'morning_sessions') {
                        t.description = `Complete ${t.goalValue} shooting sessions before 10am.`;
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

            let achievements: any[] = [];
            if (test) {
                // In test mode, assign one achievement for every template (skip eligibility logic)
                achievements = templates.map(t => ({
                    ...substituteTemplate(t),
                    completed: false,
                    dateAssigned: Timestamp.fromDate(weekStart),
                    dateCompleted: null,
                    time_frame: 'week',
                    userId,
                }));
            } else {
                // Production: use eligibility logic as before
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
                achievements = assigned.slice(0, 4).map(t => ({
                    ...t,
                    completed: false,
                    dateAssigned: Timestamp.fromDate(weekStart),
                    dateCompleted: null,
                    time_frame: 'week',
                    userId,
                }));
            }
            for (const achievement of achievements) {
                await db.collection('users').doc(userId).collection('achievements').add(achievement);
            }
        }
        logger.info('assignWeeklyAchievements executed successfully.');
        let res = { success: true, status: 200, message: 'Weekly achievements assigned successfully.' };
        return res;
    } catch (error) {
        logger.error('Error assigning weekly achievements:', error);
        const errorMessage = typeof error === 'object' && error !== null && 'message' in error ? (error as { message: string }).message : String(error);
        let res = { success: false, status: 500, message: 'assignWeeklyAchievements failed: ' + errorMessage };
        return res;
    }
}

// Callable function: assign weekly achievements for the current authenticated user on demand
export const assignPlayerAchievements = onCall(async (req) => {
    const context = req.auth;
    if (!context || !context.uid) {
        throw new Error('Authentication required');
    }
    const userId = context.uid;
    try {
        const result = await assignAchievements(false, [], { forceUsers: [userId] });
        return { success: result.success, message: result.message };
    } catch (e) {
        const msg = typeof e === 'object' && e !== null && 'message' in e ? (e as { message: string }).message : String(e);
        return { success: false, message: msg };
    }
});

async function assignAchievement({ userId, isBonusSwap = false, assignedTemplateIds = [], hasBonus = false }: {
    userId: string,
    isBonusSwap?: boolean,
    assignedTemplateIds?: string[],
    hasBonus?: boolean
}): Promise<any> {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};
    const playerAge = userData.age || 18;
    // --- Use summary stats from /users/{userId}/stats/weekly ---
    const statsDoc = await userRef.collection('stats').doc('weekly').get();
    let stats = statsDoc.exists ? statsDoc.data() || {} : {};
    const shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
    const sessionShotCounts: { [key: string]: number[] } = {};
    const sessionAccuracies: { [key: string]: number[] } = {};
    for (const type of shotTypes) {
        sessionShotCounts[type] = (stats.sessions || []).map((s: any) => s.shots?.[type] ?? 0);
        const sessionsWithAccuracy = (stats.sessions || []).filter((s: any) => s.targets_hit && typeof s.targets_hit[type] === 'number');
        sessionAccuracies[type] = sessionsWithAccuracy.map((s: any) => {
            const shots = s.shots?.[type] ?? 0;
            const hits = s.targets_hit?.[type] ?? 0;
            return shots > 0 ? (hits / shots) * 100 : 0;
        });
    }
    const difficultyMap: { [key: string]: string[] } = {
        u7: ['Easy', 'Medium', 'Hard'],
        u9: ['Easy', 'Medium', 'Hard'],
        u11: ['Easy', 'Medium', 'Hard'],
        u13: ['Easy', 'Medium', 'Hard', 'Hardest'],
        u15: ['Easy', 'Medium', 'Hard', 'Hardest'],
        u18: ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
        adult: ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
    };
    let ageGroup: string = 'adult';
    if (playerAge < 7) ageGroup = 'u7';
    else if (playerAge < 9) ageGroup = 'u9';
    else if (playerAge < 11) ageGroup = 'u11';
    else if (playerAge < 13) ageGroup = 'u13';
    else if (playerAge < 15) ageGroup = 'u15';
    else if (playerAge < 18) ageGroup = 'u18';
    const allowed: string[] = difficultyMap[ageGroup] || ['Easy'];
    function mapDifficulty(template: any): string {
        let mapped = template.difficulty;
        if (["u7", "u9", "u11"].includes(ageGroup) && (template.difficulty === "Hardest" || template.difficulty === "Impossible")) {
            mapped = "Hard";
        } else if (["u13", "u15"].includes(ageGroup) && template.difficulty === "Impossible") {
            mapped = "Hardest";
        }
        return mapped;
    }
    // --- Skill-based substitutions ---
    const avgAccuracies: { [key: string]: number } = {};
    const avgShotsPerSession: { [key: string]: number } = {};
    for (const type of shotTypes) {
        const accArr = sessionAccuracies[type] || [];
        avgAccuracies[type] = accArr.length ? accArr.reduce((a, b) => a + b, 0) / accArr.length : 0;
        const shotsArr = sessionShotCounts[type] || [];
        avgShotsPerSession[type] = shotsArr.length ? shotsArr.reduce((a, b) => a + b, 0) / shotsArr.length : 0;
    }
    function substituteTemplate(tmpl: any): any {
        // ...existing code for substituteTemplate...
        // (copy from assignAchievements)
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
        // ...existing code for all template substitutions...
        // (copy from assignAchievements)
        // --- Accuracy ---
        if (t.style === 'accuracy' && t.shotType && t.targetAccuracy) {
            if (["wrist", "snap", "backhand", "slap"].includes(t.shotType) && weakestType && t.shotType !== weakestType) {
                t.shotType = weakestType;
                t.title = `${weakestType.charAt(0).toUpperCase() + weakestType.slice(1)} Accuracy Focus`;
            }
            if (typeof t.isStreak !== 'boolean') {
                t.isStreak = false;
            }
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
            let avg = sessionAccuracies.length ? sessionAccuracies.reduce((a, b) => a + b, 0) / sessionAccuracies.length : 0;
            let bump = (t.sessions && t.sessions > 1) ? 2.5 : 5.0;
            let reasonableMin = 25;
            let templateDefault = t.targetAccuracy;
            let rawTarget = avg + bump;
            let roundedTarget = Math.round(rawTarget / 2) * 2;
            if (rawTarget < templateDefault) {
                t.targetAccuracy = Math.max(reasonableMin, Math.min(roundedTarget, templateDefault));
            } else {
                t.targetAccuracy = Math.min(Math.max(templateDefault, roundedTarget), 100);
            }
            let sessionPhrase = '';
            if (t.sessions) {
                if (t.isStreak === true) {
                    sessionPhrase = ` in any ${t.sessions} consecutive session${t.sessions > 1 ? 's' : ''}`;
                } else {
                    sessionPhrase = ` in any ${t.sessions} session${t.sessions > 1 ? 's' : ''}`;
                }
            }
            function shotTypeLabel(type: string) {
                if (type === 'backhand') return 'backhands';
                if (type === 'wrist') return 'wrist shots';
                if (type === 'snap') return 'snap shots';
                if (type === 'slap') return 'slap shots';
                if (type === 'all') return 'all shot types';
                if (type === 'any') return '';
                return type;
            }
            let shotTypePhrase = shotTypeLabel(t.shotType);
            if (t.shotType === 'any') {
                t.description = t.isStreak
                    ? `Achieve ${t.targetAccuracy}% accuracy in any${sessionPhrase}.`
                    : `Achieve ${t.targetAccuracy}% accuracy in any${sessionPhrase}.`;
            } else {
                t.description = t.isStreak
                    ? `Achieve ${t.targetAccuracy}% accuracy on ${shotTypePhrase}${sessionPhrase}.`
                    : `Achieve ${t.targetAccuracy}% accuracy on ${shotTypePhrase}${sessionPhrase}.`;
            }
        }
        // ...existing code for other substitutions (quantity, ratio, progress, consistency, etc)...
        // (copy from assignAchievements)
        // --- Quantity ---
        if (t.style === 'quantity' && t.goalValue) {
            if (["wrist", "snap", "backhand", "slap"].includes(t.shotType) && laggingType && t.shotType !== laggingType) {
                t.shotType = laggingType;
                t.title = `${laggingType.charAt(0).toUpperCase() + laggingType.slice(1)} Shot Challenge`;
            }
            function shotTypeLabel(type: string) {
                if (type === 'backhand') return 'backhands';
                if (type === 'wrist') return 'wrist shots';
                if (type === 'snap') return 'snap shots';
                if (type === 'slap') return 'slap shots';
                if (type === 'all') return 'all shot types';
                if (type === 'any') return 'shots';
                return type;
            }
            if (t.goalType === 'count_per_session') {
                t.description = `Take at least ${t.goalValue} ${shotTypeLabel(t.shotType)} for any ${t.sessions} session${t.sessions > 1 ? 's' : ''} in a row.`;
            } else if (t.goalType === 'count_evening') {
                t.description = `Take ${t.goalValue} ${shotTypeLabel(t.shotType)} after 7pm in a single session.`;
            } else if (t.goalType === 'count_time') {
                t.description = `Take ${t.goalValue} ${shotTypeLabel(t.shotType)} in under ${t.timeLimit || 10} minute${(t.timeLimit || 10) > 1 ? 's' : ''} in a single session.`;
            } else if (t.shotType === 'all') {
                t.description = `Take at least ${t.goalValue} of each shot type (wrist, snap, backhand, slap) this week.`;
            } else if (t.shotType === 'any') {
                t.description = `Take ${t.goalValue} shots (any type) this week.`;
            } else {
                t.description = `Take ${t.goalValue} ${shotTypeLabel(t.shotType)} this week.`;
            }
        }
        // ...other substitutions (ratio, progress, consistency, etc) as in assignAchievements...
        // --- Ratio ---
        if (t.style === 'ratio' && t.goalValue && t.secondaryValue) {
            function shotTypeLabel(type: string, count: number) {
                if (type === 'backhand') return count === 1 ? 'backhand' : 'backhands';
                if (type === 'wrist') return count === 1 ? 'wrist shot' : 'wrist shots';
                if (type === 'snap') return count === 1 ? 'snap shot' : 'snap shots';
                if (type === 'slap') return count === 1 ? 'slap shot' : 'slap shots';
                if (type === 'all') return 'all shot types';
                if (type === 'any') return count === 1 ? 'shot' : 'shots';
                return count === 1 ? type : type + 's';
            }
            const descPrimary = t.shotType || t.primaryType || '';
            const descSecondary = t.shotTypeComparison || t.secondaryType || '';
            const primaryLabel = shotTypeLabel(descPrimary, t.goalValue);
            const secondaryLabel = shotTypeLabel(descSecondary, t.secondaryValue);
            t.description = `Take ${t.goalValue} ${primaryLabel} for every ${t.secondaryValue} ${secondaryLabel}.`;
        }
        // --- Progress ---
        if (t.style === 'progress' && t.shotType && t.improvement) {
            if (["wrist", "snap", "backhand", "slap"].includes(t.shotType) && weakestType && t.shotType !== weakestType) {
                t.shotType = weakestType;
                t.title = `${weakestType.charAt(0).toUpperCase() + weakestType.slice(1)} Progress`;
            }
            let avg = avgAccuracies[t.shotType] || 0;
            let bump = t.improvement;
            if (avg > 0 && avg < 40) {
                bump = Math.max(2, Math.round((40 - avg) / 4));
            } else if (avg >= 40 && avg < 60) {
                bump = Math.max(t.improvement, 3);
            } else if (avg >= 60) {
                bump = Math.max(t.improvement, 2);
            }
            t.improvement = bump;
            t.description = t.goalType === 'improvement_variety'
                ? `Improve your accuracy by at least ${bump}% on all shot types.`
                : `Improve your ${t.shotType} accuracy by ${bump}%. Progress counts, even if it takes a few tries!`;
        }
        // --- Consistency ---
        if (t.style === 'consistency' && t.goalType && t.goalValue) {
            if (["wrist", "snap", "backhand", "slap"].includes(t.shotType) && laggingType && t.shotType !== laggingType) {
                t.shotType = laggingType;
                t.title = `${laggingType.charAt(0).toUpperCase() + laggingType.slice(1)} Consistency`;
            }
            let avgSessions = stats.sessions ? stats.sessions.length : 0;
            if (t.goalType === 'streak') {
                if (avgSessions >= 5) {
                    t.goalValue = Math.max(t.goalValue, 5);
                } else if (avgSessions >= 3) {
                    t.goalValue = Math.max(t.goalValue, 3);
                }
                t.description = `Complete a ${t.goalValue} day shooting streak.`;
            } else if (t.goalType === 'sessions') {
                if (avgSessions > 0) {
                    t.goalValue = Math.max(t.goalValue, Math.ceil(avgSessions * 1.2));
                }
                t.description = `Complete ${t.goalValue} shooting sessions this week.`;
            } else if (t.goalType === 'early_sessions') {
                t.description = `Complete a shooting session before 7am ${t.goalValue} time${t.goalValue > 1 ? 's' : ''}.`;
            } else if (t.goalType === 'double_sessions') {
                t.description = `Complete two shooting sessions in one day, ${t.goalValue} time${t.goalValue > 1 ? 's' : ''}.`;
            } else if (t.goalType === 'weekend_sessions') {
                t.description = `Complete a session on both Saturday and Sunday.`;
            } else if (t.goalType === 'morning_sessions') {
                t.description = `Complete ${t.goalValue} shooting sessions before 10am.`;
            }
        }
        if (t.style === 'progress' && t.goalType === 'target_hits_increase' && t.improvement) {
            t.description = `Hit ${t.improvement} targets.`;
        }
        if (t.style === 'progress' && t.goalType === 'improvement_streak' && t.improvement && t.days) {
            t.description = `Improve your accuracy on any shot type for ${t.days} days in a row.`;
        }
        if (t.style === 'progress' && t.goalType === 'improvement_sessions' && t.improvement && t.sessions) {
            t.description = `Improve your accuracy in at least ${t.sessions} different sessions.`;
        }
        if (t.style === 'progress' && t.goalType === 'improvement_evening' && t.improvement) {
            t.description = `Improve your overall accuracy by ${t.improvement}%.`;
        }
        return t;
    }
    // --- Eligibility logic ---
    let eligible: any[];
    if (isBonusSwap) {
        eligible = templates.filter((t: any) => allowed.includes(mapDifficulty(t)) && t.isBonus === true && !assignedTemplateIds.includes(t.id));
    } else {
        eligible = templates.filter((t: any) => allowed.includes(mapDifficulty(t)) && (!hasBonus ? true : t.isBonus !== true) && !assignedTemplateIds.includes(t.id));
    }
    eligible = eligible.sort(() => Math.random() - 0.5);
    if (eligible.length === 0) {
        return { success: false, message: 'No eligible achievements to assign.' };
    }
    // Pick one eligible achievement
    const chosen = substituteTemplate(eligible[0]);
    const achievement = {
        ...chosen,
        completed: false,
        dateAssigned: admin.firestore.Timestamp.now(),
        dateCompleted: null,
        time_frame: 'week',
        userId,
    };
    await userRef.collection('achievements').add(achievement);
    return { success: true, achievement };
}

// Progressive swap delays in milliseconds (after 3 free swaps)
const SWAP_DELAYS = [0, 0, 0, 60_000, 180_000, 300_000, 600_000, 1_200_000, 86_400_000]; // 0,0,0,1m,3m,5m,10m,20m,1d

// Callable function: swapAchievement
export const swapAchievement = onCall(async (req) => {
    // Auth required
    const context = req.auth;
    if (!context || !context.uid) {
        throw new Error('Authentication required');
    }
    const userId = context.uid;
    const { achievementId } = req.data || {};
    if (!achievementId) {
        throw new Error('Missing achievementId');
    }
    const userRef = db.collection('users').doc(userId);
    const achievementsRef = userRef.collection('achievements');
    const swapMetaRef = userRef.collection('meta').doc('achievementSwaps');

    // Get swap meta (swapCount, lastSwap)
    let swapMeta = (await swapMetaRef.get()).data() || {};
    let swapCount = swapMeta.swapCount || 0;
    let lastSwap = swapMeta.lastSwap ? swapMeta.lastSwap.toDate ? swapMeta.lastSwap.toDate() : new Date(swapMeta.lastSwap) : null;
    let now = new Date();
    // Determine required delay
    let delayMs = SWAP_DELAYS[Math.min(swapCount, SWAP_DELAYS.length - 1)];
    let nextAvailable = lastSwap ? new Date(lastSwap.getTime() + delayMs) : now;
    if (lastSwap && now < nextAvailable) {
        return { success: false, message: `Next swap available at ${nextAvailable.toISOString()}`, nextAvailable: nextAvailable.toISOString(), swapCount };
    }

    // Get the achievement to swap
    const achDoc = await achievementsRef.doc(achievementId).get();
    if (!achDoc.exists) {
        return { success: false, message: 'Achievement not found' };
    }

    const ach = achDoc.data();
    if (!ach) {
        return { success: false, message: 'Achievement data not found' };
    }
    if (ach.completed) {
        return { success: false, message: 'Cannot swap a completed achievement' };
    }


    // Remove the old achievement
    await achievementsRef.doc(achievementId).delete();

    // Get current achievements and bonus state
    const currentAchievementsSnap = await achievementsRef.get();
    const currentAchievements = currentAchievementsSnap.docs.map(doc => doc.data());
    const hasBonus = currentAchievements.some(a => a.isBonus === true);
    const assignedTemplateIds = currentAchievements.map((a: any) => a.id);

    // Use the new assignAchievement function for assignment
    const assignResult = await assignAchievement({
        userId,
        isBonusSwap: ach.isBonus === true,
        assignedTemplateIds,
        hasBonus
    });
    if (!assignResult.success) {
        return { success: false, message: assignResult.message || 'No eligible achievements to assign.' };
    }
    const achievement = assignResult.achievement;
    // Update swap meta
    await swapMetaRef.set({
        swapCount: swapCount + 1,
        lastSwap: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    // Calculate next delay
    const nextDelayMs = SWAP_DELAYS[Math.min(swapCount + 1, SWAP_DELAYS.length - 1)];
    const nextSwapTime = new Date(now.getTime() + nextDelayMs);
    return {
        success: true,
        newAchievement: achievement,
        swapCount: swapCount + 1,
        nextAvailable: nextSwapTime.toISOString(),
    };
});
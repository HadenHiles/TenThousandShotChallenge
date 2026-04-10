#!/usr/bin/env node
/**
 * Dumps the challenger_road/summary document for a user so we can
 * verify the data path and current badge state.
 *
 * Usage:
 *   node scripts/dump_user_cr_summary.js <userId>
 */

'use strict';

const admin = require('firebase-admin');

const userId = process.argv[2];
if (!userId) {
    console.error('Usage: node scripts/dump_user_cr_summary.js <userId>');
    process.exit(1);
}

if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
}

const db = admin.firestore();

async function dump() {
    // 1. The summary doc the app reads badges from
    const summaryRef = db.collection('users').doc(userId).collection('challenger_road').doc('summary');
    const summarySnap = await summaryRef.get();

    console.log('=== users/{uid}/challenger_road/summary ===');
    if (!summarySnap.exists) {
        console.log('  (document does not exist)');
    } else {
        const d = summarySnap.data();
        console.log('  badges:', JSON.stringify(d.badges ?? []));
        console.log('  totalAttempts:', d.total_attempts);
        console.log('  allTimeBestLevel:', d.all_time_best_level);
        console.log('  allTimeTotalChallengerRoadShots:', d.all_time_total_challenger_road_shots);
        console.log('  full doc:', JSON.stringify(d, null, 2));
    }

    // 2. All sub-collections under the user doc (to spot unexpected paths)
    const userRef = db.collection('users').doc(userId);
    const subCollections = await userRef.listCollections();
    console.log('\n=== Sub-collections under users/{uid} ===');
    for (const col of subCollections) {
        console.log(' ', col.id);
    }

    // 3. Active attempts
    const attemptsSnap = await db
        .collection('users').doc(userId)
        .collection('challenger_road_attempts')
        .orderBy('attempt_number')
        .get()
        .catch(() => null);

    // Also try the path the service uses
    const attemptsSnap2 = await db
        .collection('challenger_road_attempts')
        .where('user_id', '==', userId)
        .limit(5)
        .get()
        .catch(() => null);

    if (attemptsSnap && !attemptsSnap.empty) {
        console.log('\n=== users/{uid}/challenger_road_attempts ===');
        attemptsSnap.docs.forEach(d => console.log(' ', d.id, d.data()));
    }
    if (attemptsSnap2 && !attemptsSnap2.empty) {
        console.log('\n=== challenger_road_attempts (top-level, user_id filter) ===');
        attemptsSnap2.docs.forEach(d => console.log(' ', d.id, d.data()));
    }
}

dump().catch((err) => {
    console.error(err);
    process.exit(1);
});

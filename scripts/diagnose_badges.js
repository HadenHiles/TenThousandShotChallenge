#!/usr/bin/env node
/**
 * Diagnostic: runs the same reads that _loadRoadBadgeStats + _checkAndAwardBadges
 * do in the app, and prints exactly what gets found/missed and which badges
 * would be awarded.
 *
 * Usage:
 *   node scripts/diagnose_badges.js <userId>
 */

'use strict';

const admin = require('firebase-admin');

const userId = process.argv[2];
if (!userId) {
    console.error('Usage: node scripts/diagnose_badges.js <userId>');
    process.exit(1);
}

if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
}

const db = admin.firestore();

async function diagnose() {
    // 1. Summary
    const summarySnap = await db.collection('users').doc(userId)
        .collection('challenger_road').doc('summary').get();
    const summary = summarySnap.exists ? summarySnap.data() : {};
    console.log('=== Summary ===');
    console.log('  badges (current):', summary.badges ?? []);
    console.log('  total_attempts:', summary.total_attempts);
    console.log('  all_time_best_level:', summary.all_time_best_level);
    console.log('  all_time_total_challenger_road_shots:', summary.all_time_total_challenger_road_shots);

    const t = summary.total_attempts ?? 0;
    const shots = summary.all_time_total_challenger_road_shots ?? 0;

    // 2. Active levels
    console.log('\n=== Active Levels ===');
    let levelSnaps;
    try {
        levelSnaps = await db.collection('challenger_road_levels').where('active', '==', true).get();
        console.log('  Found', levelSnaps.size, 'active levels');
        for (const lvl of levelSnaps.docs) {
            const data = lvl.data();
            const challengeSnaps = await db.collection('challenger_road_levels').doc(lvl.id)
                .collection('challenges').where('active', '==', true).get();
            console.log(`  Level ${data.level}: ${challengeSnaps.size} active challenges`);
        }
    } catch (e) {
        console.error('  ERROR reading levels:', e.message);
        levelSnaps = { docs: [] };
    }

    // 3. Attempts - ordered by attempt_number
    console.log('\n=== Attempts (ordered by attempt_number) ===');
    let attemptsSnap;
    try {
        attemptsSnap = await db.collection('users').doc(userId)
            .collection('challenger_road_attempts').orderBy('attempt_number').get();
        console.log('  Found', attemptsSnap.size, 'attempts');
        for (const a of attemptsSnap.docs) {
            const d = a.data();
            console.log(`  [${a.id}] attempt_number=${d.attempt_number} status=${d.status} highest_level=${d.highest_level_reached_this_attempt}`);
        }
    } catch (e) {
        console.error('  ERROR reading attempts (orderBy attempt_number):', e.message);
        // Try without orderBy
        try {
            attemptsSnap = await db.collection('users').doc(userId)
                .collection('challenger_road_attempts').get();
            console.log('  Fallback (no orderBy): found', attemptsSnap.size, 'attempts');
        } catch (e2) {
            console.error('  ERROR reading attempts (no orderBy either):', e2.message);
            attemptsSnap = { docs: [] };
        }
    }

    // 4. Sessions for each attempt
    let totalSessions = 0;
    let totalPassed = 0;
    let longestStreak = 0;
    let currentStreak = 0;
    let bestAccuracy = 0;
    let perfectSessions = 0;

    for (const a of attemptsSnap.docs) {
        const attemptId = a.id;
        console.log(`\n=== Sessions for attempt ${attemptId} ===`);
        try {
            const sessSnap = await db.collection('users').doc(userId)
                .collection('challenger_road_attempts').doc(attemptId)
                .collection('challenge_sessions').orderBy('date').get();
            console.log('  Found', sessSnap.size, 'sessions');
            for (const s of sessSnap.docs) {
                const d = s.data();
                totalSessions++;
                const acc = d.total_shots > 0 ? d.shots_made / d.total_shots : 0;
                if (d.passed) {
                    totalPassed++;
                    currentStreak++;
                    if (currentStreak > longestStreak) longestStreak = currentStreak;
                } else {
                    currentStreak = 0;
                }
                if (acc > bestAccuracy) bestAccuracy = acc;
                if (d.total_shots > 0 && d.shots_made === d.total_shots) perfectSessions++;
                console.log(`    [${s.id}] challenge=${d.challenge_id} passed=${d.passed} shots_made=${d.shots_made}/${d.total_shots} (${(acc * 100).toFixed(1)}%)`);
            }
        } catch (e) {
            console.error('  ERROR reading sessions:', e.message);
        }
    }

    // 5. Evaluate which badges would be awarded
    console.log('\n=== Badge Evaluation ===');
    console.log('  Stats:');
    console.log('    total_attempts (t):', t);
    console.log('    shots:', shots);
    console.log('    totalSessions:', totalSessions);
    console.log('    totalPassed:', totalPassed);
    console.log('    longestPassStreak:', longestStreak);
    console.log('    bestAccuracy:', (bestAccuracy * 100).toFixed(1) + '%');
    console.log('    perfectSessions:', perfectSessions);

    const wouldAward = [];
    if (t >= 1) wouldAward.push('fresh_laces');
    if (totalSessions >= 1) wouldAward.push('drop_the_biscuit');
    if (totalPassed >= 1) wouldAward.push('clean_read');
    if (shots >= 100) wouldAward.push('first_bucket');
    if (shots >= 1000) wouldAward.push('building_a_barn');
    if (shots >= 5000) wouldAward.push('ten_minute_major');
    // cr_sharp removed from catalog (too close to cr_sauce at 5 passes).
    if (longestStreak >= 5) wouldAward.push('sauce');
    if (longestStreak >= 10) wouldAward.push('unstoppable');
    if (bestAccuracy >= 0.90) wouldAward.push('bar_down');
    if (bestAccuracy >= 0.95) wouldAward.push('top_cheese');
    if (perfectSessions >= 1) wouldAward.push('pure');
    if (perfectSessions >= 5) wouldAward.push('all_net');
    if (t >= 2) wouldAward.push('veteran_presence');
    if (t >= 5) wouldAward.push('lifer');

    console.log('\n  Badges that SHOULD be awarded:', wouldAward);
    console.log('  Badges currently in Firestore:', summary.badges ?? []);
    const missing = wouldAward.filter(b => !(summary.badges ?? []).includes(b));
    console.log('  MISSING from Firestore:', missing);
}

diagnose().catch((err) => {
    console.error('Fatal:', err);
    process.exit(1);
});

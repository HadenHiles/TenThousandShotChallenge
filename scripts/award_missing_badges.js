#!/usr/bin/env node
/**
 * Awards missing Challenger Road badges directly to Firestore.
 *
 * Ports the same logic as _checkAndAwardBadges / _loadRoadBadgeStats in
 * ChallengerRoadService.dart and writes the result directly.
 *
 * Usage:
 *   node scripts/award_missing_badges.js <userId>
 */

'use strict';

const admin = require('firebase-admin');

const userId = process.argv[2];
if (!userId) {
    console.error('Usage: node scripts/award_missing_badges.js <userId>');
    process.exit(1);
}

if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
}

const db = admin.firestore();

// Badge catalog - must stay in sync with badgeCatalog in ChallengerRoadService.dart.
// Only the IDs matter here; we just need to know which ones are valid.
const VALID_BADGE_IDS = new Set([
    'fresh_laces',
    'drop_the_biscuit',
    'clean_read',
    'level_clear',
    'made_the_show',
    'sharp',               // removed from catalog - kept so existing earners aren't pruned
    'scouting_report',
    'the_rematch',
    'dialed_in',
    'comeback_season',
    'the_comeback_kid',
    'ice_time_earned',
    'team_captain',
    'playoff_mode',        // removed from catalog - kept so existing earners aren't pruned
    'the_general',
    'first_bucket',
    'building_a_barn',
    'ten_minute_major',
    'buzzer_beater',
    'well_never_runs_dry',
    'bar_down',
    'top_cheese',
    'pure',
    'all_net',
    'sauce',
    'unstoppable',
    'never_missed',
    'untouchable',
    'earned_a_salary',
    'veteran_presence',
    'lifer',
    'road_dog',
    'all_time_great',
    'bender',
    // Contextually awarded - included so they're not pruned if present:
    'no_warmup_needed',
    'breakaway',
    'freight_train',
    'clean_sweep',
    'lights_out',
    'battle_tested',
    'game_7',
    'ghosts_in_the_machine', // removed from catalog - kept so existing earners aren't pruned
    'old_grudge',
    'redemption_arc',
    'pigeon',
    'sauce_boss',
    'full_send',
    'the_climb',
    'third_period_heart',
    'the_sniper',
    'hall_of_famer',
    'hockey_god',
    'the_machine',
    'all_stars',
    'three_periods',
    'career_year',
    'skip_the_tryout',
]);

async function main() {
    // ── 1. Summary ─────────────────────────────────────────────────────────────
    const summaryRef = db.collection('users').doc(userId)
        .collection('challenger_road').doc('summary');
    const summarySnap = await summaryRef.get();
    if (!summarySnap.exists) {
        console.error('No summary document found for user', userId);
        process.exit(1);
    }
    const summary = summarySnap.data();
    const currentBadges = Array.isArray(summary.badges) ? summary.badges : [];
    console.log('Current badges:', currentBadges);

    // Prune any legacy IDs no longer in catalog.
    const earned = currentBadges.filter(id => VALID_BADGE_IDS.has(id));
    const hadLegacy = earned.length !== currentBadges.length;
    if (hadLegacy) {
        console.log('Pruned legacy badges:', currentBadges.filter(id => !VALID_BADGE_IDS.has(id)));
    }

    const t = summary.total_attempts ?? 0;
    const shots = summary.all_time_total_challenger_road_shots ?? 0;

    // ── 2. Active level config ─────────────────────────────────────────────────
    const levelSnaps = await db.collection('challenger_road_levels').where('active', '==', true).get();
    const activeChallengeIdsByLevel = {};
    for (const lvlDoc of levelSnaps.docs) {
        const level = lvlDoc.data().level;
        if (level == null) continue;
        const challengeSnaps = await db.collection('challenger_road_levels').doc(lvlDoc.id)
            .collection('challenges').where('active', '==', true).get();
        activeChallengeIdsByLevel[level] = new Set(
            challengeSnaps.docs.map(d => d.id).filter(Boolean)
        );
    }
    const highestActiveLevel = Object.keys(activeChallengeIdsByLevel).length > 0
        ? Math.max(...Object.keys(activeChallengeIdsByLevel).map(Number))
        : 0;

    // ── 3. Attempts ────────────────────────────────────────────────────────────
    const attemptsSnap = await db.collection('users').doc(userId)
        .collection('challenger_road_attempts').orderBy('attempt_number').get();
    const allAttempts = attemptsSnap.docs.map(d => ({ ...d.data(), id: d.id }));

    // ── 4. Sessions (parallel) ─────────────────────────────────────────────────
    const allSessionSnaps = await Promise.all(
        allAttempts.map(a =>
            db.collection('users').doc(userId)
                .collection('challenger_road_attempts').doc(a.id)
                .collection('challenge_sessions').orderBy('date').get()
        )
    );

    // ── 5. Build stats ─────────────────────────────────────────────────────────
    let totalCrSessions = 0;
    let totalPassedSessions = 0;
    let bestSingleSessionAccuracy = 0.0;
    let perfectSessions = 0;
    let longestPassStreak = 0;
    let currentPassStreak = 0;

    const levelsEverCleared = new Set();
    let latestAttemptNumber = 0;
    let latestAttemptStartingLevel = 1;
    let previousAttemptHighestLevel = 0;

    const sessionsByChallengeByAttempt = {};
    const firstAttemptPassesByChallenge = {};
    const bestAccuracyByChallenge = {};
    const allTimePassesByChallenge = {};

    let allTimeBestSeen = 0;
    const attemptNumbersWithNewBestLevel = [];

    for (let i = 0; i < allAttempts.length; i++) {
        const attempt = allAttempts[i];
        const attemptNumber = attempt.attempt_number ?? 1;

        if (attemptNumber > latestAttemptNumber) {
            latestAttemptNumber = attemptNumber;
            latestAttemptStartingLevel = attempt.starting_level ?? 1;
        }

        const sessionsRaw = allSessionSnaps[i].docs.map(d => ({ id: d.id, ...d.data() }));
        const seenChallenges = new Set();

        for (const s of sessionsRaw) {
            totalCrSessions++;
            const acc = s.total_shots > 0 ? s.shots_made / s.total_shots : 0.0;

            if (s.passed) {
                totalPassedSessions++;
                currentPassStreak++;
                if (currentPassStreak > longestPassStreak) longestPassStreak = currentPassStreak;
            } else {
                currentPassStreak = 0;
            }

            if (acc > bestSingleSessionAccuracy) bestSingleSessionAccuracy = acc;
            if (s.total_shots > 0 && s.shots_made === s.total_shots) perfectSessions++;

            const prev = bestAccuracyByChallenge[s.challenge_id] ?? 0.0;
            if (acc > prev) bestAccuracyByChallenge[s.challenge_id] = acc;

            if (!sessionsByChallengeByAttempt[s.challenge_id]) sessionsByChallengeByAttempt[s.challenge_id] = {};
            if (!sessionsByChallengeByAttempt[s.challenge_id][attemptNumber]) sessionsByChallengeByAttempt[s.challenge_id][attemptNumber] = [];
            sessionsByChallengeByAttempt[s.challenge_id][attemptNumber].push(s);

            if (!seenChallenges.has(s.challenge_id)) {
                seenChallenges.add(s.challenge_id);
                if (s.passed) {
                    if (!firstAttemptPassesByChallenge[s.challenge_id]) firstAttemptPassesByChallenge[s.challenge_id] = [];
                    firstAttemptPassesByChallenge[s.challenge_id].push(attemptNumber);
                }
            }
        }

        // Level clearing.
        const clearedThisAttempt = new Set();
        for (const [levelStr, required] of Object.entries(activeChallengeIdsByLevel)) {
            const level = Number(levelStr);
            const passedAtLevel = new Set();
            for (const s of sessionsRaw) {
                if (s.passed && (s.level ?? 1) === level) passedAtLevel.add(s.challenge_id);
            }
            if ([...required].every(id => passedAtLevel.has(id))) clearedThisAttempt.add(level);
        }
        clearedThisAttempt.forEach(l => levelsEverCleared.add(l));

        if (attempt.highest_level_reached_this_attempt > allTimeBestSeen) {
            allTimeBestSeen = attempt.highest_level_reached_this_attempt;
            attemptNumbersWithNewBestLevel.push(attemptNumber);
        }
    }

    if (allAttempts.length >= 2) {
        previousAttemptHighestLevel = allAttempts[allAttempts.length - 2].highest_level_reached_this_attempt ?? 0;
    }

    // All-time history.
    const historySnap = await db.collection('users').doc(userId)
        .collection('challenger_road_all_time_history').get();
    for (const doc of historySnap.docs) {
        const h = doc.data();
        allTimePassesByChallenge[h.challenge_id ?? doc.id] = h.all_time_total_passed ?? 0;
    }

    // Cross-attempt metrics.
    let challengesWithPerfectRecord = 0;
    let challengesWithSalary = 0;
    let untouchableChallenges = 0;
    let scoutingReportCount = 0;
    let rematches = 0;
    let mostFailedChallengeId = null;
    let mostFailedCount = 0;

    for (const [challengeId, byAttempt] of Object.entries(sessionsByChallengeByAttempt)) {
        let failed = 0;
        for (const sessions of Object.values(byAttempt)) {
            failed += sessions.filter(s => !s.passed).length;
        }
        if (failed === 0) challengesWithPerfectRecord++;
        if (failed > mostFailedCount) { mostFailedCount = failed; mostFailedChallengeId = challengeId; }

        const passes = allTimePassesByChallenge[challengeId] ?? 0;
        if (passes >= 25) challengesWithSalary++;

        const firstPassAttempts = firstAttemptPassesByChallenge[challengeId] ?? [];
        if (firstPassAttempts.length >= 5) untouchableChallenges++;

        const attemptNums = Object.keys(byAttempt).map(Number).sort((a, b) => a - b);
        for (let i = 0; i < attemptNums.length; i++) {
            const aN = attemptNums[i];
            const sessions = byAttempt[aN];
            const passedThisAttempt = sessions.some(s => s.passed);
            if (i > 0) {
                const prevSessions = byAttempt[attemptNums[i - 1]];
                const prevPassed = prevSessions.some(s => s.passed);
                const prevSessionCount = prevSessions.length;
                const firstThisAttempt = sessions[0]?.passed ?? false;
                if (firstThisAttempt && prevSessionCount > 1) scoutingReportCount++;
                if (!prevPassed && passedThisAttempt) rematches++;
            }
        }
    }

    console.log('\nStats computed:');
    console.log('  totalCrSessions:', totalCrSessions);
    console.log('  totalPassedSessions:', totalPassedSessions);
    console.log('  longestPassStreak:', longestPassStreak);
    console.log('  bestSingleSessionAccuracy:', (bestSingleSessionAccuracy * 100).toFixed(1) + '%');
    console.log('  perfectSessions:', perfectSessions);
    console.log('  levelsEverCleared:', [...levelsEverCleared]);
    console.log('  highestActiveLevel:', highestActiveLevel);
    console.log('  latestAttemptNumber:', latestAttemptNumber);
    console.log('  t (total_attempts):', t);
    console.log('  shots:', shots);

    // ── 6. Evaluate and award ──────────────────────────────────────────────────
    const newIds = [];
    const maybeAward = (id) => {
        if (!earned.includes(id)) {
            earned.push(id);
            newIds.push(id);
        }
    };

    if (t >= 1) maybeAward('fresh_laces');
    if (totalCrSessions >= 1) maybeAward('drop_the_biscuit');
    if (totalPassedSessions >= 1) maybeAward('clean_read');
    if (levelsEverCleared.has(1)) maybeAward('level_clear');
    if (levelsEverCleared.has(3)) maybeAward('made_the_show');
    // cr_sharp removed from catalog (too close to cr_sauce at 5 passes).
    if (scoutingReportCount >= 1) maybeAward('scouting_report');
    if (rematches >= 1) maybeAward('the_rematch');
    if (latestAttemptNumber >= 2 && summary.all_time_best_level > previousAttemptHighestLevel) {
        maybeAward('comeback_season');
    }
    if (attemptNumbersWithNewBestLevel.length >= 3) maybeAward('the_comeback_kid');
    if (levelsEverCleared.has(5)) maybeAward('ice_time_earned');
    if (levelsEverCleared.has(10)) maybeAward('team_captain');
    // cr_playoff_mode removed from catalog (fired right before cr_the_general).
    if (highestActiveLevel > 0) {
        const activeAtMax = activeChallengeIdsByLevel[highestActiveLevel] ?? new Set();
        if (activeAtMax.size > 0 && levelsEverCleared.has(highestActiveLevel)) {
            maybeAward('the_general');
        }
    }
    if (shots >= 100) maybeAward('first_bucket');
    if (shots >= 1000) maybeAward('building_a_barn');
    if (shots >= 5000) maybeAward('ten_minute_major');
    if (shots >= 10000) maybeAward('buzzer_beater');
    if (shots >= 25000) maybeAward('well_never_runs_dry');
    if (bestSingleSessionAccuracy >= 0.90) maybeAward('bar_down');
    if (bestSingleSessionAccuracy >= 0.95) maybeAward('top_cheese');
    if (perfectSessions >= 1) maybeAward('pure');
    if (perfectSessions >= 5) maybeAward('all_net');
    if (longestPassStreak >= 5) maybeAward('sauce');
    if (longestPassStreak >= 10) maybeAward('unstoppable');
    if (challengesWithPerfectRecord >= 5) maybeAward('never_missed');
    if (untouchableChallenges >= 1) maybeAward('untouchable');
    if (challengesWithSalary >= 1) maybeAward('earned_a_salary');
    if (t >= 2) maybeAward('veteran_presence');
    if (t >= 5) maybeAward('lifer');
    if (totalCrSessions >= 250) maybeAward('road_dog');
    if (totalPassedSessions >= 100) maybeAward('all_time_great');
    if (latestAttemptNumber >= 2 && latestAttemptStartingLevel < previousAttemptHighestLevel) {
        maybeAward('bender');
    }

    console.log('\nBadges to award:', newIds);
    console.log('Total earned after award:', earned);

    if (newIds.length === 0 && !hadLegacy) {
        console.log('\nNo changes needed - badges are already up to date.');
        return;
    }

    await summaryRef.set({ badges: earned }, { merge: true });
    console.log('\n✓ Wrote', earned.length, 'badges to Firestore (', newIds.length, 'new).');
}

main().catch((err) => {
    console.error('Fatal:', err);
    process.exit(1);
});

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

// Badge catalog — must stay in sync with badgeCatalog in ChallengerRoadService.dart.
// Only the IDs matter here; we just need to know which ones are valid.
const VALID_BADGE_IDS = new Set([
    'cr_fresh_laces',
    'cr_drop_the_biscuit',
    'cr_clean_read',
    'cr_level_clear',
    'cr_made_the_show',
    'cr_sharp',
    'cr_scouting_report',
    'cr_the_rematch',
    'cr_dialed_in',
    'cr_comeback_season',
    'cr_the_comeback_kid',
    'cr_ice_time_earned',
    'cr_team_captain',
    'cr_playoff_mode',
    'cr_the_general',
    'cr_first_bucket',
    'cr_building_a_barn',
    'cr_ten_minute_major',
    'cr_buzzer_beater',
    'cr_well_never_runs_dry',
    'cr_bar_down',
    'cr_top_cheese',
    'cr_pure',
    'cr_all_net',
    'cr_sauce',
    'cr_unstoppable',
    'cr_never_missed',
    'cr_untouchable',
    'cr_earned_a_salary',
    'cr_veteran_presence',
    'cr_lifer',
    'cr_road_dog',
    'cr_all_time_great',
    'cr_bender',
    // Contextually awarded — included so they're not pruned if present:
    'cr_no_warmup_needed',
    'cr_breakaway',
    'cr_freight_train',
    'cr_clean_sweep',
    'cr_barnburner_run',
    'cr_lights_out',
    'cr_battle_tested',
    'cr_game_7',
    'cr_ghosts_in_the_machine',
    'cr_old_grudge',
    'cr_redemption_arc',
    'cr_pigeon',
    'cr_sauce_boss',
    'cr_full_send',
    'cr_the_climb',
    'cr_third_period_heart',
    'cr_the_sniper',
    'cr_hall_of_famer',
    'cr_hockey_god',
    'cr_the_machine',
    'cr_all_stars',
    'cr_three_periods',
    'cr_ferda',
    'cr_career_year',
    'cr_skip_the_tryout',
    'cr_greasy_but_goes_in',
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

    if (t >= 1) maybeAward('cr_fresh_laces');
    if (totalCrSessions >= 1) maybeAward('cr_drop_the_biscuit');
    if (totalPassedSessions >= 1) maybeAward('cr_clean_read');
    if (levelsEverCleared.has(1)) maybeAward('cr_level_clear');
    if (levelsEverCleared.has(3)) maybeAward('cr_made_the_show');
    if (longestPassStreak >= 4) maybeAward('cr_sharp');
    if (scoutingReportCount >= 1) maybeAward('cr_scouting_report');
    if (rematches >= 1) maybeAward('cr_the_rematch');
    if (latestAttemptNumber >= 2 && summary.all_time_best_level > previousAttemptHighestLevel) {
        maybeAward('cr_comeback_season');
    }
    if (attemptNumbersWithNewBestLevel.length >= 3) maybeAward('cr_the_comeback_kid');
    if (levelsEverCleared.has(5)) maybeAward('cr_ice_time_earned');
    if (levelsEverCleared.has(10)) maybeAward('cr_team_captain');
    if (highestActiveLevel > 0 && (summary.all_time_best_level ?? 0) >= highestActiveLevel) {
        maybeAward('cr_playoff_mode');
    }
    if (highestActiveLevel > 0) {
        const activeAtMax = activeChallengeIdsByLevel[highestActiveLevel] ?? new Set();
        if (activeAtMax.size > 0 && levelsEverCleared.has(highestActiveLevel)) {
            maybeAward('cr_the_general');
        }
    }
    if (shots >= 100) maybeAward('cr_first_bucket');
    if (shots >= 1000) maybeAward('cr_building_a_barn');
    if (shots >= 5000) maybeAward('cr_ten_minute_major');
    if (shots >= 10000) maybeAward('cr_buzzer_beater');
    if (shots >= 25000) maybeAward('cr_well_never_runs_dry');
    if (bestSingleSessionAccuracy >= 0.90) maybeAward('cr_bar_down');
    if (bestSingleSessionAccuracy >= 0.95) maybeAward('cr_top_cheese');
    if (perfectSessions >= 1) maybeAward('cr_pure');
    if (perfectSessions >= 5) maybeAward('cr_all_net');
    if (longestPassStreak >= 5) maybeAward('cr_sauce');
    if (longestPassStreak >= 10) maybeAward('cr_unstoppable');
    if (challengesWithPerfectRecord >= 5) maybeAward('cr_never_missed');
    if (untouchableChallenges >= 1) maybeAward('cr_untouchable');
    if (challengesWithSalary >= 1) maybeAward('cr_earned_a_salary');
    if (t >= 2) maybeAward('cr_veteran_presence');
    if (t >= 5) maybeAward('cr_lifer');
    if (totalCrSessions >= 250) maybeAward('cr_road_dog');
    if (totalPassedSessions >= 100) maybeAward('cr_all_time_great');
    if (latestAttemptNumber >= 2 && latestAttemptStartingLevel < previousAttemptHighestLevel) {
        maybeAward('cr_bender');
    }

    console.log('\nBadges to award:', newIds);
    console.log('Total earned after award:', earned);

    if (newIds.length === 0 && !hadLegacy) {
        console.log('\nNo changes needed — badges are already up to date.');
        return;
    }

    await summaryRef.set({ badges: earned }, { merge: true });
    console.log('\n✓ Wrote', earned.length, 'badges to Firestore (', newIds.length, 'new).');
}

main().catch((err) => {
    console.error('Fatal:', err);
    process.exit(1);
});

#!/usr/bin/env node
/**
 * Seed the challenger_road_badges Firestore collection with display overrides.
 *
 * Each document uses the badge ID as its key and stores:
 *   - display_name:        admin-editable copy of the badge name (initially matches code)
 *   - display_description: admin-editable copy of the badge description (initially matches code)
 *   - category:            read-only reference field for the admin dashboard
 *   - tier:                read-only reference field for the admin dashboard
 *
 * Idempotent — skips any document that already exists so existing admin edits
 * are never overwritten.
 *
 * Usage (against real dev project):
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
 *     node scripts/seed_challenger_road_badges.js
 *
 * Usage (against local Firestore emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *     node scripts/seed_challenger_road_badges.js
 */

'use strict';

const admin = require('firebase-admin');

// ---------------------------------------------------------------------------
// Initialise Firebase Admin
// ---------------------------------------------------------------------------

if (!admin.apps.length) {
    if (process.env.FIRESTORE_EMULATOR_HOST) {
        admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
    } else {
        admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
    }
}

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Badge catalog — mirrors ChallengerRoadService.badgeCatalog in Dart.
// Update this list whenever badges are added or removed in the Dart source.
// ---------------------------------------------------------------------------

const BADGES = [
    // ── FIRST STEPS ──────────────────────────────────────────────────────────
    { id: 'cr_fresh_laces', name: 'Fresh Laces', description: 'Started the Challenger Road.', category: 'firstSteps', tier: 'common' },
    { id: 'cr_drop_the_biscuit', name: 'Drop the Biscuit', description: 'Completed your first challenge session.', category: 'firstSteps', tier: 'common' },
    { id: 'cr_clean_read', name: 'Clean Read', description: 'Passed your first challenge.', category: 'firstSteps', tier: 'common' },
    { id: 'cr_level_clear', name: 'Level Clear', description: 'Level 1 done.', category: 'firstSteps', tier: 'common' },
    { id: 'cr_made_the_show', name: 'Made the Show', description: 'Level 3 cleared. Not a tryout anymore.', category: 'firstSteps', tier: 'uncommon' },

    // ── WITHIN-RUN EFFICIENCY ─────────────────────────────────────────────────
    { id: 'cr_no_warmup_needed', name: 'No Warmup Needed', description: 'Cleared a full level without a single failed session.', category: 'withinRunEfficiency', tier: 'rare' },
    { id: 'cr_sharp', name: 'Sharp', description: '4 passes in a row, zero failures between them.', category: 'withinRunEfficiency', tier: 'uncommon' },
    { id: 'cr_breakaway', name: 'Breakaway', description: 'Cleared every challenge in a level in a single day.', category: 'withinRunEfficiency', tier: 'rare' },
    { id: 'cr_freight_train', name: 'Freight Train', description: 'Two levels in a row with zero failed sessions.', category: 'withinRunEfficiency', tier: 'epic' },
    { id: 'cr_clean_sweep', name: 'Clean Sweep', description: 'Every challenge in a level passed on the first try.', category: 'withinRunEfficiency', tier: 'legendary' },

    // ── CROSS-ATTEMPT IMPROVEMENT ─────────────────────────────────────────────
    { id: 'cr_scouting_report', name: 'Scouting Report', description: 'First-try pass on a challenge that took multiple tries last run.', category: 'crossAttemptImprovement', tier: 'rare' },
    { id: 'cr_the_rematch', name: 'The Rematch', description: "Passed a challenge you couldn't finish in your previous attempt.", category: 'crossAttemptImprovement', tier: 'uncommon' },
    { id: 'cr_dialed_in', name: 'Dialed In', description: 'New personal best accuracy on your hardest challenge.', category: 'crossAttemptImprovement', tier: 'epic' },
    { id: 'cr_comeback_season', name: 'Comeback Season', description: 'Reached a higher level than your previous best attempt.', category: 'crossAttemptImprovement', tier: 'rare' },
    { id: 'cr_redemption_arc', name: 'Redemption Arc', description: 'First-try pass on a challenge you failed 5+ times in a previous run.', category: 'crossAttemptImprovement', tier: 'epic' },
    { id: 'cr_the_comeback_kid', name: 'The Comeback Kid', description: 'Set a new personal best level in 3 separate attempts.', category: 'crossAttemptImprovement', tier: 'hidden' },

    // ── GRIND & RESILIENCE ────────────────────────────────────────────────────
    { id: 'cr_battle_tested', name: 'Battle Tested', description: 'Failed the same challenge 5 times in a row, then passed it.', category: 'grindAndResilience', tier: 'rare' },
    { id: 'cr_game_7', name: 'Game 7', description: "Passed the challenge you've failed more than any other.", category: 'grindAndResilience', tier: 'epic' },
    { id: 'cr_ghosts_in_the_machine', name: 'Ghosts in the Machine', description: 'Passed a challenge after 10+ all-time failures on it.', category: 'grindAndResilience', tier: 'hidden' },
    { id: 'cr_third_period_heart', name: 'Third Period Heart', description: 'Cleared a level despite 10+ failed sessions inside it.', category: 'grindAndResilience', tier: 'rare' },
    { id: 'cr_old_grudge', name: 'Old Grudge', description: 'Failed this challenge in two straight attempts — then finally passed it.', category: 'grindAndResilience', tier: 'rare' },

    // ── LEVEL ADVANCEMENT ─────────────────────────────────────────────────────
    { id: 'cr_ice_time_earned', name: 'Ice Time Earned', description: 'Level 5 cleared.', category: 'levelAdvancement', tier: 'rare' },
    { id: 'cr_team_captain', name: 'Team Captain', description: 'Level 10 cleared.', category: 'levelAdvancement', tier: 'epic' },
    { id: 'cr_the_climb', name: 'The Climb', description: 'New personal best level reached.', category: 'levelAdvancement', tier: 'common' },
    { id: 'cr_playoff_mode', name: 'Playoff Mode', description: 'Reached the highest level on the Challenger Road.', category: 'levelAdvancement', tier: 'legendary' },
    { id: 'cr_the_general', name: 'The General', description: 'Every challenge, every level — all of them.', category: 'levelAdvancement', tier: 'legendary' },

    // ── CR SHOT MILESTONES ────────────────────────────────────────────────────
    { id: 'cr_first_bucket', name: 'First Bucket', description: '100 Challenger Road shots.', category: 'crShotMilestones', tier: 'common' },
    { id: 'cr_building_a_barn', name: 'Building a Barn', description: '1,000 Challenger Road shots.', category: 'crShotMilestones', tier: 'uncommon' },
    { id: 'cr_ten_minute_major', name: 'Ten-Minute Major', description: '5,000 Challenger Road shots.', category: 'crShotMilestones', tier: 'rare' },
    { id: 'cr_buzzer_beater', name: 'Buzzer Beater', description: '10,000 Challenger Road shots.', category: 'crShotMilestones', tier: 'epic' },
    { id: 'cr_three_periods', name: 'Three Periods', description: '30,000 Challenger Road shots in one attempt.', category: 'crShotMilestones', tier: 'legendary' },
    { id: 'cr_well_never_runs_dry', name: 'The Well Never Runs Dry', description: '25,000 cumulative Challenger Road shots all-time.', category: 'crShotMilestones', tier: 'legendary' },

    // ── CR SESSION ACCURACY ───────────────────────────────────────────────────
    { id: 'cr_lights_out', name: 'Lights Out', description: 'New personal best accuracy in a session.', category: 'crSessionAccuracy', tier: 'uncommon' },
    { id: 'cr_bar_down', name: 'Bar Down', description: '90%+ accuracy in a single session.', category: 'crSessionAccuracy', tier: 'rare' },
    { id: 'cr_top_cheese', name: 'Top Cheese', description: '95%+ accuracy in a single session.', category: 'crSessionAccuracy', tier: 'epic' },
    { id: 'cr_pure', name: 'Pure', description: '100% accuracy in a session. Nothing missed.', category: 'crSessionAccuracy', tier: 'epic' },
    { id: 'cr_the_sniper', name: 'The Sniper', description: '85%+ average accuracy across a full completed level.', category: 'crSessionAccuracy', tier: 'legendary' },
    { id: 'cr_all_net', name: 'All Net', description: '5 perfect 100% accuracy sessions.', category: 'crSessionAccuracy', tier: 'legendary' },

    // ── HOT STREAKS ───────────────────────────────────────────────────────────
    { id: 'cr_sauce', name: 'Sauce', description: '5 passes in a row, no failures in between.', category: 'hotStreaks', tier: 'rare' },
    { id: 'cr_unstoppable', name: 'Unstoppable', description: '10 passes in a row, no failures in between.', category: 'hotStreaks', tier: 'epic' },
    { id: 'cr_full_send', name: 'Full Send', description: 'Best accuracy AND highest shot volume in the same session.', category: 'hotStreaks', tier: 'epic' },

    // ── CHALLENGE MASTERY ─────────────────────────────────────────────────────
    { id: 'cr_never_missed', name: 'Never Missed', description: "5+ challenges you've never once failed.", category: 'challengeMastery', tier: 'hidden' },
    { id: 'cr_untouchable', name: 'Untouchable', description: 'First-try pass on the same challenge in 5+ separate runs.', category: 'challengeMastery', tier: 'hidden' },
    { id: 'cr_earned_a_salary', name: 'Earned a Salary', description: '25 all-time passes on a single challenge.', category: 'challengeMastery', tier: 'epic' },

    // ── MULTI-ATTEMPT / CAREER ────────────────────────────────────────────────
    { id: 'cr_veteran_presence', name: 'Veteran Presence', description: 'Started a second Challenger Road attempt.', category: 'multiAttemptCareer', tier: 'uncommon' },
    { id: 'cr_lifer', name: 'Lifer', description: "5 Challenger Road attempts. It's just your thing now.", category: 'multiAttemptCareer', tier: 'epic' },
    { id: 'cr_career_year', name: 'Career Year', description: 'Hit 10,000 shots AND a new personal best level in the same attempt.', category: 'multiAttemptCareer', tier: 'epic' },
    { id: 'cr_road_dog', name: 'Road Dog', description: '250 total sessions on the Challenger Road.', category: 'multiAttemptCareer', tier: 'epic' },
    { id: 'cr_all_time_great', name: 'All-Time Great', description: '100 total challenge passes across all attempts.', category: 'multiAttemptCareer', tier: 'legendary' },

    // ── ELITE / ENDGAME ───────────────────────────────────────────────────────
    { id: 'cr_hall_of_famer', name: 'Hall of Famer', description: 'Completed the full Challenger Road in a single attempt.', category: 'eliteEndgame', tier: 'legendary' },
    { id: 'cr_the_machine', name: 'The Machine', description: '80%+ average accuracy across 3 complete attempts.', category: 'eliteEndgame', tier: 'legendary' },
    { id: 'cr_hockey_god', name: 'Hockey God', description: 'Completed the full road with zero failed sessions.', category: 'eliteEndgame', tier: 'hidden' },

    // ── CHIRPY / PERSONALITY ──────────────────────────────────────────────────
    { id: 'cr_bender', name: 'Bender', description: 'Started a new attempt at a lower level than your previous best.', category: 'chirpy', tier: 'common' },
    { id: 'cr_pigeon', name: 'Pigeon', description: 'First-try pass at 95%+ accuracy on a hard challenge.', category: 'chirpy', tier: 'uncommon' },
    { id: 'cr_ferda', name: 'Ferda', description: 'Hit 10,000 shots and kept going.', category: 'chirpy', tier: 'uncommon' },
    { id: 'cr_sauce_boss', name: 'Sauce Boss', description: 'New personal best accuracy on a harder Challenger Road challenge.', category: 'chirpy', tier: 'rare' },
    { id: 'cr_skip_the_tryout', name: 'Skip the Tryout', description: 'Started a new attempt at a higher level using unlocks from a previous run.', category: 'chirpy', tier: 'common' },
    { id: 'cr_all_stars', name: 'All Stars', description: 'Completed the full road from Level 1 — even though you had levels unlocked to skip.', category: 'eliteEndgame', tier: 'hidden' },
];

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

async function seed() {
    const col = db.collection('challenger_road_badges');
    let created = 0;
    let skipped = 0;

    for (const badge of BADGES) {
        const docRef = col.doc(badge.id);
        const snap = await docRef.get();

        if (snap.exists) {
            console.log(`  SKIP  ${badge.id} (already exists)`);
            skipped++;
            continue;
        }

        await docRef.set({
            display_name: badge.name,
            display_description: badge.description,
            // Reference fields — purely informational for the admin dashboard.
            // These are never read by the Flutter app's award logic.
            category: badge.category,
            tier: badge.tier,
        });

        console.log(`  CREATE ${badge.id}`);
        created++;
    }

    console.log(`\nDone. Created: ${created}  Skipped (already exist): ${skipped}`);
}

seed().catch((err) => {
    console.error(err);
    process.exit(1);
});

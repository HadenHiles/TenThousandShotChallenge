#!/usr/bin/env node
/**
 * Seed the challenger_road_badges Firestore collection with display overrides.
 *
 * Each document uses the badge ID as its key and stores:
 *   - display_name:        admin-editable copy of the badge name (initially matches code)
 *   - display_description: admin-editable copy of the badge description (initially matches code)
 *   - display_icon:        admin-editable Material icon key used by Flutter UI
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
    { id: 'fresh_laces', name: 'Fresh Laces', description: 'Started the Challenger Road.', category: 'firstSteps', tier: 'common' },
    { id: 'drop_the_biscuit', name: 'Drop the Biscuit', description: 'Completed your first challenge session.', category: 'firstSteps', tier: 'common' },
    { id: 'clean_read', name: 'Clean Read', description: 'Passed your first challenge.', category: 'firstSteps', tier: 'common' },
    { id: 'level_clear', name: 'Level Clear', description: 'Level 1 done.', category: 'firstSteps', tier: 'common' },
    { id: 'made_the_show', name: 'Made the Show', description: 'Level 3 cleared. Not a tryout anymore.', category: 'firstSteps', tier: 'uncommon' },

    // ── WITHIN-RUN EFFICIENCY ─────────────────────────────────────────────────
    { id: 'no_warmup_needed', name: 'No Warmup Needed', description: 'Cleared a full level without a single failed session.', category: 'withinRunEfficiency', tier: 'rare' },
    // cr_sharp removed (too close to cr_sauce at 5 passes).
    { id: 'breakaway', name: 'Breakaway', description: 'Cleared every challenge in a level in a single day.', category: 'withinRunEfficiency', tier: 'rare' },
    { id: 'freight_train', name: 'Freight Train', description: 'Two levels in a row with zero failed sessions.', category: 'withinRunEfficiency', tier: 'epic' },
    { id: 'clean_sweep', name: 'Clean Sweep', description: 'Every challenge in a level passed on the first try.', category: 'withinRunEfficiency', tier: 'legendary' },

    // ── CROSS-ATTEMPT IMPROVEMENT ─────────────────────────────────────────────
    { id: 'scouting_report', name: 'Scouting Report', description: 'First-try pass on a challenge that took multiple tries last run.', category: 'crossAttemptImprovement', tier: 'rare' },
    { id: 'the_rematch', name: 'The Rematch', description: "Passed a challenge you couldn't finish in your previous attempt.", category: 'crossAttemptImprovement', tier: 'uncommon' },
    { id: 'dialed_in', name: 'Dialed In', description: 'New personal best accuracy on your hardest challenge.', category: 'crossAttemptImprovement', tier: 'epic' },
    { id: 'comeback_season', name: 'Comeback Season', description: 'Reached a higher level than your previous best attempt.', category: 'crossAttemptImprovement', tier: 'rare' },
    { id: 'redemption_arc', name: 'Redemption Arc', description: 'First-try pass on a challenge you failed 5+ times in a previous run.', category: 'crossAttemptImprovement', tier: 'epic' },
    { id: 'the_comeback_kid', name: 'The Comeback Kid', description: 'Set a new personal best level in 3 separate attempts.', category: 'crossAttemptImprovement', tier: 'epic' },

    // ── GRIND & RESILIENCE ────────────────────────────────────────────────────
    { id: 'battle_tested', name: 'Battle Tested', description: 'Failed the same challenge 5 times in a row, then passed it.', category: 'grindAndResilience', tier: 'rare' },
    { id: 'game_7', name: 'Game 7', description: "Passed the challenge you've failed more than any other.", category: 'grindAndResilience', tier: 'epic' },
    { id: 'third_period_heart', name: 'Third Period Heart', description: 'Cleared a level despite 10+ failed sessions inside it.', category: 'grindAndResilience', tier: 'rare' },
    { id: 'old_grudge', name: 'Old Grudge', description: 'Failed this challenge in two straight attempts — then finally passed it.', category: 'grindAndResilience', tier: 'rare' },

    // ── LEVEL ADVANCEMENT ─────────────────────────────────────────────────────
    { id: 'ice_time_earned', name: 'Ice Time Earned', description: 'Level 5 cleared.', category: 'levelAdvancement', tier: 'rare' },
    { id: 'team_captain', name: 'Team Captain', description: 'Level 10 cleared.', category: 'levelAdvancement', tier: 'epic' },
    { id: 'the_climb', name: 'The Climb', description: 'New personal best level reached.', category: 'levelAdvancement', tier: 'common' },
    { id: 'the_general', name: 'The General', description: 'Cleared every challenge at the current highest active level.', category: 'levelAdvancement', tier: 'legendary' },

    // ── CR SHOT MILESTONES ────────────────────────────────────────────────────
    { id: 'first_bucket', name: 'First Bucket', description: '100 Challenger Road shots.', category: 'crShotMilestones', tier: 'common' },
    { id: 'building_a_barn', name: 'Building a Barn', description: '1,000 Challenger Road shots.', category: 'crShotMilestones', tier: 'uncommon' },
    { id: 'ten_minute_major', name: 'Ten-Minute Major', description: '5,000 Challenger Road shots.', category: 'crShotMilestones', tier: 'rare' },
    { id: 'buzzer_beater', name: 'Buzzer Beater', description: '10,000 Challenger Road shots.', category: 'crShotMilestones', tier: 'epic' },
    { id: 'three_periods', name: 'Three Periods', description: '30,000 Challenger Road shots in one attempt.', category: 'crShotMilestones', tier: 'legendary' },
    { id: 'well_never_runs_dry', name: 'The Well Never Runs Dry', description: '25,000 cumulative Challenger Road shots all-time.', category: 'crShotMilestones', tier: 'legendary' },

    // ── CR SESSION ACCURACY ───────────────────────────────────────────────────
    { id: 'lights_out', name: 'Lights Out', description: 'New personal best accuracy on a levels 1–4 challenge.', category: 'crSessionAccuracy', tier: 'uncommon' },
    { id: 'bar_down', name: 'Bar Down', description: '90%+ accuracy in a single session.', category: 'crSessionAccuracy', tier: 'rare' },
    { id: 'top_cheese', name: 'Top Cheese', description: '95%+ accuracy in a single session.', category: 'crSessionAccuracy', tier: 'epic' },
    { id: 'pure', name: 'Pure', description: '100% accuracy in a session. Nothing missed.', category: 'crSessionAccuracy', tier: 'epic' },
    { id: 'the_sniper', name: 'The Sniper', description: '85%+ average accuracy across a full completed level.', category: 'crSessionAccuracy', tier: 'legendary' },
    { id: 'all_net', name: 'All Net', description: '5 perfect 100% accuracy sessions.', category: 'crSessionAccuracy', tier: 'legendary' },

    // ── HOT STREAKS ───────────────────────────────────────────────────────────
    { id: 'sauce', name: 'Sauce', description: '5 passes in a row, no failures in between.', category: 'hotStreaks', tier: 'rare' },
    { id: 'unstoppable', name: 'Unstoppable', description: '10 passes in a row, no failures in between.', category: 'hotStreaks', tier: 'epic' },
    { id: 'full_send', name: 'Full Send', description: 'Best accuracy AND highest shot volume in the same session.', category: 'hotStreaks', tier: 'epic' },

    // ── CHALLENGE MASTERY ─────────────────────────────────────────────────────
    { id: 'never_missed', name: 'Never Missed', description: "5+ challenges you've never once failed.", category: 'challengeMastery', tier: 'hidden' },
    { id: 'untouchable', name: 'Untouchable', description: 'First-try pass on the same challenge in 5+ separate runs.', category: 'challengeMastery', tier: 'hidden' },
    { id: 'earned_a_salary', name: 'Earned a Salary', description: '25 all-time passes on a single challenge.', category: 'challengeMastery', tier: 'epic' },

    // ── MULTI-ATTEMPT / CAREER ────────────────────────────────────────────────
    { id: 'veteran_presence', name: 'Veteran Presence', description: 'Started a second Challenger Road attempt.', category: 'multiAttemptCareer', tier: 'uncommon' },
    { id: 'lifer', name: 'Lifer', description: "5 Challenger Road attempts. It's just your thing now.", category: 'multiAttemptCareer', tier: 'epic' },
    { id: 'career_year', name: 'Career Year', description: 'Hit 10,000 shots AND a new personal best level in the same attempt.', category: 'multiAttemptCareer', tier: 'epic' },
    { id: 'road_dog', name: 'Road Dog', description: '250 total sessions on the Challenger Road.', category: 'multiAttemptCareer', tier: 'epic' },
    { id: 'all_time_great', name: 'All-Time Great', description: '100 total challenge passes across all attempts.', category: 'multiAttemptCareer', tier: 'legendary' },

    // ── ELITE / ENDGAME ───────────────────────────────────────────────────────
    { id: 'hall_of_famer', name: 'Hall of Famer', description: 'Completed every active Challenger Road level in one attempt.', category: 'eliteEndgame', tier: 'legendary' },
    { id: 'the_machine', name: 'The Machine', description: 'Completed 3+ attempts with 80%+ average accuracy in each completed attempt.', category: 'eliteEndgame', tier: 'legendary' },
    { id: 'hockey_god', name: 'Hockey God', description: 'Completed every active level in one attempt with zero failed sessions.', category: 'eliteEndgame', tier: 'hidden' },

    // ── CHIRPY / PERSONALITY ──────────────────────────────────────────────────
    { id: 'bender', name: 'Bender', description: 'Started a new attempt at a lower level than your previous best.', category: 'chirpy', tier: 'common' },
    { id: 'pigeon', name: 'Pigeon', description: 'First-try pass at 95%+ accuracy on a hard challenge.', category: 'chirpy', tier: 'uncommon' },
    { id: 'sauce_boss', name: 'Sauce Boss', description: 'New personal best accuracy on a harder Challenger Road challenge.', category: 'chirpy', tier: 'rare' },
    { id: 'skip_the_tryout', name: 'Skip the Tryout', description: 'Started a new attempt at a higher level using unlocks from a previous run.', category: 'chirpy', tier: 'common' },
    { id: 'all_stars', name: 'All Stars', description: 'Had unlocked skips available, started at Level 1, and completed every active level in one attempt.', category: 'eliteEndgame', tier: 'legendary' },
];

const CATEGORY_ICON = {
    firstSteps: 'route_rounded',
    withinRunEfficiency: 'bolt_rounded',
    crossAttemptImprovement: 'trending_up_rounded',
    grindAndResilience: 'shield_rounded',
    levelAdvancement: 'stairs_rounded',
    crShotMilestones: 'workspace_premium_rounded',
    crSessionAccuracy: 'gps_fixed_rounded',
    hotStreaks: 'local_fire_department_rounded',
    challengeMastery: 'emoji_events_rounded',
    multiAttemptCareer: 'repeat_rounded',
    eliteEndgame: 'military_tech_rounded',
    chirpy: 'sports_hockey_rounded',
};

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
            display_icon: CATEGORY_ICON[badge.category] || 'sports_hockey_rounded',
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

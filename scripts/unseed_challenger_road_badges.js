#!/usr/bin/env node
/**
 * Remove all seeded challenger_road_badges documents from Firestore.
 *
 * Only deletes documents whose IDs are present in the known badge catalog
 * below - will not blindly wipe the entire collection in case you have
 * added custom admin-only documents.
 *
 * Usage (against real dev project):
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
 *     node scripts/unseed_challenger_road_badges.js
 *
 * Usage (against local Firestore emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *     node scripts/unseed_challenger_road_badges.js
 */

'use strict';

const admin = require('firebase-admin');

if (!admin.apps.length) {
    if (process.env.FIRESTORE_EMULATOR_HOST) {
        admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
    } else {
        admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
    }
}

const db = admin.firestore();

const BADGE_IDS = [
    'fresh_laces', 'drop_the_biscuit', 'clean_read', 'level_clear', 'made_the_show',
    'no_warmup_needed', 'sharp', 'breakaway', 'freight_train', 'clean_sweep',
    'scouting_report', 'the_rematch', 'dialed_in', 'comeback_season', 'redemption_arc', 'the_comeback_kid',
    'battle_tested', 'game_7', 'ghosts_in_the_machine', 'third_period_heart', 'old_grudge',
    'ice_time_earned', 'team_captain', 'the_climb', 'playoff_mode', 'the_general',
    'first_bucket', 'building_a_barn', 'ten_minute_major', 'buzzer_beater', 'three_periods', 'well_never_runs_dry',
    'lights_out', 'bar_down', 'top_cheese', 'pure', 'the_sniper', 'all_net',
    'sauce', 'unstoppable', 'full_send',
    'never_missed', 'untouchable', 'earned_a_salary',
    'veteran_presence', 'lifer', 'career_year', 'road_dog', 'all_time_great',
    'hall_of_famer', 'the_machine', 'hockey_god',
    'bender', 'pigeon', 'sauce_boss', 'skip_the_tryout', 'all_stars',
];

async function unseed() {
    const col = db.collection('challenger_road_badges');
    let deleted = 0;
    let missing = 0;

    for (const id of BADGE_IDS) {
        const docRef = col.doc(id);
        const snap = await docRef.get();
        if (!snap.exists) {
            console.log(`  MISS  ${id} (not found)`);
            missing++;
            continue;
        }
        await docRef.delete();
        console.log(`  DELETE ${id}`);
        deleted++;
    }

    console.log(`\nDone. Deleted: ${deleted}  Not found: ${missing}`);
}

unseed().catch((err) => {
    console.error(err);
    process.exit(1);
});

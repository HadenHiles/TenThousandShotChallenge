#!/usr/bin/env node
/**
 * Remove all seeded challenger_road_badges documents from Firestore.
 *
 * Only deletes documents whose IDs are present in the known badge catalog
 * below — will not blindly wipe the entire collection in case you have
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
    'cr_fresh_laces', 'cr_drop_the_biscuit', 'cr_clean_read', 'cr_level_clear', 'cr_made_the_show',
    'cr_no_warmup_needed', 'cr_sharp', 'cr_breakaway', 'cr_freight_train', 'cr_clean_sweep',
    'cr_scouting_report', 'cr_the_rematch', 'cr_dialed_in', 'cr_comeback_season', 'cr_redemption_arc', 'cr_the_comeback_kid',
    'cr_battle_tested', 'cr_game_7', 'cr_ghosts_in_the_machine', 'cr_third_period_heart', 'cr_old_grudge',
    'cr_ice_time_earned', 'cr_team_captain', 'cr_the_climb', 'cr_playoff_mode', 'cr_the_general',
    'cr_first_bucket', 'cr_building_a_barn', 'cr_ten_minute_major', 'cr_buzzer_beater', 'cr_three_periods', 'cr_well_never_runs_dry',
    'cr_lights_out', 'cr_bar_down', 'cr_top_cheese', 'cr_pure', 'cr_the_sniper', 'cr_all_net',
    'cr_sauce', 'cr_unstoppable', 'cr_full_send',
    'cr_never_missed', 'cr_untouchable', 'cr_earned_a_salary',
    'cr_veteran_presence', 'cr_lifer', 'cr_career_year', 'cr_road_dog', 'cr_all_time_great',
    'cr_hall_of_famer', 'cr_the_machine', 'cr_hockey_god',
    'cr_bender', 'cr_pigeon', 'cr_sauce_boss', 'cr_skip_the_tryout', 'cr_all_stars',
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

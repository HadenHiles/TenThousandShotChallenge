#!/usr/bin/env node
/**
 * Seed the 50 new accuracy trophy definitions directly into
 * `challenger_road_badges` (the active collection) with type='global'.
 *
 * The old `seed_global_trophy_definitions.js` wrote to the now-deprecated
 * `global_trophy_definitions` collection. After the migration, all global
 * trophies live in `challenger_road_badges` with type='global'. This script
 * seeds only the new accuracy trophies into that collection.
 *
 * Idempotent – documents that already exist are skipped so re-running is safe.
 *
 * Usage (against real project – ADC / service-account):
 *   node scripts/seed_new_accuracy_trophies.js
 *
 * Usage (against local Firestore emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *     node scripts/seed_new_accuracy_trophies.js
 */

'use strict';

const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
}

const db = admin.firestore();

const CATEGORY_ICON = {
    accuracy: 'track_changes',
};

// ---------------------------------------------------------------------------
// New accuracy trophies only (50 total - 12 common, 13 uncommon, 6 rare,
// 8 epic, 11 legendary). These are additions to the 14 trophies already
// in Firestore from the original migration.
// ---------------------------------------------------------------------------
const NEW_ACCURACY_TROPHIES = [
    // ── Common ───────────────────────────────────────────────────────────────
    { id: 'g_accuracy_first_session', name: 'Eyes on the Net', description: 'Finished a session with accuracy tracked. The numbers don\'t lie.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_overall_accuracy_50', name: 'Showing Up', description: '50%+ overall accuracy in a session with 10+ shots. A start is a start.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_overall_accuracy_60', name: 'Above Average', description: '60%+ overall accuracy in a session with 25+ shots. You\'re finding it.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_wrist_accuracy_50', name: 'Wrist in Check', description: '50%+ wrist accuracy in a session (10+ wrist shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_snap_accuracy_50', name: 'Snap Study', description: '50%+ snap accuracy in a session (10+ snap shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_slap_accuracy_50', name: 'Slap Starter', description: "35%+ slap accuracy in a session (10+ slap shots). Slap shots are twice as hard \u2014 getting a third on target is real.", category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_backhand_accuracy_50', name: 'Backhand Basics', description: '50%+ backhand accuracy in a session (10+ backhand shots). Off-hand, on target.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_wrist_accuracy_60', name: 'Wrist Warm', description: '60%+ wrist accuracy in a session (15+ wrist shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_snap_accuracy_60', name: 'Finding the Snap', description: '60%+ snap accuracy in a session (15+ snap shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_slap_accuracy_60', name: 'Controlled Chaos', description: '45%+ slap accuracy in a session (15+ slap shots). Not all bombs are wild.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_backhand_accuracy_60', name: 'Off-Hand Progress', description: '60%+ backhand accuracy in a session (15+ backhand shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_all_types_accuracy_50', name: 'Dabbler', description: '50%+ accuracy on every shot type in a session (10+ each). No glaring weakness.', category: 'accuracy', tier: 'common', proOnly: true },

    // ── Uncommon ─────────────────────────────────────────────────────────────
    { id: 'g_overall_accuracy_65', name: 'Dialed', description: '65%+ overall accuracy in a session with 30+ shots. Getting there.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_wrist_accuracy_70', name: 'Wrist Work', description: '70%+ wrist accuracy in a session (20+ wrist shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_snap_accuracy_70', name: 'Snap Sharp', description: '70%+ snap accuracy in a session (20+ snap shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_slap_accuracy_70', name: 'Locked In', description: '55%+ slap accuracy in a session (15+ slap shots). That bomb has a target.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_backhand_accuracy_70', name: 'Wrong Side Right', description: '70%+ backhand accuracy in a session (20+ backhand shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_accuracy_streak_2', name: 'Back-to-Back Accuracy', description: '65%+ overall accuracy in 2 consecutive sessions.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_accuracy_streak_3', name: 'Hat Trick Accuracy', description: '70%+ overall accuracy in 3 consecutive sessions.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_all_types_accuracy_60', name: 'All Around', description: '60%+ accuracy on every shot type in a session (10+ each).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_all_types_accuracy_70', name: 'No Weak Angle', description: '70%+ accuracy on every shot type in a session (15+ each). Defenders have no read.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_wrist_accuracy_75', name: 'Wrist Precision', description: '75%+ wrist accuracy in a session (20+ wrist shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_snap_accuracy_75', name: 'Snap Precision', description: '75%+ snap accuracy in a session (20+ snap shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_slap_accuracy_75', name: 'Slap Precision', description: '60%+ slap accuracy in a session (15+ slap shots). Rare power and precision.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_backhand_accuracy_75', name: 'Backhand Precision', description: '75%+ backhand accuracy in a session (20+ backhand shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },

    // ── Rare ─────────────────────────────────────────────────────────────────
    { id: 'g_overall_accuracy_80', name: 'Sharp Shooter', description: '80%+ overall accuracy in a session with 50+ shots.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_accuracy_streak_4', name: 'On a Roll', description: '70%+ overall accuracy in 4 consecutive sessions.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_wrist_accuracy_85', name: 'Wrist Expert', description: '85%+ wrist accuracy in a session (25+ wrist shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_snap_accuracy_85', name: 'Snap Expert', description: '85%+ snap accuracy in a session (25+ snap shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_slap_accuracy_85', name: 'Slap Expert', description: '70%+ slap accuracy in a session (20+ slap shots). Pinpoint power.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_backhand_accuracy_85', name: 'Backhand Expert', description: '85%+ backhand accuracy in a session (25+ backhand shots).', category: 'accuracy', tier: 'rare', proOnly: true },

    // ── Epic ─────────────────────────────────────────────────────────────────
    { id: 'g_overall_accuracy_85', name: 'Sniper Mentality', description: '85%+ overall accuracy in a session with 50+ shots.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_overall_accuracy_90', name: 'Accuracy Freak', description: '90%+ overall accuracy in a session with 50+ shots. Almost nothing misses.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_all_types_accuracy_85', name: 'Full Arsenal', description: '85%+ accuracy on every shot type in a session (25+ each).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_all_types_accuracy_90', name: 'Complete Control', description: '90%+ accuracy on every shot type in a session (25+ each). All cylinders, all accurate.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_wrist_accuracy_95', name: 'Wrist Surgeon', description: '95%+ wrist accuracy in a session (25+ wrist shots). That release is a weapon.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_snap_accuracy_95', name: 'Snap Surgeon', description: '95%+ snap accuracy in a session (25+ snap shots).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_slap_accuracy_95', name: 'Slap Surgeon', description: '80%+ slap accuracy in a session (20+ slap shots). The bomb is now guided.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_backhand_accuracy_95', name: 'Backhand Surgeon', description: '95%+ backhand accuracy in a session (25+ backhand shots). Two hands, one killer instinct.', category: 'accuracy', tier: 'epic', proOnly: true },

    // ── Legendary ────────────────────────────────────────────────────────────
    { id: 'g_accuracy_streak_15', name: 'Reliable', description: '70%+ overall accuracy in 15 consecutive sessions. Session after session.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_accuracy_streak_20', name: 'Built Different', description: '70%+ overall accuracy in 20 consecutive sessions. Consistency is the skill.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_overall_accuracy_95', name: 'Nearly Impossible', description: '95%+ overall accuracy in a session with 50+ shots. This barely happens.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_perfect_session_75', name: 'No Mercy', description: '100% accuracy in a session with 75+ total shots. Technically flawless.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_perfect_session_100', name: 'Perfect Century', description: '100% accuracy in a session with 100+ total shots. Nothing touched the post.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_wrist_perfect', name: 'Wrist of God', description: '100% wrist accuracy in a session with 25+ wrist shots. Zero misses. Actual zero.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_snap_perfect', name: 'Snap of God', description: '100% snap accuracy in a session with 25+ snap shots.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_slap_perfect', name: 'Bomb Perfect', description: '100% slap accuracy in a session with 20+ slap shots. Full power. Full precision. Nothing missed.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_backhand_perfect', name: 'Backhand of God', description: '100% backhand accuracy in a session with 25+ backhand shots. Two hands, zero misses.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_all_types_accuracy_95', name: 'Zero Margin', description: '95%+ accuracy on every shot type in a session (25+ each). Nothing leaks.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_all_types_perfect', name: 'Total Control', description: '100% accuracy on every shot type in a single session (25+ each). The game doesn\'t stand a chance.', category: 'accuracy', tier: 'legendary', proOnly: true },
];

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

async function seed() {
    const colRef = db.collection('challenger_road_badges');

    // Fetch only existing global trophies to avoid collisions with CR badges
    const snap = await colRef.where('type', '==', 'global').get();
    const existingIds = new Set(snap.docs.map((d) => d.id));

    const missing = NEW_ACCURACY_TROPHIES.filter((t) => !existingIds.has(t.id));
    if (missing.length === 0) {
        console.log('All new accuracy trophies already exist in challenger_road_badges - nothing to seed.');
        return;
    }

    console.log(`Seeding ${missing.length} new accuracy trophy definition(s) into challenger_road_badges…`);

    // Firestore batch limit is 500 ops; 50 trophies fits easily.
    const batch = db.batch();
    for (const trophy of missing) {
        const ref = colRef.doc(trophy.id);
        batch.set(ref, {
            type: 'global',
            display_name: trophy.name,
            display_description: trophy.description,
            default_icon: CATEGORY_ICON[trophy.category],
            category: trophy.category,
            tier: trophy.tier,
            pro_only: trophy.proOnly,
            icon_url: null,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
    }

    await batch.commit();
    console.log(`✓ Seeded ${missing.length} accuracy trophy definition(s) into challenger_road_badges.`);
    console.log('');
    console.log('Summary by tier:');
    const byTier = {};
    for (const t of missing) {
        byTier[t.tier] = (byTier[t.tier] || 0) + 1;
    }
    for (const [tier, count] of Object.entries(byTier).sort()) {
        console.log(`  ${tier}: ${count}`);
    }
}

seed().catch((err) => {
    console.error('Seed failed:', err);
    process.exit(1);
});

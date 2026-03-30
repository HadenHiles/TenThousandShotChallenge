#!/usr/bin/env node
/**
 * Seed Challenger Road test data into Firestore.
 *
 * Creates 5 challenges × up to 3 levels = 14 challenge/level combinations.
 * "One-Timer Challenge" intentionally has NO Level 1 doc to test that
 * the map correctly hides it at Level 1 and only shows it at Level 2+.
 * "Snap Shot Precision" Level 2 has its own step overrides to test
 * the level-specific step fallback logic.
 *
 * Idempotent — skips any document that already exists.
 *
 * Usage (against real dev project):
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
 *     node scripts/seed_challenger_road.js
 *
 * Usage (against local Firestore emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *     node scripts/seed_challenger_road.js
 */

'use strict';

const admin = require('firebase-admin');

// ---------------------------------------------------------------------------
// Initialise Firebase Admin
// ---------------------------------------------------------------------------

if (!admin.apps.length) {
    if (process.env.FIRESTORE_EMULATOR_HOST) {
        // Emulator — no credentials needed.
        admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
    } else {
        // Real project — accepts either:
        //   1. GOOGLE_APPLICATION_CREDENTIALS pointing to a service account JSON, OR
        //   2. Application Default Credentials (run `firebase login` first).
        admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
    }
}

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Placeholder media (no Firebase Storage setup required for dev)
// ---------------------------------------------------------------------------

const IMG = 'https://placehold.co/600x400/1a1a2e/ffffff?text=Challenge+Step';
const IMG_OVERRIDE = 'https://placehold.co/600x400/0f3460/ffffff?text=Level+Override+Step';

// ---------------------------------------------------------------------------
// Challenge data
// ---------------------------------------------------------------------------

const CHALLENGES = [
    // ── Challenge 1 ──────────────────────────────────────────────────────────
    {
        id: 'seed_challenge_1',
        name: 'Wrist Shot Warmup',
        description:
            'Build muscle memory and wrist control with a focused set of wrist shots from the slot.',
        active: true,
        steps: [
            {
                step_number: 1,
                title: 'Setup',
                media_type: 'image',
                media_url: IMG,
                summary: 'Place 10 pucks on the dot, approximately 15 feet from the net.',
            },
            {
                step_number: 2,
                title: 'Follow Through',
                media_type: 'image',
                media_url: IMG,
                summary:
                    'Load your weight onto your back foot, then transfer forward as you snap your wrists. Point the blade at your target.',
            },
            {
                step_number: 3,
                title: 'Reset & Repeat',
                media_type: 'image',
                media_url: IMG,
                summary: 'Retrieve pucks and repeat from the same spot, keeping consistent form.',
            },
        ],
        levels: [
            { id: 'level_1', level: 1, level_name: 'Level 1', sequence: 1, shots_required: 10, shots_to_pass: 6, active: true, steps: null },
            { id: 'level_2', level: 2, level_name: 'Level 2', sequence: 1, shots_required: 15, shots_to_pass: 10, active: true, steps: null },
            { id: 'level_3', level: 3, level_name: 'Level 3', sequence: 1, shots_required: 20, shots_to_pass: 14, active: true, steps: null },
        ],
    },

    // ── Challenge 2 ──────────────────────────────────────────────────────────
    {
        id: 'seed_challenge_2',
        name: 'Snap Shot Precision',
        description:
            'Improve accuracy and release speed with snap shots from the top of the circles.',
        active: true,
        steps: [
            {
                step_number: 1,
                title: 'Positioning',
                media_type: 'image',
                media_url: IMG,
                summary: 'Stand at the top of the left or right circle. Keep your feet shoulder-width apart.',
            },
            {
                step_number: 2,
                title: 'Quick Release',
                media_type: 'image',
                media_url: IMG,
                summary:
                    'Snap your bottom hand down quickly while keeping the puck close to your body before releasing.',
            },
        ],
        levels: [
            { id: 'level_1', level: 1, level_name: 'Level 1', sequence: 2, shots_required: 10, shots_to_pass: 6, active: true, steps: null },
            {
                // Level 2 has its own step overrides — tests the fallback logic.
                id: 'level_2',
                level: 2,
                level_name: 'Level 2',
                sequence: 2,
                shots_required: 15,
                shots_to_pass: 10,
                active: true,
                steps: [
                    {
                        step_number: 1,
                        title: 'Advanced Positioning (Level 2)',
                        media_type: 'image',
                        media_url: IMG_OVERRIDE,
                        summary: 'Move to the high slot. Receive a pass and shoot in one motion.',
                    },
                    {
                        step_number: 2,
                        title: 'One-Touch Release (Level 2)',
                        media_type: 'image',
                        media_url: IMG_OVERRIDE,
                        summary: 'The puck should leave your stick within 0.5 seconds of receiving the pass.',
                    },
                ],
            },
            { id: 'level_3', level: 3, level_name: 'Level 3', sequence: 2, shots_required: 20, shots_to_pass: 14, active: true, steps: null },
        ],
    },

    // ── Challenge 3 ──────────────────────────────────────────────────────────
    {
        id: 'seed_challenge_3',
        name: 'Backhand Basics',
        description:
            'Develop a reliable backhand shot that goalies can\'t read by building consistent technique.',
        active: true,
        steps: [
            {
                step_number: 1,
                title: 'Blade Positioning',
                media_type: 'image',
                media_url: IMG,
                summary: 'Cup the puck on the backhand side. Keep it slightly toward the heel of the blade.',
            },
            {
                step_number: 2,
                title: 'Hip & Wrist Rotation',
                media_type: 'image',
                media_url: IMG,
                summary: 'Rotate your hips toward the net. Flick your wrists upward to lift the puck.',
            },
        ],
        levels: [
            { id: 'level_1', level: 1, level_name: 'Level 1', sequence: 3, shots_required: 10, shots_to_pass: 6, active: true, steps: null },
            { id: 'level_2', level: 2, level_name: 'Level 2', sequence: 3, shots_required: 15, shots_to_pass: 10, active: true, steps: null },
            { id: 'level_3', level: 3, level_name: 'Level 3', sequence: 3, shots_required: 20, shots_to_pass: 14, active: true, steps: null },
        ],
    },

    // ── Challenge 4 ──────────────────────────────────────────────────────────
    {
        id: 'seed_challenge_4',
        name: 'Slap Shot Power',
        description:
            'Load up and rip it. Train your slap shot mechanics to generate maximum power while staying accurate.',
        active: true,
        steps: [
            {
                step_number: 1,
                title: 'Wind Up',
                media_type: 'image',
                media_url: IMG,
                summary: 'Raise your stick to hip or shoulder height. Keep your eyes on the puck, not the net.',
            },
            {
                step_number: 2,
                title: 'Impact & Follow Through',
                media_type: 'image',
                media_url: IMG,
                summary:
                    'Strike the ice just behind the puck to flex the shaft. Finish with your stick pointing at your target.',
            },
        ],
        levels: [
            { id: 'level_1', level: 1, level_name: 'Level 1', sequence: 4, shots_required: 10, shots_to_pass: 6, active: true, steps: null },
            { id: 'level_2', level: 2, level_name: 'Level 2', sequence: 4, shots_required: 15, shots_to_pass: 10, active: true, steps: null },
            { id: 'level_3', level: 3, level_name: 'Level 3', sequence: 4, shots_required: 20, shots_to_pass: 14, active: true, steps: null },
        ],
    },

    // ── Challenge 5 ──────────────────────────────────────────────────────────
    // Intentionally has NO Level 1 doc. Tests that the map hides it at Level 1.
    {
        id: 'seed_challenge_5',
        name: 'One-Timer Challenge',
        description:
            'Step it up with one-timers. Receive a cross-ice pass and rip a shot without stopping the puck.',
        active: true,
        steps: [
            {
                step_number: 1,
                title: 'Reading the Pass',
                media_type: 'image',
                media_url: IMG,
                summary:
                    'Keep your stick on the ice and your body open to the pass. Track the puck all the way onto your blade.',
            },
            {
                step_number: 2,
                title: 'Timing the Shot',
                media_type: 'image',
                media_url: IMG,
                summary:
                    'Begin your swing as the puck arrives. Let the pass power contribute to your shot — don\'t over-swing.',
            },
        ],
        // NO level_1 — this challenge only appears on Level 2 and above.
        levels: [
            { id: 'level_2', level: 2, level_name: 'Level 2', sequence: 5, shots_required: 15, shots_to_pass: 10, active: true, steps: null },
            { id: 'level_3', level: 3, level_name: 'Level 3', sequence: 5, shots_required: 20, shots_to_pass: 14, active: true, steps: null },
        ],
    },
];

// ---------------------------------------------------------------------------
// Seed logic
// ---------------------------------------------------------------------------

async function seedChallenge(challenge) {
    const { levels, ...challengeData } = challenge;

    const ref = db
        .collection('challenger_road')
        .doc('challenges')
        .collection('challenges')
        .doc(challenge.id);

    const snap = await ref.get();
    if (snap.exists) {
        console.log(`  ↷  Skipped  ${challenge.id} (already exists)`);
        return;
    }

    const { id: _id, ...dataWithoutId } = challengeData;
    await ref.set({
        ...dataWithoutId,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    for (const level of levels) {
        const { steps, ...levelData } = level;
        await ref.collection('levels').doc(level.id).set({
            ...levelData,
            // Only include steps if this level has its own overrides.
            ...(steps != null ? { steps } : {}),
        });
    }

    const levelIds = levels.map((l) => l.id).join(', ');
    console.log(`  ✓  Seeded   ${challenge.id} — "${challenge.name}" [levels: ${levelIds}]`);
}

async function main() {
    console.log('\n🏒  Seeding Challenger Road test data...\n');

    for (const challenge of CHALLENGES) {
        await seedChallenge(challenge);
    }

    console.log('\n✅  Done.\n');
    console.log('Expected map layout:');
    console.log('  Level 1 → 4 challenges (1–4)  [seed_challenge_5 has no L1 doc]');
    console.log('  Level 2 → 5 challenges (1–5)');
    console.log('  Level 3 → 5 challenges (1–5)');
    console.log('\nVerify in Firebase Console: challenger_road/challenges/{id}/levels\n');
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('\n❌  Seed failed:', err);
        process.exit(1);
    });

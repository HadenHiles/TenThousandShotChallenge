#!/usr/bin/env node
/**
 * Seed Challenger Road test data into Firestore.
 *
 * Creates level documents that each own their challenge documents directly.
 * Repeated challenges across levels are duplicated as separate challenge docs.
 *
 * Idempotent - skips any document that already exists.
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
        // Emulator - no credentials needed.
        admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
    } else {
        // Real project - accepts either:
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
const IMG_LEVEL4 = 'https://placehold.co/600x400/402218/ffffff?text=Level+4+Challenge';

// ---------------------------------------------------------------------------
// Source data used to seed duplicated challenge docs into each level.
// ---------------------------------------------------------------------------

const CHALLENGES = [
    // ── Challenge 1 ──────────────────────────────────────────────────────────
    {
        id: 'seed_challenge_1',
        name: 'Wrist Shot Warmup',
        description:
            'Build muscle memory and wrist control with a focused set of wrist shots from the slot.',
        active: true,
        shot_type: 'wrist',
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
        shot_type: 'snap',
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
            { id: 'level_2', level: 2, level_name: 'Level 2', sequence: 2, shots_required: 15, shots_to_pass: 10, active: true, steps: null },
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
        shot_type: 'backhand',
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
        shot_type: 'slap',
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
    {
        id: 'seed_challenge_5',
        name: 'One-Timer Challenge',
        description:
            'Step it up with one-timers. Receive a cross-ice pass and rip a shot without stopping the puck.',
        active: true,
        shot_type: 'wrist',
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
                    'Begin your swing as the puck arrives. Let the pass power contribute to your shot - don\'t over-swing.',
            },
        ],
        levels: [
            { id: 'level_1', level: 1, level_name: 'Level 1', sequence: 5, shots_required: 10, shots_to_pass: 6, active: true, steps: null },
            { id: 'level_2', level: 2, level_name: 'Level 2', sequence: 5, shots_required: 15, shots_to_pass: 10, active: true, steps: null },
            { id: 'level_3', level: 3, level_name: 'Level 3', sequence: 5, shots_required: 20, shots_to_pass: 14, active: true, steps: null },
        ],
    },

    // ── Level 4 Challenge Set ───────────────────────────────────────────────
    {
        id: 'seed_challenge_6',
        name: 'Rapid Release Ladder',
        description:
            'String together fast releases from five puck positions without letting your mechanics break down.',
        active: true,
        shot_type: 'snap',
        steps: [
            {
                step_number: 1,
                title: 'Five-Puck Setup',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Set five pucks in a shallow arc across the high slot so each shot changes the release angle.',
            },
            {
                step_number: 2,
                title: 'Catch and Fire',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Move from puck to puck without resetting fully. Release each shot in rhythm.',
            },
        ],
        levels: [{ id: 'level_4', level: 4, level_name: 'Level 4', sequence: 1, shots_required: 25, shots_to_pass: 18, active: true, steps: null }],
    },
    {
        id: 'seed_challenge_7',
        name: 'Backhand Under Pressure',
        description:
            'Train your backhand finish while moving your feet and protecting the puck through contact pressure.',
        active: true,
        shot_type: 'backhand',
        steps: [
            {
                step_number: 1,
                title: 'Protect the Lane',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Approach from the hashmarks with the puck on your backhand side and shoulders over the puck.',
            },
            {
                step_number: 2,
                title: 'Lift Through the Finish',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Keep the blade cupped and finish high with a quick upward pull.',
            },
        ],
        levels: [{ id: 'level_4', level: 4, level_name: 'Level 4', sequence: 2, shots_required: 25, shots_to_pass: 18, active: true, steps: null }],
    },
    {
        id: 'seed_challenge_8',
        name: 'Slap Shot Reload',
        description:
            'Develop the ability to reload quickly and strike repeated slap shots without losing power.',
        active: true,
        shot_type: 'slap',
        steps: [
            {
                step_number: 1,
                title: 'Reload Position',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Reset your bottom hand and weight transfer after every rep instead of rushing the setup.',
            },
            {
                step_number: 2,
                title: 'Strike Cleanly',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Hit the ice just behind the puck and finish with your chest facing the net.',
            },
        ],
        levels: [{ id: 'level_4', level: 4, level_name: 'Level 4', sequence: 3, shots_required: 25, shots_to_pass: 17, active: true, steps: null }],
    },
    {
        id: 'seed_challenge_9',
        name: 'Corner Pick Wrist Shots',
        description:
            'Pick small targets from changing puck positions and hold accuracy under a heavier shot volume.',
        active: true,
        shot_type: 'wrist',
        steps: [
            {
                step_number: 1,
                title: 'Target Sequence',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Alternate corners every shot so you have to reset your aim line before each release.',
            },
            {
                step_number: 2,
                title: 'Quiet Upper Body',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Keep your head still and let the hands load and release without over-rotating your shoulders.',
            },
        ],
        levels: [{ id: 'level_4', level: 4, level_name: 'Level 4', sequence: 4, shots_required: 25, shots_to_pass: 19, active: true, steps: null }],
    },
    {
        id: 'seed_challenge_10',
        name: 'Cross-Ice One-Timer Finish',
        description:
            'Simulate a game-speed one-timer by opening up to a pass and finishing in one motion.',
        active: true,
        shot_type: 'wrist',
        steps: [
            {
                step_number: 1,
                title: 'Open Up Early',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Present the blade before the puck arrives so the shot starts from your setup, not after the catch.',
            },
            {
                step_number: 2,
                title: 'Drive Through Contact',
                media_type: 'image',
                media_url: IMG_LEVEL4,
                summary: 'Transfer through the pass and keep the stick moving through the target line.',
            },
        ],
        levels: [{ id: 'level_4', level: 4, level_name: 'Level 4', sequence: 5, shots_required: 25, shots_to_pass: 18, active: true, steps: null }],
    },
];

// ---------------------------------------------------------------------------
// Seed logic
// ---------------------------------------------------------------------------

async function seedChallenge(challenge) {
    const { levels, ...challengeData } = challenge;

    for (const level of levels) {
        const levelRef = db.collection('challenger_road_levels').doc(level.id);
        const levelSnap = await levelRef.get();

        if (!levelSnap.exists) {
            await levelRef.set({
                level: level.level,
                level_name: level.level_name,
                active: level.active,
                created_at: admin.firestore.FieldValue.serverTimestamp(),
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        const challengeDocId = `${challenge.id}_l${level.level}`;
        const challengeRef = levelRef.collection('challenges').doc(challengeDocId);
        const challengeSnap = await challengeRef.get();

        if (challengeSnap.exists) {
            console.log(`  ↷  Skipped  ${challengeDocId} (already exists)`);
            continue;
        }

        const challengeSteps = level.steps != null ? level.steps : challenge.steps;
        await challengeRef.set({
            level: level.level,
            level_name: level.level_name,
            sequence: level.sequence,
            shots_required: level.shots_required,
            shots_to_pass: level.shots_to_pass,
            name: level.name || challengeData.name,
            description: level.description || challengeData.description,
            active: challengeData.active && level.active,
            shot_type: level.shot_type || challengeData.shot_type,
            preview_thumbnail_url: level.preview_thumbnail_url || null,
            preview_thumbnail_media_type: level.preview_thumbnail_media_type || null,
            steps: challengeSteps,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`  ✓  Seeded   ${challengeDocId} - "${level.name || challenge.name}" [Level ${level.level}]`);
    }
}

async function main() {
    console.log('\n🏒  Seeding Challenger Road test data...\n');

    for (const challenge of CHALLENGES) {
        await seedChallenge(challenge);
    }

    console.log('\n✅  Done.\n');
    console.log('Expected map layout:');
    console.log('  Level 1 → 5 repeated challenges (1–5)');
    console.log('  Level 2 → 5 repeated challenges (1–5)');
    console.log('  Level 3 → 5 repeated challenges (1–5)');
    console.log('  Level 4 → 5 new challenges (6–10)');
    console.log('\nVerify in Firebase Console: challenger_road_levels/{levelId}/challenges/{challengeId}\n');
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('\n❌  Seed failed:', err);
        process.exit(1);
    });

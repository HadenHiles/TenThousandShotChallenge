#!/usr/bin/env node
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

async function migrate() {
    const legacyChallengesRef = db.collection('challenger_road').doc('challenges').collection('challenges');
    const levelsRef = db.collection('challenger_road').doc('levels').collection('levels');

    const challengeSnap = await legacyChallengesRef.get();
    if (challengeSnap.empty) {
        console.log('No legacy challenger road challenges found.');
        return;
    }

    let migratedCount = 0;
    let skippedCount = 0;

    for (const challengeDoc of challengeSnap.docs) {
        const challengeData = challengeDoc.data() || {};
        const levelsSnap = await challengeDoc.reference.collection('levels').get();

        for (const levelDoc of levelsSnap.docs) {
            const levelData = levelDoc.data() || {};
            const levelNumber = Number(levelData.level || 0);
            if (!levelNumber) continue;

            const levelId = levelDoc.id;
            const levelRef = levelsRef.doc(levelId);
            const targetChallengeId = `${challengeDoc.id}_l${levelNumber}`;
            const targetChallengeRef = levelRef.collection('challenges').doc(targetChallengeId);
            const targetChallengeSnap = await targetChallengeRef.get();

            await levelRef.set(
                {
                    level: levelNumber,
                    level_name: levelData.level_name || `Level ${levelNumber}`,
                    active: levelData.active !== false,
                    updated_at: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true },
            );

            if (targetChallengeSnap.exists) {
                skippedCount += 1;
                console.log(`↷ Skipped ${targetChallengeId} (already migrated)`);
                continue;
            }

            await targetChallengeRef.set({
                level: levelNumber,
                level_name: levelData.level_name || `Level ${levelNumber}`,
                sequence: Number(levelData.sequence || 0),
                shots_required: Number(levelData.shots_required || 10),
                shots_to_pass: Number(levelData.shots_to_pass || 6),
                name: levelData.name || challengeData.name || '',
                description: levelData.description || challengeData.description || '',
                active: challengeData.active !== false && levelData.active !== false,
                shot_type: levelData.shot_type || challengeData.shot_type || null,
                preview_thumbnail_url:
                    levelData.preview_thumbnail_url || challengeData.preview_thumbnail_url || null,
                preview_thumbnail_media_type:
                    levelData.preview_thumbnail_media_type || challengeData.preview_thumbnail_media_type || null,
                steps: levelData.steps || challengeData.steps || [],
                legacy_challenge_id: challengeDoc.id,
                legacy_level_doc_id: levelDoc.id,
                created_at:
                    challengeData.created_at || admin.firestore.FieldValue.serverTimestamp(),
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            migratedCount += 1;
            console.log(`✓ Migrated ${challengeDoc.id}/${levelDoc.id} -> ${targetChallengeId}`);
        }
    }

    console.log(`\nDone. Migrated ${migratedCount} challenge docs, skipped ${skippedCount}.`);
    console.log('New path: challenger_road/levels/levels/{levelId}/challenges/{challengeId}');
}

migrate()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error('Migration failed:', error);
        process.exit(1);
    });
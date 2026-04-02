#!/usr/bin/env node
/**
 * Remove all seed Challenger Road data from Firestore.
 *
 * Deletes every seed level-owned challenge document under the
 * challenger_road/levels/levels/{levelId}/challenges path and removes any now-empty
 * level documents created by the seed script.
 *
 * Run this before promoting real challenge data to production, or to
 * reset your dev/emulator environment cleanly.
 *
 * Usage (against real dev project):
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
 *     node scripts/unseed_challenger_road.js
 *
 * Usage (against local Firestore emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *     node scripts/unseed_challenger_road.js
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
        // Real project — accepts either:
        //   1. GOOGLE_APPLICATION_CREDENTIALS pointing to a service account JSON, OR
        //   2. Application Default Credentials (run `firebase login` first).
        admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
    }
}

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Delete a document and all documents in a named subcollection.
// Firestore does not auto-delete subcollections when a parent doc is deleted,
// so we must delete them explicitly.
// ---------------------------------------------------------------------------

async function deleteSubcollection(docRef, subcollectionName) {
    const snap = await docRef.collection(subcollectionName).get();
    if (snap.empty) return;

    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    console.log(`    ↳ Deleted ${snap.size} doc(s) from ${subcollectionName}/`);
}

async function main() {
    console.log('\n🗑️   Removing Challenger Road seed data...\n');

    const levelsRef = db.collection('challenger_road').doc('levels').collection('levels');
    const levelSnap = await levelsRef.get();

    if (levelSnap.empty) {
        console.log('  Nothing to delete — no seeded levels found.\n');
        return;
    }

    let deletedChallenges = 0;
    let deletedLevels = 0;

    for (const levelDoc of levelSnap.docs) {
        const challengesSnap = await levelDoc.ref.collection('challenges').get();
        const seedChallengeDocs = challengesSnap.docs.filter((d) => d.id.startsWith('seed_'));

        for (const doc of seedChallengeDocs) {
            console.log(`  Deleting ${levelDoc.id}/${doc.id}…`);
            await doc.ref.delete();
            deletedChallenges += 1;
            console.log(`  ✓  Deleted ${doc.id}`);
        }

        const remainingChallengesSnap = await levelDoc.ref.collection('challenges').get();
        if (remainingChallengesSnap.empty && levelDoc.id.startsWith('level_')) {
            await levelDoc.ref.delete();
            deletedLevels += 1;
            console.log(`  ✓  Deleted empty level doc ${levelDoc.id}`);
        }
    }

    console.log(`\n✅  Done. Removed ${deletedChallenges} seed challenge(s) and ${deletedLevels} empty seed level doc(s).\n`);
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('\n❌  Unseed failed:', err);
        process.exit(1);
    });

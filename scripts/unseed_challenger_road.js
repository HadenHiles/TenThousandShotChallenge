#!/usr/bin/env node
/**
 * Remove all seed Challenger Road data from Firestore.
 *
 * Deletes every document under challenger_road/challenges whose ID starts
 * with "seed_", including its "levels" subcollection.
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
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      console.error(
        'ERROR: Set GOOGLE_APPLICATION_CREDENTIALS or FIRESTORE_EMULATOR_HOST before running this script.'
      );
      process.exit(1);
    }
    admin.initializeApp();
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

  const challengesRef = db
    .collection('challenger_road')
    .doc('challenges')
    .collection('challenges');

  const snap = await challengesRef.get();

  if (snap.empty) {
    console.log('  Nothing to delete — collection is empty.\n');
    return;
  }

  const seedDocs = snap.docs.filter((d) => d.id.startsWith('seed_'));

  if (seedDocs.length === 0) {
    console.log('  No seed_ documents found — nothing to delete.\n');
    return;
  }

  for (const doc of seedDocs) {
    console.log(`  Deleting ${doc.id}…`);
    await deleteSubcollection(doc.ref, 'levels');
    await doc.ref.delete();
    console.log(`  ✓  Deleted ${doc.id}`);
  }

  console.log(`\n✅  Done. Removed ${seedDocs.length} seed challenge(s).\n`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('\n❌  Unseed failed:', err);
    process.exit(1);
  });

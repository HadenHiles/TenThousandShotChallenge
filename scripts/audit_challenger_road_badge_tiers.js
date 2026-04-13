#!/usr/bin/env node
'use strict';

/**
 * Audit Firestore challenger_road_badges tier assignments against
 * canonical tiers declared in lib/services/ChallengerRoadService.dart.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
 *     node scripts/audit_challenger_road_badge_tiers.js
 *
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *     node scripts/audit_challenger_road_badge_tiers.js
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
}

const db = admin.firestore();

function loadCanonicalTiers() {
  const dartPath = path.join(__dirname, '..', 'lib', 'services', 'ChallengerRoadService.dart');
  const src = fs.readFileSync(dartPath, 'utf8');

  const pairRegex = /id:\s*'([^']+)'[\s\S]*?tier:\s*ChallengerRoadBadgeTier\.(\w+)/g;
  const canonical = new Map();
  let match;
  while ((match = pairRegex.exec(src)) !== null) {
    canonical.set(match[1], match[2]);
  }
  return canonical;
}

async function run() {
  const canonical = loadCanonicalTiers();
  if (canonical.size === 0) {
    throw new Error('No badge tiers parsed from ChallengerRoadService.dart');
  }

  const snap = await db.collection('challenger_road_badges').get();

  let ok = 0;
  const missingTier = [];
  const unknownIds = [];
  const mismatches = [];

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const id = doc.id;
    const fsTier = typeof data.tier === 'string' ? data.tier : null;
    const canonicalTier = canonical.get(id);

    if (!canonicalTier) {
      unknownIds.push(id);
      continue;
    }

    if (!fsTier) {
      missingTier.push(id);
      continue;
    }

    if (fsTier !== canonicalTier) {
      mismatches.push({ id, firestoreTier: fsTier, canonicalTier });
      continue;
    }

    ok++;
  }

  console.log('=== Challenger Road Badge Tier Audit ===');
  console.log(`canonical badge IDs: ${canonical.size}`);
  console.log(`firestore docs: ${snap.size}`);
  console.log(`matching tiers: ${ok}`);
  console.log(`missing tier field: ${missingTier.length}`);
  console.log(`tier mismatches: ${mismatches.length}`);
  console.log(`unknown firestore IDs: ${unknownIds.length}`);

  if (missingTier.length) {
    console.log('\nMissing tier field:');
    for (const id of missingTier) console.log(` - ${id}`);
  }

  if (mismatches.length) {
    console.log('\nTier mismatches:');
    for (const m of mismatches) {
      console.log(` - ${m.id}: firestore=${m.firestoreTier} canonical=${m.canonicalTier}`);
    }
  }

  if (unknownIds.length) {
    console.log('\nUnknown Firestore IDs (not in canonical catalog):');
    for (const id of unknownIds) console.log(` - ${id}`);
  }

  if (!missingTier.length && !mismatches.length && !unknownIds.length) {
    console.log('\nAudit status: PASS');
  } else {
    console.log('\nAudit status: ATTENTION NEEDED');
  }
}

run().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});

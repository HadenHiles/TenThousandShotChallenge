#!/usr/bin/env node
'use strict';

/**
 * Sync Firestore challenger_road_badges.tier from canonical tiers in
 * lib/services/ChallengerRoadService.dart.
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
    const tiers = new Map();
    let match;
    while ((match = pairRegex.exec(src)) !== null) {
        tiers.set(match[1], match[2]);
    }
    return tiers;
}

async function run() {
    const canonical = loadCanonicalTiers();
    const col = db.collection('challenger_road_badges');
    const snap = await col.get();

    let updated = 0;
    for (const doc of snap.docs) {
        const id = doc.id;
        const expected = canonical.get(id);
        if (!expected) continue;
        const current = (doc.data() || {}).tier;
        if (current !== expected) {
            await col.doc(id).set({ tier: expected }, { merge: true });
            console.log(`Updated tier: ${id} ${current || '(none)'} -> ${expected}`);
            updated++;
        }
    }

    console.log(`Done. Updated ${updated} badge tier fields.`);
}

run().catch((err) => {
    console.error(err.message || err);
    process.exit(1);
});

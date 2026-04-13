#!/usr/bin/env node
'use strict';

/**
 * Delete challenger_road_badges docs that are not present in
 * ChallengerRoadService.badgeCatalog.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
}

const db = admin.firestore();

function loadCanonicalIds() {
    const dartPath = path.join(__dirname, '..', 'lib', 'services', 'ChallengerRoadService.dart');
    const src = fs.readFileSync(dartPath, 'utf8');
    const idRegex = /id:\s*'([^']+)'/g;
    const ids = new Set();
    let match;
    while ((match = idRegex.exec(src)) !== null) ids.add(match[1]);
    return ids;
}

async function run() {
    const canonicalIds = loadCanonicalIds();
    const col = db.collection('challenger_road_badges');
    const snap = await col.get();

    const legacy = snap.docs.map((d) => d.id).filter((id) => !canonicalIds.has(id));

    if (!legacy.length) {
        console.log('No legacy challenger_road_badges docs found.');
        return;
    }

    for (const id of legacy) {
        await col.doc(id).delete();
        console.log(`Deleted legacy badge doc: ${id}`);
    }

    console.log(`Done. Deleted ${legacy.length} legacy docs.`);
}

run().catch((err) => {
    console.error(err.message || err);
    process.exit(1);
});

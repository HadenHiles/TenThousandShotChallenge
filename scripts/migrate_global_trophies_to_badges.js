#!/usr/bin/env node
/**
 * One-time migration: move global_trophy_definitions → challenger_road_badges
 *
 * Steps:
 *   1. Copy every doc from global_trophy_definitions into challenger_road_badges
 *      with type='global' added.
 *   2. Stamp every existing challenger_road_badges doc with type='challenger_road'
 *      (if not already set) so the admin and app can filter by type.
 *   3. Delete all docs from global_trophy_definitions.
 *
 * Safe to re-run - already-migrated trophy docs are detected by checking for
 * type='global' on the destination. Already-stamped CR badge docs are skipped.
 *
 * Usage:
 *   node scripts/migrate_global_trophies_to_badges.js
 */

'use strict';

const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
}

const db = admin.firestore();

async function migrate() {
    const srcCol = db.collection('global_trophy_definitions');
    const dstCol = db.collection('challenger_road_badges');

    // ── 1. Read source collection ──────────────────────────────────────────
    const [srcSnap, dstSnap] = await Promise.all([srcCol.get(), dstCol.get()]);

    const srcDocs = srcSnap.docs;
    if (srcDocs.length === 0) {
        console.log('global_trophy_definitions is empty - nothing to migrate.');
    } else {
        console.log(`Found ${srcDocs.length} trophy definition(s) to migrate…`);
    }

    // ── 2. Stamp existing CR badge docs with type='challenger_road' ────────
    const crBadges = dstSnap.docs.filter((d) => {
        const data = d.data();
        return data.type == null; // only unstamped docs
    });
    if (crBadges.length > 0) {
        console.log(`Stamping ${crBadges.length} existing CR badge doc(s) with type='challenger_road'…`);
        // Batch in groups of 500
        for (let i = 0; i < crBadges.length; i += 499) {
            const chunk = crBadges.slice(i, i + 499);
            const batch = db.batch();
            for (const d of chunk) {
                batch.set(d.ref, { type: 'challenger_road' }, { merge: true });
            }
            await batch.commit();
        }
        console.log('  ✓ CR badges stamped.');
    } else {
        console.log('All existing CR badge docs already have a type field - skipping stamp step.');
    }

    // ── 3. Copy trophy docs to challenger_road_badges ───────────────────────
    if (srcDocs.length > 0) {
        // Detect which ones are already in destination (idempotency)
        const existingDstIds = new Set(dstSnap.docs.map((d) => d.id));
        const toMigrate = srcDocs.filter((d) => !existingDstIds.has(d.id));
        const alreadyDone = srcDocs.length - toMigrate.length;

        if (alreadyDone > 0) {
            console.log(`  ${alreadyDone} trophy doc(s) already exist in challenger_road_badges - skipping.`);
        }

        if (toMigrate.length > 0) {
            console.log(`  Copying ${toMigrate.length} trophy doc(s)…`);
            for (let i = 0; i < toMigrate.length; i += 499) {
                const chunk = toMigrate.slice(i, i + 499);
                const batch = db.batch();
                for (const srcDoc of chunk) {
                    const data = srcDoc.data();
                    const dstRef = dstCol.doc(srcDoc.id);
                    batch.set(dstRef, {
                        ...data,
                        type: 'global',
                    });
                }
                await batch.commit();
            }
            console.log('  ✓ Trophy docs copied.');
        }

        // ── 4. Delete source docs ──────────────────────────────────────────
        console.log(`Deleting ${srcDocs.length} doc(s) from global_trophy_definitions…`);
        for (let i = 0; i < srcDocs.length; i += 499) {
            const chunk = srcDocs.slice(i, i + 499);
            const batch = db.batch();
            for (const d of chunk) {
                batch.delete(d.ref);
            }
            await batch.commit();
        }
        console.log('  ✓ global_trophy_definitions cleared.');
    }

    console.log('\nMigration complete.');
    console.log('  challenger_road_badges now contains both CR badges (type=challenger_road)');
    console.log('  and global trophies (type=global).');
    console.log('\nNext steps:');
    console.log('  1. Deploy updated firestore.rules (removes global_trophy_definitions rule)');
    console.log('  2. Deploy updated Flutter app (reads challenger_road_badges filtered by type)');
    console.log('  3. Deploy updated admin dashboard (queries filtered by type)');
}

migrate().catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
});

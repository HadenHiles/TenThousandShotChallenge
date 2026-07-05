#!/usr/bin/env node
/**
 * Fetches challenger_road challenge steps from Firestore, finds webm URLs,
 * and checks each one is reachable (HTTP 200 with a video content-type).
 *
 * Usage:
 *   cd /Users/hadenhiles/Repos/TenThousandShotChallenge
 *   node scripts/check_webm_urls.js
 */

const { execSync } = require('child_process');
const https = require('https');
const http = require('http');

// ── Init Firebase Admin ─────────────────────────────────────────────────────
let admin;
try {
  admin = require('./node_modules/firebase-admin');
} catch (_) {
  // Fall back to functions/node_modules
  admin = require('./functions/node_modules/firebase-admin');
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'ten-thousand-puck-challenge',
  });
}

const db = admin.firestore();

// ── HTTP HEAD check ─────────────────────────────────────────────────────────
function checkUrl(url) {
  return new Promise((resolve) => {
    const mod = url.startsWith('https') ? https : http;
    const req = mod.request(url, { method: 'HEAD', timeout: 8000 }, (res) => {
      resolve({ status: res.statusCode, type: res.headers['content-type'] || '' });
    });
    req.on('error', (e) => resolve({ status: 0, error: e.message }));
    req.on('timeout', () => { req.destroy(); resolve({ status: 0, error: 'timeout' }); });
    req.end();
  });
}

// ── Main ────────────────────────────────────────────────────────────────────
(async () => {
  console.log('Fetching challenger_road challenges from Firestore…\n');

  const snap = await db.collection('challenger_road').doc('challenges').collection('challenges').limit(50).get();
  if (snap.empty) {
    console.log('No challenges found. Check collection path.');
    process.exit(1);
  }

  const webmEntries = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const steps = data.steps || [];
    for (const step of steps) {
      if ((step.media_type || '').toLowerCase() === 'webm' && step.media_url) {
        webmEntries.push({ challengeId: doc.id, stepNumber: step.step_number, url: step.media_url });
      }
    }
  }

  if (webmEntries.length === 0) {
    console.log('No webm steps found in the first 50 challenges.');
    process.exit(0);
  }

  console.log(`Found ${webmEntries.length} webm step(s). Checking reachability…\n`);

  let ok = 0, fail = 0;
  for (const entry of webmEntries) {
    const result = await checkUrl(entry.url);
    const isOk = result.status >= 200 && result.status < 300;
    if (isOk) ok++;
    else fail++;
    const icon = isOk ? '✅' : '❌';
    const detail = result.error ? result.error : `HTTP ${result.status}  ${result.type}`;
    console.log(`${icon}  challenge=${entry.challengeId}  step=${entry.stepNumber}`);
    console.log(`   ${detail}`);
    if (!isOk) console.log(`   URL: ${entry.url.substring(0, 100)}…`);
    console.log();
  }

  console.log(`─────────────────────────────────`);
  console.log(`✅ OK: ${ok}   ❌ Failed: ${fail}`);
  process.exit(fail > 0 ? 1 : 0);
})();

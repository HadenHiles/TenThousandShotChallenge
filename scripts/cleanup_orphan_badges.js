// One-shot script: removes orphan challenger_road_badges docs and
// strips orphan IDs from users/{uid}/challenger_road/summary badges arrays.
//
// Run from functions/ directory (where firebase-admin is installed):
//   node ../scripts/cleanup_orphan_badges.js

const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
const db = admin.firestore();

// All badge IDs currently defined in ChallengerRoadService.badgeCatalog
const VALID_BADGE_IDS = new Set([
  'fresh_laces', 'drop_the_biscuit', 'clean_read', 'level_clear', 'made_the_show',
  'no_warmup_needed', 'breakaway', 'freight_train', 'clean_sweep',
  'scouting_report', 'the_rematch', 'dialed_in', 'comeback_season', 'redemption_arc', 'the_comeback_kid',
  'battle_tested', 'game_7', 'third_period_heart', 'old_grudge',
  'ice_time_earned', 'team_captain', 'the_climb', 'the_general',
  'first_bucket', 'building_a_barn', 'ten_minute_major', 'buzzer_beater', 'three_periods', 'well_never_runs_dry',
  'lights_out', 'bar_down', 'top_cheese', 'pure', 'the_sniper', 'all_net',
  'sauce', 'unstoppable', 'full_send',
  'never_missed', 'untouchable', 'earned_a_salary',
  'veteran_presence', 'lifer', 'career_year', 'road_dog', 'all_time_great',
  'hall_of_famer', 'the_machine', 'hockey_god',
  'bender', 'pigeon', 'sauce_boss', 'skip_the_tryout', 'all_stars',
]);

const BATCH_SIZE = 400;

async function run() {
  // ── 1. Remove orphan global override docs from challenger_road_badges ─────
  const badgesSnap = await db.collection('challenger_road_badges').get();
  const toDelete = badgesSnap.docs.filter(d => !VALID_BADGE_IDS.has(d.id));

  console.log(`Orphan override docs to delete (${toDelete.length}):`);
  toDelete.forEach(d => console.log(`  - ${d.id}`));

  for (let i = 0; i < toDelete.length; i += BATCH_SIZE) {
    const batch = db.batch();
    toDelete.slice(i, i + BATCH_SIZE).forEach(d => batch.delete(d.ref));
    await batch.commit();
  }
  console.log(`✓ Deleted ${toDelete.length} orphan override docs.\n`);

  // ── 2. Strip orphan IDs from every users/{uid}/challenger_road/summary ─────
  const orphanSet = new Set(toDelete.map(d => d.id));
  if (orphanSet.size === 0) {
    console.log('No orphans found - skipping user summary scan.');
    process.exit(0);
  }

  // collectionGroup('challenger_road') catches all summary sub-docs
  const summarySnap = await db.collectionGroup('challenger_road').get();
  console.log(`User challenger_road sub-docs found: ${summarySnap.size}`);

  const userUpdates = [];
  summarySnap.forEach(doc => {
    const data = doc.data();
    const badges = Array.isArray(data.badges) ? data.badges : [];
    const featured = Array.isArray(data.featured_badges) ? data.featured_badges : [];
    const cleanBadges = badges.filter(id => !orphanSet.has(id));
    const cleanFeatured = featured.filter(id => !orphanSet.has(id));
    if (cleanBadges.length !== badges.length || cleanFeatured.length !== featured.length) {
      userUpdates.push({
        ref: doc.ref,
        cleanBadges,
        cleanFeatured,
        removedCount: (badges.length - cleanBadges.length) + (featured.length - cleanFeatured.length),
      });
    }
  });

  console.log(`User summaries with orphan badge IDs: ${userUpdates.length}`);
  for (let i = 0; i < userUpdates.length; i += BATCH_SIZE) {
    const batch = db.batch();
    userUpdates.slice(i, i + BATCH_SIZE).forEach(({ ref, cleanBadges, cleanFeatured, removedCount }) => {
      batch.update(ref, { badges: cleanBadges, featured_badges: cleanFeatured });
      console.log(`  Removed ${removedCount} orphan(s) from ${ref.path}`);
    });
    await batch.commit();
  }

  console.log(`\n✓ Done. ${userUpdates.length} user summaries cleaned.`);
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });

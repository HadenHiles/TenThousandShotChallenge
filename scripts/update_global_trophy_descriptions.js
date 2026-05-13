#!/usr/bin/env node
/**
 * Force-update ALL global trophy documents in `challenger_road_badges`
 * (type='global') with the latest display_name, display_description, and
 * default_icon from this script.
 *
 * Unlike seed scripts (which skip existing docs), this script OVERWRITES
 * display fields on every document so improvements are always reflected
 * in Firestore.
 *
 * icon_url is NOT touched — custom images set via the admin dashboard are
 * preserved.
 *
 * Usage:
 *   node scripts/update_global_trophy_descriptions.js
 */

'use strict';

const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
}

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Category default icons
// ---------------------------------------------------------------------------
const CATEGORY_ICON = {
    volume: 'workspace_premium',
    sessions: 'sports_hockey',
    weekly: 'calendar_today',
    shotType: 'gps_fixed',
    timeOfDay: 'schedule',
    accuracy: 'track_changes',
};

// ---------------------------------------------------------------------------
// Trophy catalog — inclusive descriptions.
// ALL session types count toward every category. Regular training sessions
// and Challenger Road sessions both supply per-type shot data (each CR
// challenge requires a specific shot type), so shot-type and accuracy
// trophies accumulate from both.
// ---------------------------------------------------------------------------
const TROPHIES = [
    // ── Volume ──────────────────────────────────────────────────────────────
    { id: 'g_first_shot', name: 'Biscuit on Ice', desc: 'Logged your very first shot in the app. Every journey starts somewhere.', category: 'volume', tier: 'common', proOnly: false },
    { id: 'g_shots_100', name: 'First Hundred', desc: "100 total shots logged across all your sessions. You're warming up.", category: 'volume', tier: 'common', proOnly: false },
    { id: 'g_shots_250', name: 'Quarter Stack', desc: '250 total shots logged in the app. Getting into a rhythm.', category: 'volume', tier: 'common', proOnly: false },
    { id: 'g_shots_500', name: 'Five Hundo', desc: '500 total shots logged in your training sessions. Barely even tired.', category: 'volume', tier: 'common', proOnly: false },
    { id: 'g_shots_1000', name: 'Four Digits', desc: "1,000 total shots logged. You've officially committed to putting in the reps.", category: 'volume', tier: 'uncommon', proOnly: false },
    { id: 'g_shots_2500', name: 'Quarter Way There', desc: '2,500 total shots logged. Well past the warm-up phase.', category: 'volume', tier: 'uncommon', proOnly: false },
    { id: 'g_shots_5000', name: 'Halfway There', desc: '5,000 total shots logged. Half the 10K challenge worth of reps in the bag.', category: 'volume', tier: 'rare', proOnly: false },
    { id: 'g_shots_7500', name: 'Deep In It', desc: '7,500 total shots logged. The finish line is in sight.', category: 'volume', tier: 'rare', proOnly: false },
    { id: 'g_shots_10000', name: 'The Full Ten', desc: '10,000 total shots logged. You completed the entire challenge.', category: 'volume', tier: 'epic', proOnly: false },
    { id: 'g_shots_15000', name: 'Encore', desc: "15,000 total shots logged. Once wasn't enough for you.", category: 'volume', tier: 'epic', proOnly: false },
    { id: 'g_shots_20000', name: 'Double Down', desc: '20,000 total shots logged — two full challenges worth of reps.', category: 'volume', tier: 'epic', proOnly: true },
    { id: 'g_shots_25000', name: 'Obsessed', desc: '25,000 total shots logged. Honestly, we respect it.', category: 'volume', tier: 'legendary', proOnly: true },
    { id: 'g_shots_50000', name: 'Five Times Ten Thousand', desc: '50,000 total shots logged. Absolute menace. In the best way.', category: 'volume', tier: 'legendary', proOnly: true },

    // ── Sessions ────────────────────────────────────────────────────────────
    { id: 'g_first_session', name: 'Warming Up', desc: 'Finished your first session in the app.', category: 'sessions', tier: 'common', proOnly: false },
    { id: 'g_sessions_5', name: 'Five and Counting', desc: '5 sessions completed. A habit is forming.', category: 'sessions', tier: 'common', proOnly: false },
    { id: 'g_sessions_10', name: 'Getting Reps In', desc: '10 sessions in the bag.', category: 'sessions', tier: 'common', proOnly: false },
    { id: 'g_sessions_25', name: 'Committed', desc: "25 sessions. This isn't a phase — it's a practice.", category: 'sessions', tier: 'uncommon', proOnly: false },
    { id: 'g_sessions_50', name: 'Half a Century', desc: '50 sessions completed. You show up more than most.', category: 'sessions', tier: 'uncommon', proOnly: false },
    { id: 'g_sessions_100', name: 'Century', desc: "100 sessions. You're a grinder.", category: 'sessions', tier: 'rare', proOnly: false },
    { id: 'g_sessions_150', name: 'Regular', desc: "150 sessions. You're practically a fixture at the rink.", category: 'sessions', tier: 'rare', proOnly: true },
    { id: 'g_sessions_250', name: 'Lifer', desc: '250 sessions. This app is your therapy.', category: 'sessions', tier: 'epic', proOnly: true },
    { id: 'g_sessions_500', name: 'Cult Member', desc: '500 sessions. Should we be concerned?', category: 'sessions', tier: 'legendary', proOnly: true },

    // ── Weekly ──────────────────────────────────────────────────────────────
    { id: 'g_week_streak_2', name: 'Back-to-Back', desc: 'Logged sessions in two consecutive calendar weeks.', category: 'weekly', tier: 'common', proOnly: false },
    { id: 'g_week_500', name: 'Five Hundred Week', desc: '500 total shots across all sessions in a single calendar week. Solid output.', category: 'weekly', tier: 'common', proOnly: false },
    { id: 'g_week_1000', name: 'Thousand-Shot Week', desc: "1,000 total shots across all sessions in a single calendar week. That's a grind.", category: 'weekly', tier: 'uncommon', proOnly: false },
    { id: 'g_hundred_a_day', name: '100 a Day Keeps the Coach Away', desc: '100+ shots logged on every single day of a calendar week.', category: 'weekly', tier: 'rare', proOnly: false },
    { id: 'g_week_2000', name: 'The Grind Never Stops', desc: '2,000 total shots across all sessions in a single calendar week. Certified puck machine.', category: 'weekly', tier: 'epic', proOnly: true },
    { id: 'g_week_streak_4', name: 'Monthly Momentum', desc: 'Logged sessions in four consecutive calendar weeks.', category: 'weekly', tier: 'rare', proOnly: true },
    { id: 'g_week_streak_8', name: 'Two-Month Streak', desc: 'Eight consecutive weeks of sessions without missing a week. Iron discipline.', category: 'weekly', tier: 'epic', proOnly: true },
    { id: 'g_week_streak_12', name: 'Quarter Year', desc: 'Twelve straight weeks of sessions. Three months of consistent work.', category: 'weekly', tier: 'legendary', proOnly: true },
    { id: 'g_fifty_a_day_7', name: 'Daily Devotion', desc: '50+ shots logged on every single day of a calendar week.', category: 'weekly', tier: 'rare', proOnly: true },

    // ── Shot Type (per-type totals across all sessions, including CR) ────────
    { id: 'g_wrist_50', name: 'Wristmaster Apprentice', desc: '50 wrist shots logged.', category: 'shotType', tier: 'common', proOnly: false },
    { id: 'g_snap_50', name: 'Snap Happy', desc: '50 snap shots logged.', category: 'shotType', tier: 'common', proOnly: false },
    { id: 'g_slap_50', name: 'Bomb Squad Rookie', desc: '50 slap shots logged.', category: 'shotType', tier: 'common', proOnly: false },
    { id: 'g_backhand_50', name: 'The Other Way', desc: '50 backhand shots logged.', category: 'shotType', tier: 'common', proOnly: false },
    { id: 'g_wrist_200', name: 'Snap It', desc: '200 wrist shots logged. That release is starting to look natural.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_snap_200', name: 'Quick Draw', desc: '200 snap shots logged. Getting quick off the stick.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_slap_200', name: 'Clearing The Zone', desc: '200 slap shots logged. The opposition feels it.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_backhand_200', name: 'Switchblade', desc: '200 backhand shots logged. Two sides, one threat.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_all_types_50', name: 'Complete Package', desc: '50+ shots of every type (wrist, snap, slap, backhand) logged.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_all_types_200', name: 'No Weak Spots', desc: "200+ shots of every type logged. Defenders can't predict you.", category: 'shotType', tier: 'rare', proOnly: false },
    { id: 'g_wrist_500', name: 'Wrist of Steel', desc: '500 wrist shots logged. That snap is automatic.', category: 'shotType', tier: 'rare', proOnly: true },
    { id: 'g_snap_500', name: 'Snap King', desc: '500 snap shots logged. Quick release every time.', category: 'shotType', tier: 'rare', proOnly: true },
    { id: 'g_slap_500', name: 'Cannon', desc: '500 slap shots logged. The boards are shaking.', category: 'shotType', tier: 'rare', proOnly: true },
    { id: 'g_backhand_500', name: 'Ambidextrous', desc: '500 backhand shots logged. Defenders hate this.', category: 'shotType', tier: 'rare', proOnly: true },
    { id: 'g_wrist_1000', name: 'Wrister Blister', desc: '1,000 wrist shots logged. The tape on that blade is toast.', category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_snap_1000', name: 'Hair Trigger', desc: "1,000 snap shots logged. Blink and you'll miss it.", category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_slap_1000', name: 'Headhunter', desc: '1,000 slap shots logged. Goalies are filing HR complaints.', category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_backhand_1000', name: 'Wrong Side of the Stick', desc: '1,000 backhand shots logged. Technically ambidextrous at this point.', category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_all_types_500', name: 'The Total Package', desc: '500+ shots of every type logged. No weakness.', category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_all_types_1000', name: 'Weapon of Mass Destruction', desc: '1,000+ shots of every type logged. You are the entire power play.', category: 'shotType', tier: 'legendary', proOnly: true },

    // ── Time of Day ─────────────────────────────────────────────────────────
    { id: 'g_early_riser', name: 'Early Riser', desc: 'Started a session before 6 AM. The ice is yours.', category: 'timeOfDay', tier: 'uncommon', proOnly: false },
    { id: 'g_night_owl', name: 'Night Owl', desc: 'Started a session after 10 PM. Who needs sleep?', category: 'timeOfDay', tier: 'uncommon', proOnly: false },
    { id: 'g_weekend_warrior', name: 'Weekend Warrior', desc: 'Logged sessions on both Saturday and Sunday in the same weekend.', category: 'timeOfDay', tier: 'uncommon', proOnly: false },
    { id: 'g_lunch_break', name: 'Lunch Break Grinder', desc: 'Started a session between 11 AM and 1 PM. Reps on the clock.', category: 'timeOfDay', tier: 'common', proOnly: false },
    { id: 'g_morning_grinder', name: 'Morning Grinder', desc: '10 sessions started before 6 AM. The 5 AM crew bows to you.', category: 'timeOfDay', tier: 'rare', proOnly: true },
    { id: 'g_midnight_sniper', name: 'Midnight Sniper', desc: '10 sessions started after 10 PM. Darkness is your shooting range.', category: 'timeOfDay', tier: 'rare', proOnly: true },
    { id: 'g_sunrise_shooter', name: 'Before The World Wakes', desc: '25 sessions started before 6 AM. Absolutely no excuses ever.', category: 'timeOfDay', tier: 'epic', proOnly: true },
    { id: 'g_weekend_grinder', name: 'Weekend Machine', desc: 'Logged sessions on both Saturday and Sunday for 4 consecutive weekends.', category: 'timeOfDay', tier: 'epic', proOnly: true },

    // ── Accuracy (Pro only — requires per-type shot data; regular + CR) ─────
    { id: 'g_wrist_accuracy_80', name: 'Laser Wrist', desc: '80%+ wrist accuracy in a single training session (min. 25 wrist shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_snap_accuracy_80', name: 'Snap Sniper', desc: '80%+ snap accuracy in a single training session (min. 25 snap shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_slap_accuracy_80', name: 'Precision Bomb', desc: '80%+ slap accuracy in a single training session (min. 25 slap shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_backhand_accuracy_80', name: 'Silky Backhand', desc: '80%+ backhand accuracy in a single training session (min. 25 backhand shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_overall_accuracy_75', name: 'On Target', desc: '75%+ overall accuracy in a single training session with 50+ total shots.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_wrist_accuracy_90', name: 'Surgical Wrist', desc: '90%+ wrist accuracy in a single training session (min. 25 wrist shots).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_snap_accuracy_90', name: 'Pinpoint', desc: '90%+ snap accuracy in a single training session (min. 25 snap shots).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_slap_accuracy_90', name: 'Heat Seeking', desc: '90%+ slap accuracy in a single training session (min. 25 slap shots).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_backhand_accuracy_90', name: 'Ghost Hand', desc: '90%+ backhand accuracy in a single training session (min. 25 backhand shots).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_all_types_accuracy_80', name: 'Dead Eye', desc: '80%+ accuracy on all four shot types in a single training session (min. 25 of each).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_perfect_session', name: 'Perfect Pull', desc: '100% accuracy in a single training session with 25+ total shots. Nothing missed.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_perfect_session_50', name: 'Untouchable', desc: '100% accuracy in a single training session with 50+ total shots. Godmode.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_accuracy_streak_5', name: 'Consistent', desc: '70%+ overall accuracy across 5 consecutive training sessions.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_accuracy_streak_10', name: 'Machine', desc: '70%+ overall accuracy across 10 consecutive training sessions.', category: 'accuracy', tier: 'legendary', proOnly: true },
];

async function updateDescriptions() {
    // Trophies now live in challenger_road_badges (type='global').
    const colRef = db.collection('challenger_road_badges');

    // 73 docs fits comfortably in a single 500-op batch.
    const batch = db.batch();
    for (const trophy of TROPHIES) {
        const ref = colRef.doc(trophy.id);
        batch.set(ref, {
            type: 'global',
            display_name: trophy.name,
            display_description: trophy.desc,
            default_icon: CATEGORY_ICON[trophy.category],
            category: trophy.category,
            tier: trophy.tier,
            pro_only: trophy.proOnly,
            // icon_url is intentionally omitted so existing custom images are kept.
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }

    await batch.commit();
    console.log(`✓ Updated ${TROPHIES.length} global trophy definitions in Firestore.`);
    console.log('  (icon_url fields were NOT touched — existing custom images are preserved)');
}

updateDescriptions().catch((err) => {
    console.error('Update failed:', err);
    process.exit(1);
});

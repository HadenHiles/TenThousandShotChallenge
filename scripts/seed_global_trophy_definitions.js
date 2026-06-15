#!/usr/bin/env node
/**
 * Seed the global_trophy_definitions Firestore collection.
 *
 * Each document uses the trophy ID (g_*) as its key and stores the fields
 * expected by the admin dashboard:
 *
 *   display_name        – editable name shown in UI (initially matches code)
 *   display_description – editable description (initially matches code)
 *   default_icon        – Material icon key used when no custom image is set
 *   category            – reference field for dashboard filtering
 *   tier                – reference field for dashboard filtering
 *   pro_only            – whether this trophy requires a Pro subscription
 *   icon_url            – null on seed; set by admin to use a custom image
 *
 * Idempotent – skips any document that already exists so existing admin edits
 * are never overwritten.
 *
 * Usage (against real project – ADC / service-account):
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
 *     node scripts/seed_global_trophy_definitions.js
 *
 * Usage (against local Firestore emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *     node scripts/seed_global_trophy_definitions.js
 */

'use strict';

const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'ten-thousand-puck-challenge' });
}

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Category default icons (Material Symbols Rounded names, no _rounded suffix).
// Mirror GlobalTrophyService.iconForTrophy in Dart.
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
// Trophy catalog - mirrors GlobalTrophyService.catalog in Dart exactly.
// Never rename IDs; they are persisted in user documents.
// ---------------------------------------------------------------------------
const TROPHIES = [
    // =========================================================================
    // FREE TROPHIES
    // =========================================================================

    // ── Volume ────────────────────────────────────────────────────────────────
    { id: 'g_first_shot', name: 'Biscuit on Ice', description: 'Logged your very first shot. The journey starts here.', category: 'volume', tier: 'common', proOnly: false },
    { id: 'g_shots_100', name: 'First Hundred', description: '100 shots logged. You\'re warming up.', category: 'volume', tier: 'common', proOnly: false },
    { id: 'g_shots_250', name: 'Quarter Stack', description: '250 shots logged. Getting into a rhythm.', category: 'volume', tier: 'common', proOnly: false },
    { id: 'g_shots_500', name: 'Five Hundo', description: '500 shots. Barely even tired.', category: 'volume', tier: 'common', proOnly: false },
    { id: 'g_shots_1000', name: 'Four Digits', description: '1,000 shots logged. You\'ve officially committed.', category: 'volume', tier: 'uncommon', proOnly: false },
    { id: 'g_shots_2500', name: 'Quarter Way There', description: '2,500 shots. Well past the warm-up phase.', category: 'volume', tier: 'uncommon', proOnly: false },
    { id: 'g_shots_5000', name: 'Halfway There', description: '5,000 shots. Half the challenge in the bag.', category: 'volume', tier: 'rare', proOnly: false },
    { id: 'g_shots_7500', name: 'Deep In It', description: '7,500 shots. The finish line is in sight.', category: 'volume', tier: 'rare', proOnly: false },
    { id: 'g_shots_10000', name: 'The Full Ten', description: '10,000 shots. You did the whole thing.', category: 'volume', tier: 'epic', proOnly: false },
    { id: 'g_shots_15000', name: 'Encore', description: '15,000 shots. Once wasn\'t enough for you.', category: 'volume', tier: 'epic', proOnly: false },

    // ── Sessions ──────────────────────────────────────────────────────────────
    { id: 'g_first_session', name: 'Warming Up', description: 'Finished your first shooting session.', category: 'sessions', tier: 'common', proOnly: false },
    { id: 'g_sessions_5', name: 'Five and Counting', description: '5 sessions done. You\'re forming a habit.', category: 'sessions', tier: 'common', proOnly: false },
    { id: 'g_sessions_10', name: 'Getting Reps In', description: '10 sessions in the bag. Habit forming.', category: 'sessions', tier: 'common', proOnly: false },
    { id: 'g_sessions_25', name: 'Committed', description: '25 sessions. This isn\'t a phase.', category: 'sessions', tier: 'uncommon', proOnly: false },
    { id: 'g_sessions_50', name: 'Half a Century', description: '50 sessions. You show up more than most.', category: 'sessions', tier: 'uncommon', proOnly: false },
    { id: 'g_sessions_100', name: 'Century', description: '100 sessions. You\'re a grinder.', category: 'sessions', tier: 'rare', proOnly: false },

    // ── Weekly ────────────────────────────────────────────────────────────────
    { id: 'g_week_streak_2', name: 'Back-to-Back', description: 'Shot in two consecutive weeks.', category: 'weekly', tier: 'common', proOnly: false },
    { id: 'g_week_500', name: 'Five Hundred Week', description: '500 shots in a single week. Solid output.', category: 'weekly', tier: 'common', proOnly: false },
    { id: 'g_week_1000', name: 'Thousand-Shot Week', description: '1,000 shots in a single week. That\'s a grind.', category: 'weekly', tier: 'uncommon', proOnly: false },
    { id: 'g_hundred_a_day', name: '100 a Day Keeps the Coach Away', description: '100+ shots on 7 different days in one week.', category: 'weekly', tier: 'rare', proOnly: false },

    // ── Shot Type ─────────────────────────────────────────────────────────────
    { id: 'g_wrist_50', name: 'Wristmaster Apprentice', description: '50 wrist shots logged.', category: 'shotType', tier: 'common', proOnly: false },
    { id: 'g_snap_50', name: 'Snap Happy', description: '50 snap shots logged.', category: 'shotType', tier: 'common', proOnly: false },
    { id: 'g_slap_50', name: 'Bomb Squad Rookie', description: '50 slap shots logged.', category: 'shotType', tier: 'common', proOnly: false },
    { id: 'g_backhand_50', name: 'The Other Way', description: '50 backhand shots logged.', category: 'shotType', tier: 'common', proOnly: false },
    { id: 'g_wrist_200', name: 'Snap It', description: '200 wrist shots. That release is starting to look natural.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_snap_200', name: 'Quick Draw', description: '200 snap shots. Getting quick off the stick.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_slap_200', name: 'Clearing The Zone', description: '200 slap shots. The opposition feels it.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_backhand_200', name: 'Switchblade', description: '200 backhand shots. Two sides, one threat.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_all_types_50', name: 'Complete Package', description: '50 shots of every type logged. Versatile.', category: 'shotType', tier: 'uncommon', proOnly: false },
    { id: 'g_all_types_200', name: 'No Weak Spots', description: '200 shots of every type. Defenders can\'t predict you.', category: 'shotType', tier: 'rare', proOnly: false },

    // ── Time of Day ───────────────────────────────────────────────────────────
    { id: 'g_early_riser', name: 'Early Riser', description: 'Logged a session before 6 AM. The ice is yours.', category: 'timeOfDay', tier: 'uncommon', proOnly: false },
    { id: 'g_night_owl', name: 'Night Owl', description: 'Logged a session after 10 PM. Who needs sleep?', category: 'timeOfDay', tier: 'uncommon', proOnly: false },
    { id: 'g_weekend_warrior', name: 'Weekend Warrior', description: 'Logged sessions on both Saturday and Sunday in the same weekend.', category: 'timeOfDay', tier: 'uncommon', proOnly: false },
    { id: 'g_lunch_break', name: 'Lunch Break Grinder', description: 'Logged a session between 11 AM and 1 PM.', category: 'timeOfDay', tier: 'common', proOnly: false },

    // =========================================================================
    // PRO TROPHIES
    // =========================================================================

    // ── Volume (pro) ──────────────────────────────────────────────────────────
    { id: 'g_shots_20000', name: 'Double Down', description: '20,000 shots. Two full challenges worth of reps.', category: 'volume', tier: 'epic', proOnly: true },
    { id: 'g_shots_25000', name: 'Obsessed', description: '25,000 shots. Honestly, we respect it.', category: 'volume', tier: 'legendary', proOnly: true },
    { id: 'g_shots_50000', name: 'Five Times Ten Thousand', description: '50,000 shots. Absolute menace. In the best way.', category: 'volume', tier: 'legendary', proOnly: true },

    // ── Sessions (pro) ────────────────────────────────────────────────────────
    { id: 'g_sessions_150', name: 'Regular', description: '150 sessions. You\'re practically a fixture on the ice.', category: 'sessions', tier: 'rare', proOnly: true },
    { id: 'g_sessions_250', name: 'Lifer', description: '250 sessions. This app is your therapy.', category: 'sessions', tier: 'epic', proOnly: true },
    { id: 'g_sessions_500', name: 'Cult Member', description: '500 sessions. Should we be concerned?', category: 'sessions', tier: 'legendary', proOnly: true },

    // ── Weekly (pro) ──────────────────────────────────────────────────────────
    { id: 'g_week_2000', name: 'The Grind Never Stops', description: '2,000 shots in a single week. Certified puck machine.', category: 'weekly', tier: 'epic', proOnly: true },
    { id: 'g_week_streak_4', name: 'Monthly Momentum', description: 'Shot in four consecutive weeks.', category: 'weekly', tier: 'rare', proOnly: true },
    { id: 'g_week_streak_8', name: 'Two-Month Streak', description: 'Eight weeks in a row without missing. Iron discipline.', category: 'weekly', tier: 'epic', proOnly: true },
    { id: 'g_week_streak_12', name: 'Quarter Year', description: 'Twelve straight weeks. Three months of consistent work.', category: 'weekly', tier: 'legendary', proOnly: true },
    { id: 'g_fifty_a_day_7', name: 'Daily Devotion', description: '50+ shots every day for a full week.', category: 'weekly', tier: 'rare', proOnly: true },

    // ── Shot Type (pro) ───────────────────────────────────────────────────────
    { id: 'g_wrist_500', name: 'Wrist of Steel', description: '500 wrist shots. That snap is automatic.', category: 'shotType', tier: 'rare', proOnly: true },
    { id: 'g_snap_500', name: 'Snap King', description: '500 snap shots. Quick release every time.', category: 'shotType', tier: 'rare', proOnly: true },
    { id: 'g_slap_500', name: 'Cannon', description: '500 slap shots. The boards are shaking.', category: 'shotType', tier: 'rare', proOnly: true },
    { id: 'g_backhand_500', name: 'Ambidextrous', description: '500 backhand shots. Defenders hate this.', category: 'shotType', tier: 'rare', proOnly: true },
    { id: 'g_wrist_1000', name: 'Wrister Blister', description: '1,000 wrist shots. The tape on that blade is toast.', category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_snap_1000', name: 'Hair Trigger', description: '1,000 snap shots. Blink and you\'ll miss it.', category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_slap_1000', name: 'Headhunter', description: '1,000 slap shots. Goalies are filing HR complaints.', category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_backhand_1000', name: 'Wrong Side of the Stick', description: '1,000 backhand shots. Technically ambidextrous at this point.', category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_all_types_500', name: 'The Total Package', description: '500 shots of every type. No weakness.', category: 'shotType', tier: 'epic', proOnly: true },
    { id: 'g_all_types_1000', name: 'Weapon of Mass Destruction', description: '1,000 shots of every type. You are the entire power play.', category: 'shotType', tier: 'legendary', proOnly: true },

    // ── Time of Day (pro) ─────────────────────────────────────────────────────
    { id: 'g_morning_grinder', name: 'Morning Grinder', description: '10 sessions before 6 AM. The 5 AM crew bows to you.', category: 'timeOfDay', tier: 'rare', proOnly: true },
    { id: 'g_midnight_sniper', name: 'Midnight Sniper', description: '10 sessions after 10 PM. Darkness is your shooting range.', category: 'timeOfDay', tier: 'rare', proOnly: true },
    { id: 'g_sunrise_shooter', name: 'Before The World Wakes', description: '25 sessions before 6 AM. Absolutely no excuses ever.', category: 'timeOfDay', tier: 'epic', proOnly: true },
    { id: 'g_weekend_grinder', name: 'Weekend Machine', description: 'Shot on both Saturday and Sunday for 4 consecutive weekends.', category: 'timeOfDay', tier: 'epic', proOnly: true },

    // ── Accuracy (pro) ────────────────────────────────────────────────────────
    { id: 'g_wrist_accuracy_80', name: 'Laser Wrist', description: '80%+ wrist accuracy in a single session (25+ wrist shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_snap_accuracy_80', name: 'Snap Sniper', description: '80%+ snap accuracy in a single session (25+ snap shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_slap_accuracy_80', name: 'Precision Bomb', description: '65%+ slap accuracy in a single session (20+ slap shots). Elite-level power and precision.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_backhand_accuracy_80', name: 'Silky Backhand', description: '80%+ backhand accuracy in a single session (25+ backhand shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_overall_accuracy_75', name: 'On Target', description: '75%+ overall accuracy in a session with 50+ total shots.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_wrist_accuracy_90', name: 'Surgical Wrist', description: '90%+ wrist accuracy in a single session (25+ wrist shots).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_snap_accuracy_90', name: 'Pinpoint', description: '90%+ snap accuracy in a single session (25+ snap shots).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_slap_accuracy_90', name: 'Heat Seeking', description: '75%+ slap accuracy in a single session (20+ slap shots). That bomb locks on.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_backhand_accuracy_90', name: 'Ghost Hand', description: '90%+ backhand accuracy in a single session (25+ backhand shots).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_all_types_accuracy_80', name: 'Dead Eye', description: '80%+ accuracy on every shot type in a single session (25+ each).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_perfect_session', name: 'Perfect Pull', description: '100% accuracy in a session with 25+ total shots. Nothing missed.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_perfect_session_50', name: 'Untouchable', description: '100% accuracy in a session with 50+ total shots. Godmode.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_accuracy_streak_5', name: 'Consistent', description: '70%+ overall accuracy in 5 consecutive sessions.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_accuracy_streak_10', name: 'Machine', description: '70%+ overall accuracy in 10 consecutive sessions.', category: 'accuracy', tier: 'legendary', proOnly: true },

    // ── Accuracy (common) ─────────────────────────────────────────────────────
    { id: 'g_accuracy_first_session', name: 'Eyes on the Net', description: 'Finished a session with accuracy tracked. The numbers don\'t lie.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_overall_accuracy_50', name: 'Showing Up', description: '50%+ overall accuracy in a session with 10+ shots. A start is a start.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_overall_accuracy_60', name: 'Above Average', description: '60%+ overall accuracy in a session with 25+ shots. You\'re finding it.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_wrist_accuracy_50', name: 'Wrist in Check', description: '50%+ wrist accuracy in a session (10+ wrist shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_snap_accuracy_50', name: 'Snap Study', description: '50%+ snap accuracy in a session (10+ snap shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_slap_accuracy_50', name: 'Slap Starter', description: "35%+ slap accuracy in a session (10+ slap shots). Slap shots are twice as hard \u2014 getting a third on target is real.", category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_backhand_accuracy_50', name: 'Backhand Basics', description: '50%+ backhand accuracy in a session (10+ backhand shots). Off-hand, on target.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_wrist_accuracy_60', name: 'Wrist Warm', description: '60%+ wrist accuracy in a session (15+ wrist shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_snap_accuracy_60', name: 'Finding the Snap', description: '60%+ snap accuracy in a session (15+ snap shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_slap_accuracy_60', name: 'Controlled Chaos', description: '45%+ slap accuracy in a session (15+ slap shots). Not all bombs are wild.', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_backhand_accuracy_60', name: 'Off-Hand Progress', description: '60%+ backhand accuracy in a session (15+ backhand shots).', category: 'accuracy', tier: 'common', proOnly: true },
    { id: 'g_all_types_accuracy_50', name: 'Dabbler', description: '50%+ accuracy on every shot type in a session (10+ each). No glaring weakness.', category: 'accuracy', tier: 'common', proOnly: true },

    // ── Accuracy (uncommon) ───────────────────────────────────────────────────
    { id: 'g_overall_accuracy_65', name: 'Dialed', description: '65%+ overall accuracy in a session with 30+ shots. Getting there.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_wrist_accuracy_70', name: 'Wrist Work', description: '70%+ wrist accuracy in a session (20+ wrist shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_snap_accuracy_70', name: 'Snap Sharp', description: '70%+ snap accuracy in a session (20+ snap shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_slap_accuracy_70', name: 'Locked In', description: '55%+ slap accuracy in a session (15+ slap shots). That bomb has a target.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_backhand_accuracy_70', name: 'Wrong Side Right', description: '70%+ backhand accuracy in a session (20+ backhand shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_accuracy_streak_2', name: 'Back-to-Back Accuracy', description: '65%+ overall accuracy in 2 consecutive sessions.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_accuracy_streak_3', name: 'Hat Trick Accuracy', description: '70%+ overall accuracy in 3 consecutive sessions.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_all_types_accuracy_60', name: 'All Around', description: '60%+ accuracy on every shot type in a session (10+ each).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_all_types_accuracy_70', name: 'No Weak Angle', description: '70%+ accuracy on every shot type in a session (15+ each). Defenders have no read.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_wrist_accuracy_75', name: 'Wrist Precision', description: '75%+ wrist accuracy in a session (20+ wrist shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_snap_accuracy_75', name: 'Snap Precision', description: '75%+ snap accuracy in a session (20+ snap shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_slap_accuracy_75', name: 'Slap Precision', description: '60%+ slap accuracy in a session (15+ slap shots). Rare power and precision.', category: 'accuracy', tier: 'uncommon', proOnly: true },
    { id: 'g_backhand_accuracy_75', name: 'Backhand Precision', description: '75%+ backhand accuracy in a session (20+ backhand shots).', category: 'accuracy', tier: 'uncommon', proOnly: true },

    // ── Accuracy (rare - additions) ───────────────────────────────────────────
    { id: 'g_overall_accuracy_80', name: 'Sharp Shooter', description: '80%+ overall accuracy in a session with 50+ shots.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_accuracy_streak_4', name: 'On a Roll', description: '70%+ overall accuracy in 4 consecutive sessions.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_wrist_accuracy_85', name: 'Wrist Expert', description: '85%+ wrist accuracy in a session (25+ wrist shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_snap_accuracy_85', name: 'Snap Expert', description: '85%+ snap accuracy in a session (25+ snap shots).', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_slap_accuracy_85', name: 'Slap Expert', description: '70%+ slap accuracy in a session (20+ slap shots). Pinpoint power.', category: 'accuracy', tier: 'rare', proOnly: true },
    { id: 'g_backhand_accuracy_85', name: 'Backhand Expert', description: '85%+ backhand accuracy in a session (25+ backhand shots).', category: 'accuracy', tier: 'rare', proOnly: true },

    // ── Accuracy (epic - additions) ───────────────────────────────────────────
    { id: 'g_overall_accuracy_85', name: 'Sniper Mentality', description: '85%+ overall accuracy in a session with 50+ shots.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_overall_accuracy_90', name: 'Accuracy Freak', description: '90%+ overall accuracy in a session with 50+ shots. Almost nothing misses.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_all_types_accuracy_85', name: 'Full Arsenal', description: '85%+ accuracy on every shot type in a session (25+ each).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_all_types_accuracy_90', name: 'Complete Control', description: '90%+ accuracy on every shot type in a session (25+ each). All cylinders, all accurate.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_wrist_accuracy_95', name: 'Wrist Surgeon', description: '95%+ wrist accuracy in a session (25+ wrist shots). That release is a weapon.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_snap_accuracy_95', name: 'Snap Surgeon', description: '95%+ snap accuracy in a session (25+ snap shots).', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_slap_accuracy_95', name: 'Slap Surgeon', description: '80%+ slap accuracy in a session (20+ slap shots). The bomb is now guided.', category: 'accuracy', tier: 'epic', proOnly: true },
    { id: 'g_backhand_accuracy_95', name: 'Backhand Surgeon', description: '95%+ backhand accuracy in a session (25+ backhand shots). Two hands, one killer instinct.', category: 'accuracy', tier: 'epic', proOnly: true },

    // ── Accuracy (legendary - additions) ─────────────────────────────────────
    { id: 'g_accuracy_streak_15', name: 'Reliable', description: '70%+ overall accuracy in 15 consecutive sessions. Session after session.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_accuracy_streak_20', name: 'Built Different', description: '70%+ overall accuracy in 20 consecutive sessions. Consistency is the skill.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_overall_accuracy_95', name: 'Nearly Impossible', description: '95%+ overall accuracy in a session with 50+ shots. This barely happens.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_perfect_session_75', name: 'No Mercy', description: '100% accuracy in a session with 75+ total shots. Technically flawless.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_perfect_session_100', name: 'Perfect Century', description: '100% accuracy in a session with 100+ total shots. Nothing touched the post.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_wrist_perfect', name: 'Wrist of God', description: '100% wrist accuracy in a session with 25+ wrist shots. Zero misses. Actual zero.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_snap_perfect', name: 'Snap of God', description: '100% snap accuracy in a session with 25+ snap shots.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_slap_perfect', name: 'Bomb Perfect', description: '100% slap accuracy in a session with 20+ slap shots. Full power. Full precision. Nothing missed.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_backhand_perfect', name: 'Backhand of God', description: '100% backhand accuracy in a session with 25+ backhand shots. Two hands, zero misses.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_all_types_accuracy_95', name: 'Zero Margin', description: '95%+ accuracy on every shot type in a session (25+ each). Nothing leaks.', category: 'accuracy', tier: 'legendary', proOnly: true },
    { id: 'g_all_types_perfect', name: 'Total Control', description: '100% accuracy on every shot type in a single session (25+ each). The game doesn\'t stand a chance.', category: 'accuracy', tier: 'legendary', proOnly: true },
];

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

async function seed() {
    const colRef = db.collection('global_trophy_definitions');
    const snap = await colRef.get();
    const existingIds = new Set(snap.docs.map((d) => d.id));

    const missing = TROPHIES.filter((t) => !existingIds.has(t.id));
    if (missing.length === 0) {
        console.log('All global_trophy_definitions already exist - nothing to seed.');
        return;
    }

    console.log(`Seeding ${missing.length} missing trophy definition(s)…`);

    // Firestore batch limit is 500 ops; 64 trophies fits easily.
    const batch = db.batch();
    for (const trophy of missing) {
        const ref = colRef.doc(trophy.id);
        batch.set(ref, {
            display_name: trophy.name,
            display_description: trophy.description,
            default_icon: CATEGORY_ICON[trophy.category],
            category: trophy.category,
            tier: trophy.tier,
            pro_only: trophy.proOnly,
            icon_url: null,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
    }

    await batch.commit();
    console.log(`✓ Seeded ${missing.length} trophy definition(s) into global_trophy_definitions.`);
}

seed().catch((err) => {
    console.error('Seed failed:', err);
    process.exit(1);
});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/GlobalTrophySummary.dart';

// ── Category ─────────────────────────────────────────────────────────────────

/// Behavioural grouping for global session trophies.
///
/// | Category     | Icon                             |
/// |--------------|----------------------------------|
/// | volume       | Icons.workspace_premium_rounded  |
/// | sessions     | Icons.sports_hockey_rounded      |
/// | weekly       | Icons.calendar_today_rounded     |
/// | shotType     | Icons.gps_fixed_rounded          |
/// | timeOfDay    | Icons.schedule_rounded           |
/// | accuracy     | Icons.track_changes_rounded      |
enum GlobalTrophyCategory {
  volume,
  sessions,
  weekly,
  shotType,
  timeOfDay,
  accuracy,
}

// ── Tier ──────────────────────────────────────────────────────────────────────

/// Visual rarity tier.  Uses the same colour palette as Challenger Road tiers
/// so the two systems feel unified in the shared featured showcase.
///
/// | Tier      | Colour  |
/// |-----------|---------|
/// | common    | #90A4AE |
/// | uncommon  | #66BB6A |
/// | rare      | #42A5F5 |
/// | epic      | #AB47BC |
/// | legendary | #FFD700 |
enum GlobalTrophyTier { common, uncommon, rare, epic, legendary }

// ── Definition ────────────────────────────────────────────────────────────────

/// Immutable definition of a single global-session trophy.
///
/// Instances live in [GlobalTrophyService.catalog].  Only the [id] is stored in
/// Firestore (`users/{uid}/global_trophies/summary.trophies`).
///
/// Design rules:
///  - IDs are stable snake_case strings prefixed with `g_`.
///  - `proOnly` gates the trophy behind a RevenueCat Pro entitlement.
///  - The plain icon badge design (no custom artwork) distinguishes these from
///    the CR trophies that use bespoke badge images.
class GlobalTrophyDefinition {
  /// Stable, snake_case identifier persisted in Firestore.  Never rename.
  final String id;

  /// Short display name (code-defined).
  final String name;

  /// One-sentence description (gen-Z hockey voice, code-defined).
  final String description;

  final GlobalTrophyCategory category;
  final GlobalTrophyTier tier;

  /// When true, the user must have the Pro entitlement to earn this trophy.
  final bool proOnly;

  // ── Admin-managed display overrides (stored in challenger_road_badges, type='global') ──

  /// Admin display-name override.  When non-null the UI prefers this over [name].
  /// Award logic always uses the code-defined [name].
  final String? displayName;

  /// Admin description override.  When non-null the UI prefers this.
  final String? displayDescription;

  /// Remote image URL uploaded by admins (e.g. Firebase Storage).
  /// When non-empty, the UI shows this instead of the category icon.
  final String? iconUrl;

  /// Key of a local asset to use as icon fallback when [iconUrl] is absent.
  final String? defaultIconKey;

  // ── Effective display helpers ──────────────────────────────────────────────

  String get effectiveName => displayName ?? name;
  String get effectiveDescription => displayDescription ?? description;
  String? get effectiveIconUrl => iconUrl?.trim().isEmpty == true ? null : iconUrl;

  const GlobalTrophyDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.tier,
    this.proOnly = false,
    this.displayName,
    this.displayDescription,
    this.iconUrl,
    this.defaultIconKey,
  });

  GlobalTrophyDefinition copyWith({
    String? displayName,
    String? displayDescription,
    String? iconUrl,
    String? defaultIconKey,
  }) {
    return GlobalTrophyDefinition(
      id: id,
      name: name,
      description: description,
      category: category,
      tier: tier,
      proOnly: proOnly,
      displayName: displayName ?? this.displayName,
      displayDescription: displayDescription ?? this.displayDescription,
      iconUrl: iconUrl ?? this.iconUrl,
      defaultIconKey: defaultIconKey ?? this.defaultIconKey,
    );
  }
}

// ── Input to evaluateAfterSession ─────────────────────────────────────────────

/// Lightweight session data passed to [GlobalTrophyService.evaluateAfterSession].
/// Built from the data already available at the session-save call site.
class GlobalSessionInput {
  final int total;
  final int wrist;
  final int snap;
  final int slap;
  final int backhand;

  /// Targets hit per type — only populated for Pro users.
  final int wristTargetsHit;
  final int snapTargetsHit;
  final int slapTargetsHit;
  final int backhandTargetsHit;

  /// Wall-clock time the session was saved / started (used for time-of-day
  /// trophies).  Pass [DateTime.now()] when not overriding.
  final DateTime sessionDate;

  const GlobalSessionInput({
    required this.total,
    required this.wrist,
    required this.snap,
    required this.slap,
    required this.backhand,
    this.wristTargetsHit = 0,
    this.snapTargetsHit = 0,
    this.slapTargetsHit = 0,
    this.backhandTargetsHit = 0,
    required this.sessionDate,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class GlobalTrophyService {
  final FirebaseFirestore _firestore;

  GlobalTrophyService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Firestore path
  // ---------------------------------------------------------------------------

  DocumentReference _summaryRef(String userId) => _firestore.collection('users').doc(userId).collection('global_trophies').doc('summary');

  // ---------------------------------------------------------------------------
  // Week helpers (Sunday-based, EST = UTC-5)
  // ---------------------------------------------------------------------------

  static const int _estOffsetHours = -5;

  /// Returns the most recent Sunday at 00:00 EST as a UTC [DateTime].
  static DateTime currentWeekStartUtc() {
    final nowUtc = DateTime.now().toUtc();
    // Shift to EST to find the calendar Sunday in that timezone.
    final nowEst = nowUtc.add(const Duration(hours: _estOffsetHours));
    // DateTime.weekday: Monday=1 … Sunday=7
    final daysFromSunday = nowEst.weekday % 7; // Sunday → 0, Mon → 1, … Sat → 6
    final sundayEst = DateTime(
      nowEst.year,
      nowEst.month,
      nowEst.day - daysFromSunday,
      0,
      0,
      0,
    );
    // Convert back to UTC for storage.
    return sundayEst.subtract(const Duration(hours: _estOffsetHours));
  }

  static String _dateKey(DateTime dt) {
    // Use UTC date key so it's timezone-agnostic in storage.
    final d = dt.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Summary CRUD
  // ---------------------------------------------------------------------------

  Future<GlobalTrophySummary> getUserSummary(String userId) async {
    final doc = await _summaryRef(userId).get();
    if (!doc.exists) return GlobalTrophySummary.empty();
    return GlobalTrophySummary.fromSnapshot(doc);
  }

  Stream<GlobalTrophySummary> watchUserSummary(String userId) {
    return _summaryRef(userId).snapshots().map((doc) {
      if (!doc.exists) return GlobalTrophySummary.empty();
      return GlobalTrophySummary.fromSnapshot(doc);
    });
  }

  Future<void> _saveSummary(String userId, GlobalTrophySummary summary) async {
    await _summaryRef(userId).set(summary.toMap(), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Featured trophies (shared across global + CR pools)
  // ---------------------------------------------------------------------------

  /// Persists [ids] (up to 3) as the user's featured trophies.
  Future<void> setFeaturedTrophies(String userId, List<String> ids) async {
    final clamped = ids.take(5).toList();
    await _summaryRef(userId).set(
      {'featured_trophies': clamped},
      SetOptions(merge: true),
    );
  }

  // ---------------------------------------------------------------------------
  // Admin display overrides
  // ---------------------------------------------------------------------------

  /// Admin-managed display override documents.
  /// Firestore path: challenger_road_badges (type == 'global')
  ///
  /// Supported fields on each doc:
  ///   display_name        — override trophy name shown in UI
  ///   display_description — override description shown in UI
  ///   icon_url            — remote image URL (Firebase Storage); replaces icon
  ///   default_icon        — local asset key fallback
  Query get _trophyOverridesQuery => _firestore.collection('challenger_road_badges').where('type', isEqualTo: 'global');

  /// Returns the catalog with any admin-managed display overrides applied.
  ///
  /// Reads [_trophyOverridesQuery] docs once.  When a doc exists for a trophy ID
  /// it may supply display_name, display_description, icon_url and/or
  /// default_icon; those override the code-defined copy in the UI via
  /// [GlobalTrophyDefinition.effectiveName] etc.
  /// Award logic always uses [catalog] directly and is never affected.
  Future<List<GlobalTrophyDefinition>> getTrophyCatalogForUser(String userId) async {
    try {
      final snap = await _trophyOverridesQuery.get();
      if (snap.docs.isEmpty) return catalog;
      final overrides = <String, Map<String, dynamic>>{
        for (final doc in snap.docs) doc.id: doc.data() as Map<String, dynamic>,
      };
      return catalog.map((def) {
        final ov = overrides[def.id];
        if (ov == null) return def;
        return def.copyWith(
          displayName: ov['display_name'] as String?,
          displayDescription: ov['display_description'] as String?,
          iconUrl: ov['icon_url'] as String?,
          defaultIconKey: ov['default_icon'] as String?,
        );
      }).toList();
    } catch (_) {
      return catalog;
    }
  }

  // ---------------------------------------------------------------------------
  // Trophy catalog
  // ---------------------------------------------------------------------------

  static const List<GlobalTrophyDefinition> catalog = [
    // =========================================================================
    // FREE TROPHIES
    // =========================================================================

    // ── VOLUME — all time (free) ──────────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_first_shot',
      name: 'Biscuit on Ice',
      description: 'Logged your very first shot. The journey starts here.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_100',
      name: 'First Hundred',
      description: '100 shots logged. You\'re warming up.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_500',
      name: 'Five Hundo',
      description: '500 shots. Barely even tired.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_250',
      name: 'Quarter Stack',
      description: '250 shots logged. Getting into a rhythm.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_1000',
      name: 'Four Digits',
      description: '1,000 shots logged. You\'ve officially committed.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_2500',
      name: 'Quarter Way There',
      description: '2,500 shots. Well past the warm-up phase.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_5000',
      name: 'Halfway There',
      description: '5,000 shots. Half the challenge in the bag.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.rare,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_7500',
      name: 'Deep In It',
      description: '7,500 shots. The finish line is in sight.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.rare,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_10000',
      name: 'The Full Ten',
      description: '10,000 shots. You did the whole thing.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.epic,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_15000',
      name: 'Encore',
      description: '15,000 shots. Once wasn\'t enough for you.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.epic,
    ),

    // ── SESSIONS — all time (free) ────────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_first_session',
      name: 'Warming Up',
      description: 'Finished your first shooting session.',
      category: GlobalTrophyCategory.sessions,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_sessions_5',
      name: 'Five and Counting',
      description: '5 sessions done. You\'re forming a habit.',
      category: GlobalTrophyCategory.sessions,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_sessions_10',
      name: 'Getting Reps In',
      description: '10 sessions in the bag. Habit forming.',
      category: GlobalTrophyCategory.sessions,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_sessions_25',
      name: 'Committed',
      description: '25 sessions. This isn\'t a phase.',
      category: GlobalTrophyCategory.sessions,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_sessions_50',
      name: 'Half a Century',
      description: '50 sessions. You show up more than most.',
      category: GlobalTrophyCategory.sessions,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_sessions_100',
      name: 'Century',
      description: '100 sessions. You\'re a grinder.',
      category: GlobalTrophyCategory.sessions,
      tier: GlobalTrophyTier.rare,
    ),

    // ── WEEKLY (free) ─────────────────────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_week_streak_2',
      name: 'Back-to-Back',
      description: 'Shot in two consecutive weeks.',
      category: GlobalTrophyCategory.weekly,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_week_500',
      name: 'Five Hundred Week',
      description: '500 shots in a single week. Solid output.',
      category: GlobalTrophyCategory.weekly,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_week_1000',
      name: 'Thousand-Shot Week',
      description: '1,000 shots in a single week. That\'s a grind.',
      category: GlobalTrophyCategory.weekly,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_hundred_a_day',
      name: '100 a Day Keeps the Coach Away',
      description: '100+ shots on 7 different days in one week.',
      category: GlobalTrophyCategory.weekly,
      tier: GlobalTrophyTier.rare,
    ),

    // ── SHOT TYPE (free) ──────────────────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_wrist_50',
      name: 'Wristmaster Apprentice',
      description: '50 wrist shots logged.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_snap_50',
      name: 'Snap Happy',
      description: '50 snap shots logged.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_slap_50',
      name: 'Bomb Squad Rookie',
      description: '50 slap shots logged.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_backhand_50',
      name: 'The Other Way',
      description: '50 backhand shots logged.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.common,
    ),
    GlobalTrophyDefinition(
      id: 'g_wrist_200',
      name: 'Snap It',
      description: '200 wrist shots. That release is starting to look natural.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_snap_200',
      name: 'Quick Draw',
      description: '200 snap shots. Getting quick off the stick.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_slap_200',
      name: 'Clearing The Zone',
      description: '200 slap shots. The opposition feels it.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_backhand_200',
      name: 'Switchblade',
      description: '200 backhand shots. Two sides, one threat.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_all_types_50',
      name: 'Complete Package',
      description: '50 shots of every type logged. Versatile.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_all_types_200',
      name: 'No Weak Spots',
      description: '200 shots of every type. Defenders can\'t predict you.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.rare,
    ),

    // ── TIME OF DAY (free) ────────────────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_early_riser',
      name: 'Early Riser',
      description: 'Logged a session before 6 AM. The ice is yours.',
      category: GlobalTrophyCategory.timeOfDay,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_night_owl',
      name: 'Night Owl',
      description: 'Logged a session after 10 PM. Who needs sleep?',
      category: GlobalTrophyCategory.timeOfDay,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_weekend_warrior',
      name: 'Weekend Warrior',
      description: 'Logged sessions on both Saturday and Sunday in the same weekend.',
      category: GlobalTrophyCategory.timeOfDay,
      tier: GlobalTrophyTier.uncommon,
    ),
    GlobalTrophyDefinition(
      id: 'g_lunch_break',
      name: 'Lunch Break Grinder',
      description: 'Logged a session between 11 AM and 1 PM.',
      category: GlobalTrophyCategory.timeOfDay,
      tier: GlobalTrophyTier.common,
    ),

    // =========================================================================
    // PRO TROPHIES
    // =========================================================================

    // ── VOLUME — high range (pro) ─────────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_shots_25000',
      name: 'Obsessed',
      description: '25,000 shots. Honestly, we respect it.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.legendary,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_50000',
      name: 'Five Times Ten Thousand',
      description: '50,000 shots. Absolute menace. In the best way.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.legendary,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_shots_20000',
      name: 'Double Down',
      description: '20,000 shots. Two full challenges worth of reps.',
      category: GlobalTrophyCategory.volume,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),

    // ── SESSIONS — high range (pro) ───────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_sessions_150',
      name: 'Regular',
      description: '150 sessions. You\'re practically a fixture on the ice.',
      category: GlobalTrophyCategory.sessions,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_sessions_250',
      name: 'Lifer',
      description: '250 sessions. This app is your therapy.',
      category: GlobalTrophyCategory.sessions,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_sessions_500',
      name: 'Cult Member',
      description: '500 sessions. Should we be concerned?',
      category: GlobalTrophyCategory.sessions,
      tier: GlobalTrophyTier.legendary,
      proOnly: true,
    ),

    // ── WEEKLY — high intensity (pro) ─────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_week_2000',
      name: 'The Grind Never Stops',
      description: '2,000 shots in a single week. Certified puck machine.',
      category: GlobalTrophyCategory.weekly,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_week_streak_4',
      name: 'Monthly Momentum',
      description: 'Shot in four consecutive weeks.',
      category: GlobalTrophyCategory.weekly,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_week_streak_8',
      name: 'Two-Month Streak',
      description: 'Eight weeks in a row without missing. Iron discipline.',
      category: GlobalTrophyCategory.weekly,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_week_streak_12',
      name: 'Quarter Year',
      description: 'Twelve straight weeks. Three months of consistent work.',
      category: GlobalTrophyCategory.weekly,
      tier: GlobalTrophyTier.legendary,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_fifty_a_day_7',
      name: 'Daily Devotion',
      description: '50+ shots every day for a full week.',
      category: GlobalTrophyCategory.weekly,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),

    // ── SHOT TYPE — high volume (pro) ─────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_wrist_500',
      name: 'Wrist of Steel',
      description: '500 wrist shots. That snap is automatic.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_snap_500',
      name: 'Snap King',
      description: '500 snap shots. Quick release every time.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_slap_500',
      name: 'Cannon',
      description: '500 slap shots. The boards are shaking.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_backhand_500',
      name: 'Ambidextrous',
      description: '500 backhand shots. Defenders hate this.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_wrist_1000',
      name: 'Wrister Blister',
      description: '1,000 wrist shots. The tape on that blade is toast.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_snap_1000',
      name: 'Hair Trigger',
      description: '1,000 snap shots. Blink and you\'ll miss it.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_slap_1000',
      name: 'Headhunter',
      description: '1,000 slap shots. Goalies are filing HR complaints.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_backhand_1000',
      name: 'Wrong Side of the Stick',
      description: '1,000 backhand shots. Technically ambidextrous at this point.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_all_types_500',
      name: 'The Total Package',
      description: '500 shots of every type. No weakness.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_all_types_1000',
      name: 'Weapon of Mass Destruction',
      description: '1,000 shots of every type. You are the entire power play.',
      category: GlobalTrophyCategory.shotType,
      tier: GlobalTrophyTier.legendary,
      proOnly: true,
    ),

    // ── TIME OF DAY — extremes (pro) ──────────────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_morning_grinder',
      name: 'Morning Grinder',
      description: '10 sessions before 6 AM. The 5 AM crew bows to you.',
      category: GlobalTrophyCategory.timeOfDay,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_midnight_sniper',
      name: 'Midnight Sniper',
      description: '10 sessions after 10 PM. Darkness is your shooting range.',
      category: GlobalTrophyCategory.timeOfDay,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_sunrise_shooter',
      name: 'Before The World Wakes',
      description: '25 sessions before 6 AM. Absolutely no excuses ever.',
      category: GlobalTrophyCategory.timeOfDay,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_weekend_grinder',
      name: 'Weekend Machine',
      description: 'Shot on both Saturday and Sunday for 4 consecutive weekends.',
      category: GlobalTrophyCategory.timeOfDay,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),

    // ── ACCURACY — shot-type specific (pro) ───────────────────────────────────
    GlobalTrophyDefinition(
      id: 'g_wrist_accuracy_80',
      name: 'Laser Wrist',
      description: '80%+ wrist accuracy in a single session (25+ wrist shots).',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_snap_accuracy_80',
      name: 'Snap Sniper',
      description: '80%+ snap accuracy in a single session (25+ snap shots).',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_slap_accuracy_80',
      name: 'Precision Bomb',
      description: '80%+ slap accuracy in a single session (25+ slap shots).',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_backhand_accuracy_80',
      name: 'Silky Backhand',
      description: '80%+ backhand accuracy in a single session (25+ backhand shots).',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_overall_accuracy_75',
      name: 'On Target',
      description: '75%+ overall accuracy in a session with 50+ total shots.',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_wrist_accuracy_90',
      name: 'Surgical Wrist',
      description: '90%+ wrist accuracy in a single session (25+ wrist shots).',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_snap_accuracy_90',
      name: 'Pinpoint',
      description: '90%+ snap accuracy in a single session (25+ snap shots).',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_slap_accuracy_90',
      name: 'Heat Seeking',
      description: '90%+ slap accuracy in a single session (25+ slap shots).',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_backhand_accuracy_90',
      name: 'Ghost Hand',
      description: '90%+ backhand accuracy in a single session (25+ backhand shots).',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_all_types_accuracy_80',
      name: 'Dead Eye',
      description: '80%+ accuracy on every shot type in a single session (25+ each).',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_perfect_session',
      name: 'Perfect Pull',
      description: '100% accuracy in a session with 25+ total shots. Nothing missed.',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.epic,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_perfect_session_50',
      name: 'Untouchable',
      description: '100% accuracy in a session with 50+ total shots. Godmode.',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.legendary,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_accuracy_streak_5',
      name: 'Consistent',
      description: '70%+ overall accuracy in 5 consecutive sessions.',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.rare,
      proOnly: true,
    ),
    GlobalTrophyDefinition(
      id: 'g_accuracy_streak_10',
      name: 'Machine',
      description: '70%+ overall accuracy in 10 consecutive sessions.',
      category: GlobalTrophyCategory.accuracy,
      tier: GlobalTrophyTier.legendary,
      proOnly: true,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Icon / colour helpers
  // ---------------------------------------------------------------------------

  static IconData iconForTrophy(GlobalTrophyDefinition def) {
    switch (def.category) {
      case GlobalTrophyCategory.volume:
        return Icons.workspace_premium_rounded;
      case GlobalTrophyCategory.sessions:
        return Icons.sports_hockey_rounded;
      case GlobalTrophyCategory.weekly:
        return Icons.calendar_today_rounded;
      case GlobalTrophyCategory.shotType:
        return Icons.gps_fixed_rounded;
      case GlobalTrophyCategory.timeOfDay:
        return Icons.schedule_rounded;
      case GlobalTrophyCategory.accuracy:
        return Icons.track_changes_rounded;
    }
  }

  static Color colorForTrophy(GlobalTrophyDefinition def) {
    switch (def.tier) {
      case GlobalTrophyTier.legendary:
        return const Color(0xFFFFD700);
      case GlobalTrophyTier.epic:
        return const Color(0xFFAB47BC);
      case GlobalTrophyTier.rare:
        return const Color(0xFF42A5F5);
      case GlobalTrophyTier.uncommon:
        return const Color(0xFF66BB6A);
      case GlobalTrophyTier.common:
        return const Color(0xFF90A4AE);
    }
  }

  static String tierLabel(GlobalTrophyTier tier) {
    switch (tier) {
      case GlobalTrophyTier.legendary:
        return 'Legendary';
      case GlobalTrophyTier.epic:
        return 'Epic';
      case GlobalTrophyTier.rare:
        return 'Rare';
      case GlobalTrophyTier.uncommon:
        return 'Uncommon';
      case GlobalTrophyTier.common:
        return 'Common';
    }
  }

  // ---------------------------------------------------------------------------
  // Core evaluation
  // ---------------------------------------------------------------------------

  /// Called after every session save — both regular training sessions and
  /// Challenger Road sessions. CR sessions carry full per-type shot data
  /// (each challenge requires a specific shot type, stored in `shots`), so
  /// all trophy categories including shot-type and accuracy accumulate from
  /// both session types.
  ///
  /// 1. Reads or initialises the user's [GlobalTrophySummary].
  /// 2. Rolls the weekly cache forward if the calendar week has changed.
  /// 3. Increments all-time and weekly accumulators with [session] data.
  /// 4. Evaluates the catalog against the updated accumulators.
  /// 5. Persists the updated summary.
  /// 6. Returns the [GlobalTrophyDefinition]s that were newly earned.
  Future<List<GlobalTrophyDefinition>> evaluateAfterSession(
    String userId,
    GlobalSessionInput session, {
    bool isPro = false,
  }) async {
    final weekStart = currentWeekStartUtc();
    GlobalTrophySummary summary;

    try {
      summary = await getUserSummary(userId);
    } catch (_) {
      summary = GlobalTrophySummary.empty();
    }

    // ── Initialise tracking anchor on first write ────────────────────────────
    final trackingStart = summary.trackingStartedAt ?? weekStart;

    // ── Roll weekly cache if we crossed into a new week ──────────────────────
    final bool isNewWeek = summary.currentWeekStart == null || summary.currentWeekStart!.isBefore(weekStart);

    int weekTotal = isNewWeek ? 0 : summary.currentWeekTotal;
    List<GlobalWeeklySessionEntry> weekDays = isNewWeek ? [] : List<GlobalWeeklySessionEntry>.from(summary.currentWeekDays);

    // ── Accumulate this session into the weekly day-bucket ───────────────────
    final todayKey = _dateKey(session.sessionDate);
    final existingIdx = weekDays.indexWhere((e) => e.dateKey == todayKey);
    if (existingIdx >= 0) {
      weekDays[existingIdx] = GlobalWeeklySessionEntry(
        dateKey: todayKey,
        total: weekDays[existingIdx].total + session.total,
      );
    } else {
      weekDays.add(GlobalWeeklySessionEntry(dateKey: todayKey, total: session.total));
    }
    weekTotal += session.total;

    // ── Compute new extended counters ─────────────────────────────────────────
    final localHour = ((session.sessionDate.toUtc().hour + _estOffsetHours) % 24 + 24) % 24;
    final isEarlyMorning = localHour < 6;
    final isLateNight = localHour >= 22;

    // Week streak: how many consecutive weeks (including this one) had sessions.
    int newWeekStreak;
    if (isNewWeek) {
      final prevStart = summary.currentWeekStart;
      final prevHadSessions = summary.currentWeekDays.isNotEmpty;
      final wasConsecutiveWeek = prevStart != null && weekStart.difference(prevStart).inDays == 7 && prevHadSessions;
      newWeekStreak = wasConsecutiveWeek ? summary.weekStreak + 1 : 1;
    } else {
      newWeekStreak = summary.weekStreak > 0 ? summary.weekStreak : 1;
    }

    // Consecutive weekend count: past weeks where both Sat AND Sun had sessions.
    int newConsecutiveWeekendCount = summary.consecutiveWeekendCount;
    if (isNewWeek && summary.currentWeekStart != null) {
      final prevSatKey = _weekDayKey(summary.currentWeekStart, 6);
      final prevSunKey = _weekDayKey(summary.currentWeekStart, 0);
      final prevHadBothDays = summary.currentWeekDays.any((e) => e.dateKey == prevSatKey) && summary.currentWeekDays.any((e) => e.dateKey == prevSunKey);
      final wasConsecutiveWeek = weekStart.difference(summary.currentWeekStart!).inDays == 7;
      if (prevHadBothDays && wasConsecutiveWeek) {
        newConsecutiveWeekendCount += 1;
      } else {
        newConsecutiveWeekendCount = 0; // streak broken
      }
    }

    // Accuracy streak: consecutive sessions with 70%+ overall accuracy (pro only).
    int newAccuracyStreak = summary.currentAccuracyStreak;
    if (isPro) {
      final typedTotal = session.wrist + session.snap + session.slap + session.backhand;
      if (typedTotal > 0) {
        final totalHits = session.wristTargetsHit + session.snapTargetsHit + session.slapTargetsHit + session.backhandTargetsHit;
        if (totalHits / typedTotal >= 0.70) {
          newAccuracyStreak += 1;
        } else {
          newAccuracyStreak = 0;
        }
      }
    }

    // ── Increment all-time accumulators ──────────────────────────────────────
    final newSummary = summary.copyWith(
      trackingStartedAt: trackingStart,
      allTimeTotal: summary.allTimeTotal + session.total,
      allTimeWrist: summary.allTimeWrist + session.wrist,
      allTimeSnap: summary.allTimeSnap + session.snap,
      allTimeSlap: summary.allTimeSlap + session.slap,
      allTimeBackhand: summary.allTimeBackhand + session.backhand,
      allTimeSessions: summary.allTimeSessions + 1,
      currentWeekStart: weekStart,
      currentWeekTotal: weekTotal,
      currentWeekDays: weekDays,
      weekStreak: newWeekStreak,
      earlyMorningSessions: summary.earlyMorningSessions + (isEarlyMorning ? 1 : 0),
      lateNightSessions: summary.lateNightSessions + (isLateNight ? 1 : 0),
      consecutiveWeekendCount: newConsecutiveWeekendCount,
      currentAccuracyStreak: newAccuracyStreak,
    );

    // ── Run trophy checks ─────────────────────────────────────────────────────
    final newlyEarned = _evaluate(
      prev: summary,
      updated: newSummary,
      session: session,
      isPro: isPro,
    );

    // Append newly-earned IDs to the trophy list.
    final updatedTrophies = List<String>.from(newSummary.trophies)..addAll(newlyEarned.map((d) => d.id));

    final finalSummary = newSummary.copyWith(trophies: updatedTrophies);

    // ── Persist ───────────────────────────────────────────────────────────────
    try {
      await _saveSummary(userId, finalSummary);
    } catch (_) {
      // Best-effort: never block the session save flow.
    }

    return newlyEarned;
  }

  // ---------------------------------------------------------------------------
  // Internal: diff earned set and check each criterion
  // ---------------------------------------------------------------------------

  List<GlobalTrophyDefinition> _evaluate({
    required GlobalTrophySummary prev,
    required GlobalTrophySummary updated,
    required GlobalSessionInput session,
    required bool isPro,
  }) {
    final earnedIds = updated.trophies.toSet();
    final newlyEarned = <GlobalTrophyDefinition>[];

    void maybeAward(GlobalTrophyDefinition def) {
      if (def.proOnly && !isPro) return;
      if (earnedIds.contains(def.id)) return;
      newlyEarned.add(def);
      earnedIds.add(def.id);
    }

    GlobalTrophyDefinition? findDef(String id) => catalog.where((d) => d.id == id).firstOrNull;

    void check(String id) {
      final def = findDef(id);
      if (def != null) maybeAward(def);
    }

    final t = updated.allTimeTotal;
    final sess = updated.allTimeSessions;
    final weekTotal = updated.currentWeekTotal;

    // ── VOLUME ────────────────────────────────────────────────────────────────
    if (t >= 1) check('g_first_shot');
    if (t >= 100) check('g_shots_100');
    if (t >= 250) check('g_shots_250');
    if (t >= 500) check('g_shots_500');
    if (t >= 1000) check('g_shots_1000');
    if (t >= 2500) check('g_shots_2500');
    if (t >= 5000) check('g_shots_5000');
    if (t >= 7500) check('g_shots_7500');
    if (t >= 10000) check('g_shots_10000');
    if (t >= 15000) check('g_shots_15000');
    if (t >= 20000) check('g_shots_20000');
    if (t >= 25000) check('g_shots_25000');
    if (t >= 50000) check('g_shots_50000');

    // ── SESSIONS ──────────────────────────────────────────────────────────────
    if (sess >= 1) check('g_first_session');
    if (sess >= 5) check('g_sessions_5');
    if (sess >= 10) check('g_sessions_10');
    if (sess >= 25) check('g_sessions_25');
    if (sess >= 50) check('g_sessions_50');
    if (sess >= 100) check('g_sessions_100');
    if (sess >= 150) check('g_sessions_150');
    if (sess >= 250) check('g_sessions_250');
    if (sess >= 500) check('g_sessions_500');

    // ── WEEKLY VOLUME ─────────────────────────────────────────────────────────
    if (weekTotal >= 500) check('g_week_500');
    if (weekTotal >= 1000) check('g_week_1000');
    if (weekTotal >= 2000) check('g_week_2000');

    // 100-a-day: 7 distinct days in the current week each with ≥100 shots.
    final hundredDayCount = updated.currentWeekDays.where((e) => e.total >= 100).length;
    if (hundredDayCount >= 7) check('g_hundred_a_day');

    // 50-a-day: 7 distinct days each with ≥50 shots (pro).
    final fiftyDayCount = updated.currentWeekDays.where((e) => e.total >= 50).length;
    if (fiftyDayCount >= 7) check('g_fifty_a_day_7');

    // ── WEEK STREAK ───────────────────────────────────────────────────────────
    if (updated.weekStreak >= 2) check('g_week_streak_2');
    if (updated.weekStreak >= 4) check('g_week_streak_4');
    if (updated.weekStreak >= 8) check('g_week_streak_8');
    if (updated.weekStreak >= 12) check('g_week_streak_12');

    // ── SHOT TYPE ─────────────────────────────────────────────────────────────
    if (updated.allTimeWrist >= 50) check('g_wrist_50');
    if (updated.allTimeSnap >= 50) check('g_snap_50');
    if (updated.allTimeSlap >= 50) check('g_slap_50');
    if (updated.allTimeBackhand >= 50) check('g_backhand_50');
    if (updated.allTimeWrist >= 50 && updated.allTimeSnap >= 50 && updated.allTimeSlap >= 50 && updated.allTimeBackhand >= 50) check('g_all_types_50');

    if (updated.allTimeWrist >= 200) check('g_wrist_200');
    if (updated.allTimeSnap >= 200) check('g_snap_200');
    if (updated.allTimeSlap >= 200) check('g_slap_200');
    if (updated.allTimeBackhand >= 200) check('g_backhand_200');
    if (updated.allTimeWrist >= 200 && updated.allTimeSnap >= 200 && updated.allTimeSlap >= 200 && updated.allTimeBackhand >= 200) check('g_all_types_200');

    if (updated.allTimeWrist >= 500) check('g_wrist_500');
    if (updated.allTimeSnap >= 500) check('g_snap_500');
    if (updated.allTimeSlap >= 500) check('g_slap_500');
    if (updated.allTimeBackhand >= 500) check('g_backhand_500');
    if (updated.allTimeWrist >= 500 && updated.allTimeSnap >= 500 && updated.allTimeSlap >= 500 && updated.allTimeBackhand >= 500) check('g_all_types_500');

    if (updated.allTimeWrist >= 1000) check('g_wrist_1000');
    if (updated.allTimeSnap >= 1000) check('g_snap_1000');
    if (updated.allTimeSlap >= 1000) check('g_slap_1000');
    if (updated.allTimeBackhand >= 1000) check('g_backhand_1000');
    if (updated.allTimeWrist >= 1000 && updated.allTimeSnap >= 1000 && updated.allTimeSlap >= 1000 && updated.allTimeBackhand >= 1000) check('g_all_types_1000');

    // ── TIME OF DAY ───────────────────────────────────────────────────────────
    // Counters (earlyMorningSessions, lateNightSessions) already updated in
    // evaluateAfterSession before _evaluate is called.
    final localHour = ((session.sessionDate.toUtc().hour + _estOffsetHours) % 24 + 24) % 24;

    // One-time trophies based on first occurrence.
    if (updated.earlyMorningSessions >= 1) check('g_early_riser');
    if (updated.lateNightSessions >= 1) check('g_night_owl');

    // Lunch break: session between 11:00 and 13:00 local.
    if (localHour >= 11 && localHour < 13) check('g_lunch_break');

    // Weekend warrior: both Sat AND Sun in the current week.
    final satKey = _weekDayKey(updated.currentWeekStart, 6);
    final sunKey = _weekDayKey(updated.currentWeekStart, 0);
    final hasSat = updated.currentWeekDays.any((e) => e.dateKey == satKey);
    final hasSun = updated.currentWeekDays.any((e) => e.dateKey == sunKey);
    if (hasSat && hasSun) check('g_weekend_warrior');

    // Counter-based time-of-day trophies (pro).
    if (updated.earlyMorningSessions >= 10) check('g_morning_grinder');
    if (updated.lateNightSessions >= 10) check('g_midnight_sniper');
    if (updated.earlyMorningSessions >= 25) check('g_sunrise_shooter');

    // Weekend grinder: 4 consecutive complete weekends.
    // consecutiveWeekendCount tracks PAST complete weekends.
    // Check if current week also has both days to extend it.
    final curWeekHasBothDays = hasSat && hasSun;
    final effectiveWeekendStreak = updated.consecutiveWeekendCount + (curWeekHasBothDays ? 1 : 0);
    if (effectiveWeekendStreak >= 4) check('g_weekend_grinder');

    // ── ACCURACY (pro-only, session-specific) ─────────────────────────────────
    if (isPro) {
      const int kMin = 25;
      const int kMin50 = 50;

      final wristAcc = session.wrist >= kMin ? session.wristTargetsHit / session.wrist : 0.0;
      final snapAcc = session.snap >= kMin ? session.snapTargetsHit / session.snap : 0.0;
      final slapAcc = session.slap >= kMin ? session.slapTargetsHit / session.slap : 0.0;
      final backhandAcc = session.backhand >= kMin ? session.backhandTargetsHit / session.backhand : 0.0;

      if (session.wrist >= kMin && wristAcc >= 0.80) check('g_wrist_accuracy_80');
      if (session.snap >= kMin && snapAcc >= 0.80) check('g_snap_accuracy_80');
      if (session.slap >= kMin && slapAcc >= 0.80) check('g_slap_accuracy_80');
      if (session.backhand >= kMin && backhandAcc >= 0.80) check('g_backhand_accuracy_80');

      if (session.wrist >= kMin && wristAcc >= 0.90) check('g_wrist_accuracy_90');
      if (session.snap >= kMin && snapAcc >= 0.90) check('g_snap_accuracy_90');
      if (session.slap >= kMin && slapAcc >= 0.90) check('g_slap_accuracy_90');
      if (session.backhand >= kMin && backhandAcc >= 0.90) check('g_backhand_accuracy_90');

      // All types ≥80% in same session with ≥25 each.
      if (session.wrist >= kMin && session.snap >= kMin && session.slap >= kMin && session.backhand >= kMin && wristAcc >= 0.80 && snapAcc >= 0.80 && slapAcc >= 0.80 && backhandAcc >= 0.80) check('g_all_types_accuracy_80');

      // Overall accuracy across all shots taken in this session.
      final typedTotal = session.wrist + session.snap + session.slap + session.backhand;
      final totalHits = session.wristTargetsHit + session.snapTargetsHit + session.slapTargetsHit + session.backhandTargetsHit;

      if (typedTotal >= kMin50 && typedTotal > 0 && totalHits / typedTotal >= 0.75) check('g_overall_accuracy_75');

      // Perfect session: 100% accuracy.
      if (typedTotal >= kMin && typedTotal > 0 && totalHits == typedTotal) {
        check('g_perfect_session');
      }
      if (typedTotal >= kMin50 && typedTotal > 0 && totalHits == typedTotal) {
        check('g_perfect_session_50');
      }

      // Accuracy streak trophies.
      if (updated.currentAccuracyStreak >= 5) check('g_accuracy_streak_5');
      if (updated.currentAccuracyStreak >= 10) check('g_accuracy_streak_10');
    }

    return newlyEarned;
  }

  /// Returns the YYYY-MM-DD key for [weekStart] + [daysFromSunday] offset.
  static String _weekDayKey(DateTime? weekStart, int daysFromSunday) {
    if (weekStart == null) return '';
    final day = weekStart.toUtc().add(Duration(days: daysFromSunday));
    return _dateKey(day);
  }
}

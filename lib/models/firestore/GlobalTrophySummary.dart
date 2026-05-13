import 'package:cloud_firestore/cloud_firestore.dart';

/// A snapshot of per-day session data stored inside the current-week cache.
///
/// Only the total shot count is needed for weekly-volume and "100-a-day" trophy
/// evaluation; the full session payload is not stored here.
class GlobalWeeklySessionEntry {
  /// Date key in 'YYYY-MM-DD' format (UTC) used to deduplicate days.
  final String dateKey;

  /// Total shots logged across all sessions on this day.
  final int total;

  const GlobalWeeklySessionEntry({required this.dateKey, required this.total});

  factory GlobalWeeklySessionEntry.fromMap(Map<String, dynamic> map) {
    return GlobalWeeklySessionEntry(
      dateKey: map['date_key'] as String? ?? '',
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'date_key': dateKey,
        'total': total,
      };
}

/// Persisted in `users/{uid}/global_trophies/summary`.
///
/// Mirrors the pattern used by [ChallengerRoadUserSummary]:
/// - Only IDs are stored in Firestore (trophy definitions live in code).
/// - Cumulative counters are maintained client-side and incremented after each
///   session save, so award evaluation never needs a separate Firestore read of
///   the full session history.
/// - `tracking_started_at` is set once to the Sunday-of-current-week when the
///   doc is first created, and never changed - ensuring we only award trophies
///   for sessions from that point forward.
class GlobalTrophySummary {
  // ── Earned trophies ──────────────────────────────────────────────────────

  /// Stable IDs of all earned global trophies.
  final List<String> trophies;

  /// Up to 5 trophy IDs (from either the global session pool or Challenger
  /// Road) the user has chosen to feature on their profile. Stored here as
  /// the single source of truth for the unified trophy case showcase.
  final List<String> featuredTrophies;

  // ── Forward-only tracking anchor ─────────────────────────────────────────

  /// The Sunday 00:00 EST of the week in which global-trophy tracking was
  /// first enabled for this user. Sessions before this date are ignored.
  final DateTime? trackingStartedAt;

  // ── All-time accumulators (since trackingStartedAt) ──────────────────────

  final int allTimeTotal;
  final int allTimeWrist;
  final int allTimeSnap;
  final int allTimeSlap;
  final int allTimeBackhand;

  /// Total number of normal (non-CR) sessions since tracking started.
  final int allTimeSessions;

  // ── Current-week rolling window ──────────────────────────────────────────

  /// Sunday 00:00 EST of the week currently being tracked.
  final DateTime? currentWeekStart;

  /// Running total of shots taken in the current week.
  final int currentWeekTotal;

  /// Per-day shot entries for the current week.  Max 7 entries.
  final List<GlobalWeeklySessionEntry> currentWeekDays;

  // ── Extended tracking counters ────────────────────────────────────────────

  /// Number of consecutive weeks (including the current) with ≥1 session.
  final int weekStreak;

  /// All-time count of sessions started before 06:00 local (EST).
  final int earlyMorningSessions;

  /// All-time count of sessions started at or after 22:00 local (EST).
  final int lateNightSessions;

  /// Count of past consecutive weeks where both Saturday AND Sunday had a session.
  /// The current in-progress week is not included until it rolls over.
  final int consecutiveWeekendCount;

  /// Current streak of sessions with 70%+ overall accuracy (pro-gated).
  /// Resets to 0 when a session falls below the threshold.
  final int currentAccuracyStreak;

  /// Version of the one-time historical backfill that has been applied.
  /// null = not yet run. Bump [GlobalTrophyBackfillService.kBackfillVersion]
  /// to re-trigger for all users.
  final int? backfillVersion;

  DocumentReference? reference;

  GlobalTrophySummary({
    required this.trophies,
    this.featuredTrophies = const [],
    this.trackingStartedAt,
    this.allTimeTotal = 0,
    this.allTimeWrist = 0,
    this.allTimeSnap = 0,
    this.allTimeSlap = 0,
    this.allTimeBackhand = 0,
    this.allTimeSessions = 0,
    this.currentWeekStart,
    this.currentWeekTotal = 0,
    this.currentWeekDays = const [],
    this.weekStreak = 0,
    this.earlyMorningSessions = 0,
    this.lateNightSessions = 0,
    this.consecutiveWeekendCount = 0,
    this.currentAccuracyStreak = 0,
    this.backfillVersion,
    this.reference,
  });

  GlobalTrophySummary.empty()
      : trophies = [],
        featuredTrophies = [],
        trackingStartedAt = null,
        allTimeTotal = 0,
        allTimeWrist = 0,
        allTimeSnap = 0,
        allTimeSlap = 0,
        allTimeBackhand = 0,
        allTimeSessions = 0,
        currentWeekStart = null,
        currentWeekTotal = 0,
        currentWeekDays = [],
        weekStreak = 0,
        earlyMorningSessions = 0,
        lateNightSessions = 0,
        consecutiveWeekendCount = 0,
        currentAccuracyStreak = 0,
        backfillVersion = null;

  factory GlobalTrophySummary.fromMap(Map<String, dynamic> map, {DocumentReference? reference}) {
    DateTime? parseTimestamp(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    final rawDays = map['current_week_days'];
    final days = rawDays is List ? rawDays.whereType<Map<String, dynamic>>().map(GlobalWeeklySessionEntry.fromMap).toList() : <GlobalWeeklySessionEntry>[];

    return GlobalTrophySummary(
      trophies: List<String>.from(map['trophies'] ?? []),
      featuredTrophies: List<String>.from(map['featured_trophies'] ?? []),
      trackingStartedAt: parseTimestamp(map['tracking_started_at']),
      allTimeTotal: (map['all_time_total'] as num?)?.toInt() ?? 0,
      allTimeWrist: (map['all_time_wrist'] as num?)?.toInt() ?? 0,
      allTimeSnap: (map['all_time_snap'] as num?)?.toInt() ?? 0,
      allTimeSlap: (map['all_time_slap'] as num?)?.toInt() ?? 0,
      allTimeBackhand: (map['all_time_backhand'] as num?)?.toInt() ?? 0,
      allTimeSessions: (map['all_time_sessions'] as num?)?.toInt() ?? 0,
      currentWeekStart: parseTimestamp(map['current_week_start']),
      currentWeekTotal: (map['current_week_total'] as num?)?.toInt() ?? 0,
      currentWeekDays: days,
      weekStreak: (map['week_streak'] as num?)?.toInt() ?? 0,
      earlyMorningSessions: (map['early_morning_sessions'] as num?)?.toInt() ?? 0,
      lateNightSessions: (map['late_night_sessions'] as num?)?.toInt() ?? 0,
      consecutiveWeekendCount: (map['consecutive_weekend_count'] as num?)?.toInt() ?? 0,
      currentAccuracyStreak: (map['current_accuracy_streak'] as num?)?.toInt() ?? 0,
      backfillVersion: (map['backfill_version'] as num?)?.toInt(),
      reference: reference,
    );
  }

  Map<String, dynamic> toMap() => {
        'trophies': trophies,
        'featured_trophies': featuredTrophies,
        if (trackingStartedAt != null) 'tracking_started_at': Timestamp.fromDate(trackingStartedAt!),
        'all_time_total': allTimeTotal,
        'all_time_wrist': allTimeWrist,
        'all_time_snap': allTimeSnap,
        'all_time_slap': allTimeSlap,
        'all_time_backhand': allTimeBackhand,
        'all_time_sessions': allTimeSessions,
        if (currentWeekStart != null) 'current_week_start': Timestamp.fromDate(currentWeekStart!),
        'current_week_total': currentWeekTotal,
        'current_week_days': currentWeekDays.map((e) => e.toMap()).toList(),
        'week_streak': weekStreak,
        'early_morning_sessions': earlyMorningSessions,
        'late_night_sessions': lateNightSessions,
        'consecutive_weekend_count': consecutiveWeekendCount,
        'current_accuracy_streak': currentAccuracyStreak,
        if (backfillVersion != null) 'backfill_version': backfillVersion,
      };

  GlobalTrophySummary copyWith({
    List<String>? trophies,
    List<String>? featuredTrophies,
    DateTime? trackingStartedAt,
    int? allTimeTotal,
    int? allTimeWrist,
    int? allTimeSnap,
    int? allTimeSlap,
    int? allTimeBackhand,
    int? allTimeSessions,
    DateTime? currentWeekStart,
    int? currentWeekTotal,
    List<GlobalWeeklySessionEntry>? currentWeekDays,
    int? weekStreak,
    int? earlyMorningSessions,
    int? lateNightSessions,
    int? consecutiveWeekendCount,
    int? currentAccuracyStreak,
    int? backfillVersion,
    DocumentReference? reference,
  }) {
    return GlobalTrophySummary(
      trophies: trophies ?? this.trophies,
      featuredTrophies: featuredTrophies ?? this.featuredTrophies,
      trackingStartedAt: trackingStartedAt ?? this.trackingStartedAt,
      allTimeTotal: allTimeTotal ?? this.allTimeTotal,
      allTimeWrist: allTimeWrist ?? this.allTimeWrist,
      allTimeSnap: allTimeSnap ?? this.allTimeSnap,
      allTimeSlap: allTimeSlap ?? this.allTimeSlap,
      allTimeBackhand: allTimeBackhand ?? this.allTimeBackhand,
      allTimeSessions: allTimeSessions ?? this.allTimeSessions,
      currentWeekStart: currentWeekStart ?? this.currentWeekStart,
      currentWeekTotal: currentWeekTotal ?? this.currentWeekTotal,
      currentWeekDays: currentWeekDays ?? this.currentWeekDays,
      weekStreak: weekStreak ?? this.weekStreak,
      earlyMorningSessions: earlyMorningSessions ?? this.earlyMorningSessions,
      lateNightSessions: lateNightSessions ?? this.lateNightSessions,
      consecutiveWeekendCount: consecutiveWeekendCount ?? this.consecutiveWeekendCount,
      currentAccuracyStreak: currentAccuracyStreak ?? this.currentAccuracyStreak,
      backfillVersion: backfillVersion ?? this.backfillVersion,
      reference: reference ?? this.reference,
    );
  }

  factory GlobalTrophySummary.fromSnapshot(DocumentSnapshot snapshot) => GlobalTrophySummary.fromMap(
        snapshot.data() as Map<String, dynamic>,
        reference: snapshot.reference,
      );
}

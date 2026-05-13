import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/GlobalTrophySummary.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/services/GlobalTrophyService.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API types
// ─────────────────────────────────────────────────────────────────────────────

/// Bump this when the backfill logic changes significantly enough to re-run.
const int kBackfillVersion = 1;

/// Result of a historical backfill computation.
class BackfillResult {
  /// Trophies earned historically that are not yet recorded in the summary.
  final List<GlobalTrophyDefinition> earnedTrophies;

  /// Fully reconstructed summary with all counters populated from history.
  /// Always persisted (regardless of whether the user claims trophies) so
  /// that forward evaluation works correctly from the first new session.
  final GlobalTrophySummary historicalSummary;

  const BackfillResult({
    required this.earnedTrophies,
    required this.historicalSummary,
  });

  bool get hasTrophies => earnedTrophies.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class GlobalTrophyBackfillService {
  static const int _estOffsetHours = -5;

  final FirebaseFirestore _firestore;

  GlobalTrophyBackfillService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns null if the backfill has already been applied (backfillVersion is
  /// set). Otherwise loads all historical sessions, computes the reconstructed
  /// summary, and returns the result without persisting anything.
  Future<BackfillResult?> computeIfNeeded(String userId, bool isPro) async {
    final existing = await GlobalTrophyService().getUserSummary(userId);
    if (existing.backfillVersion != null) return null;

    final sessions = await _loadAllSessions(userId);
    return _compute(existing, sessions, isPro);
  }

  /// Persists the backfill result.
  ///
  /// When [award] is true the newly earned trophies are added to the summary's
  /// `trophies` list and the user sees them in the collection.
  /// When [award] is false the summary counters are still updated (so forward
  /// evaluation works) but no new trophy IDs are written — the user's slate
  /// starts fresh from now without false "first shot" re-awards.
  Future<void> apply(
    String userId,
    BackfillResult result, {
    required bool award,
  }) async {
    final summary = result.historicalSummary;
    final updatedTrophies = award ? (List<String>.from(summary.trophies)..addAll(result.earnedTrophies.map((d) => d.id))) : summary.trophies;

    final finalSummary = summary.copyWith(
      trophies: updatedTrophies,
      backfillVersion: kBackfillVersion,
    );

    await _firestore.collection('users').doc(userId).collection('global_trophies').doc('summary').set(finalSummary.toMap(), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Session loading (iterates all iterations → sessions for the user)
  // ---------------------------------------------------------------------------

  Future<List<ShootingSession>> _loadAllSessions(String userId) async {
    final result = <ShootingSession>[];
    try {
      final iterSnap = await _firestore.collection('iterations').doc(userId).collection('iterations').get();

      for (final iterDoc in iterSnap.docs) {
        try {
          final sessSnap = await iterDoc.reference.collection('sessions').get();
          for (final sessDoc in sessSnap.docs) {
            try {
              result.add(ShootingSession.fromSnapshot(sessDoc));
            } catch (_) {
              // Skip malformed session documents.
            }
          }
        } catch (_) {
          // Skip iterations that fail to load.
        }
      }
    } catch (_) {
      // If we can't read iterations at all, return empty — caller handles it.
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Core computation
  // ---------------------------------------------------------------------------

  BackfillResult _compute(
    GlobalTrophySummary existing,
    List<ShootingSession> sessions,
    bool isPro,
  ) {
    // Filter to regular (non-CR) sessions with required fields, sorted by date.
    final valid = sessions.where((s) => s.isChallengerRoad != true && s.date != null && s.total != null).toList()..sort((a, b) => a.date!.compareTo(b.date!));

    if (valid.isEmpty) {
      // Nothing to backfill — just mark as done.
      return BackfillResult(
        earnedTrophies: [],
        historicalSummary: existing.copyWith(backfillVersion: kBackfillVersion),
      );
    }

    // ── Aggregate totals ────────────────────────────────────────────────────
    int allTimeTotal = 0;
    int allTimeWrist = 0;
    int allTimeSnap = 0;
    int allTimeSlap = 0;
    int allTimeBackhand = 0;
    int earlyMorningSessions = 0;
    int lateNightSessions = 0;
    bool hasLunchBreak = false;

    // ── Accuracy best-across-all-sessions ───────────────────────────────────
    double bestWristAcc = 0;
    double bestSnapAcc = 0;
    double bestSlapAcc = 0;
    double bestBackhandAcc = 0;
    double bestOverallAcc25 = 0;
    double bestOverallAcc50 = 0;
    bool hasPerfect25 = false;
    bool hasPerfect50 = false;
    bool hasAllTypesAcc80 = false;
    int maxAccuracyStreak = 0;
    int currentAccuracyStreak = 0;

    // ── Weekly bucketing: weekKey → { dateKey → total } ─────────────────────
    final Map<String, Map<String, int>> weekDayTotals = {};

    for (final s in valid) {
      final total = s.total ?? 0;
      final wrist = s.totalWrist ?? 0;
      final snap = s.totalSnap ?? 0;
      final slap = s.totalSlap ?? 0;
      final backhand = s.totalBackhand ?? 0;

      allTimeTotal += total;
      allTimeWrist += wrist;
      allTimeSnap += snap;
      allTimeSlap += slap;
      allTimeBackhand += backhand;

      // Time-of-day (EST)
      final localHour = ((s.date!.toUtc().hour + _estOffsetHours) % 24 + 24) % 24;
      if (localHour < 6) earlyMorningSessions++;
      if (localHour >= 22) lateNightSessions++;
      if (localHour >= 11 && localHour < 13) hasLunchBreak = true;

      // Weekly bucketing
      final weekKey = _weekKey(s.date!);
      final dayKey = _dateKey(s.date!);
      weekDayTotals.putIfAbsent(weekKey, () => {})[dayKey] = (weekDayTotals[weekKey]![dayKey] ?? 0) + total;

      // Accuracy (pro only)
      if (isPro) {
        final wristHit = s.wristTargetsHit ?? 0;
        final snapHit = s.snapTargetsHit ?? 0;
        final slapHit = s.slapTargetsHit ?? 0;
        final backhandHit = s.backhandTargetsHit ?? 0;
        final typedTotal = wrist + snap + slap + backhand;

        if (typedTotal > 0) {
          const kMin = 25;
          if (wrist >= kMin) bestWristAcc = max(bestWristAcc, wristHit / wrist);
          if (snap >= kMin) bestSnapAcc = max(bestSnapAcc, snapHit / snap);
          if (slap >= kMin) bestSlapAcc = max(bestSlapAcc, slapHit / slap);
          if (backhand >= kMin) {
            bestBackhandAcc = max(bestBackhandAcc, backhandHit / backhand);
          }

          final allHits = wristHit + snapHit + slapHit + backhandHit;
          final overallAcc = allHits / typedTotal;
          if (total >= 25) bestOverallAcc25 = max(bestOverallAcc25, overallAcc);
          if (total >= 50) bestOverallAcc50 = max(bestOverallAcc50, overallAcc);

          // Perfect session
          if (total >= 25 && allHits == typedTotal) {
            hasPerfect25 = true;
            if (total >= 50) hasPerfect50 = true;
          }

          // All-types 80% in same session
          if (!hasAllTypesAcc80 && wrist >= kMin && wristHit / wrist >= 0.80 && snap >= kMin && snapHit / snap >= 0.80 && slap >= kMin && slapHit / slap >= 0.80 && backhand >= kMin && backhandHit / backhand >= 0.80) {
            hasAllTypesAcc80 = true;
          }

          // Accuracy streak (70%+ overall)
          if (overallAcc >= 0.70) {
            currentAccuracyStreak++;
            maxAccuracyStreak = max(maxAccuracyStreak, currentAccuracyStreak);
          } else {
            currentAccuracyStreak = 0;
          }
        }
        // Sessions with no typed shots don't affect the accuracy streak.
      }
    }

    final allTimeSessions = valid.length;

    // ── Per-week analysis ───────────────────────────────────────────────────
    int maxWeekTotal = 0;
    int maxDaysWithMin100 = 0;
    int maxDaysWithMin50 = 0;
    bool hasWeekendWarrior = false;

    for (final entry in weekDayTotals.entries) {
      final weekStart = _parseWeekKey(entry.key);
      final dayMap = entry.value;
      final weekTotal = dayMap.values.fold(0, (a, b) => a + b);

      maxWeekTotal = max(maxWeekTotal, weekTotal);
      maxDaysWithMin100 = max(maxDaysWithMin100, dayMap.values.where((v) => v >= 100).length);
      maxDaysWithMin50 = max(maxDaysWithMin50, dayMap.values.where((v) => v >= 50).length);

      // Weekend warrior: Saturday AND Sunday in same week
      final satKey = _dayKey(weekStart, 6);
      final sunKey = _dayKey(weekStart, 0);
      if (dayMap.containsKey(satKey) && dayMap.containsKey(sunKey)) {
        hasWeekendWarrior = true;
      }
    }

    // ── Week streak (consecutive weeks with ≥1 session) ─────────────────────
    final weekKeys = weekDayTotals.keys.toList()..sort();
    int maxWeekStreak = weekKeys.isEmpty ? 0 : 1;
    int curWeekStreak = weekKeys.isEmpty ? 0 : 1;
    for (int i = 1; i < weekKeys.length; i++) {
      final prev = _parseWeekKey(weekKeys[i - 1]);
      final cur = _parseWeekKey(weekKeys[i]);
      if (cur.difference(prev).inDays == 7) {
        curWeekStreak++;
        maxWeekStreak = max(maxWeekStreak, curWeekStreak);
      } else {
        curWeekStreak = 1;
      }
    }

    // ── Consecutive weekends (each past week with both Sat+Sun) ─────────────
    int maxConsecWeekends = 0;
    int curConsecWeekends = 0;
    DateTime? prevWeekendWeekStart;
    for (int i = 0; i < weekKeys.length; i++) {
      final weekStart = _parseWeekKey(weekKeys[i]);
      final dayMap = weekDayTotals[weekKeys[i]]!;
      final satKey = _dayKey(weekStart, 6);
      final sunKey = _dayKey(weekStart, 0);
      final hasBoth = dayMap.containsKey(satKey) && dayMap.containsKey(sunKey);

      if (hasBoth) {
        if (prevWeekendWeekStart != null && weekStart.difference(prevWeekendWeekStart).inDays == 7) {
          curConsecWeekends++;
        } else {
          curConsecWeekends = 1;
        }
        maxConsecWeekends = max(maxConsecWeekends, curConsecWeekends);
        prevWeekendWeekStart = weekStart;
      } else {
        curConsecWeekends = 0;
        prevWeekendWeekStart = null;
      }
    }

    // ── Build the reconstructed current-week state ──────────────────────────
    final currentWeekStart = GlobalTrophyService.currentWeekStartUtc();
    final currentWeekKey = _weekKey(DateTime.now());
    final currentWeekDayMap = weekDayTotals[currentWeekKey] ?? {};
    final currentWeekDays = currentWeekDayMap.entries.map((e) => GlobalWeeklySessionEntry(dateKey: e.key, total: e.value)).toList();
    final currentWeekTotal = currentWeekDayMap.values.fold(0, (a, b) => a + b);

    final reconstructed = GlobalTrophySummary(
      trophies: List<String>.from(existing.trophies),
      featuredTrophies: existing.featuredTrophies,
      trackingStartedAt: existing.trackingStartedAt ?? valid.first.date,
      allTimeTotal: allTimeTotal,
      allTimeWrist: allTimeWrist,
      allTimeSnap: allTimeSnap,
      allTimeSlap: allTimeSlap,
      allTimeBackhand: allTimeBackhand,
      allTimeSessions: allTimeSessions,
      currentWeekStart: currentWeekStart,
      currentWeekTotal: currentWeekTotal,
      currentWeekDays: currentWeekDays,
      weekStreak: curWeekStreak, // current ongoing streak
      earlyMorningSessions: earlyMorningSessions,
      lateNightSessions: lateNightSessions,
      consecutiveWeekendCount: maxConsecWeekends,
      currentAccuracyStreak: currentAccuracyStreak,
    );

    // ── Evaluate historically-earned trophies ───────────────────────────────
    final alreadyEarned = Set<String>.from(existing.trophies);
    final newly = <GlobalTrophyDefinition>[];

    void award(String id) {
      if (alreadyEarned.contains(id)) return;
      final def = GlobalTrophyService.catalog.where((d) => d.id == id).firstOrNull;
      if (def == null) return;
      if (def.proOnly && !isPro) return;
      newly.add(def);
      alreadyEarned.add(id);
    }

    // Volume
    if (allTimeTotal >= 1) award('g_first_shot');
    if (allTimeTotal >= 100) award('g_shots_100');
    if (allTimeTotal >= 250) award('g_shots_250');
    if (allTimeTotal >= 500) award('g_shots_500');
    if (allTimeTotal >= 1000) award('g_shots_1000');
    if (allTimeTotal >= 2500) award('g_shots_2500');
    if (allTimeTotal >= 5000) award('g_shots_5000');
    if (allTimeTotal >= 7500) award('g_shots_7500');
    if (allTimeTotal >= 10000) award('g_shots_10000');
    if (allTimeTotal >= 15000) award('g_shots_15000');
    if (allTimeTotal >= 20000) award('g_shots_20000');
    if (allTimeTotal >= 25000) award('g_shots_25000');
    if (allTimeTotal >= 50000) award('g_shots_50000');

    // Sessions
    if (allTimeSessions >= 1) award('g_first_session');
    if (allTimeSessions >= 5) award('g_sessions_5');
    if (allTimeSessions >= 10) award('g_sessions_10');
    if (allTimeSessions >= 25) award('g_sessions_25');
    if (allTimeSessions >= 50) award('g_sessions_50');
    if (allTimeSessions >= 100) award('g_sessions_100');
    if (allTimeSessions >= 150) award('g_sessions_150');
    if (allTimeSessions >= 250) award('g_sessions_250');
    if (allTimeSessions >= 500) award('g_sessions_500');

    // Weekly volume (best single week)
    if (maxWeekTotal >= 500) award('g_week_500');
    if (maxWeekTotal >= 1000) award('g_week_1000');
    if (maxWeekTotal >= 2000) award('g_week_2000');
    if (maxDaysWithMin100 >= 7) award('g_hundred_a_day');
    if (maxDaysWithMin50 >= 7) award('g_fifty_a_day_7');

    // Week streak
    if (maxWeekStreak >= 2) award('g_week_streak_2');
    if (maxWeekStreak >= 4) award('g_week_streak_4');
    if (maxWeekStreak >= 8) award('g_week_streak_8');
    if (maxWeekStreak >= 12) award('g_week_streak_12');

    // Shot type
    if (allTimeWrist >= 50) award('g_wrist_50');
    if (allTimeSnap >= 50) award('g_snap_50');
    if (allTimeSlap >= 50) award('g_slap_50');
    if (allTimeBackhand >= 50) award('g_backhand_50');
    if (allTimeWrist >= 50 && allTimeSnap >= 50 && allTimeSlap >= 50 && allTimeBackhand >= 50) award('g_all_types_50');
    if (allTimeWrist >= 200) award('g_wrist_200');
    if (allTimeSnap >= 200) award('g_snap_200');
    if (allTimeSlap >= 200) award('g_slap_200');
    if (allTimeBackhand >= 200) award('g_backhand_200');
    if (allTimeWrist >= 200 && allTimeSnap >= 200 && allTimeSlap >= 200 && allTimeBackhand >= 200) award('g_all_types_200');
    if (allTimeWrist >= 500) award('g_wrist_500');
    if (allTimeSnap >= 500) award('g_snap_500');
    if (allTimeSlap >= 500) award('g_slap_500');
    if (allTimeBackhand >= 500) award('g_backhand_500');
    if (allTimeWrist >= 500 && allTimeSnap >= 500 && allTimeSlap >= 500 && allTimeBackhand >= 500) award('g_all_types_500');
    if (allTimeWrist >= 1000) award('g_wrist_1000');
    if (allTimeSnap >= 1000) award('g_snap_1000');
    if (allTimeSlap >= 1000) award('g_slap_1000');
    if (allTimeBackhand >= 1000) award('g_backhand_1000');
    if (allTimeWrist >= 1000 && allTimeSnap >= 1000 && allTimeSlap >= 1000 && allTimeBackhand >= 1000) award('g_all_types_1000');

    // Time of day
    if (earlyMorningSessions >= 1) award('g_early_riser');
    if (lateNightSessions >= 1) award('g_night_owl');
    if (hasLunchBreak) award('g_lunch_break');
    if (hasWeekendWarrior) award('g_weekend_warrior');
    if (earlyMorningSessions >= 10) award('g_morning_grinder');
    if (lateNightSessions >= 10) award('g_midnight_sniper');
    if (earlyMorningSessions >= 25) award('g_sunrise_shooter');
    if (maxConsecWeekends >= 4) award('g_weekend_grinder');

    // Accuracy (pro only)
    if (isPro) {
      if (bestWristAcc >= 0.80) award('g_wrist_accuracy_80');
      if (bestSnapAcc >= 0.80) award('g_snap_accuracy_80');
      if (bestSlapAcc >= 0.80) award('g_slap_accuracy_80');
      if (bestBackhandAcc >= 0.80) award('g_backhand_accuracy_80');
      if (bestOverallAcc25 >= 0.75) award('g_overall_accuracy_75');
      if (bestWristAcc >= 0.90) award('g_wrist_accuracy_90');
      if (bestSnapAcc >= 0.90) award('g_snap_accuracy_90');
      if (bestSlapAcc >= 0.90) award('g_slap_accuracy_90');
      if (bestBackhandAcc >= 0.90) award('g_backhand_accuracy_90');
      if (hasAllTypesAcc80) award('g_all_types_accuracy_80');
      if (hasPerfect25) award('g_perfect_session');
      if (hasPerfect50) award('g_perfect_session_50');
      if (maxAccuracyStreak >= 5) award('g_accuracy_streak_5');
      if (maxAccuracyStreak >= 10) award('g_accuracy_streak_10');
    }

    return BackfillResult(
      earnedTrophies: newly,
      historicalSummary: reconstructed,
    );
  }

  // ---------------------------------------------------------------------------
  // Week / date key helpers (mirrors GlobalTrophyService logic)
  // ---------------------------------------------------------------------------

  /// Sunday-based week key in EST, formatted as 'YYYY-MM-DD' of the Sunday.
  static String _weekKey(DateTime dt) {
    final utc = dt.toUtc();
    final est = utc.add(const Duration(hours: _estOffsetHours));
    final daysFromSunday = est.weekday % 7; // Mon=1…Sun=7 → Sun=0
    final sunday = DateTime(est.year, est.month, est.day - daysFromSunday);
    return '${sunday.year.toString().padLeft(4, '0')}-'
        '${sunday.month.toString().padLeft(2, '0')}-'
        '${sunday.day.toString().padLeft(2, '0')}';
  }

  /// Parse a weekKey string back to a DateTime (midnight local).
  static DateTime _parseWeekKey(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// UTC date key 'YYYY-MM-DD'.
  static String _dateKey(DateTime dt) {
    final d = dt.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Date key for a given weekday offset from weekStart.
  /// weekStart is Sunday (offset 0); Saturday is offset 6.
  static String _dayKey(DateTime weekStart, int offset) {
    return _dateKey(weekStart.add(Duration(days: offset)));
  }
}

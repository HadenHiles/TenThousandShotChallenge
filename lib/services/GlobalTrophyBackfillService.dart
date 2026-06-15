import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/GlobalTrophySummary.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/services/GlobalTrophyService.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API types
// ─────────────────────────────────────────────────────────────────────────────

/// Bump this when the backfill logic changes significantly enough to re-run.
const int kBackfillVersion = 2;

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
  /// evaluation works) but no new trophy IDs are written - the user's slate
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
      // If we can't read iterations at all, return empty - caller handles it.
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
      // Nothing to backfill - just mark as done.
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
    // Per-shot-type: best accuracy at each minimum shot count tier.
    double bestWristAcc10 = 0, bestWristAcc15 = 0, bestWristAcc20 = 0, bestWristAcc25 = 0;
    double bestSnapAcc10 = 0, bestSnapAcc15 = 0, bestSnapAcc20 = 0, bestSnapAcc25 = 0;
    double bestSlapAcc10 = 0, bestSlapAcc15 = 0, bestSlapAcc20 = 0, bestSlapAcc25 = 0;
    double bestBackhandAcc10 = 0, bestBackhandAcc15 = 0, bestBackhandAcc20 = 0, bestBackhandAcc25 = 0;
    bool hasWristPerfect = false, hasSnapPerfect = false, hasSlapPerfect = false, hasBackhandPerfect = false;
    // Overall accuracy: best at each minimum.
    double bestOverallAcc10 = 0, bestOverallAcc25 = 0, bestOverallAcc30 = 0, bestOverallAcc50 = 0;
    bool hasFirstAccSession = false;
    // Perfect sessions.
    bool hasPerfect25 = false, hasPerfect50 = false, hasPerfect75 = false, hasPerfect100 = false;
    // All-types accuracy in a single session.
    bool hasAllTypes50 = false, hasAllTypes60 = false, hasAllTypes70 = false;
    bool hasAllTypes80 = false, hasAllTypes85 = false, hasAllTypes90 = false, hasAllTypes95 = false;
    bool hasAllTypesPerfect = false;
    // Accuracy streaks.
    int maxAccuracyStreak65 = 0, currentAccuracyStreak65 = 0;
    int maxAccuracyStreak = 0, currentAccuracyStreak = 0;

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
          hasFirstAccSession = true;
          final allHits = wristHit + snapHit + slapHit + backhandHit;
          final overallAcc = allHits / typedTotal;

          // Overall at each minimum.
          if (typedTotal >= 10) bestOverallAcc10 = max(bestOverallAcc10, overallAcc);
          if (typedTotal >= 25) bestOverallAcc25 = max(bestOverallAcc25, overallAcc);
          if (typedTotal >= 30) bestOverallAcc30 = max(bestOverallAcc30, overallAcc);
          if (typedTotal >= 50) bestOverallAcc50 = max(bestOverallAcc50, overallAcc);

          // Per-type at each minimum.
          if (wrist >= 10) bestWristAcc10 = max(bestWristAcc10, wristHit / wrist);
          if (wrist >= 15) bestWristAcc15 = max(bestWristAcc15, wristHit / wrist);
          if (wrist >= 20) bestWristAcc20 = max(bestWristAcc20, wristHit / wrist);
          if (wrist >= 25) {
            bestWristAcc25 = max(bestWristAcc25, wristHit / wrist);
            if (wristHit == wrist) hasWristPerfect = true;
          }
          if (snap >= 10) bestSnapAcc10 = max(bestSnapAcc10, snapHit / snap);
          if (snap >= 15) bestSnapAcc15 = max(bestSnapAcc15, snapHit / snap);
          if (snap >= 20) bestSnapAcc20 = max(bestSnapAcc20, snapHit / snap);
          if (snap >= 25) {
            bestSnapAcc25 = max(bestSnapAcc25, snapHit / snap);
            if (snapHit == snap) hasSnapPerfect = true;
          }
          if (slap >= 10) bestSlapAcc10 = max(bestSlapAcc10, slapHit / slap);
          if (slap >= 15) bestSlapAcc15 = max(bestSlapAcc15, slapHit / slap);
          if (slap >= 20) {
            bestSlapAcc20 = max(bestSlapAcc20, slapHit / slap);
            // Slap perfect requires only 20+ shots (half the wrist/snap minimum
            // reflects that slap shots are ~2x harder to be accurate with).
            if (slapHit == slap) hasSlapPerfect = true;
          }
          if (slap >= 25) bestSlapAcc25 = max(bestSlapAcc25, slapHit / slap);
          if (backhand >= 10) bestBackhandAcc10 = max(bestBackhandAcc10, backhandHit / backhand);
          if (backhand >= 15) bestBackhandAcc15 = max(bestBackhandAcc15, backhandHit / backhand);
          if (backhand >= 20) bestBackhandAcc20 = max(bestBackhandAcc20, backhandHit / backhand);
          if (backhand >= 25) {
            bestBackhandAcc25 = max(bestBackhandAcc25, backhandHit / backhand);
            if (backhandHit == backhand) hasBackhandPerfect = true;
          }

          // Perfect sessions.
          if (typedTotal >= 25 && allHits == typedTotal) hasPerfect25 = true;
          if (typedTotal >= 50 && allHits == typedTotal) hasPerfect50 = true;
          if (typedTotal >= 75 && allHits == typedTotal) hasPerfect75 = true;
          if (typedTotal >= 100 && allHits == typedTotal) hasPerfect100 = true;

          // All-types per-session checks.
          if (!hasAllTypes50 && wrist >= 10 && snap >= 10 && slap >= 10 && backhand >= 10) {
            final wa = wristHit / wrist, sa = snapHit / snap, la = slapHit / slap, ba = backhandHit / backhand;
            if (wa >= 0.50 && sa >= 0.50 && la >= 0.50 && ba >= 0.50) hasAllTypes50 = true;
            if (wa >= 0.60 && sa >= 0.60 && la >= 0.60 && ba >= 0.60) hasAllTypes60 = true;
          }
          if (!hasAllTypes70 && wrist >= 15 && snap >= 15 && slap >= 15 && backhand >= 15) {
            final wa = wristHit / wrist, sa = snapHit / snap, la = slapHit / slap, ba = backhandHit / backhand;
            if (wa >= 0.70 && sa >= 0.70 && la >= 0.70 && ba >= 0.70) hasAllTypes70 = true;
          }
          if (wrist >= 25 && snap >= 25 && slap >= 25 && backhand >= 25) {
            final wa = wristHit / wrist, sa = snapHit / snap, la = slapHit / slap, ba = backhandHit / backhand;
            if (wa >= 0.80 && sa >= 0.80 && la >= 0.80 && ba >= 0.80) hasAllTypes80 = true;
            if (wa >= 0.85 && sa >= 0.85 && la >= 0.85 && ba >= 0.85) hasAllTypes85 = true;
            if (wa >= 0.90 && sa >= 0.90 && la >= 0.90 && ba >= 0.90) hasAllTypes90 = true;
            if (wa >= 0.95 && sa >= 0.95 && la >= 0.95 && ba >= 0.95) hasAllTypes95 = true;
            if (wristHit == wrist && snapHit == snap && slapHit == slap && backhandHit == backhand) hasAllTypesPerfect = true;
          }

          // Accuracy streaks.
          if (overallAcc >= 0.65) {
            currentAccuracyStreak65++;
            maxAccuracyStreak65 = max(maxAccuracyStreak65, currentAccuracyStreak65);
          } else {
            currentAccuracyStreak65 = 0;
          }
          if (overallAcc >= 0.70) {
            currentAccuracyStreak++;
            maxAccuracyStreak = max(maxAccuracyStreak, currentAccuracyStreak);
          } else {
            currentAccuracyStreak = 0;
          }
        }
        // Sessions with no typed shots don't affect accuracy streaks.
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
      currentAccuracyStreak65: currentAccuracyStreak65,
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
      if (hasFirstAccSession) award('g_accuracy_first_session');

      // Overall accuracy.
      if (bestOverallAcc10 >= 0.50) award('g_overall_accuracy_50');
      if (bestOverallAcc25 >= 0.60) award('g_overall_accuracy_60');
      if (bestOverallAcc30 >= 0.65) award('g_overall_accuracy_65');
      if (bestOverallAcc50 >= 0.75) award('g_overall_accuracy_75');
      if (bestOverallAcc50 >= 0.80) award('g_overall_accuracy_80');
      if (bestOverallAcc50 >= 0.85) award('g_overall_accuracy_85');
      if (bestOverallAcc50 >= 0.90) award('g_overall_accuracy_90');
      if (bestOverallAcc50 >= 0.95) award('g_overall_accuracy_95');

      // Wrist accuracy.
      if (bestWristAcc10 >= 0.50) award('g_wrist_accuracy_50');
      if (bestWristAcc15 >= 0.60) award('g_wrist_accuracy_60');
      if (bestWristAcc20 >= 0.70) award('g_wrist_accuracy_70');
      if (bestWristAcc20 >= 0.75) award('g_wrist_accuracy_75');
      if (bestWristAcc25 >= 0.80) award('g_wrist_accuracy_80');
      if (bestWristAcc25 >= 0.85) award('g_wrist_accuracy_85');
      if (bestWristAcc25 >= 0.90) award('g_wrist_accuracy_90');
      if (bestWristAcc25 >= 0.95) award('g_wrist_accuracy_95');
      if (hasWristPerfect) award('g_wrist_perfect');

      // Snap accuracy.
      if (bestSnapAcc10 >= 0.50) award('g_snap_accuracy_50');
      if (bestSnapAcc15 >= 0.60) award('g_snap_accuracy_60');
      if (bestSnapAcc20 >= 0.70) award('g_snap_accuracy_70');
      if (bestSnapAcc20 >= 0.75) award('g_snap_accuracy_75');
      if (bestSnapAcc25 >= 0.80) award('g_snap_accuracy_80');
      if (bestSnapAcc25 >= 0.85) award('g_snap_accuracy_85');
      if (bestSnapAcc25 >= 0.90) award('g_snap_accuracy_90');
      if (bestSnapAcc25 >= 0.95) award('g_snap_accuracy_95');
      if (hasSnapPerfect) award('g_snap_perfect');

      // Slap accuracy (thresholds scaled ~15pp lower — slap shots are ~2x harder to be accurate).
      if (bestSlapAcc10 >= 0.35) award('g_slap_accuracy_50');
      if (bestSlapAcc15 >= 0.45) award('g_slap_accuracy_60');
      if (bestSlapAcc15 >= 0.55) award('g_slap_accuracy_70');
      if (bestSlapAcc15 >= 0.60) award('g_slap_accuracy_75');
      if (bestSlapAcc20 >= 0.65) award('g_slap_accuracy_80');
      if (bestSlapAcc20 >= 0.70) award('g_slap_accuracy_85');
      if (bestSlapAcc20 >= 0.75) award('g_slap_accuracy_90');
      if (bestSlapAcc20 >= 0.80) award('g_slap_accuracy_95');
      if (hasSlapPerfect) award('g_slap_perfect');

      // Backhand accuracy.
      if (bestBackhandAcc10 >= 0.50) award('g_backhand_accuracy_50');
      if (bestBackhandAcc15 >= 0.60) award('g_backhand_accuracy_60');
      if (bestBackhandAcc20 >= 0.70) award('g_backhand_accuracy_70');
      if (bestBackhandAcc20 >= 0.75) award('g_backhand_accuracy_75');
      if (bestBackhandAcc25 >= 0.80) award('g_backhand_accuracy_80');
      if (bestBackhandAcc25 >= 0.85) award('g_backhand_accuracy_85');
      if (bestBackhandAcc25 >= 0.90) award('g_backhand_accuracy_90');
      if (bestBackhandAcc25 >= 0.95) award('g_backhand_accuracy_95');
      if (hasBackhandPerfect) award('g_backhand_perfect');

      // All-types accuracy.
      if (hasAllTypes50) award('g_all_types_accuracy_50');
      if (hasAllTypes60) award('g_all_types_accuracy_60');
      if (hasAllTypes70) award('g_all_types_accuracy_70');
      if (hasAllTypes80) award('g_all_types_accuracy_80');
      if (hasAllTypes85) award('g_all_types_accuracy_85');
      if (hasAllTypes90) award('g_all_types_accuracy_90');
      if (hasAllTypes95) award('g_all_types_accuracy_95');
      if (hasAllTypesPerfect) award('g_all_types_perfect');

      // Perfect sessions.
      if (hasPerfect25) award('g_perfect_session');
      if (hasPerfect50) award('g_perfect_session_50');
      if (hasPerfect75) award('g_perfect_session_75');
      if (hasPerfect100) award('g_perfect_session_100');

      // Accuracy streaks.
      if (maxAccuracyStreak65 >= 2) award('g_accuracy_streak_2');
      if (maxAccuracyStreak >= 3) award('g_accuracy_streak_3');
      if (maxAccuracyStreak >= 4) award('g_accuracy_streak_4');
      if (maxAccuracyStreak >= 5) award('g_accuracy_streak_5');
      if (maxAccuracyStreak >= 10) award('g_accuracy_streak_10');
      if (maxAccuracyStreak >= 15) award('g_accuracy_streak_15');
      if (maxAccuracyStreak >= 20) award('g_accuracy_streak_20');
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

// ignore_for_file: avoid_function_literals_in_foreach_calls

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/firestore/GlobalTrophySummary.dart';
import 'package:tenthousandshotchallenge/services/GlobalTrophyService.dart';

// ---------------------------------------------------------------------------
// Comprehensive simulation tests for every one of the 73 global trophies.
//
// Strategy
// --------
// • All tests call [evaluateAfterSession] via a [GlobalTrophyService] that is
//   wired to a [FakeFirebaseFirestore] instance - no real Firebase required.
// • Where a trophy needs specific accumulated state (e.g., 999 shots already
//   logged), the Firestore doc is pre-seeded before the evaluation call.
// • "Boundary" tests verify both N-1 (NOT awarded) and N (awarded).
// • Pro-only trophies are tested with isPro=false (not awarded) and
//   isPro=true (awarded).
// • Already-earned trophies must NOT be re-returned.
//
// Time-zone note
// --------------
// The service hardcodes EST = UTC-5 for time-of-day calculations.
// The neutral session date used throughout is Wednesday 2026-05-13 14:00 UTC
// (= 9 AM EST), which does NOT trigger early-morning, lunch-break, late-night
// or weekend trophies.
// ---------------------------------------------------------------------------

void main() {
  group('GlobalTrophyService – trophy evaluation', () {
    late FakeFirebaseFirestore fakeFirestore;
    late GlobalTrophyService service;
    const String uid = 'test_user';

    // Wednesday 9 AM EST – safe default that doesn't trigger time-of-day trophies.
    final kNeutralDate = DateTime.utc(2026, 5, 13, 14, 0); // 14:00 UTC = 9 AM EST

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = GlobalTrophyService(firestore: fakeFirestore);
    });

    // ── Helpers ──────────────────────────────────────────────────────────────

    /// Writes [s] to the fake Firestore summary doc so that the next
    /// [evaluateAfterSession] call starts from the desired state.
    Future<void> seed(GlobalTrophySummary s) => fakeFirestore.collection('users').doc(uid).collection('global_trophies').doc('summary').set(s.toMap());

    /// Thin wrapper around [evaluateAfterSession].
    /// Returns only the IDs of newly-earned trophies for easy assertions.
    Future<List<String>> eval({
      int total = 1,
      int wrist = 0,
      int snap = 0,
      int slap = 0,
      int backhand = 0,
      int wristH = 0,
      int snapH = 0,
      int slapH = 0,
      int backhandH = 0,
      DateTime? date,
      bool pro = false,
    }) async {
      final defs = await service.evaluateAfterSession(
        uid,
        GlobalSessionInput(
          total: total,
          wrist: wrist,
          snap: snap,
          slap: slap,
          backhand: backhand,
          wristTargetsHit: wristH,
          snapTargetsHit: snapH,
          slapTargetsHit: slapH,
          backhandTargetsHit: backhandH,
          sessionDate: date ?? kNeutralDate,
        ),
        isPro: pro,
      );
      return defs.map((d) => d.id).toList();
    }

    /// Builds a [GlobalTrophySummary] with all un-specified fields zero/empty.
    /// Sets [currentWeekStart] to the real current week start by default so
    /// that the service never treats the session as a "new week" unless we
    /// explicitly pass an old [weekStart].
    GlobalTrophySummary blank({
      List<String> earned = const [],
      int total = 0,
      int sessions = 0,
      int wrist = 0,
      int snap = 0,
      int slap = 0,
      int backhand = 0,
      int weekTotal = 0,
      List<GlobalWeeklySessionEntry> weekDays = const [],
      DateTime? weekStart,
      int weekStreak = 0,
      int earlyMorning = 0,
      int lateNight = 0,
      int weekendCount = 0,
      int accuracyStreak65 = 0,
      int accuracyStreak = 0,
    }) {
      return GlobalTrophySummary(
        trophies: earned,
        allTimeTotal: total,
        allTimeSessions: sessions,
        allTimeWrist: wrist,
        allTimeSnap: snap,
        allTimeSlap: slap,
        allTimeBackhand: backhand,
        currentWeekTotal: weekTotal,
        currentWeekDays: weekDays,
        currentWeekStart: weekStart ?? GlobalTrophyService.currentWeekStartUtc(),
        weekStreak: weekStreak,
        earlyMorningSessions: earlyMorning,
        lateNightSessions: lateNight,
        consecutiveWeekendCount: weekendCount,
        currentAccuracyStreak65: accuracyStreak65,
        currentAccuracyStreak: accuracyStreak,
      );
    }

    /// Mirrors [GlobalTrophyService._dateKey] - formats a UTC date as YYYY-MM-DD.
    String dateKey(DateTime dt) {
      final d = dt.toUtc();
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    // =========================================================================
    // 1. CATALOG INTEGRITY
    // =========================================================================

    group('Catalog integrity', () {
      test('catalog contains exactly 123 trophies', () {
        expect(GlobalTrophyService.catalog.length, 123);
      });

      test('all trophy IDs are unique', () {
        final ids = GlobalTrophyService.catalog.map((d) => d.id).toList();
        expect(ids.toSet().length, ids.length, reason: 'Duplicate trophy IDs detected');
      });

      test('all trophies have non-empty IDs and descriptions', () {
        for (final def in GlobalTrophyService.catalog) {
          expect(def.id, isNotEmpty, reason: 'Empty ID found in catalog');
          expect(def.description, isNotEmpty, reason: '${def.id} has empty description');
        }
      });

      test('all expected trophy IDs exist in the catalog', () {
        const expected = [
          // Volume
          'g_first_shot', 'g_shots_100', 'g_shots_250', 'g_shots_500',
          'g_shots_1000', 'g_shots_2500', 'g_shots_5000', 'g_shots_7500',
          'g_shots_10000', 'g_shots_15000', 'g_shots_20000', 'g_shots_25000',
          'g_shots_50000',
          // Sessions
          'g_first_session', 'g_sessions_5', 'g_sessions_10', 'g_sessions_25',
          'g_sessions_50', 'g_sessions_100', 'g_sessions_150', 'g_sessions_250',
          'g_sessions_500',
          // Weekly volume
          'g_week_500', 'g_week_1000', 'g_week_2000', 'g_hundred_a_day',
          'g_fifty_a_day_7',
          // Week streak
          'g_week_streak_2', 'g_week_streak_4', 'g_week_streak_8',
          'g_week_streak_12',
          // Shot type
          'g_wrist_50', 'g_snap_50', 'g_slap_50', 'g_backhand_50',
          'g_wrist_200', 'g_snap_200', 'g_slap_200', 'g_backhand_200',
          'g_all_types_50', 'g_all_types_200',
          'g_wrist_500', 'g_snap_500', 'g_slap_500', 'g_backhand_500',
          'g_all_types_500',
          'g_wrist_1000', 'g_snap_1000', 'g_slap_1000', 'g_backhand_1000',
          'g_all_types_1000',
          // Time of day
          'g_early_riser', 'g_night_owl', 'g_lunch_break', 'g_weekend_warrior',
          'g_morning_grinder', 'g_midnight_sniper', 'g_sunrise_shooter',
          'g_weekend_grinder',
          // Accuracy – first session
          'g_accuracy_first_session',
          // Overall accuracy
          'g_overall_accuracy_50', 'g_overall_accuracy_60', 'g_overall_accuracy_65',
          'g_overall_accuracy_75', 'g_overall_accuracy_80', 'g_overall_accuracy_85',
          'g_overall_accuracy_90', 'g_overall_accuracy_95',
          // Per-type accuracy
          'g_wrist_accuracy_50', 'g_wrist_accuracy_60', 'g_wrist_accuracy_70',
          'g_wrist_accuracy_75', 'g_wrist_accuracy_80', 'g_wrist_accuracy_85',
          'g_wrist_accuracy_90', 'g_wrist_accuracy_95', 'g_wrist_perfect',
          'g_snap_accuracy_50', 'g_snap_accuracy_60', 'g_snap_accuracy_70',
          'g_snap_accuracy_75', 'g_snap_accuracy_80', 'g_snap_accuracy_85',
          'g_snap_accuracy_90', 'g_snap_accuracy_95', 'g_snap_perfect',
          'g_slap_accuracy_50', 'g_slap_accuracy_60', 'g_slap_accuracy_70',
          'g_slap_accuracy_75', 'g_slap_accuracy_80', 'g_slap_accuracy_85',
          'g_slap_accuracy_90', 'g_slap_accuracy_95', 'g_slap_perfect',
          'g_backhand_accuracy_50', 'g_backhand_accuracy_60', 'g_backhand_accuracy_70',
          'g_backhand_accuracy_75', 'g_backhand_accuracy_80', 'g_backhand_accuracy_85',
          'g_backhand_accuracy_90', 'g_backhand_accuracy_95', 'g_backhand_perfect',
          // All-types accuracy
          'g_all_types_accuracy_50', 'g_all_types_accuracy_60', 'g_all_types_accuracy_70',
          'g_all_types_accuracy_80', 'g_all_types_accuracy_85', 'g_all_types_accuracy_90',
          'g_all_types_accuracy_95', 'g_all_types_perfect',
          // Perfect sessions
          'g_perfect_session', 'g_perfect_session_50',
          'g_perfect_session_75', 'g_perfect_session_100',
          // Accuracy streaks
          'g_accuracy_streak_2', 'g_accuracy_streak_3', 'g_accuracy_streak_4',
          'g_accuracy_streak_5', 'g_accuracy_streak_10',
          'g_accuracy_streak_15', 'g_accuracy_streak_20',
        ];
        final catalogIds = GlobalTrophyService.catalog.map((d) => d.id).toSet();
        for (final id in expected) {
          expect(catalogIds, contains(id), reason: 'Missing trophy: $id');
        }
      });
    });

    // =========================================================================
    // 2. VOLUME TROPHIES  (allTimeTotal thresholds)
    // =========================================================================

    group('Volume trophies', () {
      // Parameterised helper - registers two tests per trophy.
      void volumeTest(String id, int threshold, {bool proOnly = false}) {
        test('$id: awarded when allTimeTotal crosses $threshold', () async {
          await seed(blank(total: threshold - 1));
          final earned = await eval(total: 1, pro: proOnly);
          expect(earned, contains(id));
        });

        test('$id: NOT awarded one shot below $threshold', () async {
          await seed(blank(total: threshold - 2));
          final earned = await eval(total: 1, pro: proOnly);
          expect(earned, isNot(contains(id)));
        });
      }

      volumeTest('g_first_shot', 1);
      volumeTest('g_shots_100', 100);
      volumeTest('g_shots_250', 250);
      volumeTest('g_shots_500', 500);
      volumeTest('g_shots_1000', 1000);
      volumeTest('g_shots_2500', 2500);
      volumeTest('g_shots_5000', 5000);
      volumeTest('g_shots_7500', 7500);
      volumeTest('g_shots_10000', 10000);
      volumeTest('g_shots_15000', 15000);
      volumeTest('g_shots_20000', 20000, proOnly: true);
      volumeTest('g_shots_25000', 25000, proOnly: true);
      volumeTest('g_shots_50000', 50000, proOnly: true);

      test('g_first_shot: awards on very first session (empty state)', () async {
        final earned = await eval(total: 1);
        expect(earned, contains('g_first_shot'));
      });

      test('all free volume trophies awarded in one huge session', () async {
        final earned = await eval(total: 15000, pro: false);
        for (final id in [
          'g_first_shot',
          'g_shots_100',
          'g_shots_250',
          'g_shots_500',
          'g_shots_1000',
          'g_shots_2500',
          'g_shots_5000',
          'g_shots_7500',
          'g_shots_10000',
          'g_shots_15000',
        ]) {
          expect(earned, contains(id), reason: '$id should be awarded');
        }
        for (final id in ['g_shots_20000', 'g_shots_25000', 'g_shots_50000']) {
          expect(earned, isNot(contains(id)), reason: '$id is pro-only, should not be awarded');
        }
      });

      test('pro volume trophies awarded in one huge session when isPro=true', () async {
        final earned = await eval(total: 50000, pro: true);
        for (final id in ['g_shots_20000', 'g_shots_25000', 'g_shots_50000']) {
          expect(earned, contains(id), reason: '$id should be awarded to pro');
        }
      });
    });

    // =========================================================================
    // 3. SESSION COUNT TROPHIES
    // =========================================================================

    group('Session count trophies', () {
      void sessionTest(String id, int threshold, {bool proOnly = false}) {
        test('$id: awarded at session #$threshold', () async {
          await seed(blank(sessions: threshold - 1));
          final earned = await eval(pro: proOnly);
          expect(earned, contains(id));
        });

        test('$id: NOT awarded at session #${threshold - 1}', () async {
          await seed(blank(sessions: threshold - 2));
          final earned = await eval(pro: proOnly);
          expect(earned, isNot(contains(id)));
        });
      }

      sessionTest('g_first_session', 1);
      sessionTest('g_sessions_5', 5);
      sessionTest('g_sessions_10', 10);
      sessionTest('g_sessions_25', 25);
      sessionTest('g_sessions_50', 50);
      sessionTest('g_sessions_100', 100);
      sessionTest('g_sessions_150', 150, proOnly: true);
      sessionTest('g_sessions_250', 250, proOnly: true);
      sessionTest('g_sessions_500', 500, proOnly: true);

      test('g_first_session: awards on very first session (empty state)', () async {
        final earned = await eval();
        expect(earned, contains('g_first_session'));
      });
    });

    // =========================================================================
    // 4. WEEKLY VOLUME TROPHIES
    // =========================================================================

    group('Weekly volume trophies', () {
      final currWeekStart = GlobalTrophyService.currentWeekStartUtc();

      void weekVolumeTest(String id, int threshold, {bool proOnly = false}) {
        test('$id: awarded when weekly total crosses $threshold', () async {
          await seed(blank(weekTotal: threshold - 1, weekStart: currWeekStart));
          final earned = await eval(total: 1, pro: proOnly);
          expect(earned, contains(id));
        });

        test('$id: NOT awarded one shot below $threshold', () async {
          await seed(blank(weekTotal: threshold - 2, weekStart: currWeekStart));
          final earned = await eval(total: 1, pro: proOnly);
          expect(earned, isNot(contains(id)));
        });
      }

      weekVolumeTest('g_week_500', 500);
      weekVolumeTest('g_week_1000', 1000);
      weekVolumeTest('g_week_2000', 2000, proOnly: true);

      // ── g_hundred_a_day ────────────────────────────────────────────────────

      test('g_hundred_a_day: awarded when all 7 days have ≥100 shots', () async {
        // Pre-seed 6 days with exactly 100 shots; the eval session adds the 7th.
        final satDate = currWeekStart.add(const Duration(days: 6, hours: 14)); // Saturday 9 AM EST
        final sixDays = List.generate(
          6,
          (i) => GlobalWeeklySessionEntry(
            dateKey: dateKey(currWeekStart.add(Duration(days: i))),
            total: 100,
          ),
        );
        await seed(blank(weekStart: currWeekStart, weekDays: sixDays));
        final earned = await eval(total: 100, date: satDate);
        expect(earned, contains('g_hundred_a_day'));
      });

      test('g_hundred_a_day: NOT awarded when 7th day has only 99 shots', () async {
        final satDate = currWeekStart.add(const Duration(days: 6, hours: 14));
        final sixDays = List.generate(
          6,
          (i) => GlobalWeeklySessionEntry(
            dateKey: dateKey(currWeekStart.add(Duration(days: i))),
            total: 100,
          ),
        );
        await seed(blank(weekStart: currWeekStart, weekDays: sixDays));
        final earned = await eval(total: 99, date: satDate);
        expect(earned, isNot(contains('g_hundred_a_day')));
      });

      test('g_hundred_a_day: NOT awarded when only 6 days have ≥100 shots', () async {
        // Pre-seed 5 days with 100 shots; eval adds the 6th day at 100 shots.
        final satDate = currWeekStart.add(const Duration(days: 6, hours: 14));
        final fiveDays = List.generate(
          5,
          (i) => GlobalWeeklySessionEntry(
            dateKey: dateKey(currWeekStart.add(Duration(days: i))),
            total: 100,
          ),
        );
        await seed(blank(weekStart: currWeekStart, weekDays: fiveDays));
        final earned = await eval(total: 100, date: satDate);
        expect(earned, isNot(contains('g_hundred_a_day')));
      });

      // ── g_fifty_a_day_7 (pro) ──────────────────────────────────────────────

      test('g_fifty_a_day_7: awarded when all 7 days have ≥50 shots (pro)', () async {
        final satDate = currWeekStart.add(const Duration(days: 6, hours: 14));
        final sixDays = List.generate(
          6,
          (i) => GlobalWeeklySessionEntry(
            dateKey: dateKey(currWeekStart.add(Duration(days: i))),
            total: 50,
          ),
        );
        await seed(blank(weekStart: currWeekStart, weekDays: sixDays));
        final earned = await eval(total: 50, date: satDate, pro: true);
        expect(earned, contains('g_fifty_a_day_7'));
      });

      test('g_fifty_a_day_7: NOT awarded when 7th day has only 49 shots', () async {
        final satDate = currWeekStart.add(const Duration(days: 6, hours: 14));
        final sixDays = List.generate(
          6,
          (i) => GlobalWeeklySessionEntry(
            dateKey: dateKey(currWeekStart.add(Duration(days: i))),
            total: 50,
          ),
        );
        await seed(blank(weekStart: currWeekStart, weekDays: sixDays));
        final earned = await eval(total: 49, date: satDate, pro: true);
        expect(earned, isNot(contains('g_fifty_a_day_7')));
      });

      test('g_fifty_a_day_7: NOT awarded to free user even with all 7 days ≥50', () async {
        final satDate = currWeekStart.add(const Duration(days: 6, hours: 14));
        final sixDays = List.generate(
          6,
          (i) => GlobalWeeklySessionEntry(
            dateKey: dateKey(currWeekStart.add(Duration(days: i))),
            total: 50,
          ),
        );
        await seed(blank(weekStart: currWeekStart, weekDays: sixDays));
        final earned = await eval(total: 50, date: satDate, pro: false);
        expect(earned, isNot(contains('g_fifty_a_day_7')));
      });
    });

    // =========================================================================
    // 5. WEEK STREAK TROPHIES
    // =========================================================================

    group('Week streak trophies', () {
      final currWeekStart = GlobalTrophyService.currentWeekStartUtc();
      final prevWeekStart = currWeekStart.subtract(const Duration(days: 7));
      final skippedWeekStart = currWeekStart.subtract(const Duration(days: 14));

      /// A summary that simulates "had sessions last week with streak N".
      /// When [evaluateAfterSession] runs this week it will detect a new
      /// consecutive week and increment the streak.
      GlobalTrophySummary prevWeekState({required int streak}) => blank(
            weekStart: prevWeekStart,
            weekDays: [
              GlobalWeeklySessionEntry(
                dateKey: dateKey(prevWeekStart.add(const Duration(days: 3))),
                total: 50,
              )
            ],
            weekStreak: streak,
            // Keep total/sessions high enough that low-threshold trophies
            // don't fire unexpectedly.
            total: 5000,
            sessions: 100,
          );

      test('g_week_streak_2: NOT awarded on very first session', () async {
        final earned = await eval();
        expect(earned, isNot(contains('g_week_streak_2')));
      });

      test('g_week_streak_2: NOT awarded when week was skipped (14-day gap)', () async {
        await seed(blank(
          weekStart: skippedWeekStart,
          weekDays: [
            GlobalWeeklySessionEntry(
              dateKey: dateKey(skippedWeekStart.add(const Duration(days: 3))),
              total: 50,
            )
          ],
          weekStreak: 1,
          total: 5000,
          sessions: 100,
        ));
        final earned = await eval();
        // 14-day gap → wasConsecutiveWeek = false → streak resets to 1
        expect(earned, isNot(contains('g_week_streak_2')));
      });

      test('g_week_streak_2: awarded when second consecutive week starts', () async {
        await seed(prevWeekState(streak: 1));
        final earned = await eval();
        expect(earned, contains('g_week_streak_2'));
      });

      test('g_week_streak_4: awarded at 4 consecutive weeks (pro)', () async {
        await seed(prevWeekState(streak: 3));
        final earned = await eval(pro: true);
        expect(earned, contains('g_week_streak_4'));
      });

      test('g_week_streak_4: NOT awarded to free user', () async {
        await seed(prevWeekState(streak: 3));
        final earned = await eval(pro: false);
        expect(earned, isNot(contains('g_week_streak_4')));
      });

      test('g_week_streak_8: awarded at 8 consecutive weeks (pro)', () async {
        await seed(prevWeekState(streak: 7));
        final earned = await eval(pro: true);
        expect(earned, contains('g_week_streak_8'));
      });

      test('g_week_streak_12: awarded at 12 consecutive weeks (pro)', () async {
        await seed(prevWeekState(streak: 11));
        final earned = await eval(pro: true);
        expect(earned, contains('g_week_streak_12'));
      });

      test('g_week_streak_4/8/12: NOT awarded to free user even at streak 12', () async {
        await seed(prevWeekState(streak: 11));
        final earned = await eval(pro: false);
        for (final id in ['g_week_streak_4', 'g_week_streak_8', 'g_week_streak_12']) {
          expect(earned, isNot(contains(id)));
        }
      });
    });

    // =========================================================================
    // 6. SHOT TYPE TROPHIES  (all-time per-type accumulators)
    // =========================================================================

    group('Shot type trophies', () {
      // Registers boundary tests for a single-type threshold trophy.
      void shotTypeTest(
        String id,
        String type,
        int threshold, {
        bool proOnly = false,
      }) {
        test('$id: awarded when $type total crosses $threshold', () async {
          final w = type == 'wrist' ? threshold - 1 : 0;
          final sn = type == 'snap' ? threshold - 1 : 0;
          final sl = type == 'slap' ? threshold - 1 : 0;
          final bh = type == 'backhand' ? threshold - 1 : 0;
          await seed(blank(wrist: w, snap: sn, slap: sl, backhand: bh));
          final addW = type == 'wrist' ? 1 : 0;
          final addSn = type == 'snap' ? 1 : 0;
          final addSl = type == 'slap' ? 1 : 0;
          final addBh = type == 'backhand' ? 1 : 0;
          final earned = await eval(
            total: 1,
            wrist: addW,
            snap: addSn,
            slap: addSl,
            backhand: addBh,
            pro: proOnly,
          );
          expect(earned, contains(id));
        });

        test('$id: NOT awarded one shot below $threshold for $type', () async {
          final w = type == 'wrist' ? threshold - 2 : 0;
          final sn = type == 'snap' ? threshold - 2 : 0;
          final sl = type == 'slap' ? threshold - 2 : 0;
          final bh = type == 'backhand' ? threshold - 2 : 0;
          await seed(blank(wrist: w, snap: sn, slap: sl, backhand: bh));
          final addW = type == 'wrist' ? 1 : 0;
          final addSn = type == 'snap' ? 1 : 0;
          final addSl = type == 'slap' ? 1 : 0;
          final addBh = type == 'backhand' ? 1 : 0;
          final earned = await eval(
            total: 1,
            wrist: addW,
            snap: addSn,
            slap: addSl,
            backhand: addBh,
            pro: proOnly,
          );
          expect(earned, isNot(contains(id)));
        });
      }

      // 50-shot per-type thresholds (free)
      shotTypeTest('g_wrist_50', 'wrist', 50);
      shotTypeTest('g_snap_50', 'snap', 50);
      shotTypeTest('g_slap_50', 'slap', 50);
      shotTypeTest('g_backhand_50', 'backhand', 50);

      // 200-shot per-type thresholds (free)
      shotTypeTest('g_wrist_200', 'wrist', 200);
      shotTypeTest('g_snap_200', 'snap', 200);
      shotTypeTest('g_slap_200', 'slap', 200);
      shotTypeTest('g_backhand_200', 'backhand', 200);

      // 500-shot per-type thresholds (pro)
      shotTypeTest('g_wrist_500', 'wrist', 500, proOnly: true);
      shotTypeTest('g_snap_500', 'snap', 500, proOnly: true);
      shotTypeTest('g_slap_500', 'slap', 500, proOnly: true);
      shotTypeTest('g_backhand_500', 'backhand', 500, proOnly: true);

      // 1000-shot per-type thresholds (pro)
      shotTypeTest('g_wrist_1000', 'wrist', 1000, proOnly: true);
      shotTypeTest('g_snap_1000', 'snap', 1000, proOnly: true);
      shotTypeTest('g_slap_1000', 'slap', 1000, proOnly: true);
      shotTypeTest('g_backhand_1000', 'backhand', 1000, proOnly: true);

      // ── All-types combined trophies ─────────────────────────────────────────

      // Helper: all four types just below threshold, session crosses one at a time
      void allTypesTest(String id, int threshold, {bool proOnly = false}) {
        test('$id: awarded when all four types cross $threshold', () async {
          await seed(blank(
            wrist: threshold - 1,
            snap: threshold - 1,
            slap: threshold - 1,
            backhand: threshold - 1,
          ));
          final earned = await eval(
            total: 4,
            wrist: 1,
            snap: 1,
            slap: 1,
            backhand: 1,
            pro: proOnly,
          );
          expect(earned, contains(id));
        });

        test('$id: NOT awarded when one type is still below $threshold', () async {
          // backhand is one short
          await seed(blank(
            wrist: threshold,
            snap: threshold,
            slap: threshold,
            backhand: threshold - 1,
          ));
          final earned = await eval(
            total: 1,
            wrist: 0,
            snap: 0,
            slap: 0,
            backhand: 0, // backhand does NOT cross threshold in this session
            pro: proOnly,
          );
          expect(earned, isNot(contains(id)));
        });
      }

      allTypesTest('g_all_types_50', 50);
      allTypesTest('g_all_types_200', 200);
      allTypesTest('g_all_types_500', 500, proOnly: true);
      allTypesTest('g_all_types_1000', 1000, proOnly: true);
    });

    // =========================================================================
    // 7. TIME-OF-DAY TROPHIES
    // =========================================================================

    group('Time-of-day trophies', () {
      // EST = UTC-5; localHour = ((utcHour - 5) % 24 + 24) % 24

      // Early morning: 10:00 UTC → localHour = 5 (< 6 ✓)
      final earlyDate = DateTime.utc(2026, 5, 13, 10, 0); // Wednesday 5 AM EST
      // Late night: 03:00 UTC → localHour = 22 (≥ 22 ✓)
      final lateDate = DateTime.utc(2026, 5, 14, 3, 0); // Thursday 10 PM EST
      // Lunch: 16:00 UTC → localHour = 11 (≥ 11 && < 13 ✓)
      final lunchDate = DateTime.utc(2026, 5, 13, 16, 0); // Wednesday 11 AM EST

      // ── g_early_riser ────────────────────────────────────────────────────────

      test('g_early_riser: awarded on first early-morning session', () async {
        final earned = await eval(date: earlyDate);
        expect(earned, contains('g_early_riser'));
      });

      test('g_early_riser: NOT awarded at 6 AM EST (boundary excluded)', () async {
        // 11:00 UTC → localHour = 6 (NOT < 6)
        final sixAmDate = DateTime.utc(2026, 5, 13, 11, 0);
        final earned = await eval(date: sixAmDate);
        expect(earned, isNot(contains('g_early_riser')));
      });

      // ── g_night_owl ──────────────────────────────────────────────────────────

      test('g_night_owl: awarded on first late-night session', () async {
        final earned = await eval(date: lateDate);
        expect(earned, contains('g_night_owl'));
      });

      test('g_night_owl: NOT awarded at 9 PM EST (below 10 PM threshold)', () async {
        // 02:00 UTC → localHour = 21 (NOT ≥ 22)
        final ninepmDate = DateTime.utc(2026, 5, 14, 2, 0);
        final earned = await eval(date: ninepmDate);
        expect(earned, isNot(contains('g_night_owl')));
      });

      // ── g_lunch_break ────────────────────────────────────────────────────────

      test('g_lunch_break: awarded for session at 11 AM EST', () async {
        final earned = await eval(date: lunchDate);
        expect(earned, contains('g_lunch_break'));
      });

      test('g_lunch_break: awarded for session at noon EST', () async {
        final noonDate = DateTime.utc(2026, 5, 13, 17, 0); // 12:00 EST
        final earned = await eval(date: noonDate);
        expect(earned, contains('g_lunch_break'));
      });

      test('g_lunch_break: NOT awarded at 1 PM EST (boundary excluded)', () async {
        // 18:00 UTC → localHour = 13 (NOT < 13)
        final onepmDate = DateTime.utc(2026, 5, 13, 18, 0);
        final earned = await eval(date: onepmDate);
        expect(earned, isNot(contains('g_lunch_break')));
      });

      test('g_lunch_break: NOT awarded at 10 AM EST', () async {
        final tenAmDate = DateTime.utc(2026, 5, 13, 15, 0); // 10 AM EST
        final earned = await eval(date: tenAmDate);
        expect(earned, isNot(contains('g_lunch_break')));
      });

      // ── g_morning_grinder (pro – 10 early sessions) ──────────────────────────

      test('g_morning_grinder: awarded at 10th early-morning session (pro)', () async {
        await seed(blank(earlyMorning: 9));
        final earned = await eval(date: earlyDate, pro: true);
        expect(earned, contains('g_morning_grinder'));
      });

      test('g_morning_grinder: NOT awarded at 9th early-morning session', () async {
        await seed(blank(earlyMorning: 8));
        final earned = await eval(date: earlyDate, pro: true);
        expect(earned, isNot(contains('g_morning_grinder')));
      });

      test('g_morning_grinder: NOT awarded to free user', () async {
        await seed(blank(earlyMorning: 9));
        final earned = await eval(date: earlyDate, pro: false);
        expect(earned, isNot(contains('g_morning_grinder')));
      });

      // ── g_midnight_sniper (pro – 10 late-night sessions) ─────────────────────

      test('g_midnight_sniper: awarded at 10th late-night session (pro)', () async {
        await seed(blank(lateNight: 9));
        final earned = await eval(date: lateDate, pro: true);
        expect(earned, contains('g_midnight_sniper'));
      });

      test('g_midnight_sniper: NOT awarded at 9th late-night session', () async {
        await seed(blank(lateNight: 8));
        final earned = await eval(date: lateDate, pro: true);
        expect(earned, isNot(contains('g_midnight_sniper')));
      });

      test('g_midnight_sniper: NOT awarded to free user', () async {
        await seed(blank(lateNight: 9));
        final earned = await eval(date: lateDate, pro: false);
        expect(earned, isNot(contains('g_midnight_sniper')));
      });

      // ── g_sunrise_shooter (pro – 25 early sessions) ──────────────────────────

      test('g_sunrise_shooter: awarded at 25th early-morning session (pro)', () async {
        await seed(blank(earlyMorning: 24));
        final earned = await eval(date: earlyDate, pro: true);
        expect(earned, contains('g_sunrise_shooter'));
      });

      test('g_sunrise_shooter: NOT awarded at 24th early-morning session', () async {
        await seed(blank(earlyMorning: 23));
        final earned = await eval(date: earlyDate, pro: true);
        expect(earned, isNot(contains('g_sunrise_shooter')));
      });

      test('g_sunrise_shooter: NOT awarded to free user', () async {
        await seed(blank(earlyMorning: 24));
        final earned = await eval(date: earlyDate, pro: false);
        expect(earned, isNot(contains('g_sunrise_shooter')));
      });
    });

    // =========================================================================
    // 8. WEEKEND TROPHIES
    // =========================================================================

    group('Weekend trophies', () {
      final currWeekStart = GlobalTrophyService.currentWeekStartUtc();
      // 9 AM EST on the current week's Sunday
      final sundayDate = currWeekStart.add(const Duration(hours: 14)); // 14:00 UTC = 9 AM EST
      // 9 AM EST on the current week's Saturday
      final saturdayDate = currWeekStart.add(const Duration(days: 6, hours: 14));
      // The Sunday dateKey as the service computes it
      String sundayKey() => dateKey(currWeekStart);
      // The Saturday dateKey as the service computes it
      String saturdayKey() => dateKey(currWeekStart.add(const Duration(days: 6)));

      // ── g_weekend_warrior ────────────────────────────────────────────────────

      test('g_weekend_warrior: awarded when both Sat and Sun are logged this week', () async {
        // Pre-seed the Sunday entry; the eval call adds Saturday.
        await seed(blank(
          weekStart: currWeekStart,
          weekDays: [GlobalWeeklySessionEntry(dateKey: sundayKey(), total: 50)],
        ));
        final earned = await eval(total: 50, date: saturdayDate);
        expect(earned, contains('g_weekend_warrior'));
      });

      test('g_weekend_warrior: NOT awarded with only Sunday logged', () async {
        // Sunday in weekDays, eval on a Wednesday → still no Saturday
        final earned = await eval(date: sundayDate);
        expect(earned, isNot(contains('g_weekend_warrior')));
      });

      test('g_weekend_warrior: NOT awarded with only Saturday logged', () async {
        await seed(blank(
          weekStart: currWeekStart,
          weekDays: [GlobalWeeklySessionEntry(dateKey: saturdayKey(), total: 50)],
        ));
        // Eval on Wednesday - adds Wednesday key but not Sunday
        final earned = await eval(total: 50);
        expect(earned, isNot(contains('g_weekend_warrior')));
      });

      // ── g_weekend_grinder (pro – 4 consecutive full weekends) ────────────────

      test('g_weekend_grinder: awarded on 4th consecutive weekend (pro)', () async {
        // 3 past consecutive weekends; current week has Sunday already.
        // Eval on Saturday completes the current weekend → effectiveWeekendStreak = 4.
        await seed(blank(
          weekStart: currWeekStart,
          weekDays: [GlobalWeeklySessionEntry(dateKey: sundayKey(), total: 50)],
          weekendCount: 3,
          total: 5000,
          sessions: 100,
        ));
        final earned = await eval(total: 50, date: saturdayDate, pro: true);
        expect(earned, contains('g_weekend_grinder'));
      });

      test('g_weekend_grinder: NOT awarded at 3 consecutive weekends', () async {
        // 2 past; current week only Saturday logged (no Sunday) → curWeekHasBothDays=false
        await seed(blank(
          weekStart: currWeekStart,
          weekDays: [GlobalWeeklySessionEntry(dateKey: saturdayKey(), total: 50)],
          weekendCount: 2,
          total: 5000,
          sessions: 100,
        ));
        // Eval on Saturday again (duplicate – still no Sunday)
        final earned = await eval(total: 50, date: saturdayDate, pro: true);
        expect(earned, isNot(contains('g_weekend_grinder')));
      });

      test('g_weekend_grinder: NOT awarded to free user', () async {
        await seed(blank(
          weekStart: currWeekStart,
          weekDays: [GlobalWeeklySessionEntry(dateKey: sundayKey(), total: 50)],
          weekendCount: 3,
          total: 5000,
          sessions: 100,
        ));
        final earned = await eval(total: 50, date: saturdayDate, pro: false);
        expect(earned, isNot(contains('g_weekend_grinder')));
      });
    });

    // =========================================================================
    // 9. ACCURACY TROPHIES  (pro-only, session-specific)
    // =========================================================================

    group('Accuracy trophies', () {
      // ── g_accuracy_first_session ─────────────────────────────────────────────

      test('g_accuracy_first_session: awarded on any session with typed shots (pro)', () async {
        final earned = await eval(total: 1, wrist: 1, wristH: 0, pro: true);
        expect(earned, contains('g_accuracy_first_session'));
      });

      test('g_accuracy_first_session: NOT awarded when typedTotal is zero (pro)', () async {
        // A session where only untargeted shots are taken (no wrist/snap/slap/backhand)
        final earned = await eval(total: 5, pro: true);
        expect(earned, isNot(contains('g_accuracy_first_session')));
      });

      test('g_accuracy_first_session: NOT awarded to free user', () async {
        final earned = await eval(total: 1, wrist: 1, wristH: 1, pro: false);
        expect(earned, isNot(contains('g_accuracy_first_session')));
      });

      // ── Overall accuracy thresholds ──────────────────────────────────────────

      // Parameterised helper: tests a given overall-accuracy trophy.
      //   [threshold] = % as 0.XX, [minShots] = minimum typed shots required,
      //   [hitsForPass] = hits that yield just-enough accuracy,
      //   [hitsForFail] = hits that yield just-below accuracy.
      void overallAccTest(String id, int minShots, int hitsForPass, int hitsForFail) {
        test('$id: awarded at ${(hitsForPass / minShots * 100).round()}% with $minShots shots (pro)', () async {
          final earned = await eval(total: minShots, wrist: minShots, wristH: hitsForPass, pro: true);
          expect(earned, contains(id));
        });
        test('$id: NOT awarded below threshold ($hitsForFail/$minShots, pro)', () async {
          final earned = await eval(total: minShots, wrist: minShots, wristH: hitsForFail, pro: true);
          expect(earned, isNot(contains(id)));
        });
        test('$id: NOT awarded with fewer than $minShots typed shots (pro)', () async {
          final shots = minShots - 1;
          final earned = await eval(total: shots, wrist: shots, wristH: shots, pro: true);
          expect(earned, isNot(contains(id)));
        });
        test('$id: NOT awarded to free user', () async {
          final earned = await eval(total: minShots, wrist: minShots, wristH: hitsForPass, pro: false);
          expect(earned, isNot(contains(id)));
        });
      }

      overallAccTest('g_overall_accuracy_50', 10, 5, 4); // 50% vs 40%
      overallAccTest('g_overall_accuracy_60', 25, 15, 14); // 60% vs 56%
      overallAccTest('g_overall_accuracy_65', 30, 20, 19); // 66.7% vs 63.3%
      overallAccTest('g_overall_accuracy_75', 50, 38, 37); // 76% vs 74%
      overallAccTest('g_overall_accuracy_80', 50, 40, 39); // 80% vs 78%
      overallAccTest('g_overall_accuracy_85', 50, 43, 42); // 86% vs 84%
      overallAccTest('g_overall_accuracy_90', 50, 45, 44); // 90% vs 88%
      overallAccTest('g_overall_accuracy_95', 50, 48, 47); // 96% vs 94%

      // ── Per-type accuracy: parameterised helper ────────────────────────────

      // [shotField]: which typed-shot count to use (wrist/snap/slap/backhand).
      // [min]: minimum shots required for this threshold.
      // [hits]: hits needed to just-exceed the threshold.
      // [failHits]: hits that fall just below.
      void perTypeTest(
        String id,
        String shotField,
        int min,
        int hits,
        int failHits,
      ) {
        Future<List<String>> fire(int shotCount, int hitCount, {bool pro = true}) {
          switch (shotField) {
            case 'wrist':
              return eval(total: shotCount, wrist: shotCount, wristH: hitCount, pro: pro);
            case 'snap':
              return eval(total: shotCount, snap: shotCount, snapH: hitCount, pro: pro);
            case 'slap':
              return eval(total: shotCount, slap: shotCount, slapH: hitCount, pro: pro);
            default: // backhand
              return eval(total: shotCount, backhand: shotCount, backhandH: hitCount, pro: pro);
          }
        }

        test('$id: awarded at ${(hits / min * 100).round()}% with $min $shotField shots (pro)', () async {
          expect(await fire(min, hits), contains(id));
        });
        test('$id: NOT awarded at ${(failHits / min * 100).round()}% ($failHits/$min, pro)', () async {
          expect(await fire(min, failHits), isNot(contains(id)));
        });
        test('$id: NOT awarded with ${min - 1} $shotField shots even at 100% (pro)', () async {
          expect(await fire(min - 1, min - 1), isNot(contains(id)));
        });
        test('$id: NOT awarded to free user', () async {
          expect(await fire(min, hits, pro: false), isNot(contains(id)));
        });
      }

      // Wrist
      perTypeTest('g_wrist_accuracy_50', 'wrist', 10, 5, 4);
      perTypeTest('g_wrist_accuracy_60', 'wrist', 15, 9, 8);
      perTypeTest('g_wrist_accuracy_70', 'wrist', 20, 14, 13);
      perTypeTest('g_wrist_accuracy_75', 'wrist', 20, 15, 14);
      perTypeTest('g_wrist_accuracy_80', 'wrist', 25, 20, 19);
      perTypeTest('g_wrist_accuracy_85', 'wrist', 25, 22, 21);
      perTypeTest('g_wrist_accuracy_90', 'wrist', 25, 23, 22);
      perTypeTest('g_wrist_accuracy_95', 'wrist', 25, 24, 23);

      test('g_wrist_perfect: awarded with 25/25 wrist shots (pro)', () async {
        expect(await eval(total: 25, wrist: 25, wristH: 25, pro: true), contains('g_wrist_perfect'));
      });
      test('g_wrist_perfect: NOT awarded with one miss (24/25, pro)', () async {
        expect(await eval(total: 25, wrist: 25, wristH: 24, pro: true), isNot(contains('g_wrist_perfect')));
      });
      test('g_wrist_perfect: NOT awarded with fewer than 25 wrist shots', () async {
        expect(await eval(total: 24, wrist: 24, wristH: 24, pro: true), isNot(contains('g_wrist_perfect')));
      });

      // Snap
      perTypeTest('g_snap_accuracy_50', 'snap', 10, 5, 4);
      perTypeTest('g_snap_accuracy_60', 'snap', 15, 9, 8);
      perTypeTest('g_snap_accuracy_70', 'snap', 20, 14, 13);
      perTypeTest('g_snap_accuracy_75', 'snap', 20, 15, 14);
      perTypeTest('g_snap_accuracy_80', 'snap', 25, 20, 19);
      perTypeTest('g_snap_accuracy_85', 'snap', 25, 22, 21);
      perTypeTest('g_snap_accuracy_90', 'snap', 25, 23, 22);
      perTypeTest('g_snap_accuracy_95', 'snap', 25, 24, 23);

      test('g_snap_perfect: awarded with 25/25 snap shots (pro)', () async {
        expect(await eval(total: 25, snap: 25, snapH: 25, pro: true), contains('g_snap_perfect'));
      });
      test('g_snap_perfect: NOT awarded with 24/25 snap shots', () async {
        expect(await eval(total: 25, snap: 25, snapH: 24, pro: true), isNot(contains('g_snap_perfect')));
      });

      // Slap (thresholds scaled ~15pp lower — slap shots are ~2x harder to be accurate)
      perTypeTest('g_slap_accuracy_50', 'slap', 10, 4, 3); // 40% ≥ 35% ✓, 30% < 35% ✗
      perTypeTest('g_slap_accuracy_60', 'slap', 15, 7, 6); // 46.7% ≥ 45% ✓, 40% < 45% ✗
      perTypeTest('g_slap_accuracy_70', 'slap', 15, 9, 8); // 60% ≥ 55% ✓, 53% < 55% ✗
      perTypeTest('g_slap_accuracy_75', 'slap', 15, 9, 8); // 60% ≥ 60% ✓, 53% < 60% ✗
      perTypeTest('g_slap_accuracy_80', 'slap', 20, 13, 12); // 65% ≥ 65% ✓, 60% < 65% ✗
      perTypeTest('g_slap_accuracy_85', 'slap', 20, 14, 13); // 70% ≥ 70% ✓, 65% < 70% ✗
      perTypeTest('g_slap_accuracy_90', 'slap', 20, 15, 14); // 75% ≥ 75% ✓, 70% < 75% ✗
      perTypeTest('g_slap_accuracy_95', 'slap', 20, 16, 15); // 80% ≥ 80% ✓, 75% < 80% ✗

      test('g_slap_perfect: awarded with 20/20 slap shots (pro)', () async {
        expect(await eval(total: 20, slap: 20, slapH: 20, pro: true), contains('g_slap_perfect'));
      });
      test('g_slap_perfect: NOT awarded with 19/20 slap shots', () async {
        expect(await eval(total: 20, slap: 20, slapH: 19, pro: true), isNot(contains('g_slap_perfect')));
      });

      // Backhand
      perTypeTest('g_backhand_accuracy_50', 'backhand', 10, 5, 4);
      perTypeTest('g_backhand_accuracy_60', 'backhand', 15, 9, 8);
      perTypeTest('g_backhand_accuracy_70', 'backhand', 20, 14, 13);
      perTypeTest('g_backhand_accuracy_75', 'backhand', 20, 15, 14);
      perTypeTest('g_backhand_accuracy_80', 'backhand', 25, 20, 19);
      perTypeTest('g_backhand_accuracy_85', 'backhand', 25, 22, 21);
      perTypeTest('g_backhand_accuracy_90', 'backhand', 25, 23, 22);
      perTypeTest('g_backhand_accuracy_95', 'backhand', 25, 24, 23);

      test('g_backhand_perfect: awarded with 25/25 backhand shots (pro)', () async {
        expect(await eval(total: 25, backhand: 25, backhandH: 25, pro: true), contains('g_backhand_perfect'));
      });
      test('g_backhand_perfect: NOT awarded with 24/25 backhand shots', () async {
        expect(await eval(total: 25, backhand: 25, backhandH: 24, pro: true), isNot(contains('g_backhand_perfect')));
      });

      // ── All-types accuracy ────────────────────────────────────────────────────

      // Helper: all four types with equal shot counts and equal hit counts.
      Future<List<String>> allTypes(int each, int hitsEach, {bool pro = true}) => eval(
            total: each * 4,
            wrist: each,
            snap: each,
            slap: each,
            backhand: each,
            wristH: hitsEach,
            snapH: hitsEach,
            slapH: hitsEach,
            backhandH: hitsEach,
            pro: pro,
          );

      void allTypesAccTest(String id, int minEach, int hitsForPass, int hitsForFail) {
        test('$id: awarded when all types hit threshold ($hitsForPass/$minEach each, pro)', () async {
          expect(await allTypes(minEach, hitsForPass), contains(id));
        });
        test('$id: NOT awarded when all types fall below threshold ($hitsForFail/$minEach, pro)', () async {
          expect(await allTypes(minEach, hitsForFail), isNot(contains(id)));
        });
        test('$id: NOT awarded when one type is below minimum shots (pro)', () async {
          // backhand is one short
          final earned = await eval(
            total: minEach * 3 + (minEach - 1),
            wrist: minEach,
            snap: minEach,
            slap: minEach,
            backhand: minEach - 1,
            wristH: hitsForPass,
            snapH: hitsForPass,
            slapH: hitsForPass,
            backhandH: hitsForPass,
            pro: true,
          );
          expect(earned, isNot(contains(id)));
        });
        test('$id: NOT awarded to free user', () async {
          expect(await allTypes(minEach, hitsForPass, pro: false), isNot(contains(id)));
        });
      }

      allTypesAccTest('g_all_types_accuracy_50', 10, 5, 4); // 50% vs 40%
      allTypesAccTest('g_all_types_accuracy_60', 10, 6, 5); // 60% vs 50%
      allTypesAccTest('g_all_types_accuracy_70', 15, 11, 10); // 73% vs 67%
      allTypesAccTest('g_all_types_accuracy_80', 25, 20, 19); // 80% vs 76%
      allTypesAccTest('g_all_types_accuracy_85', 25, 22, 21); // 88% vs 84%
      allTypesAccTest('g_all_types_accuracy_90', 25, 23, 22); // 92% vs 88%
      allTypesAccTest('g_all_types_accuracy_95', 25, 24, 23); // 96% vs 92%

      test('g_all_types_perfect: awarded with 25/25 on all four types (pro)', () async {
        expect(await allTypes(25, 25), contains('g_all_types_perfect'));
      });
      test('g_all_types_perfect: NOT awarded when one type has a miss (pro)', () async {
        final earned = await eval(
          total: 100,
          wrist: 25, snap: 25, slap: 25, backhand: 25,
          wristH: 25, snapH: 25, slapH: 25,
          backhandH: 24, // one miss
          pro: true,
        );
        expect(earned, isNot(contains('g_all_types_perfect')));
      });

      // ── Perfect sessions ──────────────────────────────────────────────────────

      test('g_perfect_session: awarded with 25+ typed shots at 100% accuracy (pro)', () async {
        expect(await eval(total: 25, wrist: 25, wristH: 25, pro: true), contains('g_perfect_session'));
      });

      test('g_perfect_session: NOT awarded with 24 typed shots even at 100%', () async {
        expect(await eval(total: 24, wrist: 24, wristH: 24, pro: true), isNot(contains('g_perfect_session')));
      });

      test('g_perfect_session: NOT awarded with one miss (24/25)', () async {
        expect(await eval(total: 25, wrist: 25, wristH: 24, pro: true), isNot(contains('g_perfect_session')));
      });

      test('g_perfect_session: NOT awarded to free user', () async {
        expect(await eval(total: 25, wrist: 25, wristH: 25, pro: false), isNot(contains('g_perfect_session')));
      });

      test('g_perfect_session_50: awarded with 50+ typed shots at 100% (pro)', () async {
        final earned = await eval(total: 50, wrist: 50, wristH: 50, pro: true);
        expect(earned, contains('g_perfect_session'));
        expect(earned, contains('g_perfect_session_50'));
      });

      test('g_perfect_session_50: NOT awarded with 49 typed shots', () async {
        expect(await eval(total: 49, wrist: 49, wristH: 49, pro: true), isNot(contains('g_perfect_session_50')));
      });

      test('g_perfect_session_75: awarded with 75+ typed shots at 100% (pro)', () async {
        final earned = await eval(total: 75, wrist: 75, wristH: 75, pro: true);
        expect(earned, contains('g_perfect_session_75'));
        expect(earned, contains('g_perfect_session_50'));
        expect(earned, contains('g_perfect_session'));
      });

      test('g_perfect_session_75: NOT awarded with 74 typed shots', () async {
        expect(await eval(total: 74, wrist: 74, wristH: 74, pro: true), isNot(contains('g_perfect_session_75')));
      });

      test('g_perfect_session_100: awarded with 100+ typed shots at 100% (pro)', () async {
        final earned = await eval(total: 100, wrist: 100, wristH: 100, pro: true);
        expect(earned, contains('g_perfect_session_100'));
        expect(earned, contains('g_perfect_session_75'));
        expect(earned, contains('g_perfect_session_50'));
        expect(earned, contains('g_perfect_session'));
      });

      test('g_perfect_session_100: NOT awarded with 99 typed shots', () async {
        expect(await eval(total: 99, wrist: 99, wristH: 99, pro: true), isNot(contains('g_perfect_session_100')));
      });

      // ── Accuracy streak trophies ──────────────────────────────────────────────
      //
      // g_accuracy_streak_2 uses the 65% (streak65) counter.
      // g_accuracy_streak_3 and above use the 70% counter.

      // --- streak_2 (65% threshold) ---

      test('g_accuracy_streak_2: awarded on 2nd consecutive 65%+ session (pro)', () async {
        // Seed streak65=1, then pass with 66.7% (20/30)
        await seed(blank(accuracyStreak65: 1, total: 100, sessions: 5));
        final earned = await eval(total: 30, wrist: 30, wristH: 20, pro: true);
        expect(earned, contains('g_accuracy_streak_2'));
      });

      test('g_accuracy_streak_2: NOT awarded when session drops to 64% (pro)', () async {
        await seed(blank(accuracyStreak65: 1, total: 100, sessions: 5));
        // 19/30 = 63.3% < 65% → streak65 resets to 0
        final earned = await eval(total: 30, wrist: 30, wristH: 19, pro: true);
        expect(earned, isNot(contains('g_accuracy_streak_2')));
        final s = await service.getUserSummary(uid);
        expect(s.currentAccuracyStreak65, 0);
      });

      test('g_accuracy_streak_2: NOT awarded to free user', () async {
        await seed(blank(accuracyStreak65: 1, total: 100, sessions: 5));
        final earned = await eval(total: 30, wrist: 30, wristH: 20, pro: false);
        expect(earned, isNot(contains('g_accuracy_streak_2')));
      });

      // Session exactly at 65% should count toward streak65 but NOT streak70
      test('65% session increments streak65 but not streak70 (pro)', () async {
        // 65/100 = exactly 65%
        await eval(total: 100, wrist: 100, wristH: 65, pro: true);
        final s = await service.getUserSummary(uid);
        expect(s.currentAccuracyStreak65, 1);
        expect(s.currentAccuracyStreak, 0); // 65% < 70%
      });

      // --- streak_3 (70% threshold) ---

      test('g_accuracy_streak_3: awarded on 3rd consecutive 70%+ session (pro)', () async {
        await seed(blank(accuracyStreak: 2, total: 100, sessions: 5));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: true); // 76% ≥ 70%
        expect(earned, contains('g_accuracy_streak_3'));
      });

      test('g_accuracy_streak_3: NOT awarded on 2nd consecutive session', () async {
        await seed(blank(accuracyStreak: 1, total: 100, sessions: 5));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: true);
        expect(earned, isNot(contains('g_accuracy_streak_3')));
      });

      // --- streak_4 ---

      test('g_accuracy_streak_4: awarded on 4th consecutive 70%+ session (pro)', () async {
        await seed(blank(accuracyStreak: 3, total: 100, sessions: 5));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: true);
        expect(earned, contains('g_accuracy_streak_4'));
      });

      // --- streak_5 ---

      test('g_accuracy_streak_5: awarded on 5th consecutive 70%+ session (pro)', () async {
        await seed(blank(accuracyStreak: 4, total: 100, sessions: 5));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: true);
        expect(earned, contains('g_accuracy_streak_5'));
      });

      test('g_accuracy_streak_5: NOT awarded on 4th consecutive session', () async {
        await seed(blank(accuracyStreak: 3, total: 100, sessions: 5));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: true);
        expect(earned, isNot(contains('g_accuracy_streak_5')));
      });

      test('g_accuracy_streak_5: NOT awarded to free user', () async {
        await seed(blank(accuracyStreak: 4, total: 100, sessions: 5));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: false);
        expect(earned, isNot(contains('g_accuracy_streak_5')));
      });

      // --- streak_10 ---

      test('g_accuracy_streak_10: awarded on 10th consecutive 70%+ session (pro)', () async {
        await seed(blank(accuracyStreak: 9, total: 100, sessions: 10));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: true);
        expect(earned, contains('g_accuracy_streak_10'));
      });

      test('g_accuracy_streak_10: NOT awarded on 9th consecutive session', () async {
        await seed(blank(accuracyStreak: 8, total: 100, sessions: 9));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: true);
        expect(earned, isNot(contains('g_accuracy_streak_10')));
      });

      // --- streak_15 ---

      test('g_accuracy_streak_15: awarded on 15th consecutive 70%+ session (pro)', () async {
        await seed(blank(accuracyStreak: 14, total: 200, sessions: 15));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: true);
        expect(earned, contains('g_accuracy_streak_15'));
      });

      // --- streak_20 ---

      test('g_accuracy_streak_20: awarded on 20th consecutive 70%+ session (pro)', () async {
        await seed(blank(accuracyStreak: 19, total: 300, sessions: 20));
        final earned = await eval(total: 50, wrist: 50, wristH: 38, pro: true);
        expect(earned, contains('g_accuracy_streak_20'));
      });

      // --- streak reset / zero-typed-shots boundary ---

      test('70%+ streak resets to 0 when session drops below 70% (pro)', () async {
        await seed(blank(accuracyStreak: 5, total: 100, sessions: 6));
        // 30/50 = 60% < 70%
        await eval(total: 50, wrist: 50, wristH: 30, pro: true);
        final s = await service.getUserSummary(uid);
        expect(s.currentAccuracyStreak, 0);
      });

      test('65%+ streak resets to 0 when session drops below 65% (pro)', () async {
        await seed(blank(accuracyStreak65: 3, total: 100, sessions: 4));
        // 19/30 = 63.3% < 65%
        await eval(total: 30, wrist: 30, wristH: 19, pro: true);
        final s = await service.getUserSummary(uid);
        expect(s.currentAccuracyStreak65, 0);
      });

      test('both streaks preserved when session has zero typed shots (pro)', () async {
        await seed(blank(accuracyStreak65: 3, accuracyStreak: 3, total: 100, sessions: 4));
        // No typed shots → neither streak changes
        await eval(total: 10, wrist: 0, snap: 0, slap: 0, backhand: 0, pro: true);
        final s = await service.getUserSummary(uid);
        expect(s.currentAccuracyStreak65, 3);
        expect(s.currentAccuracyStreak, 3);
      });
    });

    // =========================================================================
    // 10. DUPLICATE PREVENTION  (already-earned trophies not re-returned)
    // =========================================================================

    group('Duplicate prevention', () {
      test('already-earned volume trophy not returned again', () async {
        await seed(blank(earned: ['g_first_shot'], total: 0));
        final earned = await eval(total: 1);
        expect(earned, isNot(contains('g_first_shot')));
      });

      test('already-earned session trophy not returned again', () async {
        await seed(blank(earned: ['g_first_session'], sessions: 0));
        final earned = await eval();
        expect(earned, isNot(contains('g_first_session')));
      });

      test('crossing multiple thresholds with some already earned only returns new ones', () async {
        // g_first_shot and g_shots_100 already earned; g_shots_250 is new
        await seed(blank(earned: ['g_first_shot', 'g_shots_100'], total: 249));
        final earned = await eval(total: 1);
        expect(earned, isNot(contains('g_first_shot')));
        expect(earned, isNot(contains('g_shots_100')));
        expect(earned, contains('g_shots_250'));
      });

      test('trophy persisted in Firestore after award', () async {
        await eval(total: 1);
        final summary = await service.getUserSummary(uid);
        expect(summary.trophies, contains('g_first_shot'));
        expect(summary.trophies, contains('g_first_session'));
      });
    });

    // 11. MULTI-TROPHY SESSIONS
    // =========================================================================

    group('Multiple trophies awarded in a single session', () {
      test('first session from scratch awards g_first_shot and g_first_session', () async {
        final earned = await eval(total: 1);
        expect(earned, contains('g_first_shot'));
        expect(earned, contains('g_first_session'));
      });

      test('large first session awards all reachable volume thresholds', () async {
        final earned = await eval(total: 5000, pro: false);
        for (final id in [
          'g_first_shot',
          'g_shots_100',
          'g_shots_250',
          'g_shots_500',
          'g_shots_1000',
          'g_shots_2500',
          'g_shots_5000',
        ]) {
          expect(earned, contains(id), reason: '$id should be awarded');
        }
      });

      test('perfect 50-shot session awards both perfect trophies plus accuracy trophies', () async {
        const shots = 50;
        final earned = await eval(
          total: shots,
          wrist: shots,
          wristH: shots,
          pro: true,
        );
        expect(earned, contains('g_perfect_session'));
        expect(earned, contains('g_perfect_session_50'));
        expect(earned, contains('g_wrist_accuracy_80'));
        expect(earned, contains('g_wrist_accuracy_90'));
        expect(earned, contains('g_overall_accuracy_75'));
      });
    });

    // =========================================================================
    // 12. ACCUMULATOR PERSISTENCE
    // =========================================================================

    group('Accumulators persist correctly across multiple sessions', () {
      test('allTimeTotal accumulates across two sequential eval calls', () async {
        await eval(total: 50);
        await eval(total: 50);
        final summary = await service.getUserSummary(uid);
        expect(summary.allTimeTotal, 100);
      });

      test('allTimeSessions increments on each eval call', () async {
        await eval();
        await eval();
        await eval();
        final summary = await service.getUserSummary(uid);
        expect(summary.allTimeSessions, 3);
      });

      test('per-type counters accumulate across sessions', () async {
        await eval(total: 10, wrist: 5, snap: 3, slap: 1, backhand: 1);
        await eval(total: 10, wrist: 2, snap: 4, slap: 2, backhand: 2);
        final summary = await service.getUserSummary(uid);
        expect(summary.allTimeWrist, 7);
        expect(summary.allTimeSnap, 7);
        expect(summary.allTimeSlap, 3);
        expect(summary.allTimeBackhand, 3);
      });

      test('volume trophy awarded on second call when threshold crossed', () async {
        // First call: 90 shots (below 100)
        final first = await eval(total: 90);
        expect(first, isNot(contains('g_shots_100')));
        // Second call: 10 more shots (total = 100)
        final second = await eval(total: 10);
        expect(second, contains('g_shots_100'));
      });

      test('weekly total resets when entering a new week', () async {
        final prevWeekStart = GlobalTrophyService.currentWeekStartUtc().subtract(const Duration(days: 7));
        // Pre-seed with 900 shots last week
        await seed(blank(
          weekTotal: 900,
          weekStart: prevWeekStart,
          weekDays: [
            GlobalWeeklySessionEntry(
              dateKey: dateKey(prevWeekStart.add(const Duration(days: 3))),
              total: 900,
            )
          ],
          total: 900,
          sessions: 5,
        ));
        // Eval in the new week with only 100 shots
        final earned = await eval(total: 100);
        // g_week_1000 should NOT be awarded - weekly counter was reset
        expect(earned, isNot(contains('g_week_1000')));
        // But g_week_500 should also NOT be awarded (only 100 shots this week)
        expect(earned, isNot(contains('g_week_500')));
      });
    });

    // =========================================================================
    // 13. WEEK-START HELPER
    // =========================================================================

    group('currentWeekStartUtc', () {
      test('returns a Sunday at midnight EST', () {
        final ws = GlobalTrophyService.currentWeekStartUtc();
        // Shift back 5 hours to recover the EST midnight instant.
        final estMidnight = ws.add(const Duration(hours: -5));
        // DateTime.sunday = 7; (7 % 7) == 0 confirms it is a Sunday in the code.
        expect(estMidnight.hour, 0);
        expect(estMidnight.minute, 0);
        expect(estMidnight.second, 0);
        expect(estMidnight.weekday % 7, 0, reason: 'Should be Sunday (weekday%7 == 0)');
      });

      test('is stable when called twice in quick succession', () {
        final ws1 = GlobalTrophyService.currentWeekStartUtc();
        final ws2 = GlobalTrophyService.currentWeekStartUtc();
        expect(ws1, equals(ws2));
      });
    });
  });
}

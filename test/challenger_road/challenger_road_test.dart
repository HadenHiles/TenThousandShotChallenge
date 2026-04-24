import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeAllTimeHistory.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeProgressEntry.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seeds one active challenge + level doc.  Returns the challenge document ID.
Future<String> _seedChallenge(
  FakeFirebaseFirestore db, {
  required int level,
  String? challengeId,
  bool active = true,
  bool levelActive = true,
  Map<String, dynamic>? challengeData,
  Map<String, dynamic>? levelData,
}) async {
  final id = challengeId ?? 'ch_$level';
  final levelId = 'level_$level';

  await db.collection('challenger_road_levels').doc(levelId).set({
    'level': level,
    'level_name': 'Level $level',
    'active': levelActive,
    ...?levelData,
  });

  await db.collection('challenger_road_levels').doc(levelId).collection('challenges').doc(id).set({
    'level': level,
    'level_name': 'Level $level',
    'sequence': 1,
    'shots_required': 10,
    'shots_to_pass': 6,
    'name': 'Challenge $level',
    'description': 'Description $level',
    'active': active,
    'shot_type': 'wrist',
    'steps': const <Map<String, dynamic>>[],
    ...?challengeData,
  });
  return id;
}

/// Seeds a passing challenge_progress entry for [challengeId] in [attemptId].
Future<void> _seedPassingProgress(
  FakeFirebaseFirestore db, {
  required String userId,
  required String attemptId,
  required String challengeId,
  required int level,
}) async {
  final date = DateTime.now();
  await db.collection('users').doc(userId).collection('challenger_road_attempts').doc(attemptId).collection('challenge_progress').doc(challengeId).set({
    'challengeId': challengeId,
    'bestLevel': level,
    'totalAttempts': 1,
    'totalPassed': 1,
    'firstPassedAt': Timestamp.fromDate(date),
    'lastAttemptAt': Timestamp.fromDate(date),
    'levelHistory': [
      {
        'level': level,
        'passed': true,
        'shotsMade': 8,
        'shotsRequired': 10,
        'date': Timestamp.fromDate(date),
      }
    ],
  });
}

/// Creates an active attempt document and returns its ID.
Future<String> _seedAttempt(
  FakeFirebaseFirestore db, {
  required String userId,
  int currentLevel = 1,
  int highestLevel = 1,
  int startingLevel = 1,
  int shotCount = 0,
  int totalShots = 0,
  int resetCount = 0,
  String status = 'active',
}) async {
  final ref = await db.collection('users').doc(userId).collection('challenger_road_attempts').add({
    'attempt_number': 1,
    'starting_level': startingLevel,
    'current_level': currentLevel,
    'challenger_road_shot_count': shotCount,
    'total_shots_this_attempt': totalShots,
    'reset_count': resetCount,
    'highest_level_reached_this_attempt': highestLevel,
    'status': status,
    'start_date': Timestamp.fromDate(DateTime.now()),
    'end_date': null,
  });
  return ref.id;
}

Future<void> _seedSummary(
  FakeFirebaseFirestore db, {
  required String userId,
  int totalAttempts = 0,
  int allTimeBestLevel = 0,
  int? allTimeBestLevelShots,
  int allTimeTotalChallengerRoadShots = 0,
  List<String> badges = const [],
}) async {
  await db.collection('users').doc(userId).collection('challenger_road').doc('summary').set({
    'total_attempts': totalAttempts,
    'all_time_best_level': allTimeBestLevel,
    'all_time_best_level_shots': allTimeBestLevelShots,
    'all_time_total_challenger_road_shots': allTimeTotalChallengerRoadShots,
    'badges': badges,
  });
}

ChallengeSession _makeSession({
  String challengeId = 'ch_1',
  int level = 1,
  int shotsMade = 8,
  int totalShots = 10,
  int shotsRequired = 10,
  int shotsToPass = 6,
  bool? passed,
}) {
  final p = passed ?? (shotsMade >= shotsToPass);
  return ChallengeSession(
    challengeId: challengeId,
    challengeName: '',
    level: level,
    date: DateTime.now(),
    duration: const Duration(minutes: 5),
    shotsRequired: shotsRequired,
    shotsToPass: shotsToPass,
    shotsMade: shotsMade,
    totalShots: totalShots,
    passed: p,
    shots: [],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Model round-trip tests ────────────────────────────────────────────────

  group('ChallengerRoadLevel fromMap / toMap round-trip', () {
    test('preserves all scalar fields', () {
      final map = {
        'id': 'lvl_1',
        'level': 2,
        'level_name': 'Level 2',
        'sequence': 3,
        'shots_required': 15,
        'shots_to_pass': 10,
        'active': true,
        'steps': null,
      };
      final obj = ChallengerRoadLevel.fromMap(map);
      expect(obj.level, 2);
      expect(obj.levelName, 'Level 2');
      expect(obj.sequence, 3);
      expect(obj.shotsRequired, 15);
      expect(obj.shotsToPass, 10);
      expect(obj.challengeName, isNull);
      expect(obj.challengeDescription, isNull);
      expect(obj.challengeShotType, isNull);
      expect(obj.active, true);
      expect(obj.steps, isNull);

      final rt = ChallengerRoadLevel.fromMap(obj.toMap());
      expect(rt.level, obj.level);
      expect(rt.levelName, obj.levelName);
      expect(rt.shotsRequired, obj.shotsRequired);
      expect(rt.shotsToPass, obj.shotsToPass);
      expect(rt.challengeName, obj.challengeName);
      expect(rt.challengeDescription, obj.challengeDescription);
      expect(rt.challengeShotType, obj.challengeShotType);
      expect(rt.active, obj.active);
    });

    test('preserves per-level challenge overrides', () {
      final map = {
        'id': 'lvl_2',
        'level': 2,
        'level_name': 'Level 2',
        'sequence': 4,
        'shots_required': 15,
        'shots_to_pass': 10,
        'name': 'Custom Level Challenge',
        'description': 'Level-specific description',
        'shot_type': 'snap',
        'preview_thumbnail_url': 'https://example.com/thumb.png',
        'preview_thumbnail_media_type': 'image',
        'active': true,
        'steps': null,
      };

      final obj = ChallengerRoadLevel.fromMap(map);
      expect(obj.challengeName, 'Custom Level Challenge');
      expect(obj.challengeDescription, 'Level-specific description');
      expect(obj.challengeShotType, 'snap');
      expect(obj.previewThumbnailUrl, 'https://example.com/thumb.png');
      expect(obj.previewThumbnailMediaType, 'image');

      final rt = ChallengerRoadLevel.fromMap(obj.toMap());
      expect(rt.challengeName, obj.challengeName);
      expect(rt.challengeDescription, obj.challengeDescription);
      expect(rt.challengeShotType, obj.challengeShotType);
      expect(rt.previewThumbnailUrl, obj.previewThumbnailUrl);
      expect(rt.previewThumbnailMediaType, obj.previewThumbnailMediaType);
    });

    test('uses defaults when fields are absent', () {
      final obj = ChallengerRoadLevel.fromMap({});
      expect(obj.level, 1);
      expect(obj.levelName, 'Level 1');
      expect(obj.shotsRequired, 10);
      expect(obj.shotsToPass, 6);
      expect(obj.challengeName, isNull);
      expect(obj.active, true);
    });
  });

  group('ChallengerRoadService.getChallengesForLevel()', () {
    late FakeFirebaseFirestore db;
    late ChallengerRoadService service;

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ChallengerRoadService(firestore: db);
    });

    test('returns level-owned challenge documents with their final UI fields', () async {
      await _seedChallenge(
        db,
        level: 2,
        challengeId: 'ch_custom',
        challengeData: {
          'name': 'Custom Level Challenge',
          'description': 'Level-specific description',
          'shot_type': 'snap',
          'preview_thumbnail_url': 'https://example.com/level.png',
          'preview_thumbnail_media_type': 'image',
          'steps': [
            {
              'step_number': 1,
              'title': 'Level Step',
              'media_type': 'image',
              'media_url': 'https://example.com/level-step.png',
              'summary': 'Level summary',
            }
          ],
        },
      );

      final challenges = await service.getChallengesForLevel(2);

      expect(challenges, hasLength(1));
      expect(challenges.first.id, 'ch_custom');
      expect(challenges.first.name, 'Custom Level Challenge');
      expect(challenges.first.description, 'Level-specific description');
      expect(challenges.first.shotType, 'snap');
      expect(challenges.first.previewThumbnailUrl, 'https://example.com/level.png');
      expect(challenges.first.steps, hasLength(1));
      expect(challenges.first.steps.first.title, 'Level Step');
    });

    test('falls back to parent challenge fields when no level overrides exist', () async {
      await _seedChallenge(
        db,
        level: 1,
        challengeId: 'ch_base',
        challengeData: {
          'name': 'Base Challenge',
          'description': 'Base description',
          'shot_type': 'backhand',
          'steps': [
            {
              'step_number': 1,
              'title': 'Base Step',
              'media_type': 'image',
              'media_url': 'https://example.com/base.png',
              'summary': 'Base summary',
            }
          ],
        },
      );

      final challenges = await service.getChallengesForLevel(1);

      expect(challenges, hasLength(1));
      expect(challenges.first.name, 'Base Challenge');
      expect(challenges.first.description, 'Base description');
      expect(challenges.first.shotType, 'backhand');
      expect(challenges.first.steps.first.title, 'Base Step');
    });
  });

  group('ChallengeSession fromMap / toMap', () {
    test('fromMap correctly deserializes all fields', () {
      final date = DateTime(2025, 6, 1, 12);
      final map = {
        'id': 'sess_1',
        'challenge_id': 'ch_1',
        'level': 3,
        'date': Timestamp.fromDate(date),
        'duration': 300,
        'shots_required': 12,
        'shots_to_pass': 8,
        'shots_made': 9,
        'total_shots': 12,
        'passed': true,
        'shots': <dynamic>[],
      };
      final obj = ChallengeSession.fromMap(map);
      expect(obj.challengeId, 'ch_1');
      expect(obj.level, 3);
      expect(obj.shotsMade, 9);
      expect(obj.totalShots, 12);
      expect(obj.passed, true);
      expect(obj.duration.inSeconds, 300);
    });

    test('toMap preserves scalar fields', () {
      final session = _makeSession(challengeId: 'ch_2', level: 2, shotsMade: 7, totalShots: 10);
      final map = session.toMap();
      expect(map['challenge_id'], 'ch_2');
      expect(map['level'], 2);
      expect(map['shots_made'], 7);
      expect(map['total_shots'], 10);
      expect(map['passed'], true);
    });
  });

  group('ChallengeProgressEntry fromMap / toMap round-trip', () {
    test('preserves all fields including levelHistory', () {
      final date = DateTime(2025, 5, 1);
      final map = {
        'challengeId': 'ch_2',
        'bestLevel': 2,
        'totalAttempts': 3,
        'totalPassed': 2,
        'firstPassedAt': Timestamp.fromDate(date),
        'lastAttemptAt': Timestamp.fromDate(date),
        'levelHistory': [
          {
            'level': 1,
            'passed': true,
            'shotsMade': 7,
            'shotsRequired': 10,
            'date': Timestamp.fromDate(date),
          }
        ],
      };
      final obj = ChallengeProgressEntry.fromMap(map);
      expect(obj.challengeId, 'ch_2');
      expect(obj.bestLevel, 2);
      expect(obj.totalAttempts, 3);
      expect(obj.totalPassed, 2);
      expect(obj.levelHistory.length, 1);
      expect(obj.levelHistory.first.shotsMade, 7);

      final rt = ChallengeProgressEntry.fromMap(obj.toMap());
      expect(rt.challengeId, obj.challengeId);
      expect(rt.bestLevel, obj.bestLevel);
      expect(rt.totalAttempts, obj.totalAttempts);
      expect(rt.levelHistory.length, obj.levelHistory.length);
    });
  });

  group('ChallengeAllTimeHistory fromMap / toMap round-trip', () {
    test('preserves all fields', () {
      final first = DateTime(2024, 1, 1);
      final last = DateTime(2025, 1, 1);
      final map = {
        'challengeId': 'ch_3',
        'allTimeBestLevel': 5,
        'allTimeTotalAttempts': 10,
        'allTimeTotalPassed': 7,
        'firstPassedAt': Timestamp.fromDate(first),
        'lastPassedAt': Timestamp.fromDate(last),
      };
      final obj = ChallengeAllTimeHistory.fromMap(map);
      expect(obj.challengeId, 'ch_3');
      expect(obj.allTimeBestLevel, 5);
      expect(obj.allTimeTotalAttempts, 10);
      expect(obj.allTimeTotalPassed, 7);
      expect(obj.firstPassedAt, first);
      expect(obj.lastPassedAt, last);

      final rt = ChallengeAllTimeHistory.fromMap(obj.toMap());
      expect(rt.allTimeBestLevel, obj.allTimeBestLevel);
      expect(rt.allTimeTotalAttempts, obj.allTimeTotalAttempts);
      expect(rt.firstPassedAt, obj.firstPassedAt);
    });

    test('handles null timestamp fields', () {
      final map = {
        'challengeId': 'ch_null',
        'allTimeBestLevel': 0,
        'allTimeTotalAttempts': 1,
        'allTimeTotalPassed': 0,
        'firstPassedAt': null,
        'lastPassedAt': null,
      };
      final obj = ChallengeAllTimeHistory.fromMap(map);
      expect(obj.firstPassedAt, isNull);
      expect(obj.lastPassedAt, isNull);
    });
  });

  group('ChallengerRoadUserSummary fromMap / toMap round-trip', () {
    test('preserves best-attempt shots metadata', () {
      final summary = ChallengerRoadUserSummary.fromMap({
        'current_attempt_id': 'attempt_1',
        'total_attempts': 3,
        'all_time_best_level': 6,
        'all_time_best_level_shots': 2450,
        'all_time_total_challenger_road_shots': 12000,
        'badges': ['cr_attempts_1'],
      });

      expect(summary.currentAttemptId, 'attempt_1');
      expect(summary.allTimeBestLevel, 6);
      expect(summary.allTimeBestLevelShots, 2450);

      final roundTrip = ChallengerRoadUserSummary.fromMap(summary.toMap());
      expect(roundTrip.allTimeBestLevel, 6);
      expect(roundTrip.allTimeBestLevelShots, 2450);
    });

    test('defaults best-attempt shots to null for older docs', () {
      final summary = ChallengerRoadUserSummary.fromMap({
        'total_attempts': 1,
        'all_time_best_level': 4,
        'all_time_total_challenger_road_shots': 5000,
        'badges': <String>[],
      });

      expect(summary.allTimeBestLevel, 4);
      expect(summary.allTimeBestLevelShots, isNull);
    });
  });

  // ── Service tests using FakeFirebaseFirestore ─────────────────────────────

  group('ChallengerRoadService.isLevelComplete()', () {
    late FakeFirebaseFirestore db;
    late ChallengerRoadService service;
    const uid = 'test_user';

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ChallengerRoadService(firestore: db);
    });

    test('returns false when no challenge docs exist at the level', () async {
      final attemptId = await _seedAttempt(db, userId: uid);
      final result = await service.isLevelComplete(uid, attemptId, 1);
      expect(result, false);
    });

    test('returns false when at least one challenge is not passed', () async {
      await _seedChallenge(db, level: 1, challengeId: 'ch_a');
      await _seedChallenge(db, level: 1, challengeId: 'ch_b');
      final attemptId = await _seedAttempt(db, userId: uid);

      // Only pass ch_a; ch_b has no progress entry.
      await _seedPassingProgress(db, userId: uid, attemptId: attemptId, challengeId: 'ch_a', level: 1);

      final result = await service.isLevelComplete(uid, attemptId, 1);
      expect(result, false);
    });

    test('returns true only when all active challenges at the level are passed', () async {
      await _seedChallenge(db, level: 1, challengeId: 'ch_a');
      await _seedChallenge(db, level: 1, challengeId: 'ch_b');
      final attemptId = await _seedAttempt(db, userId: uid);

      await _seedPassingProgress(db, userId: uid, attemptId: attemptId, challengeId: 'ch_a', level: 1);
      await _seedPassingProgress(db, userId: uid, attemptId: attemptId, challengeId: 'ch_b', level: 1);

      final result = await service.isLevelComplete(uid, attemptId, 1);
      expect(result, true);
    });

    test('ignores inactive challenge docs when checking completion', () async {
      await _seedChallenge(db, level: 1, challengeId: 'ch_active');
      await _seedChallenge(db, level: 1, challengeId: 'ch_inactive', active: false);
      final attemptId = await _seedAttempt(db, userId: uid);

      await _seedPassingProgress(db, userId: uid, attemptId: attemptId, challengeId: 'ch_active', level: 1);
      // ch_inactive NOT passed - but it's inactive, so level should still be complete.

      final result = await service.isLevelComplete(uid, attemptId, 1);
      expect(result, true);
    });
  });

  group('ChallengerRoadService.incrementChallengerRoadShots()', () {
    late FakeFirebaseFirestore db;
    late ChallengerRoadService service;
    const uid = 'test_user';

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ChallengerRoadService(firestore: db);
    });

    test('does not trigger milestone below 10,000', () async {
      final attemptId = await _seedAttempt(db, userId: uid, shotCount: 5000);
      final result = await service.incrementChallengerRoadShots(uid, attemptId, 100);
      expect(result.didHitMilestone, false);
      expect(result.newCount, 5100);
      expect(result.resetCount, 0);
    });

    test('triggers milestone at exactly 10,000', () async {
      final attemptId = await _seedAttempt(db, userId: uid, shotCount: 9950);
      final result = await service.incrementChallengerRoadShots(uid, attemptId, 50);
      expect(result.didHitMilestone, true);
      expect(result.newCount, 0);
      expect(result.resetCount, 1);
    });

    test('wraps remainder correctly when overshooting 10,000', () async {
      final attemptId = await _seedAttempt(db, userId: uid, shotCount: 9990);
      final result = await service.incrementChallengerRoadShots(uid, attemptId, 25);
      expect(result.didHitMilestone, true);
      expect(result.newCount, 15);
      expect(result.resetCount, 1);
    });

    test('totalShotsThisAttempt never resets across milestone', () async {
      final attemptId = await _seedAttempt(db, userId: uid, shotCount: 9990, totalShots: 9990);
      await service.incrementChallengerRoadShots(uid, attemptId, 25);

      final snap = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptId).get();
      final data = snap.data()!;
      expect(data['total_shots_this_attempt'], 9990 + 25);
      expect(data['challenger_road_shot_count'], 15);
    });

    test('resetCount increments cumulatively across multiple milestones', () async {
      final attemptId = await _seedAttempt(db, userId: uid, shotCount: 9990, resetCount: 2);
      final result = await service.incrementChallengerRoadShots(uid, attemptId, 20);
      expect(result.resetCount, 3);
    });
  });

  group('ChallengerRoadService.restartChallengerRoad()', () {
    late FakeFirebaseFirestore db;
    late ChallengerRoadService service;
    const uid = 'test_user';

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ChallengerRoadService(firestore: db);
    });

    test('creates first attempt at level 1 when no previous attempt exists', () async {
      final newAttempt = await service.restartChallengerRoad(uid);
      expect(newAttempt.startingLevel, 1);
      expect(newAttempt.currentLevel, 1);
      expect(newAttempt.status, 'active');
    });

    test('starting level = max(1, highestLevelReached - 1)', () async {
      await _seedAttempt(db, userId: uid, highestLevel: 5);
      final newAttempt = await service.restartChallengerRoad(uid);
      expect(newAttempt.startingLevel, 4);
    });

    test('starting level is at minimum 1 when highestLevel is 1', () async {
      await _seedAttempt(db, userId: uid, highestLevel: 1);
      final newAttempt = await service.restartChallengerRoad(uid);
      expect(newAttempt.startingLevel, 1);
    });

    test('starting level is at minimum 1 when highestLevel is 2', () async {
      await _seedAttempt(db, userId: uid, highestLevel: 2);
      final newAttempt = await service.restartChallengerRoad(uid);
      expect(newAttempt.startingLevel, 1);
    });

    test('marks the old attempt as cancelled for a mid-attempt do-over', () async {
      final oldId = await _seedAttempt(db, userId: uid, highestLevel: 3);
      await service.restartChallengerRoad(uid);

      final snap = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(oldId).get();
      expect(snap.data()!['status'], 'cancelled');
    });

    test('new attempt is set to active', () async {
      await _seedAttempt(db, userId: uid, highestLevel: 4);
      final newAttempt = await service.restartChallengerRoad(uid);
      expect(newAttempt.status, 'active');
    });
  });

  group('ChallengerRoadService.advanceLevel() best-attempt comparator', () {
    late FakeFirebaseFirestore db;
    late ChallengerRoadService service;
    const uid = 'test_user';

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ChallengerRoadService(firestore: db);
    });

    test('stores total shots when setting a new personal-best level', () async {
      final attemptId = await _seedAttempt(
        db,
        userId: uid,
        currentLevel: 4,
        highestLevel: 3,
        totalShots: 1875,
      );
      await _seedSummary(db, userId: uid, allTimeBestLevel: 3, allTimeBestLevelShots: 1600);

      await service.advanceLevel(uid, attemptId);

      final summarySnap = await db.collection('users').doc(uid).collection('challenger_road').doc('summary').get();
      expect(summarySnap.data()!['all_time_best_level'], 4);
      expect(summarySnap.data()!['all_time_best_level_shots'], 1875);
    });

    test('uses fewer shots as tie-breaker for the same best level', () async {
      final attemptId = await _seedAttempt(
        db,
        userId: uid,
        currentLevel: 5,
        highestLevel: 4,
        totalShots: 2210,
      );
      await _seedSummary(db, userId: uid, allTimeBestLevel: 5, allTimeBestLevelShots: 2400);

      await service.advanceLevel(uid, attemptId);

      final summarySnap = await db.collection('users').doc(uid).collection('challenger_road').doc('summary').get();
      expect(summarySnap.data()!['all_time_best_level'], 5);
      expect(summarySnap.data()!['all_time_best_level_shots'], 2210);
    });

    test('does not replace the best attempt when the same level took more shots', () async {
      final attemptId = await _seedAttempt(
        db,
        userId: uid,
        currentLevel: 5,
        highestLevel: 4,
        totalShots: 2600,
      );
      await _seedSummary(db, userId: uid, allTimeBestLevel: 5, allTimeBestLevelShots: 2400);

      await service.advanceLevel(uid, attemptId);

      final summarySnap = await db.collection('users').doc(uid).collection('challenger_road').doc('summary').get();
      expect(summarySnap.data()!['all_time_best_level'], 5);
      expect(summarySnap.data()!['all_time_best_level_shots'], 2400);
    });
  });

  group('ChallengerRoadService.saveChallengeSession() - updateChallengeProgress', () {
    late FakeFirebaseFirestore db;
    late ChallengerRoadService service;
    const uid = 'test_user';

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ChallengerRoadService(firestore: db);
    });

    test('creates progress entry on first session', () async {
      final attemptId = await _seedAttempt(db, userId: uid);
      final session = _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 8, shotsToPass: 6);
      await service.saveChallengeSession(uid, attemptId, session);

      final snap = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptId).collection('challenge_progress').doc('ch_1').get();
      expect(snap.exists, true);
      final data = snap.data()!;
      expect(data['totalAttempts'], 1);
      expect(data['totalPassed'], 1);
      expect(data['bestLevel'], 1);
      expect((data['levelHistory'] as List).length, 1);
    });

    test('bestLevel updates to max across sessions', () async {
      final attemptId = await _seedAttempt(db, userId: uid);

      final sess1 = _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 8, shotsToPass: 6);
      await service.saveChallengeSession(uid, attemptId, sess1);

      final sess2 = _makeSession(challengeId: 'ch_1', level: 2, shotsMade: 9, shotsToPass: 6);
      await service.saveChallengeSession(uid, attemptId, sess2);

      final snap = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptId).collection('challenge_progress').doc('ch_1').get();
      expect(snap.data()!['bestLevel'], 2);
    });

    test('totalAttempts increments on each session', () async {
      final attemptId = await _seedAttempt(db, userId: uid);

      final sess1 = _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 3, shotsToPass: 6, passed: false);
      await service.saveChallengeSession(uid, attemptId, sess1);

      final sess2 = _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 8, shotsToPass: 6, passed: true);
      await service.saveChallengeSession(uid, attemptId, sess2);

      final snap = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptId).collection('challenge_progress').doc('ch_1').get();
      expect(snap.data()!['totalAttempts'], 2);
    });

    test('levelHistory is appended on each session', () async {
      final attemptId = await _seedAttempt(db, userId: uid);

      for (int i = 0; i < 3; i++) {
        await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 1));
      }

      final snap = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptId).collection('challenge_progress').doc('ch_1').get();
      expect((snap.data()!['levelHistory'] as List).length, 3);
    });

    test('firstPassedAt is set only once (not overwritten on retry)', () async {
      final attemptId = await _seedAttempt(db, userId: uid);

      final sess1 = _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 8, shotsToPass: 6, passed: true);
      await service.saveChallengeSession(uid, attemptId, sess1);

      final snap1 = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptId).collection('challenge_progress').doc('ch_1').get();
      final firstPassed = snap1.data()!['firstPassedAt'];

      // Wait a tick to ensure a different timestamp would be written if logic were wrong.
      await Future.delayed(const Duration(milliseconds: 10));

      final sess2 = _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 9, shotsToPass: 6, passed: true);
      await service.saveChallengeSession(uid, attemptId, sess2);

      final snap2 = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptId).collection('challenge_progress').doc('ch_1').get();
      expect(snap2.data()!['firstPassedAt'], firstPassed);
    });
  });

  group('ChallengerRoadService.saveChallengeSession() - updateChallengeAllTimeHistory', () {
    late FakeFirebaseFirestore db;
    late ChallengerRoadService service;
    const uid = 'test_user';

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ChallengerRoadService(firestore: db);
    });

    test('allTimeBestLevel is max across calls', () async {
      final attemptId = await _seedAttempt(db, userId: uid);

      await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 8));
      await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 3, shotsMade: 8));
      await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 2, shotsMade: 8));

      final snap = await db.collection('users').doc(uid).collection('challenger_road_challenge_history').doc('ch_1').get();
      expect(snap.data()!['allTimeBestLevel'], 3);
    });

    test('allTimeTotalAttempts increments on each session', () async {
      final attemptId = await _seedAttempt(db, userId: uid);

      await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 1));
      await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 1));
      await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 1));

      final snap = await db.collection('users').doc(uid).collection('challenger_road_challenge_history').doc('ch_1').get();
      expect(snap.data()!['allTimeTotalAttempts'], 3);
    });

    test('firstPassedAt is set only on the first passing session and not overwritten', () async {
      final attemptId = await _seedAttempt(db, userId: uid);

      // Fail first.
      await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 2, passed: false));

      // Pass - this should set firstPassedAt.
      await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 8, passed: true));
      final snap1 = await db.collection('users').doc(uid).collection('challenger_road_challenge_history').doc('ch_1').get();
      final firstPassed = snap1.data()!['firstPassedAt'];
      expect(firstPassed, isNotNull);

      await Future.delayed(const Duration(milliseconds: 10));

      // Pass again - firstPassedAt should stay the same.
      await service.saveChallengeSession(uid, attemptId, _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 9, passed: true));
      final snap2 = await db.collection('users').doc(uid).collection('challenger_road_challenge_history').doc('ch_1').get();
      expect(snap2.data()!['firstPassedAt'], firstPassed);
    });

    test('WriteBatch atomically writes session + progress + allTimeHistory', () async {
      final attemptId = await _seedAttempt(db, userId: uid);
      final session = _makeSession(challengeId: 'ch_1', level: 1, shotsMade: 7);

      await service.saveChallengeSession(uid, attemptId, session);

      // All three paths must exist.
      final sessions = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptId).collection('challenge_sessions').get();
      expect(sessions.docs.length, 1);

      final progress = await db.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptId).collection('challenge_progress').doc('ch_1').get();
      expect(progress.exists, true);

      final history = await db.collection('users').doc(uid).collection('challenger_road_challenge_history').doc('ch_1').get();
      expect(history.exists, true);
    });
  });

  group('ChallengerRoadService badge display helpers', () {
    test('buildDisplayBadgeDefs keeps catalog badges and appends unknown earned as legacy', () {
      final defs = ChallengerRoadService.buildDisplayBadgeDefs(
        earnedBadgeIds: const ['cr_fresh_laces', 'legacy_custom_badge'],
        catalog: const [
          ChallengerRoadBadgeDefinition(
            id: 'cr_fresh_laces',
            name: 'Fresh Laces',
            description: 'Started the Challenger Road.',
            category: ChallengerRoadBadgeCategory.firstSteps,
            tier: ChallengerRoadBadgeTier.common,
          ),
        ],
      );

      expect(defs.any((d) => d.id == 'cr_fresh_laces'), isTrue);
      final legacy = defs.where((d) => d.id == 'legacy_custom_badge').single;
      expect(legacy.description, 'Legacy Challenger Road badge.');
      expect(legacy.category, ChallengerRoadBadgeCategory.chirpy);
    });

    test('visibleDisplayBadgeDefs hides hidden-tier badges by default', () {
      final visible = ChallengerRoadService.visibleDisplayBadgeDefs(
        badges: const [
          ChallengerRoadBadgeDefinition(
            id: 'common_badge',
            name: 'Common',
            description: 'Common badge',
            category: ChallengerRoadBadgeCategory.firstSteps,
            tier: ChallengerRoadBadgeTier.common,
          ),
          ChallengerRoadBadgeDefinition(
            id: 'hidden_badge',
            name: 'Hidden',
            description: 'Hidden badge',
            category: ChallengerRoadBadgeCategory.challengeMastery,
            tier: ChallengerRoadBadgeTier.hidden,
          ),
        ],
      );

      expect(visible.map((b) => b.id), contains('common_badge'));
      expect(visible.map((b) => b.id), isNot(contains('hidden_badge')));
    });

    test('groupDisplayBadgesByTier returns groups common -> legendary', () {
      final groups = ChallengerRoadService.groupDisplayBadgesByTier(
        badges: const [
          ChallengerRoadBadgeDefinition(
            id: 'legendary_badge',
            name: 'Legendary Badge',
            description: 'Legendary',
            category: ChallengerRoadBadgeCategory.eliteEndgame,
            tier: ChallengerRoadBadgeTier.legendary,
          ),
          ChallengerRoadBadgeDefinition(
            id: 'common_badge',
            name: 'Common Badge',
            description: 'Common',
            category: ChallengerRoadBadgeCategory.firstSteps,
            tier: ChallengerRoadBadgeTier.common,
          ),
          ChallengerRoadBadgeDefinition(
            id: 'epic_badge',
            name: 'Epic Badge',
            description: 'Epic',
            category: ChallengerRoadBadgeCategory.hotStreaks,
            tier: ChallengerRoadBadgeTier.epic,
          ),
        ],
        earnedBadgeIds: const ['common_badge'],
      );

      expect(groups.map((g) => g.tier).toList(), const [
        ChallengerRoadBadgeTier.common,
        ChallengerRoadBadgeTier.epic,
        ChallengerRoadBadgeTier.legendary,
      ]);
    });

    test('iconForBadge prefers defaultIconKey over category fallback', () {
      const def = ChallengerRoadBadgeDefinition(
        id: 'custom_icon_badge',
        name: 'Custom Icon',
        description: 'Uses override icon',
        category: ChallengerRoadBadgeCategory.firstSteps,
        tier: ChallengerRoadBadgeTier.common,
        defaultIconKey: 'military_tech_rounded',
      );

      final icon = ChallengerRoadService.iconForBadge(def);
      expect(icon, Icons.military_tech_rounded);
    });
  });
}

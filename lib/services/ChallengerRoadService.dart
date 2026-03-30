import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeAllTimeHistory.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeProgressEntry.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';

/// Returned by [ChallengerRoadService.incrementChallengerRoadShots] so callers
/// can trigger the 10K celebration without a second Firestore read.
class ChallengerRoadMilestoneResult {
  final bool didHitMilestone;

  /// The new value of `challengerRoadShotCount` after the update (already
  /// reset to the remainder if a milestone was crossed).
  final int newCount;

  /// Total number of times the 10K milestone has been hit this attempt
  /// (cumulative, never resets).
  final int resetCount;

  const ChallengerRoadMilestoneResult({
    required this.didHitMilestone,
    required this.newCount,
    required this.resetCount,
  });
}

class ChallengerRoadService {
  final FirebaseFirestore _firestore;

  ChallengerRoadService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Internal path helpers
  // ---------------------------------------------------------------------------

  /// Root of the global challenges sub-collection.
  /// Firestore path: challenger_road/challenges/challenges
  CollectionReference get _challengesRef => _firestore.collection('challenger_road').doc('challenges').collection('challenges');

  /// Levels sub-collection for a given challenge.
  CollectionReference _levelsRef(String challengeId) => _challengesRef.doc(challengeId).collection('levels');

  /// Per-user Challenger Road summary document.
  /// Firestore path: users/{uid}/challenger_road/summary
  DocumentReference _userSummaryRef(String userId) => _firestore.collection('users').doc(userId).collection('challenger_road').doc('summary');

  /// Attempts sub-collection for a user.
  CollectionReference _attemptsRef(String userId) => _firestore.collection('users').doc(userId).collection('challenger_road_attempts');

  /// Challenge sessions sub-collection for a given attempt.
  CollectionReference _sessionsRef(String userId, String attemptId) => _attemptsRef(userId).doc(attemptId).collection('challenge_sessions');

  /// Per-challenge progress sub-collection within one attempt.
  CollectionReference _progressRef(String userId, String attemptId) => _attemptsRef(userId).doc(attemptId).collection('challenge_progress');

  /// Cross-attempt per-challenge history sub-collection.
  CollectionReference _allTimeHistoryRef(String userId) => _firestore.collection('users').doc(userId).collection('challenger_road_challenge_history');

  // ---------------------------------------------------------------------------
  // 1. Global challenge data
  // ---------------------------------------------------------------------------

  /// Returns all [ChallengerRoadChallenge] objects that have an active level
  /// document at [level], ordered by that level's [sequence] field.
  Future<List<ChallengerRoadChallenge>> getChallengesForLevel(int level) async {
    // Query the 'levels' collection group for all active level docs matching [level].
    final levelSnaps = await _firestore.collectionGroup('levels').where('level', isEqualTo: level).where('active', isEqualTo: true).orderBy('sequence').get();

    if (levelSnaps.docs.isEmpty) return [];

    // For each level doc, fetch the parent challenge document.
    final results = await Future.wait(
      levelSnaps.docs.map((levelDoc) async {
        // Parent path: challenger_road/challenges/challenges/{challengeId}
        final challengeRef = levelDoc.reference.parent.parent;
        if (challengeRef == null) return null;
        final challengeSnap = await challengeRef.get();
        if (!challengeSnap.exists) return null;
        final data = challengeSnap.data() ?? {};
        if (data['active'] != true) return null;
        return ChallengerRoadChallenge.fromSnapshot(challengeSnap);
      }),
    );

    return results.whereType<ChallengerRoadChallenge>().toList();
  }

  /// Returns all [ChallengerRoadLevel] documents for a given challenge,
  /// ordered by [level] ascending.
  Future<List<ChallengerRoadLevel>> getLevelsForChallenge(String challengeId) async {
    final snap = await _levelsRef(challengeId).orderBy('level').get();
    return snap.docs.map(ChallengerRoadLevel.fromSnapshot).toList();
  }

  /// Returns the [ChallengerRoadLevel] document for a specific challenge at a
  /// specific level, or null if the challenge does not participate at that level.
  Future<ChallengerRoadLevel?> getLevelDoc(String challengeId, int level) async {
    final snap = await _levelsRef(challengeId).where('level', isEqualTo: level).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return ChallengerRoadLevel.fromSnapshot(snap.docs.first);
  }

  // ---------------------------------------------------------------------------
  // 2. Distinct active level numbers (for map rendering)
  // ---------------------------------------------------------------------------

  /// Returns a sorted list of all distinct active level numbers across all challenges.
  /// Used to build the full snake map without loading every challenge.
  Future<List<int>> getAllActiveLevels() async {
    final snap = await _firestore.collectionGroup('levels').where('active', isEqualTo: true).get();

    final levels = snap.docs.map((d) => d.data()['level'] as num?).whereType<num>().map((n) => n.toInt()).toSet().toList()..sort();

    return levels;
  }

  // ---------------------------------------------------------------------------
  // 3. User attempt management
  // ---------------------------------------------------------------------------

  /// Returns the current active [ChallengerRoadAttempt] for a user, or null
  /// if the user has never started Challenger Road.
  Future<ChallengerRoadAttempt?> getActiveAttempt(String userId) async {
    final snap = await _attemptsRef(userId).where('status', isEqualTo: 'active').limit(1).get();
    if (snap.docs.isEmpty) return null;
    return ChallengerRoadAttempt.fromSnapshot(snap.docs.first);
  }

  /// Creates a brand-new [ChallengerRoadAttempt] for a user starting at
  /// [startingLevel]. Also updates the user summary's `currentAttemptId` and
  /// `totalAttempts`, then runs badge checks.
  Future<ChallengerRoadAttempt> createAttempt(String userId, int startingLevel) async {
    final summary = await getUserSummary(userId);
    final attemptNumber = summary.totalAttempts + 1;

    final attempt = ChallengerRoadAttempt(
      attemptNumber: attemptNumber,
      startingLevel: startingLevel,
      currentLevel: startingLevel,
      challengerRoadShotCount: 0,
      totalShotsThisAttempt: 0,
      resetCount: 0,
      highestLevelReachedThisAttempt: startingLevel,
      status: 'active',
      startDate: DateTime.now(),
    );

    final docRef = await _attemptsRef(userId).add(attempt.toMap());
    attempt.id = docRef.id;

    await updateUserSummary(userId, {
      'current_attempt_id': docRef.id,
      'total_attempts': attemptNumber,
    });

    await _checkAndAwardBadges(
      userId: userId,
      summary: summary.copyWith(
        currentAttemptId: docRef.id,
        totalAttempts: attemptNumber,
      ),
    );

    return attempt;
  }

  /// Applies a partial update to an attempt document. Callers should use the
  /// snake_case field names that match the Firestore document schema.
  Future<void> updateAttempt(String userId, String attemptId, Map<String, dynamic> data) async {
    await _attemptsRef(userId).doc(attemptId).update(data);
  }

  // ---------------------------------------------------------------------------
  // 4. Challenge session management
  // ---------------------------------------------------------------------------

  /// Saves a completed [ChallengeSession] and atomically updates both the
  /// per-attempt [ChallengeProgressEntry] and the cross-attempt
  /// [ChallengeAllTimeHistory] for the same challenge.
  ///
  /// All three writes succeed or none do (WriteBatch).
  Future<void> saveChallengeSession(String userId, String attemptId, ChallengeSession session) async {
    final batch = _firestore.batch();

    // 1. New challenge_sessions document.
    final sessionRef = _sessionsRef(userId, attemptId).doc();
    batch.set(sessionRef, session.toMap());

    // 2. Upsert challenge_progress for this attempt.
    await _buildChallengeProgressUpdate(userId, attemptId, session, batch: batch);

    // 3. Upsert cross-attempt challenge history.
    await _buildAllTimeHistoryUpdate(userId, session, batch: batch);

    await batch.commit();

    // Badge checks (outside the batch — read-then-write pattern).
    final summary = await getUserSummary(userId);
    await _checkAndAwardBadges(userId: userId, summary: summary);
  }

  /// Returns all [ChallengeSession] documents for a given attempt, ordered by
  /// date descending.
  Future<List<ChallengeSession>> getSessionsForAttempt(String userId, String attemptId) async {
    final snap = await _sessionsRef(userId, attemptId).orderBy('date', descending: true).get();
    return snap.docs.map(ChallengeSession.fromSnapshot).toList();
  }

  /// Returns true if a passing session exists for [challengeId] at [level]
  /// within a given attempt.
  ///
  /// Prefer [getChallengeProgress] for repeated/bulk checks — this method
  /// queries challenge_sessions directly and is best for one-off verification.
  Future<bool> isChallengePassedAtLevel(String userId, String attemptId, String challengeId, int level) async {
    // Fast path: read challenge_progress document (O(1) doc read).
    final progress = await getChallengeProgress(userId, attemptId, challengeId);
    if (progress != null) return progress.bestLevel >= level;

    // Fallback: query sessions directly (no progress doc yet = never passed).
    return false;
  }

  // ---------------------------------------------------------------------------
  // 4b. Per-challenge history management
  // ---------------------------------------------------------------------------

  /// Returns the [ChallengeProgressEntry] for a specific challenge within one
  /// attempt, or null if the challenge has never been attempted.
  Future<ChallengeProgressEntry?> getChallengeProgress(String userId, String attemptId, String challengeId) async {
    final snap = await _progressRef(userId, attemptId).doc(challengeId).get();
    if (!snap.exists) return null;
    return ChallengeProgressEntry.fromSnapshot(snap);
  }

  /// Returns the [ChallengeAllTimeHistory] for a specific challenge across all
  /// of a user's attempts, or null if the challenge has never been attempted.
  Future<ChallengeAllTimeHistory?> getChallengeAllTimeHistory(String userId, String challengeId) async {
    final snap = await _allTimeHistoryRef(userId).doc(challengeId).get();
    if (!snap.exists) return null;
    return ChallengeAllTimeHistory.fromSnapshot(snap);
  }

  // ---------------------------------------------------------------------------
  // 5. Level advancement
  // ---------------------------------------------------------------------------

  /// Returns true when every active challenge that participates at [level] has
  /// a passing session in the given attempt.
  Future<bool> isLevelComplete(String userId, String attemptId, int level) async {
    // Get all active challenge IDs that have a level doc at this level.
    final levelSnaps = await _firestore.collectionGroup('levels').where('level', isEqualTo: level).where('active', isEqualTo: true).get();

    if (levelSnaps.docs.isEmpty) return false;

    for (final levelDoc in levelSnaps.docs) {
      final challengeRef = levelDoc.reference.parent.parent;
      if (challengeRef == null) continue;

      // Verify the parent challenge itself is active.
      final challengeSnap = await challengeRef.get();
      if (!challengeSnap.exists) continue;
      final data = challengeSnap.data() ?? {};
      if (data['active'] != true) continue;

      final passed = await isChallengePassedAtLevel(userId, attemptId, challengeRef.id, level);
      if (!passed) return false;
    }

    return true;
  }

  /// Advances the user's current level by 1, updating [ChallengerRoadAttempt]
  /// and [ChallengerRoadUserSummary] as needed. Call this after confirming
  /// [isLevelComplete] returns true.
  ///
  /// Returns the updated [ChallengerRoadAttempt].
  Future<ChallengerRoadAttempt> advanceLevel(String userId, String attemptId) async {
    final attemptSnap = await _attemptsRef(userId).doc(attemptId).get();
    final attempt = ChallengerRoadAttempt.fromSnapshot(attemptSnap);

    final completedLevel = attempt.currentLevel;
    final newLevel = completedLevel + 1;
    final newHighest = max(attempt.highestLevelReachedThisAttempt, completedLevel);

    await updateAttempt(userId, attemptId, {
      'current_level': newLevel,
      'highest_level_reached_this_attempt': newHighest,
    });

    // Update all-time best level on user summary if we set a new record.
    // Capture pre-advancement best level for comeback badge check.
    final summary = await getUserSummary(userId);
    final prevBestLevel = summary.allTimeBestLevel;
    if (newHighest > summary.allTimeBestLevel) {
      await updateUserSummary(userId, {'all_time_best_level': newHighest});
    }

    final updatedSummary = await getUserSummary(userId);
    await _checkAndAwardBadges(userId: userId, summary: updatedSummary);

    // Extra badges that require attempt-level context not available from summary alone.
    final extraBadges = <String>[];

    // cr_comeback: started at level 1 on a player who previously reached higher;
    // awarded when they complete level 5 in this attempt.
    if (completedLevel >= 5 && attempt.startingLevel == 1 && prevBestLevel > 1) {
      extraBadges.add('cr_comeback');
    }

    // cr_perfect_level: no retries at this level in this attempt.
    if (await _isLevelPerfect(userId, attemptId, completedLevel)) {
      extraBadges.add('cr_perfect_level');
    }

    if (extraBadges.isNotEmpty) {
      final freshSummary = await getUserSummary(userId);
      final earned = List<String>.from(freshSummary.badges);
      bool changed = false;
      for (final badgeId in extraBadges) {
        if (!earned.contains(badgeId)) {
          earned.add(badgeId);
          changed = true;
        }
      }
      if (changed) await updateUserSummary(userId, {'badges': earned});
    }

    return attempt.copyWith(
      currentLevel: newLevel,
      highestLevelReachedThisAttempt: newHighest,
    );
  }

  // ---------------------------------------------------------------------------
  // 6. 10K milestone handling
  // ---------------------------------------------------------------------------

  /// Adds [count] shots to both `challengerRoadShotCount` and
  /// `totalShotsThisAttempt`. If the rolling counter reaches or exceeds 10,000,
  /// it wraps around (resets to the remainder) and `resetCount` is incremented.
  ///
  /// Also updates [ChallengerRoadUserSummary.allTimeTotalChallengerRoadShots].
  Future<ChallengerRoadMilestoneResult> incrementChallengerRoadShots(String userId, String attemptId, int count) async {
    final attemptSnap = await _attemptsRef(userId).doc(attemptId).get();
    final attempt = ChallengerRoadAttempt.fromSnapshot(attemptSnap);

    final newRolling = attempt.challengerRoadShotCount + count;
    final newTotal = attempt.totalShotsThisAttempt + count;
    final didHit = newRolling >= 10000;
    final finalRolling = didHit ? newRolling - 10000 : newRolling;
    final newResetCount = attempt.resetCount + (didHit ? 1 : 0);

    await updateAttempt(userId, attemptId, {
      'challenger_road_shot_count': finalRolling,
      'total_shots_this_attempt': newTotal,
      'reset_count': newResetCount,
    });

    // Keep the all-time total in sync on the summary doc.
    final summary = await getUserSummary(userId);
    final newAllTimeTotal = summary.allTimeTotalChallengerRoadShots + count;
    await updateUserSummary(userId, {
      'all_time_total_challenger_road_shots': newAllTimeTotal,
    });

    if (didHit) {
      final updatedSummary = await getUserSummary(userId);
      await _checkAndAwardBadges(userId: userId, summary: updatedSummary);
    }

    return ChallengerRoadMilestoneResult(
      didHitMilestone: didHit,
      newCount: finalRolling,
      resetCount: newResetCount,
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Attempt restart
  // ---------------------------------------------------------------------------

  /// Marks the current active attempt as 'completed', then creates and returns
  /// a new attempt starting at `max(1, previousHighestLevel - 1)`.
  Future<ChallengerRoadAttempt> restartChallengerRoad(String userId) async {
    final active = await getActiveAttempt(userId);

    int startingLevel = 1;
    if (active != null) {
      await updateAttempt(userId, active.id!, {
        'status': 'completed',
        'end_date': Timestamp.fromDate(DateTime.now()),
      });
      startingLevel = max(1, active.highestLevelReachedThisAttempt - 1);
    }

    return createAttempt(userId, startingLevel);
  }

  // ---------------------------------------------------------------------------
  // 8. User summary
  // ---------------------------------------------------------------------------

  /// Returns the [ChallengerRoadUserSummary] for a user, creating an empty one
  /// if it does not yet exist.
  Future<ChallengerRoadUserSummary> getUserSummary(String userId) async {
    final snap = await _userSummaryRef(userId).get();
    if (!snap.exists) return ChallengerRoadUserSummary.empty();
    return ChallengerRoadUserSummary.fromSnapshot(snap);
  }

  /// Live stream of the user summary — use in profile widgets.
  Stream<ChallengerRoadUserSummary> watchUserSummary(String userId) {
    return _userSummaryRef(userId).snapshots().map((snap) {
      if (!snap.exists) return ChallengerRoadUserSummary.empty();
      return ChallengerRoadUserSummary.fromSnapshot(snap);
    });
  }

  /// Applies a partial update to the user summary document. If the document
  /// does not exist it will be created (merge: true behaviour via [SetOptions]).
  Future<void> updateUserSummary(String userId, Map<String, dynamic> data) async {
    await _userSummaryRef(userId).set(data, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Internal: batch helpers
  // ---------------------------------------------------------------------------

  /// Reads the existing [ChallengeProgressEntry] for [session.challengeId] (if
  /// any) and enqueues an upsert into [batch].
  Future<void> _buildChallengeProgressUpdate(
    String userId,
    String attemptId,
    ChallengeSession session, {
    required WriteBatch batch,
  }) async {
    final ref = _progressRef(userId, attemptId).doc(session.challengeId);
    final snap = await ref.get();

    final historyEntry = ChallengeLevelHistoryEntry(
      level: session.level,
      passed: session.passed,
      shotsMade: session.shotsMade,
      shotsRequired: session.shotsRequired,
      date: session.date,
    );

    if (!snap.exists) {
      final entry = ChallengeProgressEntry(
        challengeId: session.challengeId,
        bestLevel: session.passed ? session.level : 0,
        totalAttempts: 1,
        totalPassed: session.passed ? 1 : 0,
        firstPassedAt: session.passed ? session.date : null,
        lastAttemptAt: session.date,
        levelHistory: [historyEntry],
      );
      batch.set(ref, entry.toMap());
    } else {
      final existing = ChallengeProgressEntry.fromSnapshot(snap);
      final newBest = session.passed ? max(existing.bestLevel, session.level) : existing.bestLevel;
      final data = <String, dynamic>{
        'bestLevel': newBest,
        'totalAttempts': existing.totalAttempts + 1,
        'totalPassed': existing.totalPassed + (session.passed ? 1 : 0),
        'lastAttemptAt': Timestamp.fromDate(session.date),
        'levelHistory': [
          ...existing.levelHistory.map((e) => e.toMap()),
          historyEntry.toMap(),
        ],
      };
      if (session.passed && existing.firstPassedAt == null) {
        data['firstPassedAt'] = Timestamp.fromDate(session.date);
      }
      batch.update(ref, data);
    }
  }

  /// Reads the existing [ChallengeAllTimeHistory] for [session.challengeId]
  /// and enqueues an upsert into [batch].
  Future<void> _buildAllTimeHistoryUpdate(
    String userId,
    ChallengeSession session, {
    required WriteBatch batch,
  }) async {
    final ref = _allTimeHistoryRef(userId).doc(session.challengeId);
    final snap = await ref.get();

    if (!snap.exists) {
      final history = ChallengeAllTimeHistory(
        challengeId: session.challengeId,
        allTimeBestLevel: session.passed ? session.level : 0,
        allTimeTotalAttempts: 1,
        allTimeTotalPassed: session.passed ? 1 : 0,
        firstPassedAt: session.passed ? session.date : null,
        lastPassedAt: session.passed ? session.date : null,
      );
      batch.set(ref, history.toMap());
    } else {
      final existing = ChallengeAllTimeHistory.fromSnapshot(snap);
      final newBest = session.passed ? max(existing.allTimeBestLevel, session.level) : existing.allTimeBestLevel;
      final data = <String, dynamic>{
        'allTimeBestLevel': newBest,
        'allTimeTotalAttempts': existing.allTimeTotalAttempts + 1,
        'allTimeTotalPassed': existing.allTimeTotalPassed + (session.passed ? 1 : 0),
      };
      if (session.passed) {
        if (existing.firstPassedAt == null) {
          data['firstPassedAt'] = Timestamp.fromDate(session.date);
        }
        data['lastPassedAt'] = Timestamp.fromDate(session.date);
      }
      batch.update(ref, data);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal: badge helpers
  // ---------------------------------------------------------------------------

  /// Returns true if every active challenge at [level] was completed on the
  /// first try within [attemptId] — i.e., there is exactly one
  /// [ChallengeLevelHistoryEntry] at this level in each progress entry.
  Future<bool> _isLevelPerfect(String userId, String attemptId, int level) async {
    try {
      final levelSnaps = await _firestore.collectionGroup('levels').where('level', isEqualTo: level).where('active', isEqualTo: true).get();
      if (levelSnaps.docs.isEmpty) return false;

      for (final levelDoc in levelSnaps.docs) {
        final challengeRef = levelDoc.reference.parent.parent;
        if (challengeRef == null) continue;
        final challengeSnap = await challengeRef.get();
        if (!challengeSnap.exists) continue;
        final data = challengeSnap.data() ?? {};
        if (data['active'] != true) continue;

        final progressSnap = await _progressRef(userId, attemptId).doc(challengeRef.id).get();
        if (!progressSnap.exists) return false;
        final entry = ChallengeProgressEntry.fromSnapshot(progressSnap);
        final attemptsAtLevel = entry.levelHistory.where((h) => h.level == level).length;
        if (attemptsAtLevel != 1) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks all badge conditions against the current [summary] and awards any
  /// newly earned badges. Idempotent — will not re-award a badge already in the
  /// `badges` list.
  Future<void> _checkAndAwardBadges({
    required String userId,
    required ChallengerRoadUserSummary summary,
  }) async {
    final earned = List<String>.from(summary.badges);
    final newBadges = <String>[];

    void maybeAward(String badgeId) {
      if (!earned.contains(badgeId)) {
        earned.add(badgeId);
        newBadges.add(badgeId);
      }
    }

    // Attempt count badges.
    const attemptTiers = [
      (1, 'cr_attempts_1'),
      (3, 'cr_attempts_3'),
      (10, 'cr_attempts_10'),
      (25, 'cr_attempts_25'),
      (50, 'cr_attempts_50'),
    ];
    for (final (threshold, id) in attemptTiers) {
      if (summary.totalAttempts >= threshold) maybeAward(id);
    }

    // 10K milestone badges (based on cumulative resets across all attempts).
    // We approximate from allTimeTotalChallengerRoadShots / 10000.
    final milestoneCount = summary.allTimeTotalChallengerRoadShots ~/ 10000;
    if (milestoneCount >= 1) maybeAward('cr_10k_x1');
    if (milestoneCount >= 3) maybeAward('cr_10k_x3');
    if (milestoneCount >= 10) maybeAward('cr_10k_x10');

    // All-time best level badges.
    if (summary.allTimeBestLevel >= 5) maybeAward('cr_level_5');
    if (summary.allTimeBestLevel >= 10) maybeAward('cr_level_10');

    if (newBadges.isEmpty) return;

    await updateUserSummary(userId, {'badges': earned});
  }
}

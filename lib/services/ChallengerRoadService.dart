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
    // Query active level docs, then filter by level client-side to avoid
    // requiring a composite collection-group index on (active, level).
    final allActiveLevelSnaps = await _firestore.collectionGroup('levels').where('active', isEqualTo: true).get();
    final levelSnapsDocs = allActiveLevelSnaps.docs.where((d) => (d.data()['level'] as num?)?.toInt() == level).toList()
      ..sort((a, b) {
        final aSeq = (a.data()['sequence'] as num?)?.toInt() ?? 0;
        final bSeq = (b.data()['sequence'] as num?)?.toInt() ?? 0;
        return aSeq.compareTo(bSeq);
      });

    if (levelSnapsDocs.isEmpty) return [];

    // For each level doc, fetch the parent challenge document.
    final results = await Future.wait(
      levelSnapsDocs.map((levelDoc) async {
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

  /// Returns all [ChallengeSession] tries for a specific [challengeId] at a
  /// specific [level] within one attempt, ordered by date descending.
  Future<List<ChallengeSession>> getTriesForChallenge(
    String userId,
    String attemptId,
    String challengeId,
    int level,
  ) async {
    final snap = await _sessionsRef(userId, attemptId).where('challenge_id', isEqualTo: challengeId).where('level', isEqualTo: level).orderBy('date', descending: true).get();
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
    final allActiveLevelSnaps = await _firestore.collectionGroup('levels').where('active', isEqualTo: true).get();
    final levelSnapsDocs = allActiveLevelSnaps.docs.where((d) => (d.data()['level'] as num?)?.toInt() == level).toList();

    if (levelSnapsDocs.isEmpty) return false;

    for (final levelDoc in levelSnapsDocs) {
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

  /// Replays any missed level unlocks for the active attempt by checking
  /// contiguous level completion from the persisted current level onward.
  ///
  /// This is forward-only: it advances stale attempts that should already have
  /// unlocked additional levels, but it does not downgrade stored progress.
  Future<ChallengerRoadAttempt?> syncActiveAttemptProgress(String userId) async {
    final activeAttempt = await getActiveAttempt(userId);
    if (activeAttempt == null) return null;

    var attempt = activeAttempt;

    while (await isLevelComplete(userId, attempt.id!, attempt.currentLevel)) {
      attempt = await advanceLevel(userId, attempt.id!);
    }

    return attempt;
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

  /// Restarts Challenger Road for a user.
  ///
  /// **Mid-attempt restart** (`resetCount == 0`, i.e. user has never hit the
  /// 10 000-shot milestone in the current attempt): the attempt is marked
  /// `cancelled` and a fresh attempt doc is created reusing the **same**
  /// `attemptNumber` — `totalAttempts` in the user summary is NOT incremented.
  ///
  /// **Post-completion restart** (`resetCount >= 1`): the attempt is marked
  /// `completed` and a genuinely new attempt is created with an incremented
  /// `attemptNumber` / `totalAttempts` (original behaviour).
  Future<ChallengerRoadAttempt> restartChallengerRoad(String userId) async {
    final active = await getActiveAttempt(userId);

    int startingLevel = 1;
    if (active != null) {
      startingLevel = max(1, active.highestLevelReachedThisAttempt - 1);

      final hasCompletedRoad = active.resetCount >= 1;
      await updateAttempt(userId, active.id!, {
        'status': hasCompletedRoad ? 'completed' : 'cancelled',
        'end_date': Timestamp.fromDate(DateTime.now()),
      });

      if (!hasCompletedRoad) {
        // Reuse the same attempt number — this is a "do-over", not a new attempt.
        final attempt = ChallengerRoadAttempt(
          attemptNumber: active.attemptNumber,
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
        // Only update the pointer — do NOT touch total_attempts.
        await updateUserSummary(userId, {'current_attempt_id': docRef.id});
        return attempt;
      }
    }

    // Genuine new attempt (post-completion) — increment totalAttempts.
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

  Future<_RoadBadgeStats> _loadRoadBadgeStats(String userId) async {
    final challengeSnap = await _challengesRef.where('active', isEqualTo: true).get();
    final challenges = challengeSnap.docs.map(ChallengerRoadChallenge.fromSnapshot).toList();
    final challengeById = <String, ChallengerRoadChallenge>{
      for (final challenge in challenges)
        if (challenge.id != null) challenge.id!: challenge,
    };

    final levelOneChallenges = await getChallengesForLevel(1);
    final levelOneChallengeIds = levelOneChallenges.map((c) => c.id).whereType<String>().toSet();

    final levelOnePassesByChallenge = <String, int>{};
    var outperformPlusTwoPasses = 0;

    final attemptsSnap = await _attemptsRef(userId).get();
    for (final attemptDoc in attemptsSnap.docs) {
      final attemptId = attemptDoc.id;

      final progressSnap = await _progressRef(userId, attemptId).get();
      for (final progressDoc in progressSnap.docs) {
        final progress = ChallengeProgressEntry.fromSnapshot(progressDoc);
        final levelOnePasses = progress.levelHistory.where((h) => h.level == 1 && h.passed).length;
        if (levelOnePasses > 0) {
          levelOnePassesByChallenge[progress.challengeId] = (levelOnePassesByChallenge[progress.challengeId] ?? 0) + levelOnePasses;
        }
      }

      final passedSessionsSnap = await _sessionsRef(userId, attemptId).where('passed', isEqualTo: true).get();
      for (final sessionDoc in passedSessionsSnap.docs) {
        final session = ChallengeSession.fromSnapshot(sessionDoc);
        if (session.shotsMade >= (session.shotsToPass + 2)) {
          outperformPlusTwoPasses++;
        }
      }
    }

    int levelOnePassesForShotType(String shotType) {
      var total = 0;
      levelOnePassesByChallenge.forEach((challengeId, passes) {
        if ((challengeById[challengeId]?.shotType ?? '') == shotType) {
          total += passes;
        }
      });
      return total;
    }

    int passesForChallengeNameContaining(String query) {
      final normalized = query.toLowerCase();
      final matchingIds = challengeById.values.where((c) => c.name.toLowerCase().contains(normalized)).map((c) => c.id).whereType<String>();
      var total = 0;
      for (final id in matchingIds) {
        total += levelOnePassesByChallenge[id] ?? 0;
      }
      return total;
    }

    final levelOneAllClear = levelOneChallengeIds.isNotEmpty && levelOneChallengeIds.every((id) => (levelOnePassesByChallenge[id] ?? 0) > 0);

    return _RoadBadgeStats(
      levelOneWristPasses: levelOnePassesForShotType('wrist'),
      levelOneSnapPasses: levelOnePassesForShotType('snap'),
      levelOneBackhandPasses: levelOnePassesForShotType('backhand'),
      levelOneSlapPasses: levelOnePassesForShotType('slap'),
      wristWarmupLevelOnePasses: passesForChallengeNameContaining('wrist shot warmup'),
      outperformPlusTwoPasses: outperformPlusTwoPasses,
      levelOneAllClear: levelOneAllClear,
    );
  }

  /// Returns true if every active challenge at [level] was completed on the
  /// first try within [attemptId] — i.e., there is exactly one
  /// [ChallengeLevelHistoryEntry] at this level in each progress entry.
  Future<bool> _isLevelPerfect(String userId, String attemptId, int level) async {
    try {
      final allActiveLevelSnaps = await _firestore.collectionGroup('levels').where('active', isEqualTo: true).get();
      final levelSnapsDocs = allActiveLevelSnaps.docs.where((d) => (d.data()['level'] as num?)?.toInt() == level).toList();
      if (levelSnapsDocs.isEmpty) return false;

      for (final levelDoc in levelSnapsDocs) {
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
    final stats = await _loadRoadBadgeStats(userId);

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
    ];
    for (final (threshold, id) in attemptTiers) {
      if (summary.totalAttempts >= threshold) maybeAward(id);
    }

    // 10K milestone badge (first milestone).
    final milestoneCount = summary.allTimeTotalChallengerRoadShots ~/ 10000;
    if (milestoneCount >= 1) maybeAward('cr_10k_x1');

    // Challenge / shot-type progression badges.
    if (stats.levelOneAllClear) maybeAward('cr_level1_all_clear');
    if (stats.levelOneWristPasses >= 3) maybeAward('cr_wrist_l1_x3');
    if (stats.levelOneSnapPasses >= 3) maybeAward('cr_snap_l1_x3');
    if (stats.levelOneBackhandPasses >= 3) maybeAward('cr_backhand_l1_x3');
    if (stats.levelOneSlapPasses >= 3) maybeAward('cr_slap_l1_x3');
    if (stats.wristWarmupLevelOnePasses >= 3) maybeAward('cr_wrist_warmup_l1_x3');
    if (stats.outperformPlusTwoPasses >= 5) maybeAward('cr_outperform_plus2_x5');

    if (newBadges.isEmpty) return;

    await updateUserSummary(userId, {'badges': earned});
  }
}

class _RoadBadgeStats {
  final int levelOneWristPasses;
  final int levelOneSnapPasses;
  final int levelOneBackhandPasses;
  final int levelOneSlapPasses;
  final int wristWarmupLevelOnePasses;
  final int outperformPlusTwoPasses;
  final bool levelOneAllClear;

  const _RoadBadgeStats({
    required this.levelOneWristPasses,
    required this.levelOneSnapPasses,
    required this.levelOneBackhandPasses,
    required this.levelOneSlapPasses,
    required this.wristWarmupLevelOnePasses,
    required this.outperformPlusTwoPasses,
    required this.levelOneAllClear,
  });
}

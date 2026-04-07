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

enum ChallengerRoadBadgeCategory {
  attempts,
  shotsMilestone,
  levelAllClear,
  shotTypeLevelMastery,
  outperform,
  special,
}

class ChallengerRoadBadgeDefinition {
  final String id;
  final String name;
  final String description;
  final ChallengerRoadBadgeCategory category;
  final int? threshold;
  final int? level;
  final String? shotType;

  const ChallengerRoadBadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.threshold,
    this.level,
    this.shotType,
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

  /// Root of the Challenger Road levels collection.
  /// Firestore path: challenger_road_levels/{levelId}
  CollectionReference get _levelsRef => _firestore.collection('challenger_road_levels');

  /// Challenge docs owned by a specific level.
  CollectionReference _challengesRef(String levelDocId) => _levelsRef.doc(levelDocId).collection('challenges');

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

  String _shotTypeLevelKey(String shotType, int level) => '${shotType.toLowerCase()}|$level';

  Future<QueryDocumentSnapshot?> _findActiveLevelSnapshot(int level) async {
    final snap = await _levelsRef.where('active', isEqualTo: true).get();
    for (final doc in snap.docs) {
      final levelValue = ((doc.data() as Map<String, dynamic>?)?['level'] as num?)?.toInt();
      if (levelValue == level) return doc;
    }
    return null;
  }

  String _shotTypeLabel(String shotType) {
    switch (shotType.toLowerCase()) {
      case 'wrist':
        return 'Wrist Shot';
      case 'snap':
        return 'Snap Shot';
      case 'backhand':
        return 'Backhand';
      case 'slap':
        return 'Slap Shot';
      default:
        return shotType;
    }
  }

  List<ChallengerRoadBadgeDefinition> _buildBadgeDefinitions(_RoadBadgeStats stats) {
    final levels = stats.activeChallengeIdsByLevel.keys.toList()..sort();
    final maxLevel = levels.isEmpty ? 0 : levels.last;

    final badges = <ChallengerRoadBadgeDefinition>[
      const ChallengerRoadBadgeDefinition(
        id: 'cr_attempts_1',
        name: 'First Step',
        description: 'Start your first Challenger Road attempt.',
        category: ChallengerRoadBadgeCategory.attempts,
        threshold: 1,
      ),
      const ChallengerRoadBadgeDefinition(
        id: 'cr_attempts_3',
        name: 'Committed',
        description: 'Start 3 Challenger Road attempts.',
        category: ChallengerRoadBadgeCategory.attempts,
        threshold: 3,
      ),
      const ChallengerRoadBadgeDefinition(
        id: 'cr_attempts_10',
        name: 'Road Grinder',
        description: 'Start 10 Challenger Road attempts.',
        category: ChallengerRoadBadgeCategory.attempts,
        threshold: 10,
      ),
      const ChallengerRoadBadgeDefinition(
        id: 'cr_10k_x1',
        name: 'First 10,000',
        description: 'Hit 10,000 Challenger Road shots.',
        category: ChallengerRoadBadgeCategory.shotsMilestone,
        threshold: 10000,
      ),
      const ChallengerRoadBadgeDefinition(
        id: 'cr_outperform_plus2_x5',
        name: 'Clutch Finisher',
        description: 'Exceed the target score by 2+ shots in 5 sessions.',
        category: ChallengerRoadBadgeCategory.outperform,
        threshold: 5,
      ),
      const ChallengerRoadBadgeDefinition(
        id: 'cr_perfect_level',
        name: 'Perfect Level',
        description: 'In one attempt, hit the target score on your first try for every challenge in a level.',
        category: ChallengerRoadBadgeCategory.special,
      ),
    ];

    if (maxLevel >= 5) {
      badges.add(
        const ChallengerRoadBadgeDefinition(
          id: 'cr_comeback',
          name: 'Comeback Kid',
          description: 'After previously reaching above Level 1, restart at Level 1 and reach Level 5 in that new attempt.',
          category: ChallengerRoadBadgeCategory.special,
        ),
      );
    }

    if (maxLevel >= 6) {
      badges.add(
        const ChallengerRoadBadgeDefinition(
          id: 'cr_attempts_25',
          name: 'Road Veteran',
          description: 'Start 25 Challenger Road attempts.',
          category: ChallengerRoadBadgeCategory.attempts,
          threshold: 25,
        ),
      );
    }

    if (maxLevel >= 10) {
      badges.add(
        const ChallengerRoadBadgeDefinition(
          id: 'cr_attempts_50',
          name: 'Road Legend',
          description: 'Start 50 Challenger Road attempts.',
          category: ChallengerRoadBadgeCategory.attempts,
          threshold: 50,
        ),
      );
    }

    for (final level in levels) {
      badges.add(
        ChallengerRoadBadgeDefinition(
          id: 'cr_level_${level}_all_clear',
          name: level == 1 ? 'Level 1 Clear' : 'Level $level Conqueror',
          description: 'Pass every active Level $level challenge at least once.',
          category: ChallengerRoadBadgeCategory.levelAllClear,
          level: level,
        ),
      );

      for (final shotType in const ['wrist', 'snap', 'backhand', 'slap']) {
        final activeCount = stats.activeShotTypeChallengeCountByLevel[_shotTypeLevelKey(shotType, level)] ?? 0;
        if (activeCount == 0) continue;

        final threshold = min(8, max(2, activeCount + ((level + 1) ~/ 2)));
        final shotLabel = _shotTypeLabel(shotType);

        badges.add(
          ChallengerRoadBadgeDefinition(
            id: 'cr_${shotType}_l${level}_x$threshold',
            name: '$shotLabel L$level Specialist',
            description: 'Complete Level $level $shotLabel challenges $threshold times total.',
            category: ChallengerRoadBadgeCategory.shotTypeLevelMastery,
            threshold: threshold,
            level: level,
            shotType: shotType,
          ),
        );
      }
    }

    return badges;
  }

  /// Returns the profile badge catalog generated from the current active
  /// Challenger Road levels/challenges.
  Future<List<ChallengerRoadBadgeDefinition>> getBadgeCatalogForUser(String userId) async {
    final stats = await _loadRoadBadgeStats(userId);
    return _buildBadgeDefinitions(stats);
  }

  // ---------------------------------------------------------------------------
  // 1. Global challenge data
  // ---------------------------------------------------------------------------

  /// Returns all [ChallengerRoadChallenge] objects that have an active level
  /// document at [level], ordered by that level's [sequence] field.
  Future<List<ChallengerRoadChallenge>> getChallengesForLevel(int level) async {
    final levelSnap = await _findActiveLevelSnapshot(level);
    if (levelSnap == null) return [];

    // level_name is authoritative on the parent level document — override
    // whatever the challenge sub-docs carry so a single field update is enough.
    final parentData = levelSnap.data() as Map<String, dynamic>?;
    final parentLevelName = (parentData?['level_name'] as String?)?.trim();

    final challengesSnap = await _challengesRef(levelSnap.id).orderBy('sequence').get();
    return challengesSnap.docs.map(ChallengerRoadChallenge.fromSnapshot).where((c) => c.active).map((c) {
      if (parentLevelName != null && parentLevelName.isNotEmpty && parentLevelName != c.levelName) {
        return c.copyWith(levelName: parentLevelName);
      }
      return c;
    }).toList();
  }

  /// Returns the [ChallengerRoadLevel] document for a specific challenge at a
  /// specific level, or null if the challenge does not participate at that level.
  Future<ChallengerRoadLevel?> getLevelDoc(String challengeId, int level) async {
    final challenges = await getChallengesForLevel(level);
    for (final challenge in challenges) {
      if (challenge.id == challengeId) {
        return challenge.toLevelDoc();
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. Distinct active level numbers (for map rendering)
  // ---------------------------------------------------------------------------

  /// Returns a sorted list of all distinct active level numbers across all challenges.
  /// Used to build the full snake map without loading every challenge.
  Future<List<int>> getAllActiveLevels() async {
    final snap = await _levelsRef.where('active', isEqualTo: true).get();

    final levels = snap.docs.map((d) => (d.data() as Map<String, dynamic>?)?['level'] as num?).whereType<num>().map((n) => n.toInt()).toSet().toList()..sort();

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
    final challenges = await getChallengesForLevel(level);
    if (challenges.isEmpty) return false;

    for (final challenge in challenges) {
      final challengeId = challenge.id;
      if (challengeId == null) continue;

      final passed = await isChallengePassedAtLevel(userId, attemptId, challengeId, level);
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
    final bestAttemptUpdate = _buildBestAttemptSummaryUpdate(
      summary: summary,
      completedLevel: completedLevel,
      totalShotsThisAttempt: attempt.totalShotsThisAttempt,
    );
    if (bestAttemptUpdate.isNotEmpty) {
      await updateUserSummary(userId, bestAttemptUpdate);
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

  /// Called when the user taps "RUN IT BACK" after completing the full road.
  ///
  /// Marks the current attempt as `completed` and creates a genuine new attempt
  /// starting from level 1. Unlike [restartChallengerRoad] this path is always
  /// a fresh start — the road was finished, not abandoned.
  Future<ChallengerRoadAttempt> runItBack(String userId) async {
    final active = await getActiveAttempt(userId);
    if (active != null) {
      await updateAttempt(userId, active.id!, {
        'status': 'completed',
        'end_date': Timestamp.fromDate(DateTime.now()),
      });
    }
    // Always start from level 1 — the user beat the whole road.
    return createAttempt(userId, 1);
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

  Map<String, dynamic> _buildBestAttemptSummaryUpdate({
    required ChallengerRoadUserSummary summary,
    required int completedLevel,
    required int totalShotsThisAttempt,
  }) {
    if (!_isBetterBestAttempt(
      summary: summary,
      completedLevel: completedLevel,
      totalShotsThisAttempt: totalShotsThisAttempt,
    )) {
      return const <String, dynamic>{};
    }

    return {
      'all_time_best_level': completedLevel,
      'all_time_best_level_shots': totalShotsThisAttempt,
    };
  }

  bool _isBetterBestAttempt({
    required ChallengerRoadUserSummary summary,
    required int completedLevel,
    required int totalShotsThisAttempt,
  }) {
    if (completedLevel <= 0) return false;
    if (completedLevel > summary.allTimeBestLevel) return true;
    if (completedLevel < summary.allTimeBestLevel) return false;

    final bestShots = summary.allTimeBestLevelShots;
    if (bestShots == null) return true;
    return totalShotsThisAttempt < bestShots;
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
    final levelSnaps = await _levelsRef.where('active', isEqualTo: true).get();
    final activeChallengeIdsByLevel = <int, Set<String>>{};
    final activeShotTypeChallengeCountByLevel = <String, int>{};
    final challengeById = <String, ChallengerRoadChallenge>{};

    for (final levelDoc in levelSnaps.docs) {
      final level = ((levelDoc.data() as Map<String, dynamic>?)?['level'] as num?)?.toInt();
      if (level == null) continue;

      final challengeSnaps = await _challengesRef(levelDoc.id).where('active', isEqualTo: true).get();
      for (final challengeSnap in challengeSnaps.docs) {
        final challenge = ChallengerRoadChallenge.fromSnapshot(challengeSnap);
        final challengeId = challenge.id;
        if (challengeId == null) continue;

        challengeById[challengeId] = challenge;
        activeChallengeIdsByLevel.putIfAbsent(level, () => <String>{}).add(challengeId);

        final shotType = challenge.shotType?.toLowerCase();
        if (shotType != null && shotType.isNotEmpty) {
          final key = _shotTypeLevelKey(shotType, level);
          activeShotTypeChallengeCountByLevel[key] = (activeShotTypeChallengeCountByLevel[key] ?? 0) + 1;
        }
      }
    }

    final clearedChallengeIdsByLevel = <int, Set<String>>{};
    final passesByShotTypeAndLevel = <String, int>{};
    var outperformPlusTwoPasses = 0;

    final attemptsSnap = await _attemptsRef(userId).get();
    for (final attemptDoc in attemptsSnap.docs) {
      final attemptId = attemptDoc.id;

      final progressSnap = await _progressRef(userId, attemptId).get();
      for (final progressDoc in progressSnap.docs) {
        final progress = ChallengeProgressEntry.fromSnapshot(progressDoc);

        final challenge = challengeById[progress.challengeId];
        final shotType = challenge?.shotType?.toLowerCase();

        for (final history in progress.levelHistory) {
          if (!history.passed) continue;

          clearedChallengeIdsByLevel.putIfAbsent(history.level, () => <String>{}).add(progress.challengeId);

          if (shotType != null && shotType.isNotEmpty) {
            final key = _shotTypeLevelKey(shotType, history.level);
            passesByShotTypeAndLevel[key] = (passesByShotTypeAndLevel[key] ?? 0) + 1;
          }
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

    final highestActiveLevel = activeChallengeIdsByLevel.keys.isEmpty ? 0 : (activeChallengeIdsByLevel.keys.toList()..sort()).last;

    return _RoadBadgeStats(
      highestActiveLevel: highestActiveLevel,
      activeChallengeIdsByLevel: activeChallengeIdsByLevel,
      activeShotTypeChallengeCountByLevel: activeShotTypeChallengeCountByLevel,
      clearedChallengeIdsByLevel: clearedChallengeIdsByLevel,
      passesByShotTypeAndLevel: passesByShotTypeAndLevel,
      outperformPlusTwoPasses: outperformPlusTwoPasses,
    );
  }

  /// Returns true if every active challenge at [level] was completed on the
  /// first try within [attemptId] — i.e., there is exactly one
  /// [ChallengeLevelHistoryEntry] at this level in each progress entry.
  Future<bool> _isLevelPerfect(String userId, String attemptId, int level) async {
    try {
      final challenges = await getChallengesForLevel(level);
      if (challenges.isEmpty) return false;

      for (final challenge in challenges) {
        final challengeId = challenge.id;
        if (challengeId == null) continue;

        final progressSnap = await _progressRef(userId, attemptId).doc(challengeId).get();
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
    final badgeDefs = _buildBadgeDefinitions(stats);

    void maybeAward(String badgeId) {
      if (!earned.contains(badgeId)) {
        earned.add(badgeId);
        newBadges.add(badgeId);
      }
    }

    for (final badge in badgeDefs) {
      switch (badge.category) {
        case ChallengerRoadBadgeCategory.attempts:
          if (summary.totalAttempts >= (badge.threshold ?? 0)) {
            maybeAward(badge.id);
          }
          break;
        case ChallengerRoadBadgeCategory.shotsMilestone:
          if (summary.allTimeTotalChallengerRoadShots >= (badge.threshold ?? 0)) {
            maybeAward(badge.id);
          }
          break;
        case ChallengerRoadBadgeCategory.levelAllClear:
          final level = badge.level;
          if (level == null) break;
          final activeCount = stats.activeChallengeIdsByLevel[level]?.length ?? 0;
          final clearedCount = stats.clearedChallengeIdsByLevel[level]?.length ?? 0;
          if (activeCount > 0 && clearedCount >= activeCount) {
            maybeAward(badge.id);
          }
          break;
        case ChallengerRoadBadgeCategory.shotTypeLevelMastery:
          final level = badge.level;
          final shotType = badge.shotType;
          final threshold = badge.threshold;
          if (level == null || shotType == null || threshold == null) break;

          final passes = stats.passesByShotTypeAndLevel[_shotTypeLevelKey(shotType, level)] ?? 0;
          if (passes >= threshold) {
            maybeAward(badge.id);
          }
          break;
        case ChallengerRoadBadgeCategory.outperform:
          if (stats.outperformPlusTwoPasses >= (badge.threshold ?? 0)) {
            maybeAward(badge.id);
          }
          break;
        case ChallengerRoadBadgeCategory.special:
          // Awarded via separate context-aware checks.
          break;
      }
    }

    if (newBadges.isEmpty) return;

    await updateUserSummary(userId, {'badges': earned});
  }
}

class _RoadBadgeStats {
  final int highestActiveLevel;
  final Map<int, Set<String>> activeChallengeIdsByLevel;
  final Map<String, int> activeShotTypeChallengeCountByLevel;
  final Map<int, Set<String>> clearedChallengeIdsByLevel;
  final Map<String, int> passesByShotTypeAndLevel;
  final int outperformPlusTwoPasses;

  const _RoadBadgeStats({
    required this.highestActiveLevel,
    required this.activeChallengeIdsByLevel,
    required this.activeShotTypeChallengeCountByLevel,
    required this.clearedChallengeIdsByLevel,
    required this.passesByShotTypeAndLevel,
    required this.outperformPlusTwoPasses,
  });
}

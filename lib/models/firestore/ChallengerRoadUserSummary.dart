import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengerRoadUserSummary {
  /// The Firestore ID of the currently active attempt, or null if none.
  final String? currentAttemptId;

  /// Total number of Challenger Road attempts started by this user.
  final int totalAttempts;

  /// The highest level this user has fully completed across all attempts.
  /// Used to display the Personal Best badge on their profile.
  final int allTimeBestLevel;

  /// Cumulative Challenger Road shots across all attempts and milestone resets.
  /// Used for "× 10,000" badge calculations.
  final int allTimeTotalChallengerRoadShots;

  /// Badge IDs earned by this user (e.g. 'cr_10k_x1', 'cr_level_5').
  final List<String> badges;

  DocumentReference? reference;

  ChallengerRoadUserSummary({
    this.currentAttemptId,
    required this.totalAttempts,
    required this.allTimeBestLevel,
    required this.allTimeTotalChallengerRoadShots,
    required this.badges,
    this.reference,
  });

  ChallengerRoadUserSummary.empty()
      : currentAttemptId = null,
        totalAttempts = 0,
        allTimeBestLevel = 0,
        allTimeTotalChallengerRoadShots = 0,
        badges = [];

  ChallengerRoadUserSummary.fromMap(Map<String, dynamic> map, {this.reference})
      : currentAttemptId = map['current_attempt_id'],
        totalAttempts = map['total_attempts'] ?? 0,
        allTimeBestLevel = map['all_time_best_level'] ?? 0,
        allTimeTotalChallengerRoadShots = map['all_time_total_challenger_road_shots'] ?? 0,
        badges = List<String>.from(map['badges'] ?? []);

  Map<String, dynamic> toMap() {
    return {
      'current_attempt_id': currentAttemptId,
      'total_attempts': totalAttempts,
      'all_time_best_level': allTimeBestLevel,
      'all_time_total_challenger_road_shots': allTimeTotalChallengerRoadShots,
      'badges': badges,
    };
  }

  ChallengerRoadUserSummary.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(
          snapshot.data() as Map<String, dynamic>,
          reference: snapshot.reference,
        );

  ChallengerRoadUserSummary copyWith({
    String? currentAttemptId,
    int? totalAttempts,
    int? allTimeBestLevel,
    int? allTimeTotalChallengerRoadShots,
    List<String>? badges,
  }) {
    return ChallengerRoadUserSummary(
      currentAttemptId: currentAttemptId ?? this.currentAttemptId,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      allTimeBestLevel: allTimeBestLevel ?? this.allTimeBestLevel,
      allTimeTotalChallengerRoadShots: allTimeTotalChallengerRoadShots ?? this.allTimeTotalChallengerRoadShots,
      badges: badges ?? this.badges,
      reference: reference,
    );
  }
}

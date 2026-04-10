import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengerRoadUserSummary {
  /// The Firestore ID of the currently active attempt, or null if none.
  final String? currentAttemptId;

  /// Total number of Challenger Road attempts started by this user.
  final int totalAttempts;

  /// The highest level this user has fully completed across all attempts.
  /// Used to display the Personal Best badge on their profile.
  final int allTimeBestLevel;

  /// Shots taken when the current personal-best level record was set.
  /// Lower is better when comparing attempts that reached the same level.
  final int? allTimeBestLevelShots;

  /// Cumulative Challenger Road shots across all attempts and milestone resets.
  /// Used for "× 10,000" badge calculations.
  final int allTimeTotalChallengerRoadShots;

  /// Badge IDs earned by this user (e.g. 'cr_10k_x1', 'cr_level_5').
  final List<String> badges;

  /// Up to 3 badge IDs the user has chosen to feature on their player card.
  final List<String> featuredBadges;

  DocumentReference? reference;

  ChallengerRoadUserSummary({
    this.currentAttemptId,
    required this.totalAttempts,
    required this.allTimeBestLevel,
    this.allTimeBestLevelShots,
    required this.allTimeTotalChallengerRoadShots,
    required this.badges,
    this.featuredBadges = const [],
    this.reference,
  });

  ChallengerRoadUserSummary.empty()
      : currentAttemptId = null,
        totalAttempts = 0,
        allTimeBestLevel = 0,
        allTimeBestLevelShots = null,
        allTimeTotalChallengerRoadShots = 0,
        badges = [],
        featuredBadges = [];

  ChallengerRoadUserSummary.fromMap(Map<String, dynamic> map, {this.reference})
      : currentAttemptId = map['current_attempt_id'],
        totalAttempts = map['total_attempts'] ?? 0,
        allTimeBestLevel = map['all_time_best_level'] ?? 0,
        allTimeBestLevelShots = (map['all_time_best_level_shots'] as num?)?.toInt(),
        allTimeTotalChallengerRoadShots = map['all_time_total_challenger_road_shots'] ?? 0,
        badges = List<String>.from(map['badges'] ?? []),
        featuredBadges = List<String>.from(map['featured_badges'] ?? []);

  Map<String, dynamic> toMap() {
    return {
      'current_attempt_id': currentAttemptId,
      'total_attempts': totalAttempts,
      'all_time_best_level': allTimeBestLevel,
      'all_time_best_level_shots': allTimeBestLevelShots,
      'all_time_total_challenger_road_shots': allTimeTotalChallengerRoadShots,
      'badges': badges,
      'featured_badges': featuredBadges,
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
    int? allTimeBestLevelShots,
    int? allTimeTotalChallengerRoadShots,
    List<String>? badges,
    List<String>? featuredBadges,
  }) {
    return ChallengerRoadUserSummary(
      currentAttemptId: currentAttemptId ?? this.currentAttemptId,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      allTimeBestLevel: allTimeBestLevel ?? this.allTimeBestLevel,
      allTimeBestLevelShots: allTimeBestLevelShots ?? this.allTimeBestLevelShots,
      allTimeTotalChallengerRoadShots: allTimeTotalChallengerRoadShots ?? this.allTimeTotalChallengerRoadShots,
      badges: badges ?? this.badges,
      featuredBadges: featuredBadges ?? this.featuredBadges,
      reference: reference,
    );
  }
}

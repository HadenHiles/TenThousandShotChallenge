import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengerRoadAttempt {
  String? id;
  final int attemptNumber;

  /// The level the player started this attempt on.
  /// Computed as max(1, previousAttempt.highestLevelReachedThisAttempt - 1).
  final int startingLevel;

  /// The level the player is currently on.
  final int currentLevel;

  /// Challenger Road-scoped shot counter. Resets to 0 each time 10,000 is reached.
  final int challengerRoadShotCount;

  /// Cumulative shots taken this attempt — never resets. Used for badge math.
  final int totalShotsThisAttempt;

  /// How many times the 10k milestone has been hit in this attempt.
  final int resetCount;

  /// The highest level fully completed during this attempt.
  /// Used to compute the next attempt's startingLevel.
  final int highestLevelReachedThisAttempt;

  /// 'active' or 'completed'
  final String status;

  final DateTime startDate;
  final DateTime? endDate;

  DocumentReference? reference;

  ChallengerRoadAttempt({
    this.id,
    required this.attemptNumber,
    required this.startingLevel,
    required this.currentLevel,
    required this.challengerRoadShotCount,
    required this.totalShotsThisAttempt,
    required this.resetCount,
    required this.highestLevelReachedThisAttempt,
    required this.status,
    required this.startDate,
    this.endDate,
    this.reference,
  });

  ChallengerRoadAttempt.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        attemptNumber = map['attempt_number'] ?? 1,
        startingLevel = map['starting_level'] ?? 1,
        currentLevel = map['current_level'] ?? 1,
        challengerRoadShotCount = map['challenger_road_shot_count'] ?? 0,
        totalShotsThisAttempt = map['total_shots_this_attempt'] ?? 0,
        resetCount = map['reset_count'] ?? 0,
        highestLevelReachedThisAttempt = map['highest_level_reached_this_attempt'] ?? 1,
        status = map['status'] ?? 'active',
        startDate = (map['start_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endDate = (map['end_date'] as Timestamp?)?.toDate();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'attempt_number': attemptNumber,
      'starting_level': startingLevel,
      'current_level': currentLevel,
      'challenger_road_shot_count': challengerRoadShotCount,
      'total_shots_this_attempt': totalShotsThisAttempt,
      'reset_count': resetCount,
      'highest_level_reached_this_attempt': highestLevelReachedThisAttempt,
      'status': status,
      'start_date': startDate,
      'end_date': endDate,
    };
  }

  ChallengerRoadAttempt.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(
          {
            ...snapshot.data() as Map<String, dynamic>,
            'id': snapshot.id,
          },
          reference: snapshot.reference,
        );

  ChallengerRoadAttempt copyWith({
    int? currentLevel,
    int? challengerRoadShotCount,
    int? totalShotsThisAttempt,
    int? resetCount,
    int? highestLevelReachedThisAttempt,
    String? status,
    DateTime? endDate,
  }) {
    return ChallengerRoadAttempt(
      id: id,
      attemptNumber: attemptNumber,
      startingLevel: startingLevel,
      currentLevel: currentLevel ?? this.currentLevel,
      challengerRoadShotCount: challengerRoadShotCount ?? this.challengerRoadShotCount,
      totalShotsThisAttempt: totalShotsThisAttempt ?? this.totalShotsThisAttempt,
      resetCount: resetCount ?? this.resetCount,
      highestLevelReachedThisAttempt: highestLevelReachedThisAttempt ?? this.highestLevelReachedThisAttempt,
      status: status ?? this.status,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      reference: reference,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeAllTimeHistory {
  final String challengeId;
  final int allTimeBestLevel;
  final int allTimeTotalAttempts;
  final int allTimeTotalPassed;
  final DateTime? firstPassedAt;
  final DateTime? lastPassedAt;

  const ChallengeAllTimeHistory({
    required this.challengeId,
    required this.allTimeBestLevel,
    required this.allTimeTotalAttempts,
    required this.allTimeTotalPassed,
    this.firstPassedAt,
    this.lastPassedAt,
  });

  factory ChallengeAllTimeHistory.fromMap(Map<String, dynamic> map) {
    return ChallengeAllTimeHistory(
      challengeId: map['challengeId'] as String,
      allTimeBestLevel: (map['allTimeBestLevel'] as num).toInt(),
      allTimeTotalAttempts: (map['allTimeTotalAttempts'] as num).toInt(),
      allTimeTotalPassed: (map['allTimeTotalPassed'] as num).toInt(),
      firstPassedAt: map['firstPassedAt'] != null ? (map['firstPassedAt'] as Timestamp).toDate() : null,
      lastPassedAt: map['lastPassedAt'] != null ? (map['lastPassedAt'] as Timestamp).toDate() : null,
    );
  }

  factory ChallengeAllTimeHistory.fromSnapshot(DocumentSnapshot snapshot) {
    return ChallengeAllTimeHistory.fromMap({
      ...snapshot.data() as Map<String, dynamic>,
      'challengeId': snapshot.id,
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'allTimeBestLevel': allTimeBestLevel,
      'allTimeTotalAttempts': allTimeTotalAttempts,
      'allTimeTotalPassed': allTimeTotalPassed,
      'firstPassedAt': firstPassedAt != null ? Timestamp.fromDate(firstPassedAt!) : null,
      'lastPassedAt': lastPassedAt != null ? Timestamp.fromDate(lastPassedAt!) : null,
    };
  }

  ChallengeAllTimeHistory copyWith({
    String? challengeId,
    int? allTimeBestLevel,
    int? allTimeTotalAttempts,
    int? allTimeTotalPassed,
    DateTime? firstPassedAt,
    DateTime? lastPassedAt,
  }) {
    return ChallengeAllTimeHistory(
      challengeId: challengeId ?? this.challengeId,
      allTimeBestLevel: allTimeBestLevel ?? this.allTimeBestLevel,
      allTimeTotalAttempts: allTimeTotalAttempts ?? this.allTimeTotalAttempts,
      allTimeTotalPassed: allTimeTotalPassed ?? this.allTimeTotalPassed,
      firstPassedAt: firstPassedAt ?? this.firstPassedAt,
      lastPassedAt: lastPassedAt ?? this.lastPassedAt,
    );
  }
}

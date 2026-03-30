import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeLevelHistoryEntry {
  final int level;
  final bool passed;
  final int shotsMade;
  final int shotsRequired;
  final DateTime date;

  const ChallengeLevelHistoryEntry({
    required this.level,
    required this.passed,
    required this.shotsMade,
    required this.shotsRequired,
    required this.date,
  });

  factory ChallengeLevelHistoryEntry.fromMap(Map<String, dynamic> map) {
    return ChallengeLevelHistoryEntry(
      level: (map['level'] as num).toInt(),
      passed: map['passed'] as bool,
      shotsMade: (map['shotsMade'] as num).toInt(),
      shotsRequired: (map['shotsRequired'] as num).toInt(),
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'passed': passed,
      'shotsMade': shotsMade,
      'shotsRequired': shotsRequired,
      'date': Timestamp.fromDate(date),
    };
  }
}

class ChallengeProgressEntry {
  final String challengeId;
  final int bestLevel;
  final int totalAttempts;
  final int totalPassed;
  final DateTime? firstPassedAt;
  final DateTime? lastAttemptAt;
  final List<ChallengeLevelHistoryEntry> levelHistory;

  const ChallengeProgressEntry({
    required this.challengeId,
    required this.bestLevel,
    required this.totalAttempts,
    required this.totalPassed,
    this.firstPassedAt,
    this.lastAttemptAt,
    required this.levelHistory,
  });

  factory ChallengeProgressEntry.fromMap(Map<String, dynamic> map) {
    return ChallengeProgressEntry(
      challengeId: map['challengeId'] as String,
      bestLevel: (map['bestLevel'] as num).toInt(),
      totalAttempts: (map['totalAttempts'] as num).toInt(),
      totalPassed: (map['totalPassed'] as num).toInt(),
      firstPassedAt: map['firstPassedAt'] != null ? (map['firstPassedAt'] as Timestamp).toDate() : null,
      lastAttemptAt: map['lastAttemptAt'] != null ? (map['lastAttemptAt'] as Timestamp).toDate() : null,
      levelHistory: (map['levelHistory'] as List<dynamic>? ?? []).map((e) => ChallengeLevelHistoryEntry.fromMap(e as Map<String, dynamic>)).toList(),
    );
  }

  factory ChallengeProgressEntry.fromSnapshot(DocumentSnapshot snapshot) {
    return ChallengeProgressEntry.fromMap({
      ...snapshot.data() as Map<String, dynamic>,
      'challengeId': snapshot.id,
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'bestLevel': bestLevel,
      'totalAttempts': totalAttempts,
      'totalPassed': totalPassed,
      'firstPassedAt': firstPassedAt != null ? Timestamp.fromDate(firstPassedAt!) : null,
      'lastAttemptAt': lastAttemptAt != null ? Timestamp.fromDate(lastAttemptAt!) : null,
      'levelHistory': levelHistory.map((e) => e.toMap()).toList(),
    };
  }

  ChallengeProgressEntry copyWith({
    String? challengeId,
    int? bestLevel,
    int? totalAttempts,
    int? totalPassed,
    DateTime? firstPassedAt,
    DateTime? lastAttemptAt,
    List<ChallengeLevelHistoryEntry>? levelHistory,
  }) {
    return ChallengeProgressEntry(
      challengeId: challengeId ?? this.challengeId,
      bestLevel: bestLevel ?? this.bestLevel,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      totalPassed: totalPassed ?? this.totalPassed,
      firstPassedAt: firstPassedAt ?? this.firstPassedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      levelHistory: levelHistory ?? this.levelHistory,
    );
  }
}

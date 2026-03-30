import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';

class ChallengeSession {
  String? id;
  final String challengeId;
  final int level;
  final DateTime date;
  final Duration duration;

  /// Copied from ChallengerRoadLevel at the time of the session.
  final int shotsRequired;

  /// Copied from ChallengerRoadLevel at the time of the session.
  final int shotsToPass;

  /// On-target shots logged during this session.
  final int shotsMade;

  /// Total shots taken this session (on-target + missed).
  final int totalShots;

  /// True when shotsMade >= shotsToPass.
  final bool passed;

  /// Individual shot records — reuses the existing Shots model.
  final List<Shots> shots;

  DocumentReference? reference;

  ChallengeSession({
    this.id,
    required this.challengeId,
    required this.level,
    required this.date,
    required this.duration,
    required this.shotsRequired,
    required this.shotsToPass,
    required this.shotsMade,
    required this.totalShots,
    required this.passed,
    required this.shots,
    this.reference,
  });

  ChallengeSession.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        challengeId = map['challenge_id'] ?? '',
        level = map['level'] ?? 1,
        date = (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        duration = Duration(seconds: map['duration'] ?? 0),
        shotsRequired = map['shots_required'] ?? 0,
        shotsToPass = map['shots_to_pass'] ?? 0,
        shotsMade = map['shots_made'] ?? 0,
        totalShots = map['total_shots'] ?? 0,
        passed = map['passed'] ?? false,
        shots = (map['shots'] as List<dynamic>?)?.map((s) => Shots.fromMap(s as Map<String, dynamic>)).toList() ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'challenge_id': challengeId,
      'level': level,
      'date': date,
      'duration': duration.inSeconds,
      'shots_required': shotsRequired,
      'shots_to_pass': shotsToPass,
      'shots_made': shotsMade,
      'total_shots': totalShots,
      'passed': passed,
      'shots': shots.map((s) => s.toMap()).toList(),
    };
  }

  ChallengeSession.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(
          {
            ...snapshot.data() as Map<String, dynamic>,
            'id': snapshot.id,
          },
          reference: snapshot.reference,
        );
}

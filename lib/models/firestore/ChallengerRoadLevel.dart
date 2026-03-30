import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeStep.dart';

class ChallengerRoadLevel {
  String? id;

  /// Numeric level number (1, 2, 3 …)
  final int level;

  /// Display name, e.g. "Level 1"
  final String levelName;

  /// Position on the map for this level. Lower = closer to the bottom (Level 1 area).
  final int sequence;

  /// Total shots the player must take to complete this challenge level.
  final int shotsRequired;

  /// Minimum on-target shots needed to pass.
  final int shotsToPass;

  final bool active;

  /// Optional step override for this level.
  /// When null, the parent ChallengerRoadChallenge steps are used instead.
  final List<ChallengeStep>? steps;

  DocumentReference? reference;

  ChallengerRoadLevel({
    this.id,
    required this.level,
    required this.levelName,
    required this.sequence,
    required this.shotsRequired,
    required this.shotsToPass,
    required this.active,
    this.steps,
    this.reference,
  });

  ChallengerRoadLevel.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        level = map['level'] ?? 1,
        levelName = map['level_name'] ?? 'Level 1',
        sequence = map['sequence'] ?? 0,
        shotsRequired = map['shots_required'] ?? 10,
        shotsToPass = map['shots_to_pass'] ?? 6,
        active = map['active'] ?? true,
        steps = (map['steps'] as List<dynamic>?)?.map((s) => ChallengeStep.fromMap(s as Map<String, dynamic>)).toList();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level': level,
      'level_name': levelName,
      'sequence': sequence,
      'shots_required': shotsRequired,
      'shots_to_pass': shotsToPass,
      'active': active,
      'steps': steps?.map((s) => s.toMap()).toList(),
    };
  }

  ChallengerRoadLevel.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(
          {
            ...snapshot.data() as Map<String, dynamic>,
            'id': snapshot.id,
          },
          reference: snapshot.reference,
        );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeStep.dart';

class ChallengerRoadChallenge {
  String? id;
  final String name;
  final String description;
  final bool active;

  /// The shot type this challenge focuses on: 'wrist', 'snap', 'slap', or
  /// 'backhand'. Null means no specific shot type is required.
  final String? shotType;

  final List<ChallengeStep> steps;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  DocumentReference? reference;

  ChallengerRoadChallenge({
    this.id,
    required this.name,
    required this.description,
    required this.active,
    this.shotType,
    required this.steps,
    this.createdAt,
    this.updatedAt,
    this.reference,
  });

  ChallengerRoadChallenge.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        name = map['name'] ?? '',
        description = map['description'] ?? '',
        active = map['active'] ?? true,
        shotType = map['shot_type'] as String?,
        steps = (map['steps'] as List<dynamic>?)?.map((s) => ChallengeStep.fromMap(s as Map<String, dynamic>)).toList() ?? [],
        createdAt = (map['created_at'] as Timestamp?)?.toDate(),
        updatedAt = (map['updated_at'] as Timestamp?)?.toDate();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'active': active,
      'shot_type': shotType,
      'steps': steps.map((s) => s.toMap()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  ChallengerRoadChallenge.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(
          {
            ...snapshot.data() as Map<String, dynamic>,
            'id': snapshot.id,
          },
          reference: snapshot.reference,
        );
}

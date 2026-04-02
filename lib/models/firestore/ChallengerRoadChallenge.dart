import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeStep.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';

class ChallengerRoadChallenge {
  String? id;
  final int level;
  final String levelName;
  final int sequence;
  final String name;
  final String description;
  final int shotsRequired;
  final int shotsToPass;
  final bool active;

  /// Optional dedicated preview media shown in Challenger Road map focus card.
  final String? previewThumbnailUrl;

  /// Optional media type for [previewThumbnailUrl] ('image', 'gif', 'video').
  /// Defaults to 'image' when omitted and url is provided.
  final String? previewThumbnailMediaType;

  /// The shot type this challenge focuses on: 'wrist', 'snap', 'slap', or
  /// 'backhand'. Null means no specific shot type is required.
  final String? shotType;

  final List<ChallengeStep> steps;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  DocumentReference? reference;

  ChallengerRoadChallenge({
    this.id,
    required this.level,
    required this.levelName,
    required this.sequence,
    required this.name,
    required this.description,
    required this.shotsRequired,
    required this.shotsToPass,
    required this.active,
    this.previewThumbnailUrl,
    this.previewThumbnailMediaType,
    this.shotType,
    required this.steps,
    this.createdAt,
    this.updatedAt,
    this.reference,
  });

  ChallengerRoadChallenge.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        level = (map['level'] as num?)?.toInt() ?? 1,
        levelName = map['level_name'] ?? 'Level 1',
        sequence = (map['sequence'] as num?)?.toInt() ?? 0,
        name = map['name'] ?? '',
        description = map['description'] ?? '',
        shotsRequired = (map['shots_required'] as num?)?.toInt() ?? 10,
        shotsToPass = (map['shots_to_pass'] as num?)?.toInt() ?? 6,
        active = map['active'] ?? true,
        previewThumbnailUrl = map['preview_thumbnail_url'] as String?,
        previewThumbnailMediaType = map['preview_thumbnail_media_type'] as String?,
        shotType = map['shot_type'] as String?,
        steps = (map['steps'] as List<dynamic>?)?.map((s) => ChallengeStep.fromMap(s as Map<String, dynamic>)).toList() ?? [],
        createdAt = (map['created_at'] as Timestamp?)?.toDate(),
        updatedAt = (map['updated_at'] as Timestamp?)?.toDate();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level': level,
      'level_name': levelName,
      'sequence': sequence,
      'name': name,
      'description': description,
      'shots_required': shotsRequired,
      'shots_to_pass': shotsToPass,
      'active': active,
      'preview_thumbnail_url': previewThumbnailUrl,
      'preview_thumbnail_media_type': previewThumbnailMediaType,
      'shot_type': shotType,
      'steps': steps.map((s) => s.toMap()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  ChallengerRoadChallenge copyWith({
    String? id,
    int? level,
    String? levelName,
    int? sequence,
    String? name,
    String? description,
    int? shotsRequired,
    int? shotsToPass,
    bool? active,
    String? previewThumbnailUrl,
    String? previewThumbnailMediaType,
    String? shotType,
    List<ChallengeStep>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
    DocumentReference? reference,
  }) {
    return ChallengerRoadChallenge(
      id: id ?? this.id,
      level: level ?? this.level,
      levelName: levelName ?? this.levelName,
      sequence: sequence ?? this.sequence,
      name: name ?? this.name,
      description: description ?? this.description,
      shotsRequired: shotsRequired ?? this.shotsRequired,
      shotsToPass: shotsToPass ?? this.shotsToPass,
      active: active ?? this.active,
      previewThumbnailUrl: previewThumbnailUrl ?? this.previewThumbnailUrl,
      previewThumbnailMediaType: previewThumbnailMediaType ?? this.previewThumbnailMediaType,
      shotType: shotType ?? this.shotType,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reference: reference ?? this.reference,
    );
  }

  ChallengerRoadLevel toLevelDoc() {
    return ChallengerRoadLevel(
      level: level,
      levelName: levelName,
      sequence: sequence,
      shotsRequired: shotsRequired,
      shotsToPass: shotsToPass,
      active: active,
      steps: steps,
    );
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

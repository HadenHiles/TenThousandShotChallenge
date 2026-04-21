import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single entry in a user's `notifications` subcollection.
///
/// Written by the Cloud Function whenever a friend session or challenge
/// notification is sent.
/// Schema:
///   type          : String  — 'friend_session' | 'friend_challenge'
///   from_uid      : String  — UID of the user who triggered the event
///   from_name     : String  — display name of that user
///   shots         : int     — shot count (session total OR shots_made for challenges)
///   message       : String  — fun body text (same as the push notification body)
///   challenge_id  : String? — (challenge only) Firestore doc ID of the challenge
///   challenge_name: String? — (challenge only) human-readable challenge name
///   level         : int?    — (challenge only) level number
///   shots_made    : int?    — (challenge only) on-target shots
///   shots_to_pass : int?    — (challenge only) shots required to pass
///   created_at    : Timestamp
///   read          : bool
class AppNotification {
  final String id;
  final String type;
  final String fromUid;
  final String fromName;
  final int shots;
  final String message;
  // Challenge-specific fields (null for friend_session notifications).
  final String? challengeId;
  final String? challengeName;
  final int? level;
  final int? shotsMade;
  final int? shotsToPass;
  final DateTime? createdAt;
  final bool read;
  final DocumentReference? reference;

  const AppNotification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    required this.shots,
    required this.message,
    this.challengeId,
    this.challengeName,
    this.level,
    this.shotsMade,
    this.shotsToPass,
    this.createdAt,
    required this.read,
    this.reference,
  });

  bool get isChallenge => type == 'friend_challenge';

  static AppNotification fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime? createdAt;
    final raw = d['created_at'];
    if (raw is Timestamp) createdAt = raw.toDate();

    return AppNotification(
      id: doc.id,
      type: (d['type'] as String?) ?? 'friend_session',
      fromUid: (d['from_uid'] as String?) ?? '',
      fromName: (d['from_name'] as String?) ?? 'Someone',
      shots: (d['shots'] as int?) ?? 0,
      message: (d['message'] as String?) ?? '',
      challengeId: d['challenge_id'] as String?,
      challengeName: d['challenge_name'] as String?,
      level: d['level'] as int?,
      shotsMade: d['shots_made'] as int?,
      shotsToPass: d['shots_to_pass'] as int?,
      createdAt: createdAt,
      read: (d['read'] as bool?) ?? false,
      reference: doc.reference,
    );
  }
}

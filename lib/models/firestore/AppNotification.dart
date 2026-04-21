import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single entry in a user's `notifications` subcollection.
///
/// Written by the Cloud Function whenever a friend session notification is sent.
/// Schema:
///   type        : String  — e.g. 'friend_session'
///   from_uid    : String  — UID of the user who triggered the event
///   from_name   : String  — display name of that user
///   shots       : int     — shot count from the session
///   message     : String  — fun body text (same as the push notification body)
///   created_at  : Timestamp
///   read        : bool
class AppNotification {
  final String id;
  final String type;
  final String fromUid;
  final String fromName;
  final int shots;
  final String message;
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
    this.createdAt,
    required this.read,
    this.reference,
  });

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
      createdAt: createdAt,
      read: (d['read'] as bool?) ?? false,
      reference: doc.reference,
    );
  }
}

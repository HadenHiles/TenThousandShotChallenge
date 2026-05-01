import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single entry in a user's `notifications` subcollection.
///
/// Written by Cloud Functions or client-side service code whenever a
/// notification-worthy event occurs.
///
/// type values:
///   'friend_session'               - a friend logged a practice session
///   'friend_challenge'             - a friend passed a Challenger Road challenge
///   'invite_received'              - someone sent you a teammate invite
///   'invite_accepted'              - a teammate accepted your invite
///   'weekly_achievements_available'- new weekly challenges have been assigned
///   'achievement_completed'        - you completed a weekly achievement
///   'cr_badge_earned'              - you earned a Challenger Road trophy
///   'cr_level_completed'           - you completed a Challenger Road level
class AppNotification {
  final String id;
  final String type;
  final String fromUid;
  final String fromName;
  final int shots;
  final String message;
  // Challenge-specific fields.
  final String? challengeId;
  final String? challengeName;
  final int? level;
  final int? shotsMade;
  final int? shotsToPass;
  // Achievement-specific fields.
  final String? achievementTitle;
  final String? achievementDescription;
  // Trophy-specific fields.
  final String? trophyId;
  final String? trophyName;

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
    this.achievementTitle,
    this.achievementDescription,
    this.trophyId,
    this.trophyName,
    this.createdAt,
    required this.read,
    this.reference,
  });

  bool get isChallenge => type == 'friend_challenge';
  bool get isInviteReceived => type == 'invite_received';
  bool get isInviteAccepted => type == 'invite_accepted';
  bool get isWeeklyAvailable => type == 'weekly_achievements_available';
  bool get isAchievementCompleted => type == 'achievement_completed';
  bool get isTrophyEarned => type == 'cr_badge_earned';
  bool get isLevelCompleted => type == 'cr_level_completed';

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
      achievementTitle: d['achievement_title'] as String?,
      achievementDescription: d['achievement_description'] as String?,
      trophyId: d['badge_id'] as String?,
      trophyName: d['badge_name'] as String?,
      createdAt: createdAt,
      read: (d['read'] as bool?) ?? false,
      reference: doc.reference,
    );
  }
}

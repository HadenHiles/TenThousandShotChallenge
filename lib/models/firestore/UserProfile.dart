import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String? id;
  final String? displayName;
  final String? nickname;
  final String? email;
  final String? photoUrl;
  final bool? public;
  final bool? friendNotifications;
  final bool? practiceReminders;
  final bool? isPro;
  final String? subscriptionLevel;

  /// All teams the user belongs to. Replaces the old single `team_id` field.
  /// Legacy Firestore documents that only have `team_id` are migrated
  /// transparently on read; both fields are written on save for backward
  /// compatibility with older clients.
  List<String> teamIds;
  final String? fcmToken;
  DocumentReference? reference;

  /// Backward-compatible getter – returns the first (primary) team ID, or
  /// null when the user is not on any team. Use [teamIds] for multi-team logic.
  String? get teamId => teamIds.isNotEmpty ? teamIds.first : null;

  /// Returns the preferred name for use in notifications.
  /// Uses [nickname] if set, otherwise the first word of [displayName].
  String get notifName {
    if (nickname != null && nickname!.trim().isNotEmpty) {
      return nickname!.trim();
    }
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!.split(' ').first;
    }
    return 'Someone';
  }

  /// The 6th positional argument accepts the legacy single [teamId] string for
  /// call-sites that construct placeholder objects (e.g. "Deleted User").
  /// Pass [teamIds] via the named parameter to supply a full list.
  UserProfile(
    this.displayName,
    this.email,
    this.photoUrl,
    this.public,
    this.friendNotifications,
    String? teamId, // legacy positional – used to seed teamIds when no list given
    this.fcmToken, {
    this.nickname,
    this.practiceReminders,
    this.isPro,
    this.subscriptionLevel,
    List<String>? teamIds,
  }) : teamIds = teamIds ?? (teamId != null ? [teamId] : const []);

  /// Parses the team list from a Firestore map, transparently migrating legacy
  /// documents that only contain the single `team_id` field.
  static List<String> _parseTeamIds(Map<String, dynamic> map) {
    final raw = map['team_ids'];
    if (raw != null) return List<String>.from(raw);
    final legacy = map['team_id'] as String?;
    return legacy != null && legacy.isNotEmpty ? [legacy] : <String>[];
  }

  UserProfile.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        displayName = map['display_name'],
        nickname = map['nickname'],
        email = map['email'],
        photoUrl = map['photo_url'],
        public = map['public'] ?? false,
        friendNotifications = map['friend_notifications'] ?? true,
        practiceReminders = map['practice_reminders'] ?? false,
        isPro = map['is_pro'] ?? false,
        subscriptionLevel = map['subscription_level'] ?? ((map['is_pro'] ?? false) ? 'pro' : 'free'),
        teamIds = _parseTeamIds(map),
        fcmToken = map['fcm_token'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'nickname': nickname,
      'email': email,
      'photo_url': photoUrl,
      'public': public ?? false,
      'friend_notifications': friendNotifications ?? true,
      'practice_reminders': practiceReminders ?? false,
      'is_pro': isPro ?? false,
      'subscription_level': subscriptionLevel,
      // Write both fields for forward + backward compatibility:
      // • team_ids  – the authoritative list for new clients
      // • team_id   – the primary team kept in sync for legacy clients
      'team_ids': teamIds,
      'team_id': teamIds.isNotEmpty ? teamIds.first : null,
      'fcm_token': fcmToken,
    };
  }

  UserProfile.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

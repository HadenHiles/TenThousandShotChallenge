import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String? id;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool? public;
  final bool? friendNotifications;
  final bool? practiceReminders;
  final bool? healthSync;
  final bool? isPro;
  final String? subscriptionLevel;
  String? teamId;
  final String? fcmToken;
  DocumentReference? reference;

  UserProfile(
    this.displayName,
    this.email,
    this.photoUrl,
    this.public,
    this.friendNotifications,
    this.teamId,
    this.fcmToken, {
    this.practiceReminders,
    this.healthSync,
    this.isPro,
    this.subscriptionLevel,
  });

  UserProfile.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        displayName = map['display_name'],
        email = map['email'],
        photoUrl = map['photo_url'],
        public = map['public'] ?? false,
        friendNotifications = map['friend_notifications'] ?? true,
        practiceReminders = map['practice_reminders'] ?? false,
        healthSync = map['health_sync'] ?? false,
        isPro = map['is_pro'] ?? false,
        subscriptionLevel = map['subscription_level'] ?? ((map['is_pro'] ?? false) ? 'pro' : 'free'),
        teamId = map['team_id'],
        fcmToken = map['fcm_token'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
      'public': public ?? false,
      'friend_notifications': friendNotifications ?? true,
      'practice_reminders': practiceReminders ?? false,
      'health_sync': healthSync ?? false,
      'is_pro': isPro ?? false,
      'subscription_level': subscriptionLevel,
      'team_id': teamId,
      'fcm_token': fcmToken,
    };
  }

  UserProfile.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

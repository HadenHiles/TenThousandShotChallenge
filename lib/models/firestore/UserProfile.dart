import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String? id;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool? public;
  final String? teamId;
  final bool? teamOwner;
  final String? fcmToken;
  DocumentReference? reference;

  UserProfile(this.displayName, this.email, this.photoUrl, this.public, this.teamId, this.teamOwner, this.fcmToken);

  UserProfile.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        displayName = map['display_name'],
        email = map['email'],
        photoUrl = map['photo_url'],
        public = map['public'] ?? false,
        teamId = map['team_id'],
        teamOwner = map['team_owner'] ?? false,
        fcmToken = map['fcm_token'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
      'public': public ?? false,
      'team_id': teamId,
      'team_owner': teamOwner ?? false,
      'fcm_token': fcmToken,
    };
  }

  UserProfile.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

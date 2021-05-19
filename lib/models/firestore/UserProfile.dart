import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String id;
  final String displayName;
  final String email;
  final String photoUrl;
  DocumentReference reference;

  UserProfile(this.displayName, this.email, this.photoUrl);

  UserProfile.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        displayName = map['display_name'],
        email = map['email'],
        photoUrl = map['photo_url'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
    };
  }

  UserProfile.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

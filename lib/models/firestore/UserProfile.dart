import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String id;
  final String displayName;
  final String email;
  final String photoUrl;
  final bool public;
  DocumentReference reference;

  UserProfile(this.displayName, this.email, this.photoUrl, this.public);

  UserProfile.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        displayName = map['display_name'],
        email = map['email'],
        photoUrl = map['photo_url'],
        public = map['public'] ?? true;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
      'public': public ?? true,
    };
  }

  UserProfile.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

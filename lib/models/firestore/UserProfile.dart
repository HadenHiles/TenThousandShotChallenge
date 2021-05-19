import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String id;
  final String displayName;
  final String email;
  DocumentReference reference;

  UserProfile(this.displayName, this.email);

  UserProfile.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'],
        displayName = map['display_name'],
        email = map['email'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
    };
  }

  UserProfile.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

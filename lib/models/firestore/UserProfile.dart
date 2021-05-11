import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String id;
  final String displayName;
  DocumentReference reference;

  UserProfile(this.displayName);

  UserProfile.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['display_name'] != null),
        id = map['id'],
        displayName = map['display_name'];

  Map<String, dynamic> toMap() {
    return {'id': id, 'display_name': displayName};
  }

  UserProfile.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Teammate {
  String id;
  final String uid;
  final bool active;
  DocumentReference reference;

  Teammate(this.uid, this.active);

  Teammate.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['uid'] != null),
        assert(map['active'] != null),
        id = map['id'],
        uid = map['uid'],
        active = map['active'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'active': active,
    };
  }

  Teammate.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Invite {
  String id;
  final String uid;
  final bool pending;
  DocumentReference reference;

  Invite(this.uid, this.pending);

  Invite.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['uid'] != null),
        assert(map['active'] != null),
        id = map['id'],
        uid = map['uid'],
        pending = map['pending'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'pending': pending,
    };
  }

  Invite.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

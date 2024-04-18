import 'package:cloud_firestore/cloud_firestore.dart';

class Invite {
  String? id;
  final String? fromUid;
  final DateTime? date;
  DocumentReference? reference;

  Invite(this.fromUid, this.date);

  Invite.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['from_uid'] != null),
        assert(map['date'] != null),
        id = map['id'],
        fromUid = map['from_uid'],
        date = map['date'] != null ? map['date'].toDate() : null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_uid': fromUid,
      'date': date,
    };
  }

  Invite.fromSnapshot(DocumentSnapshot? snapshot) : this.fromMap(snapshot!.data() as Map<String, dynamic>, reference: snapshot.reference);
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Shots {
  String? id;
  DateTime? date;
  String? type;
  int? count;
  int? targetsHit;
  DocumentReference? reference;

  Shots(this.date, this.type, this.count, this.targetsHit);

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'type': type,
        'count': count,
        'targets_hit': targetsHit,
      };

  Shots.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['date'] != null),
        assert(map['type'] != null),
        assert(map['count'] != null),
        id = map['id'],
        date = map['date']?.toDate(),
        type = map['type'],
        count = map['count'],
        targetsHit = map['targets_hit'];

  Shots.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Shots {
  String? id;
  DateTime? date;
  String? type;
  int? count;
  int? targetsHit; // <-- Add this
  DocumentReference? reference;

  Shots(this.date, this.type, this.count, {this.targetsHit});

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'type': type,
        'count': count,
        'targetsHit': targetsHit,
      };

  Shots.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['date'] != null),
        assert(map['type'] != null),
        assert(map['count'] != null),
        id = map['id'],
        date = map['date']?.toDate(),
        type = map['type'],
        count = map['count'],
        targetsHit = map['targetsHit'];

  Shots.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

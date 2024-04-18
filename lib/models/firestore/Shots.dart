import 'package:cloud_firestore/cloud_firestore.dart';

class Shots {
  String? id;
  final DateTime? date;
  final String? type;
  final int? count;
  DocumentReference? reference;

  Shots(this.date, this.type, this.count);

  Shots.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['date'] != null),
        assert(map['type'] != null),
        assert(map['count'] != null),
        id = map['id'],
        date = map['date'] != null ? map['date'].toDate() : null,
        type = map['type'],
        count = map['count'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'type': type,
      'count': count,
    };
  }

  Shots.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

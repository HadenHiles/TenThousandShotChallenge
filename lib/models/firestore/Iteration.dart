import 'package:cloud_firestore/cloud_firestore.dart';

class Iteration {
  String id;
  final DateTime startDate;
  final DateTime endDate;
  final int total;
  final bool complete;
  DocumentReference reference;

  Iteration(this.startDate, this.endDate, this.total, this.complete);

  Iteration.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['start_date'] != null),
        assert(map['total'] != null),
        id = map['id'],
        startDate = map['start_date'] != null ? map['start_date'].toDate() : null,
        endDate = map['end_date'] != null ? map['end_date'].toDate() : null,
        total = map['total'],
        complete = map['complete'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_date': startDate,
      'end_date': endDate,
      'total': total,
      'complete': complete,
    };
  }

  Iteration.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';

class ShotType {
  String id;
  final int total;
  List<Shots> shots;
  DocumentReference reference;

  ShotType(this.total);

  ShotType.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['total'] != null),
        id = map['id'],
        total = map['total'];

  Map<String, dynamic> toMap() {
    List<Map<String, dynamic>> mappedShots = [];

    shots?.forEach((m) {
      mappedShots.add(m.toMap());
    });

    return {
      'id': id,
      'total': total,
      'shots': mappedShots,
    };
  }

  ShotType.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

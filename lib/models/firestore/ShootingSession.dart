import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';

class ShootingSession {
  String id;
  final int total;
  final int totalWrist;
  final int totalSnap;
  final int totalSlap;
  final int totalBackhand;
  List<Shots> shots;
  DocumentReference reference;

  ShootingSession(this.total, this.totalWrist, this.totalSnap, this.totalSlap, this.totalBackhand);

  ShootingSession.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['total'] != null),
        assert(map['total_rist'] != null),
        assert(map['total_snap'] != null),
        assert(map['total_slap'] != null),
        assert(map['total_backhand'] != null),
        id = map['id'],
        total = map['total'],
        totalWrist = map['total_wrist'],
        totalSnap = map['total_snap'],
        totalSlap = map['total_slap'],
        totalBackhand = map['total_backhand'];

  Map<String, dynamic> toMap() {
    List<Map<String, dynamic>> mappedShots = [];

    shots?.forEach((m) {
      mappedShots.add(m.toMap());
    });

    return {
      'id': id,
      'total': total,
      'total_wrist': totalWrist,
      'total_snap': totalSnap,
      'total_slap': totalSlap,
      'total_backhand': totalBackhand,
    };
  }

  ShootingSession.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

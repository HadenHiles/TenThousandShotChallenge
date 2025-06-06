import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';

class ShootingSession {
  String? id;
  final int? total;
  final int? totalWrist;
  final int? totalSnap;
  final int? totalSlap;
  final int? totalBackhand;
  final DateTime? date;
  final Duration? duration;
  final int? wristTargetsHit;
  final int? snapTargetsHit;
  final int? slapTargetsHit;
  final int? backhandTargetsHit;
  List<Shots>? shots;
  DocumentReference? reference;

  ShootingSession(
    this.total,
    this.totalWrist,
    this.totalSnap,
    this.totalSlap,
    this.totalBackhand,
    this.date,
    this.duration, {
    this.wristTargetsHit,
    this.snapTargetsHit,
    this.slapTargetsHit,
    this.backhandTargetsHit,
    this.shots,
    this.reference,
  });

  ShootingSession.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['total'] != null),
        assert(map['total_wrist'] != null),
        assert(map['total_snap'] != null),
        assert(map['total_slap'] != null),
        assert(map['total_backhand'] != null),
        assert(map['date'] != null),
        assert(map['duration'] != null),
        assert(map['wrist_targets_hit'] != null),
        assert(map['snap_targets_hit'] != null),
        assert(map['slap_targets_hit'] != null),
        assert(map['backhand_targets_hit'] != null),
        id = reference!.id,
        total = map['total'],
        totalWrist = map['total_wrist'],
        totalSnap = map['total_snap'],
        totalSlap = map['total_slap'],
        totalBackhand = map['total_backhand'],
        date = map['date']?.toDate(),
        duration = Duration(seconds: map['duration']),
        wristTargetsHit = map['wrist_targets_hit'],
        snapTargetsHit = map['snap_targets_hit'],
        slapTargetsHit = map['slap_targets_hit'],
        backhandTargetsHit = map['backhand_targets_hit'];

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
      'date': date,
      'duration': duration!.inSeconds,
      'wrist_targets_hit': wristTargetsHit,
      'snap_targets_hit': snapTargetsHit,
      'slap_targets_hit': slapTargetsHit,
      'backhand_targets_hit': backhandTargetsHit,
    };
  }

  ShootingSession.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

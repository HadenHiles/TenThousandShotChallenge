import 'package:cloud_firestore/cloud_firestore.dart';

class Iteration {
  String? id;
  final DateTime? startDate;
  final DateTime? targetDate;
  final DateTime? endDate;
  final Duration? totalDuration;
  final int? total;
  final int? totalWrist;
  final int? totalSnap;
  final int? totalSlap;
  final int? totalBackhand;
  final bool? complete;
  final DateTime? udpatedAt;
  DocumentReference? reference;

  Iteration(this.startDate, this.targetDate, this.endDate, this.totalDuration, this.total, this.totalWrist, this.totalSnap, this.totalSlap, this.totalBackhand, this.complete, this.udpatedAt);

  Iteration.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['start_date'] != null),
        assert(map['total'] != null),
        id = map['id'],
        startDate = map['start_date']?.toDate(),
        targetDate = map['target_date']?.toDate(),
        endDate = map['end_date']?.toDate(),
        totalDuration = Duration(seconds: map['total_duration']),
        total = map['total'],
        totalWrist = map['total_wrist'],
        totalSnap = map['total_snap'],
        totalSlap = map['total_slap'],
        totalBackhand = map['total_backhand'],
        complete = map['complete'],
        udpatedAt = map['updated_at'] != null ? map['updated_at']?.toDate() : DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_date': startDate,
      'target_date': targetDate ??
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day + 100,
          ),
      'end_date': endDate,
      'total_duration': totalDuration!.inSeconds,
      'total': total,
      'total_wrist': totalWrist,
      'total_snap': totalSnap,
      'total_slap': totalSlap,
      'total_backhand': totalBackhand,
      'complete': complete,
      'updated_at': udpatedAt
    };
  }

  Iteration.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

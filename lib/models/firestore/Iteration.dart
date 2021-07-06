import 'package:cloud_firestore/cloud_firestore.dart';

class Iteration {
  String id;
  final DateTime startDate;
  final DateTime targetDate;
  final DateTime endDate;
  final Duration totalDuration;
  final int total;
  final int totalWrist;
  final int totalSnap;
  final int totalSlap;
  final int totalBackhand;
  final bool complete;
  DocumentReference reference;

  Iteration(this.startDate, this.targetDate, this.endDate, this.totalDuration, this.total, this.totalWrist, this.totalSnap, this.totalSlap, this.totalBackhand, this.complete);

  Iteration.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['start_date'] != null),
        assert(map['total'] != null),
        id = map['id'],
        startDate = map['start_date'] != null ? map['start_date'].toDate() : null,
        targetDate = map['target_date'] != null ? map['target_date'].toDate() : null,
        endDate = map['end_date'] != null ? map['end_date'].toDate() : null,
        totalDuration = Duration(seconds: map['total_duration']),
        total = map['total'],
        totalWrist = map['total_wrist'],
        totalSnap = map['total_snap'],
        totalSlap = map['total_slap'],
        totalBackhand = map['total_backhand'],
        complete = map['complete'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_date': startDate,
      'target_date': targetDate != null
          ? targetDate
          : DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day + 100,
            ),
      'end_date': endDate,
      'total_duration': totalDuration.inSeconds,
      'total': total,
      'total_wrist': totalWrist,
      'total_snap': totalSnap,
      'total_slap': totalSlap,
      'total_backhand': totalBackhand,
      'complete': complete,
    };
  }

  Iteration.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}

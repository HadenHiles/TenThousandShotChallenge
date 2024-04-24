import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  String? id;
  final DateTime? startDate;
  final DateTime? targetDate;
  final int? goalTotal;
  final bool? ownerParticipating;
  DocumentReference? reference;

  Team(this.startDate, this.targetDate, this.goalTotal, this.ownerParticipating);

  Team.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['start_date'] != null),
        assert(map['goal_total'] != null),
        assert(map['owner_participating'] != null),
        id = map['id'],
        startDate = map['start_date']?.toDate(),
        targetDate = map['target_date']?.toDate(),
        goalTotal = map['goal_total'],
        ownerParticipating = map['owner_participating'];

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
      'goal_total': goalTotal,
      'owner_participating': ownerParticipating
    };
  }

  Team.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

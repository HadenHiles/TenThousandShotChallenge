import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  String? id;
  final String? name;
  final DateTime? startDate;
  final DateTime? targetDate;
  final int? goalTotal;
  final bool? ownerParticipating;
  final bool? public;
  DocumentReference? reference;

  Team(this.name, this.startDate, this.targetDate, this.goalTotal, this.ownerParticipating, this.public);

  Team.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['start_date'] != null),
        assert(map['goal_total'] != null),
        assert(map['owner_participating'] != null),
        id = map['id'],
        name = map['name'],
        startDate = map['start_date']?.toDate(),
        targetDate = map['target_date']?.toDate(),
        goalTotal = map['goal_total'],
        ownerParticipating = map['owner_participating'],
        public = map['public'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_date': startDate,
      'target_date': targetDate ??
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day + 100,
          ),
      'goal_total': goalTotal,
      'owner_participating': ownerParticipating,
      'public': public
    };
  }

  Team.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

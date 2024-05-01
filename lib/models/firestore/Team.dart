import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  String? id;
  String? name;
  String? nameLowercase;
  final DateTime? startDate;
  final DateTime? targetDate;
  final int? goalTotal;
  final String? ownerId;
  final bool? ownerParticipating;
  bool? public;
  DocumentReference? reference;

  Team(this.name, this.startDate, this.targetDate, this.goalTotal, this.ownerId, this.ownerParticipating, this.public);

  Team.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['start_date'] != null),
        assert(map['goal_total'] != null),
        assert(map['owner_id'] != null),
        assert(map['owner_participating'] != null),
        id = map['id'],
        name = map['name'],
        nameLowercase = map['name_lowercase'],
        startDate = map['start_date']?.toDate(),
        targetDate = map['target_date']?.toDate(),
        goalTotal = map['goal_total'],
        ownerId = map['owner_id'],
        ownerParticipating = map['owner_participating'],
        public = map['public'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_lowercase': name!.toLowerCase(),
      'start_date': startDate,
      'target_date': targetDate ??
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day + 100,
          ),
      'goal_total': goalTotal,
      'owner_id': ownerId,
      'owner_participating': ownerParticipating,
      'public': public
    };
  }

  Team.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

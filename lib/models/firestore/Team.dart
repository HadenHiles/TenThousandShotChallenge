import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:word_generator/word_generator.dart';

class Team {
  String? id;
  String? code;
  String? name;
  String? nameLowercase;
  DateTime? startDate;
  DateTime? targetDate;
  final int? goalTotal;
  final String? ownerId;
  final bool? ownerParticipating;
  bool? public;
  List<String>? players;
  DocumentReference? reference;

  Team(this.name, this.startDate, this.targetDate, this.goalTotal, this.ownerId, this.ownerParticipating, this.public, this.players);

  Team.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['code'] != null),
        assert(map['start_date'] != null),
        assert(map['goal_total'] != null),
        assert(map['owner_id'] != null),
        assert(map['owner_participating'] != null),
        id = map['id'],
        code = map['code'],
        name = map['name'],
        nameLowercase = map['name_lowercase'],
        startDate = map['start_date']?.toDate(),
        targetDate = map['target_date']?.toDate(),
        goalTotal = map['goal_total'],
        ownerId = map['owner_id'],
        ownerParticipating = map['owner_participating'],
        public = map['public'],
        players = List<String>.from(map['players'] ?? [])..sort((a, b) => a.compareTo(b));

  Map<String, dynamic> toMap() {
    final wordGenerator = WordGenerator();
    String code = wordGenerator.randomNoun().toUpperCase() + wordGenerator.randomVerb().toUpperCase() + Random().nextInt(9999).toString().padLeft(4, '0');
    int id = DateTime.now().millisecondsSinceEpoch;

    return {
      'id': id,
      'code': code,
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
      'public': public,
      'players': players
    };
  }

  Team.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}

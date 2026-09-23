import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';

abstract final class TeamMembershipService {
  /// Repairs missing user-side membership fields from team player lists.
  ///
  /// Existing profile memberships remain in their current order because team
  /// removal flows clean them up separately. This method only restores links
  /// that are still confirmed by a team's `players` array.
  static Future<List<String>> reconcileUserMemberships({
    required String userId,
    required FirebaseFirestore firestore,
  }) async {
    final userReference = firestore.collection('users').doc(userId);
    final results = await Future.wait([
      userReference.get(),
      firestore.collection('teams').where('players', arrayContains: userId).get(),
    ]);

    final userSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final teamSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
    if (!userSnapshot.exists) return const [];

    final profile = UserProfile.fromSnapshot(userSnapshot);
    final reconciledTeamIds = List<String>.of(profile.teamIds);
    for (final teamDocument in teamSnapshot.docs) {
      if (!reconciledTeamIds.contains(teamDocument.id)) {
        reconciledTeamIds.add(teamDocument.id);
      }
    }

    final data = userSnapshot.data()!;
    final primaryTeamId = reconciledTeamIds.isEmpty ? null : reconciledTeamIds.first;
    final hasCanonicalTeamIds = data['team_ids'] is List && listEquals(List<String>.from(data['team_ids'] as List), reconciledTeamIds);
    if (!hasCanonicalTeamIds || data['team_id'] != primaryTeamId) {
      await userReference.set({
        'team_ids': reconciledTeamIds,
        'team_id': primaryTeamId,
      }, SetOptions(merge: true));
    }

    return reconciledTeamIds;
  }
}

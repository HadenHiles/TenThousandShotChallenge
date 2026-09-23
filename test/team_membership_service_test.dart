import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/services/TeamMembershipService.dart';

void main() {
  group('TeamMembershipService', () {
    test('restores a missing user team from the team players list', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('user-1').set({
        'display_name': 'Returning Player',
        'email': 'player@example.com',
      });
      await firestore.collection('teams').doc('team-1').set({
        'name': 'Test Team',
        'players': ['user-1'],
      });
      await firestore.collection('teams').doc('other-team').set({
        'name': 'Other Team',
        'players': ['user-2'],
      });

      final teamIds = await TeamMembershipService.reconcileUserMemberships(
        userId: 'user-1',
        firestore: firestore,
      );

      final user = (await firestore.collection('users').doc('user-1').get()).data()!;
      expect(teamIds, ['team-1']);
      expect(user['team_ids'], ['team-1']);
      expect(user['team_id'], 'team-1');
      expect(user['display_name'], 'Returning Player');
    });

    test('preserves a legacy primary team and adds other confirmed teams', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('user-1').set({
        'team_id': 'legacy-team',
      });
      await firestore.collection('teams').doc('legacy-team').set({
        'players': ['user-1'],
      });
      await firestore.collection('teams').doc('second-team').set({
        'players': ['user-1'],
      });

      final teamIds = await TeamMembershipService.reconcileUserMemberships(
        userId: 'user-1',
        firestore: firestore,
      );

      final user = (await firestore.collection('users').doc('user-1').get()).data()!;
      expect(teamIds.first, 'legacy-team');
      expect(teamIds, containsAll(['legacy-team', 'second-team']));
      expect(user['team_ids'], teamIds);
      expect(user['team_id'], 'legacy-team');
    });

    test('does not create an incomplete profile for a missing user document', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('teams').doc('team-1').set({
        'players': ['user-1'],
      });

      final teamIds = await TeamMembershipService.reconcileUserMemberships(
        userId: 'user-1',
        firestore: firestore,
      );

      expect(teamIds, isEmpty);
      expect((await firestore.collection('users').doc('user-1').get()).exists, isFalse);
    });
  });
}

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/Invite.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:firebase_core/firebase_core.dart';

bool get isIntegrationTest => Platform.environment['FLUTTER_TEST'] != 'true' && Platform.environment['USE_FIREBASE_EMULATOR'] == 'true';

void main() {
  group('Firestore Integration Tests', () {
    late FirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late MockUser mockUser;

    setUp(() async {
      if (isIntegrationTest) {
        await Firebase.initializeApp();
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        firestore = FirebaseFirestore.instance;
      } else {
        firestore = FakeFirebaseFirestore();
      }
      mockUser = MockUser(
        uid: 'test_user_1',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      auth = MockFirebaseAuth(mockUser: mockUser);

      // Ensure user is signed in
      await auth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password',
      );
    });

    group('User Profile Management', () {
      test('should create user profile correctly', () async {
        final userProfile = UserProfile(
          'Test User',
          'test@example.com',
          'https://example.com/avatar.jpg',
          true,
          true,
          null,
          'fcm_token_123',
        );

        await firestore.collection('users').doc('test_user_1').set(userProfile.toMap());

        final doc = await firestore.collection('users').doc('test_user_1').get();
        expect(doc.exists, true);

        final retrievedProfile = UserProfile.fromSnapshot(doc);
        expect(retrievedProfile.displayName, 'Test User');
        expect(retrievedProfile.email, 'test@example.com');
        expect(retrievedProfile.public, true);
        expect(retrievedProfile.friendNotifications, true);
      });

      test('should update user profile settings', () async {
        // Create initial profile
        await firestore.collection('users').doc('test_user_1').set({
          'display_name': 'Old Name',
          'email': 'test@example.com',
          'public': false,
          'friend_notifications': false,
        });

        // Update profile
        await firestore.collection('users').doc('test_user_1').update({
          'display_name': 'New Name',
          'public': true,
          'friend_notifications': true,
        });

        final doc = await firestore.collection('users').doc('test_user_1').get();
        final profile = UserProfile.fromSnapshot(doc);

        expect(profile.displayName, 'New Name');
        expect(profile.public, true);
        expect(profile.friendNotifications, true);
      });

      test('should handle user search by display name', () async {
        // Setup test users
        await firestore.collection('users').doc('user1').set({
          'display_name': 'John Smith',
          'display_name_lowercase': 'john smith',
          'email': 'john@example.com',
          'public': true,
        });

        await firestore.collection('users').doc('user2').set({
          'display_name': 'Jane Doe',
          'display_name_lowercase': 'jane doe',
          'email': 'jane@example.com',
          'public': true,
        });

        // Search for users starting with "john"
        final query = await firestore.collection('users').where('public', isEqualTo: true).orderBy('display_name_lowercase').startAt(['john']).endAt(['john\uf8ff']).get();

        expect(query.docs.length, 1);
        expect(query.docs.first.data()['display_name'], 'John Smith');
      });
    });

    group('Shooting Sessions and Shot Tracking', () {
      test('should save shooting session with shots correctly', () async {
        // Setup iteration
        await _setupTestIteration(firestore, 'test_user_1');

        // Create test shots
        final shots = [
          Shots(DateTime.now(), 'wrist', 25, 20),
          Shots(DateTime.now(), 'snap', 15, 12),
          Shots(DateTime.now(), 'slap', 10, 8),
        ];

        // Save shooting session
        final result = await saveShootingSession(shots, auth, firestore);
        expect(result, true);

        // Verify session was saved
        final iterationsQuery = await firestore.collection('iterations').doc('test_user_1').collection('iterations').get();

        expect(iterationsQuery.docs.isNotEmpty, true);

        final sessionsQuery = await iterationsQuery.docs.first.reference.collection('sessions').get();

        expect(sessionsQuery.docs.isNotEmpty, true);

        final session = ShootingSession.fromSnapshot(sessionsQuery.docs.first);
        expect(session.total, 50);
        expect(session.totalWrist, 25);
        expect(session.totalSnap, 15);
        expect(session.totalSlap, 10);
        expect(session.wristTargetsHit, 20);
        expect(session.snapTargetsHit, 12);
        expect(session.slapTargetsHit, 8);
      });

      test('should update iteration totals when saving sessions', () async {
        await _setupTestIteration(firestore, 'test_user_1');

        // Save first session
        final shots1 = [Shots(DateTime.now(), 'wrist', 25, 20)];
        await saveShootingSession(shots1, auth, firestore);

        // Save second session
        final shots2 = [Shots(DateTime.now(), 'snap', 30, 25)];
        await saveShootingSession(shots2, auth, firestore);

        // Check iteration totals
        final iterationsQuery = await firestore.collection('iterations').doc('test_user_1').collection('iterations').get();

        final iteration = Iteration.fromSnapshot(iterationsQuery.docs.first);
        expect(iteration.total, 55); // 25 + 30
        expect(iteration.totalWrist, 25);
        expect(iteration.totalSnap, 30);
      });

      test('should save individual shots in subcollection', () async {
        await _setupTestIteration(firestore, 'test_user_1');

        final shots = [
          Shots(DateTime.now(), 'wrist', 25, 20),
          Shots(DateTime.now(), 'snap', 15, 12),
        ];

        await saveShootingSession(shots, auth, firestore);

        // Verify shots subcollection
        final iterationsQuery = await firestore.collection('iterations').doc('test_user_1').collection('iterations').get();

        final sessionsQuery = await iterationsQuery.docs.first.reference.collection('sessions').get();

        final shotsQuery = await sessionsQuery.docs.first.reference.collection('shots').get();

        expect(shotsQuery.docs.length, 2);

        final shotTypes = shotsQuery.docs.map((doc) => doc.data()['type']).toList();
        expect(shotTypes, containsAll(['wrist', 'snap']));
      });
    });

    group('Team Management', () {
      test('should create team correctly', () async {
        final team = Team(
          'Test Team',
          DateTime.now(),
          DateTime.now().add(Duration(days: 100)),
          10000,
          'test_user_1',
          true,
          true,
          ['test_user_1'],
        );

        await firestore.collection('teams').doc('team_1').set(team.toMap());

        final doc = await firestore.collection('teams').doc('team_1').get();
        final retrievedTeam = Team.fromSnapshot(doc);

        expect(retrievedTeam.name, 'Test Team');
        expect(retrievedTeam.ownerId, 'test_user_1');
        expect(retrievedTeam.goalTotal, 10000);
        expect(retrievedTeam.players, contains('test_user_1'));
      });

      test('should add player to team', () async {
        // Create team
        await firestore.collection('teams').doc('team_1').set({
          'name': 'Test Team',
          'code': 'TEST123',
          'start_date': Timestamp.now(),
          'goal_total': 10000,
          'owner_id': 'test_user_1',
          'owner_participating': true,
          'public': true,
          'players': ['test_user_1'],
        });

        // Add player to team
        await firestore.collection('teams').doc('team_1').update({
          'players': FieldValue.arrayUnion(['test_user_2'])
        });

        final doc = await firestore.collection('teams').doc('team_1').get();
        final team = Team.fromSnapshot(doc);

        expect(team.players, contains('test_user_1'));
        expect(team.players, contains('test_user_2'));
        expect(team.players!.length, 2);
      });

      test('should update user team association', () async {
        // Create user profile
        await firestore.collection('users').doc('test_user_1').set({
          'display_name': 'Test User',
          'email': 'test@example.com',
          'team_id': null,
        });

        // Update user with team
        await firestore.collection('users').doc('test_user_1').update({'team_id': 'team_1'});

        final doc = await firestore.collection('users').doc('test_user_1').get();
        final user = UserProfile.fromSnapshot(doc);

        expect(user.teamId, 'team_1');
      });
    });

    group('Friend Invitations and Management', () {
      test('should send friend invitation', () async {
        // Setup users
        await _setupTestUsers(firestore);

        final result = await inviteFriend('test_user_1', 'test_user_2', firestore);
        expect(result, true);

        // Verify invite was created
        final inviteDoc = await firestore.collection('invites').doc('test_user_2').collection('invites').doc('test_user_1').get();

        expect(inviteDoc.exists, true);

        final invite = Invite.fromSnapshot(inviteDoc);
        expect(invite.fromUid, 'test_user_1');
      });

      test('should accept friend invitation', () async {
        await _setupTestUsers(firestore);

        // Create invitation
        final invite = Invite('test_user_1', DateTime.now());
        await firestore.collection('invites').doc('test_user_2').collection('invites').doc('test_user_1').set(invite.toMap());

        // Create signed-in auth for test_user_2
        final user2Auth = MockFirebaseAuth(mockUser: MockUser(uid: 'test_user_2'));
        await user2Auth.signInWithEmailAndPassword(email: 'test2@example.com', password: 'password');

        // Accept invitation
        final result = await acceptInvite(invite, user2Auth, firestore);
        expect(result, true);

        // Verify friendship was created
        final friend1Doc = await firestore.collection('teammates').doc('test_user_2').collection('teammates').doc('test_user_1').get();

        final friend2Doc = await firestore.collection('teammates').doc('test_user_1').collection('teammates').doc('test_user_2').get();

        expect(friend1Doc.exists, true);
        expect(friend2Doc.exists, true);

        // Verify invitation was deleted
        final inviteDoc = await firestore.collection('invites').doc('test_user_2').collection('invites').doc('test_user_1').get();

        expect(inviteDoc.exists, false);
      });

      test('should prevent duplicate friend invitations', () async {
        await _setupTestUsers(firestore);

        // Send first invitation
        await inviteFriend('test_user_1', 'test_user_2', firestore);

        // Try to send duplicate invitation
        final result = await inviteFriend('test_user_1', 'test_user_2', firestore);
        expect(result, true); // Should not create duplicate

        // Verify only one invitation exists
        final invitesQuery = await firestore.collection('invites').doc('test_user_2').collection('invites').get();

        expect(invitesQuery.docs.length, 1);
      });

      test('should delete friend invitation', () async {
        await _setupTestUsers(firestore);

        // Create invitation
        final invite = Invite('test_user_1', DateTime.now());
        await firestore.collection('invites').doc('test_user_2').collection('invites').doc('test_user_1').set(invite.toMap());

        // Create signed-in auth for test_user_2
        final user2Auth = MockFirebaseAuth(mockUser: MockUser(uid: 'test_user_2'));
        await user2Auth.signInWithEmailAndPassword(email: 'test2@example.com', password: 'password');

        // Delete invitation
        final result = await deleteInvite('test_user_1', 'test_user_2', user2Auth, firestore);
        expect(result, true);

        // Verify invitation was deleted
        final inviteDoc = await firestore.collection('invites').doc('test_user_2').collection('invites').doc('test_user_1').get();

        expect(inviteDoc.exists, false);
      });
    });

    group('Data Integrity and Edge Cases', () {
      test('should handle missing iteration gracefully', () async {
        // Try to save session without iteration
        final shots = [Shots(DateTime.now(), 'wrist', 25, 20)];

        // This should create a new iteration
        final result = await saveShootingSession(shots, auth, firestore);
        expect(result, true);

        // Verify new iteration was created
        final iterationsQuery = await firestore.collection('iterations').doc('test_user_1').collection('iterations').get();

        expect(iterationsQuery.docs.isNotEmpty, true);
      });

      test('should handle session deletion correctly', () async {
        await _setupTestIteration(firestore, 'test_user_1');

        // Create and save session
        final shots = [Shots(DateTime.now(), 'wrist', 25, 20)];
        await saveShootingSession(shots, auth, firestore);

        // Get the session to delete
        final iterationsQuery = await firestore.collection('iterations').doc('test_user_1').collection('iterations').get();

        final sessionsQuery = await iterationsQuery.docs.first.reference.collection('sessions').get();

        final session = ShootingSession.fromSnapshot(sessionsQuery.docs.first);
        session.reference = sessionsQuery.docs.first.reference;

        // Delete session
        final result = await deleteSession(session, auth, firestore);
        expect(result, true);

        // Verify session was deleted
        final updatedSessionsQuery = await iterationsQuery.docs.first.reference.collection('sessions').get();

        expect(updatedSessionsQuery.docs.isEmpty, true);
      });

      test('should validate shot type constraints', () async {
        final validShotTypes = ['wrist', 'snap', 'slap', 'backhand'];

        for (final shotType in validShotTypes) {
          final shot = Shots(DateTime.now(), shotType, 25, 20);
          expect(shot.type, shotType);
          expect(shot.count, 25);
          expect(shot.targetsHit, 20);
        }
      });

      test('should handle accuracy tracking for pro users', () async {
        await _setupTestIteration(firestore, 'test_user_1');

        // Test shots with accuracy data
        final shots = [
          Shots(DateTime.now(), 'wrist', 25, 20), // 80% accuracy
          Shots(DateTime.now(), 'snap', 20, 15), // 75% accuracy
        ];

        await saveShootingSession(shots, auth, firestore);

        // Verify accuracy data was saved
        final iterationsQuery = await firestore.collection('iterations').doc('test_user_1').collection('iterations').get();

        final sessionsQuery = await iterationsQuery.docs.first.reference.collection('sessions').get();

        final session = ShootingSession.fromSnapshot(sessionsQuery.docs.first);
        expect(session.wristTargetsHit, 20);
        expect(session.snapTargetsHit, 15);

        // Verify individual shot accuracy
        final shotsQuery = await sessionsQuery.docs.first.reference.collection('shots').get();

        for (final shotDoc in shotsQuery.docs) {
          final shot = Shots.fromSnapshot(shotDoc);
          expect(shot.targetsHit, isNotNull);
          expect(shot.targetsHit! <= shot.count!, true);
        }
      });
    });

    group('Performance and Scalability Tests', () {
      test('should handle large number of shots efficiently', () async {
        await _setupTestIteration(firestore, 'test_user_1');

        // Create a large session with many shots
        final shots = <Shots>[];
        for (int i = 0; i < 100; i++) {
          shots.add(Shots(DateTime.now(), 'wrist', 10, 8));
        }

        final stopwatch = Stopwatch()..start();
        final result = await saveShootingSession(shots, auth, firestore);
        stopwatch.stop();

        expect(result, true);
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete in under 5 seconds
      });

      test('should handle multiple concurrent sessions', () async {
        await _setupTestIteration(firestore, 'test_user_1');

        // Create multiple sessions concurrently
        final futures = <Future>[];
        for (int i = 0; i < 5; i++) {
          final shots = [Shots(DateTime.now(), 'wrist', 10, 8)];
          futures.add(saveShootingSession(shots, auth, firestore));
        }

        final results = await Future.wait(futures);
        expect(results.every((result) => result == true), true);

        // Verify all sessions were saved
        final iterationsQuery = await firestore.collection('iterations').doc('test_user_1').collection('iterations').get();

        final sessionsQuery = await iterationsQuery.docs.first.reference.collection('sessions').get();

        expect(sessionsQuery.docs.length, 5);
      });
    });
  });
}

// Helper functions
Future<void> _setupTestIteration(FirebaseFirestore firestore, String uid) async {
  final iteration = Iteration(
    DateTime.now(),
    DateTime.now().add(Duration(days: 100)),
    null,
    Duration.zero,
    0,
    0,
    0,
    0,
    0,
    false,
    DateTime.now(),
  );

  await firestore.collection('iterations').doc(uid).collection('iterations').add(iteration.toMap());
}

Future<void> _setupTestUsers(FirebaseFirestore firestore) async {
  await firestore.collection('users').doc('test_user_1').set({
    'display_name': 'Test User 1',
    'email': 'test1@example.com',
    'public': true,
    'fcm_token': 'token1',
  });

  await firestore.collection('users').doc('test_user_2').set({
    'display_name': 'Test User 2',
    'email': 'test2@example.com',
    'public': true,
    'fcm_token': 'token2',
  });
}

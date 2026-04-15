import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/tabs/friends/CompareStats.dart';
import '../mock_firebase.dart';

void main() {
  group('CompareStats widget', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUpAll(() async {
      await setupFirebaseAuthMocks();
    });

    setUp(() async {
      mockUser = MockUser(uid: 'me_uid', displayName: 'Me', email: 'me@test.com');
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      await mockAuth.signInWithEmailAndPassword(email: 'me@test.com', password: 'pw');
      fakeFirestore = FakeFirebaseFirestore();

      // Seed current user profile
      await fakeFirestore.collection('users').doc('me_uid').set({
        'id': 'me_uid',
        'display_name': 'Me',
        'email': 'me@test.com',
        'photo_url': null,
        'public': true,
        'friend_notifications': true,
        'team_id': null,
        'fcm_token': null,
      });

      // Seed friend user profile
      await fakeFirestore.collection('users').doc('friend_uid').set({
        'id': 'friend_uid',
        'display_name': 'Friend',
        'email': 'friend@test.com',
        'photo_url': null,
        'public': true,
        'friend_notifications': true,
        'team_id': null,
        'fcm_token': null,
      });

      // Seed some shots for me
      final myIter = await fakeFirestore.collection('iterations').doc('me_uid').collection('iterations').add({'complete': false});
      await myIter.collection('sessions').add({
        'date': Timestamp.fromDate(DateTime.now()),
        'total': 300,
        'total_wrist': 150,
        'total_snap': 100,
        'total_slap': 50,
        'total_backhand': 0,
        'wrist_targets_hit': 90,
        'snap_targets_hit': 60,
        'slap_targets_hit': 30,
        'backhand_targets_hit': 0,
      });

      // Seed some shots for friend
      final friendIter = await fakeFirestore.collection('iterations').doc('friend_uid').collection('iterations').add({'complete': false});
      await friendIter.collection('sessions').add({
        'date': Timestamp.fromDate(DateTime.now()),
        'total': 500,
        'total_wrist': 200,
        'total_snap': 150,
        'total_slap': 100,
        'total_backhand': 50,
        'wrist_targets_hit': 120,
        'snap_targets_hit': 80,
        'slap_targets_hit': 60,
        'backhand_targets_hit': 20,
      });
    });

    Widget buildWidget({String friendUid = 'friend_uid'}) {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: MaterialApp(
          home: CompareStats(friendUid: friendUid),
        ),
      );
    }

    testWidgets('renders CompareStats without crashing', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byType(CompareStats), findsOneWidget);
    });

    testWidgets('shows both display names after load', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.textContaining('Me', findRichText: true), findsWidgets);
      expect(find.textContaining('Friend', findRichText: true), findsWidgets);
    });

    testWidgets('shows Total Shots label after load', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.textContaining('Total Shots', findRichText: true), findsOneWidget);
    });

    testWidgets('shows AppBar title COMPARE STATS', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.textContaining('COMPARE STATS', findRichText: true), findsOneWidget);
    });
  });
}

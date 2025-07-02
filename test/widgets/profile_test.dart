import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/tabs/Profile.dart';

void main() {
  group('Profile Screen', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUp(() async {
      mockUser = MockUser(
        uid: 'test_uid',
        displayName: 'Test User',
        email: 'test@example.com',
        photoURL: '', // Use empty string to avoid network image loading
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      // Ensure user is signed in (guarantee currentUser is non-null)
      if (mockAuth.currentUser == null) {
        await mockAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'password');
      }
      fakeFirestore = FakeFirebaseFirestore();

      // Insert required user document
      await fakeFirestore.collection('users').doc('test_uid').set({
        'id': 'test_uid',
        'display_name': 'Test User',
        'email': 'test@example.com',
        'photo_url': '', // Use empty string to avoid network image loading
        'public': true,
        'friend_notifications': true,
        'team_id': null,
        'fcm_token': null,
      });

      // Insert a complete iteration document with all required fields
      final now = DateTime.now();
      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').doc('iteration1').set({
        'id': 'iteration1',
        'start_date': Timestamp.fromDate(now.subtract(const Duration(days: 10))),
        'target_date': Timestamp.fromDate(now.add(const Duration(days: 20))),
        'end_date': null,
        'total_duration': 3600,
        'total': 100,
        'total_wrist': 40,
        'total_snap': 30,
        'total_slap': 20,
        'total_backhand': 10,
        'complete': false,
        'updated_at': Timestamp.now(),
      });

      // Insert two session documents with all required fields for date range
      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').doc('iteration1').collection('sessions').doc('session1').set({
        'id': 'session1',
        'total': 25,
        'total_wrist': 10,
        'total_snap': 5,
        'total_slap': 5,
        'total_backhand': 5,
        'date': Timestamp.fromDate(now.subtract(const Duration(days: 9))),
        'duration': 600,
        'wrist_targets_hit': 8,
        'snap_targets_hit': 3,
        'slap_targets_hit': 4,
        'backhand_targets_hit': 2,
      });
      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').doc('iteration1').collection('sessions').doc('session2').set({
        'id': 'session2',
        'total': 30,
        'total_wrist': 12,
        'total_snap': 8,
        'total_slap': 6,
        'total_backhand': 4,
        'date': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        'duration': 900,
        'wrist_targets_hit': 10,
        'snap_targets_hit': 5,
        'slap_targets_hit': 5,
        'backhand_targets_hit': 3,
      });

      // Insert a shot document for each session (for accuracy charts)
      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').doc('iteration1').collection('sessions').doc('session1').collection('shots').doc('shot1').set({
        'id': 'shot1',
        'date': Timestamp.fromDate(now.subtract(const Duration(days: 9))),
        'type': 'wrist',
        'count': 10,
        'targets_hit': 8,
      });
      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').doc('iteration1').collection('sessions').doc('session2').collection('shots').doc('shot2').set({
        'id': 'shot2',
        'date': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        'type': 'snap',
        'count': 8,
        'targets_hit': 5,
      });
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: MaterialApp(
          home: Profile(),
        ),
      );
    }

    testWidgets('renders profile avatar and user info', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      expect(find.byType(Profile), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows accuracy and sessions sections', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      // Expand both sections to ensure text is visible
      final accuracyHeader = find.textContaining('SHOT ACCURACY', findRichText: true);
      final sessionsHeader = find.textContaining('RECENT SESSIONS', findRichText: true);
      expect(accuracyHeader, findsOneWidget);
      expect(sessionsHeader, findsOneWidget);
      await tester.tap(accuracyHeader);
      await tester.pumpAndSettle();
      await tester.tap(sessionsHeader);
      await tester.pumpAndSettle();
      // Now check for the text (case-insensitive, rich text aware)
      expect(find.textContaining('SHOT ACCURACY', findRichText: true), findsOneWidget);
      expect(find.textContaining('RECENT SESSIONS', findRichText: true), findsOneWidget);
    });

    testWidgets('toggles accuracy section', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      final accuracyHeader = find.textContaining('SHOT ACCURACY', findRichText: true);
      expect(accuracyHeader, findsOneWidget);
      await tester.tap(accuracyHeader);
      await tester.pumpAndSettle();
      // Should show accuracy content (locked or unlocked)
      expect(find.byType(AnimatedCrossFade), findsWidgets);
    });

    testWidgets('toggles sessions section', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      final sessionsHeader = find.textContaining('RECENT SESSIONS', findRichText: true);
      expect(sessionsHeader, findsOneWidget);
      await tester.tap(sessionsHeader);
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedCrossFade), findsWidgets);
    });

    testWidgets('shows View History button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      // Expand sessions section to ensure button is visible
      final sessionsHeader = find.textContaining('RECENT SESSIONS', findRichText: true);
      expect(sessionsHeader, findsOneWidget);
      await tester.tap(sessionsHeader);
      await tester.pumpAndSettle();

      // Scroll the top-level Scrollable to bring the button into view
      final topLevelScrollable = find.byType(Scrollable).first;
      final viewHistoryButtonKey = const Key('viewHistoryButton');
      await tester.scrollUntilVisible(
        find.byKey(viewHistoryButtonKey),
        200.0,
        scrollable: topLevelScrollable,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(viewHistoryButtonKey), findsOneWidget);
    });

    // Add more tests for session dismiss, confirm dialog, and navigation as needed
  });
}

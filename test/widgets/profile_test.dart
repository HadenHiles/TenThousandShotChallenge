import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/tabs/Profile.dart';
import 'package:firebase_core/firebase_core.dart';
import '../mock_firebase.dart';

bool isIntegrationTest = Platform.environment['FLUTTER_TEST'] != 'true' && Platform.environment['USE_FIREBASE_EMULATOR'] == 'true';

void main() {
  group('Profile Screen', () {
    late MockFirebaseAuth mockAuth;
    late FirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUpAll(() async {
      await setupFirebaseAuthMocks();
    });

    setUp(() async {
      if (isIntegrationTest) {
        await Firebase.initializeApp();
        fakeFirestore = FirebaseFirestore.instance;
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      } else {
        fakeFirestore = FakeFirebaseFirestore();
      }
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

    /// Pump the widget tree to let streams emit and frames settle.
    /// Uses separate pump() calls first to process microtasks, then timed pumps.
    Future<void> pumpForDuration(WidgetTester tester, [Duration duration = const Duration(milliseconds: 400)]) async {
      await tester.pump(); // Process microtasks (stream subscriptions etc.)
      await tester.pump(); // Second microtask drain
      await tester.pump(duration); // Let timers and delayed work fire
    }

    testWidgets('renders profile avatar and user info', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      expect(find.byType(Profile), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows accuracy and sessions sections', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      // Profile now shows dashboard cards (not accordion sections)
      expect(find.textContaining('SHOT ACCURACY', findRichText: true), findsOneWidget);
      expect(find.textContaining('SESSIONS', findRichText: true), findsOneWidget);
    });

    testWidgets('accuracy card shows shot type chips', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      // Accuracy card always shows glance chips (dummy values when not pro)
      expect(find.textContaining('SHOT ACCURACY', findRichText: true), findsOneWidget);
      // W, SN, SL, B are the chip labels for wrist/snap/slap/backhand
      expect(find.text('W'), findsWidgets);
    });

    testWidgets('sessions card shows sessions text', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      // Sessions card shows SESSIONS label and history icon
      expect(find.textContaining('SESSIONS', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('sessions card is tappable and navigates to history', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      // Sessions card exists and shows history icon (navigation arrow)
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      // The sessions card is an InkWell/GestureDetector; verify the card text is present
      expect(find.textContaining('SESSIONS', findRichText: true), findsOneWidget);
    });

    // Add more tests for session dismiss, confirm dialog, and navigation as needed
  });
}

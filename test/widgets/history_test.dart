import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/tabs/profile/History.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/main.dart' as main_globals;
import '../mock_firebase.dart';

void main() {
  group('History Screen', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUpAll(() async {
      NetworkStatusService.isTestingOverride = true;
      await setupFirebaseAuthMocks();
      main_globals.preferences = Preferences(
        false,
        25,
        true,
        DateTime.now().add(const Duration(days: 100)),
        null,
      );
    });

    setUp(() async {
      mockUser = MockUser(
        uid: 'test_uid',
        displayName: 'Test User',
        email: 'test@example.com',
        photoURL: '',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      if (mockAuth.currentUser == null) {
        await mockAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'password');
      }

      fakeFirestore = FakeFirebaseFirestore();

      final now = DateTime.now();
      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').doc('iteration1').set({
        'id': 'iteration1',
        'start_date': Timestamp.fromDate(now.subtract(const Duration(days: 20))),
        'target_date': Timestamp.fromDate(now.add(const Duration(days: 10))),
        'end_date': null,
        'total_duration': 5400,
        'total': 200,
        'total_wrist': 80,
        'total_snap': 60,
        'total_slap': 40,
        'total_backhand': 20,
        'complete': false,
        'updated_at': Timestamp.now(),
      });

      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').doc('iteration1').collection('sessions').doc('session1').set({
        'id': 'session1',
        'total': 50,
        'total_wrist': 20,
        'total_snap': 15,
        'total_slap': 10,
        'total_backhand': 5,
        'date': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
        'duration': 900,
        'wrist_targets_hit': 15,
        'snap_targets_hit': 10,
        'slap_targets_hit': 8,
        'backhand_targets_hit': 3,
      });
    });

    Widget createWidgetUnderTest({String? initialIterationId}) {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: MaterialApp(
          home: History(
            sessionPanelController: PanelController(),
            initialIterationId: initialIterationId,
          ),
        ),
      );
    }

    // Do NOT use tester.pump(duration) — advancing fake timers fires Firestore/rxdart
    // stream callbacks that create an infinite microtask chain at teardown.
    Future<void> pump(WidgetTester tester, [int times = 3]) async {
      for (int i = 0; i < times; i++) {
        await tester.pump();
      }
    }

    /// Runs a test body while suppressing layout overflow and Firebase errors.
    Future<void> runTest(WidgetTester tester, Widget widget, Future<void> Function() body) async {
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final msg = details.exception.toString();
        if (msg.contains('RenderFlex overflowed') || msg.contains('FirebaseException') || msg.contains('No Firebase App')) return;
        FlutterError.dumpErrorToConsole(details);
      };
      try {
        await tester.pumpWidget(widget);
        await body();
      } finally {
        FlutterError.onError = oldOnError;
      }
    }

    testWidgets('renders History screen', (WidgetTester tester) async {
      await runTest(tester, createWidgetUnderTest(), () async {
        await pump(tester);
        expect(find.byType(History), findsOneWidget);
      });
    });

    testWidgets('shows SHOOTING HISTORY title', (WidgetTester tester) async {
      await runTest(tester, createWidgetUnderTest(), () async {
        await pump(tester);
        expect(find.textContaining('SHOOTING HISTORY', findRichText: true), findsOneWidget);
      });
    });

    testWidgets('shows iteration dropdown with data', (WidgetTester tester) async {
      await runTest(tester, createWidgetUnderTest(), () async {
        await pump(tester);
        expect(find.byType(DropdownButton<String>), findsOneWidget);
      });
    });

    testWidgets('shows challenge label in dropdown after stream loads', (WidgetTester tester) async {
      await runTest(tester, createWidgetUnderTest(), () async {
        await pump(tester, 4);
        expect(find.textContaining('challenge', findRichText: true), findsWidgets);
      });
    });

    testWidgets('shows History widget when initialIterationId provided', (WidgetTester tester) async {
      await runTest(tester, createWidgetUnderTest(initialIterationId: 'iteration1'), () async {
        await pump(tester, 4);
        expect(find.byType(History), findsOneWidget);
      });
    });
  });
}

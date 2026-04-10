import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/tabs/Shots.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/main.dart' as main_globals;
import 'package:firebase_core/firebase_core.dart';

import 'shots_test.mocks.dart';
import '../mock_firebase.dart';

// Generate mocks
@GenerateMocks([
  SessionService,
  PanelController,
])
void main() {
  group('Shots Screen', () {
    late MockFirebaseAuth mockAuth;
    late FirebaseFirestore fakeFirestore;
    late MockUser mockUser;
    late MockSessionService mockSessionService;
    late MockPanelController mockPanelController;

    setUpAll(() async {
      // Set up global preferences mock
      main_globals.preferences = Preferences(false, 25, true, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100), null);

      // Initialize Firebase for widgets that use FirebaseFirestore.instance directly
      await setupFirebaseAuthMocks();
    });

    final bool isIntegrationTest = Platform.environment['FLUTTER_TEST'] != 'true' && Platform.environment['USE_FIREBASE_EMULATOR'] == 'true';

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
        photoURL: '',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);

      // Ensure user is signed in
      if (mockAuth.currentUser == null) {
        await mockAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'password');
      }

      mockSessionService = MockSessionService();
      mockPanelController = MockPanelController();

      // Set up session service mocks with proper behavior
      when(mockSessionService.isRunning).thenReturn(false);
      when(mockSessionService.currentDuration).thenReturn(Duration.zero);
      when(mockSessionService.start()).thenReturn(null);
      when(mockSessionService.reset()).thenReturn(null);

      // Insert a complete iteration document with all required fields
      final now = DateTime.now();
      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').doc('iteration1').set({
        'id': 'iteration1',
        'start_date': Timestamp.fromDate(now.subtract(const Duration(days: 10))),
        'target_date': Timestamp.fromDate(now.add(const Duration(days: 30))),
        'end_date': null,
        'total_duration': 3600,
        'total': 150,
        'total_wrist': 60,
        'total_snap': 40,
        'total_slap': 30,
        'total_backhand': 20,
        'complete': false,
        'updated_at': Timestamp.now(),
      });
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SessionServiceProvider(
              service: mockSessionService,
              child: Shots(
                sessionPanelController: mockPanelController,
                resetSignal: 0,
              ),
            ),
          ),
        ),
      );
    }

    // Helper to run tests with overflow and Firebase error suppression.
    // Uses bounded pump calls instead of pumpAndSettle to avoid timeouts from
    // infinite Firestore streams in WeeklyAchievementsWidget / AchievementStatsRow.
    Future<void> runWithErrorSuppression(WidgetTester tester, Future<void> Function() testCode) async {
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final msg = details.exception.toString();
        if (msg.contains('RenderFlex overflowed') || msg.contains('FirebaseException') || msg.contains('No Firebase App')) {
          return; // Ignore known non-critical errors during widget tests
        }
        oldOnError?.call(details);
      };

      try {
        await tester.binding.setSurfaceSize(const Size(1200, 1600));
        await testCode();
      } finally {
        FlutterError.onError = oldOnError;
      }
    }

    /// Pump the widget tree to let streams emit and frames settle.
    /// Uses separate pump() calls first to process microtasks, then timed pumps.
    Future<void> pumpForDuration(WidgetTester tester, [Duration duration = const Duration(milliseconds: 400)]) async {
      await tester.pump(); // Process microtasks (stream subscriptions etc.)
      await tester.pump(); // Second microtask drain
      await tester.pump(duration); // Let timers and delayed work fire
    }

    testWidgets('renders shots screen correctly', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await pumpForDuration(tester);

        expect(find.byType(Shots), findsOneWidget);
        // The season overview card shows '10,000 Shot Challenge'
        expect(find.textContaining('10,000', findRichText: true), findsWidgets);
      });
    });

    testWidgets('displays basic UI elements', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await pumpForDuration(tester);

        // Should show the main challenge card
        expect(find.textContaining('10,000', findRichText: true), findsWidgets);

        // Should show progress section (progress bar is rendered)
        expect(find.byType(Stack), findsWidgets);
      });
    });

    testWidgets('displays shot counts and numbers', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await pumpForDuration(tester);

        // The fake iteration has 150 total shots; this should appear in the UI
        expect(find.textContaining('150', findRichText: true), findsWidgets);

        // 10,000 should appear (goal)
        expect(find.textContaining('10,000', findRichText: true), findsWidgets);
      });
    });

    testWidgets('displays start shooting button when session not running', (WidgetTester tester) async {
      when(mockSessionService.isRunning).thenReturn(false);

      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await pumpForDuration(tester);

        // START SHOOTING button should be visible at bottom
        expect(find.textContaining('START SHOOTING', findRichText: true), findsOneWidget);
      });
    });

    testWidgets('shot mix card shows shot type labels', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await pumpForDuration(tester);

        // Shot type labels appear in the shot mix breakdown card
        expect(find.textContaining('WRIST', findRichText: true), findsWidgets);
        expect(find.textContaining('SNAP', findRichText: true), findsWidgets);
        expect(find.textContaining('BACKHAND', findRichText: true), findsWidgets);
        expect(find.textContaining('SLAP', findRichText: true), findsWidgets);
      });
    });

    testWidgets('handles no iteration data gracefully', (WidgetTester tester) async {
      // Clear all iteration data
      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').get().then((snapshot) async {
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      });

      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await pumpForDuration(tester);

        // Should show default state without errors
        expect(find.byType(Shots), findsOneWidget);
        // Look for start shooting button which should appear when no data
        expect(find.textContaining("START SHOOTING", findRichText: true), findsWidgets);
      });
    });

    testWidgets('displays session service provider correctly', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await pumpForDuration(tester);

        // Should render without session service provider errors
        expect(find.byType(Shots), findsOneWidget);
        expect(find.byType(AnimatedBuilder), findsWidgets);
      });
    });

    testWidgets('shows various UI components', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await pumpForDuration(tester);

        // Should show colored containers for each shot type
        expect(find.byType(Container), findsWidgets);

        // Should show the shot breakdown chart area
        expect(find.byType(Stack), findsWidgets);

        // Should show icons
        expect(find.byType(Icon), findsWidgets);

        // Shot type indicators should be present
        expect(find.textContaining('W'), findsWidgets); // Wrist
        expect(find.textContaining('SN'), findsWidgets); // Snap
        expect(find.textContaining('B'), findsWidgets); // Backhand
        expect(find.textContaining('SL'), findsWidgets); // Slap
      });
    });
  });
}

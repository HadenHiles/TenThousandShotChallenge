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

    setUpAll(() {
      // Set up global preferences mock
      main_globals.preferences = Preferences(false, 25, true, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100), null);

      // Handle overflow errors during testing
      WidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() async {
      if (Platform.environment['USE_FIREBASE_EMULATOR'] == 'true') {
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
              child: Shots(sessionPanelController: mockPanelController),
            ),
          ),
        ),
      );
    }

    // Helper to run tests with overflow error suppression
    Future<void> runWithErrorSuppression(WidgetTester tester, Future<void> Function() testCode) async {
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exception.toString().contains('RenderFlex overflowed')) {
          return; // Ignore layout overflow errors
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

    testWidgets('renders shots screen correctly', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byType(Shots), findsOneWidget);
        expect(find.textContaining('GOAL', findRichText: true), findsOneWidget);
        expect(find.textContaining('PROGRESS', findRichText: true), findsOneWidget);
      });
    });

    testWidgets('displays basic UI elements', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Should show goal section
        expect(find.textContaining('GOAL', findRichText: true), findsOneWidget);

        // Should show shots per day/week toggle
        expect(find.byIcon(Icons.swap_vert), findsOneWidget);

        // Should show progress section
        expect(find.textContaining('PROGRESS', findRichText: true), findsOneWidget);
      });
    });

    testWidgets('displays shot counts and numbers', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Should show shot type labels (they appear multiple times, so use findsWidgets)
        expect(find.textContaining('WRIST', findRichText: true), findsWidgets);
        expect(find.textContaining('SNAP', findRichText: true), findsWidgets);
        expect(find.textContaining('BACKHAND', findRichText: true), findsWidgets);
        expect(find.textContaining('SLAP', findRichText: true), findsWidgets);

        // Should show progress numbers (150 appears, and 10,000 appears multiple times)
        expect(find.textContaining('150'), findsOneWidget);
        expect(find.textContaining('10,000'), findsWidgets);
      });
    });

    testWidgets('displays start shooting button when session not running', (WidgetTester tester) async {
      when(mockSessionService.isRunning).thenReturn(false);

      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.textContaining('START SHOOTING', findRichText: true), findsOneWidget);
        expect(find.byType(TextButton), findsWidgets);
      });
    });

    testWidgets('can interact with toggle button', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final swapButton = find.byIcon(Icons.swap_vert);
        expect(swapButton, findsOneWidget);

        await tester.tap(swapButton);
        await tester.pumpAndSettle();

        // Should still show the swap button (toggle functionality)
        expect(swapButton, findsOneWidget);
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
        await tester.pumpAndSettle();

        // Should show default state without errors
        expect(find.byType(Shots), findsOneWidget);
        // Look for start shooting button which should appear when no data
        expect(find.textContaining("START SHOOTING", findRichText: true), findsWidgets);
      });
    });

    testWidgets('displays session service provider correctly', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Should render without session service provider errors
        expect(find.byType(Shots), findsOneWidget);
        expect(find.byType(AnimatedBuilder), findsWidgets);
      });
    });

    testWidgets('shows various UI components', (WidgetTester tester) async {
      await runWithErrorSuppression(tester, () async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadAllClearScreen.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadBadgeAwardScreen.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadMapView.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadMilestoneScreen.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadTeaserView.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengeResultScreen.dart';
import '../mock_firebase.dart';

// ── Shared test fixtures ───────────────────────────────────────────────────

const _testBadge = ChallengerRoadBadgeDefinition(
  id: 'cr_first_steps',
  name: 'First Steps',
  description: 'You took your first step on the Challenger Road.',
  category: ChallengerRoadBadgeCategory.firstSteps,
  tier: ChallengerRoadBadgeTier.common,
);

final _testAttempt = ChallengerRoadAttempt(
  id: 'attempt_1',
  attemptNumber: 1,
  startingLevel: 1,
  currentLevel: 1,
  challengerRoadShotCount: 500,
  totalShotsThisAttempt: 500,
  resetCount: 0,
  highestLevelReachedThisAttempt: 1,
  status: 'active',
  startDate: DateTime(2024, 1, 1),
);

final _testChallenge = ChallengerRoadChallenge(
  id: 'challenge_1',
  level: 1,
  levelName: 'Level 1',
  sequence: 1,
  name: 'Wrist Shot Basics',
  description: 'Master the basics of the wrist shot.',
  shotsRequired: 50,
  shotsToPass: 35,
  active: true,
  steps: const [],
);

final _testLevelDoc = ChallengerRoadLevel(
  id: 'level_1',
  level: 1,
  levelName: 'Level 1',
  sequence: 1,
  shotsRequired: 50,
  shotsToPass: 35,
  active: true,
);

const _noMilestone = ChallengerRoadMilestoneResult(
  didHitMilestone: false,
  newCount: 500,
  resetCount: 0,
);

const _firstMilestone = ChallengerRoadMilestoneResult(
  didHitMilestone: true,
  newCount: 0,
  resetCount: 1,
);

ChallengeSession _makeSession({required bool passed}) {
  return ChallengeSession(
    challengeId: 'challenge_1',
    level: 1,
    date: DateTime(2024, 1, 1),
    duration: const Duration(minutes: 5),
    shotsRequired: 50,
    shotsToPass: 35,
    shotsMade: passed ? 40 : 10,
    totalShots: 50,
    passed: passed,
    shots: const [],
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Pump N times with no duration (safe for screens without repeating timers).
Future<void> pumpN(WidgetTester tester, [int times = 3]) async {
  for (int i = 0; i < times; i++) {
    await tester.pump();
  }
}

void main() {
  setUpAll(() async {
    await setupFirebaseAuthMocks();
    NetworkStatusService.isTestingOverride = true;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      if (msg.contains('FirebaseException') ||
          msg.contains('No Firebase App') ||
          msg.contains('RenderFlex overflowed') ||
          msg.contains('MissingPluginException') ||
          msg.contains('PlatformException') ||
          msg.contains('NetworkException') ||
          msg.contains('TimeoutException') ||
          msg.contains('video_player') ||
          msg.contains('LateInitializationError') ||
          msg.contains('Navigator')) {
        return;
      }
      FlutterError.dumpErrorToConsole(details);
    };
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 1 – ChallengerRoadAllClearScreen
  // Simple StatelessWidget, no Firebase or async deps.
  // ═══════════════════════════════════════════════════════════════════════════

  group('ChallengerRoadAllClearScreen', () {
    Widget buildScreen() => const MaterialApp(
          home: ChallengerRoadAllClearScreen(completedLevel: 1),
        );

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      expect(find.byType(ChallengerRoadAllClearScreen), findsOneWidget);
    });

    testWidgets('shows trophy icon', (tester) async {
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
    });

    testWidgets('shows level complete badge text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      expect(find.textContaining('LEVEL 1 COMPLETE', findRichText: true), findsOneWidget);
    });

    testWidgets('shows back to road CTA button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      expect(find.textContaining('BACK TO THE ROAD', findRichText: true), findsOneWidget);
    });

    testWidgets('shows completed road headline', (tester) async {
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      // Verifies the flagship copy is in the tree
      expect(find.textContaining("CONQUERED", findRichText: true), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 2 – ChallengerRoadBadgeAwardScreen
  // Has Future.delayed timers for animation sequencing; pump 2 seconds so all
  // animations (scale, text fade-in, button) finish before asserting.
  // ═══════════════════════════════════════════════════════════════════════════

  group('ChallengerRoadBadgeAwardScreen', () {
    Widget buildScreen({List<ChallengerRoadBadgeDefinition>? badges}) => MaterialApp(
          home: ChallengerRoadBadgeAwardScreen(badges: badges ?? [_testBadge]),
        );

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildScreen());
      // pump 2s so all Future.delayed animation timers fire and complete
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ChallengerRoadBadgeAwardScreen), findsOneWidget);
    });

    testWidgets('shows BADGE UNLOCKED label after animation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('BADGE UNLOCKED', findRichText: true), findsOneWidget);
    });

    testWidgets('shows badge name in uppercase after animation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 2));
      // _testBadge.name = 'First Steps' → rendered as 'FIRST STEPS'
      expect(find.textContaining('FIRST STEPS', findRichText: true), findsOneWidget);
    });

    testWidgets('shows COMMON tier label after animation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('COMMON', findRichText: true), findsOneWidget);
    });

    testWidgets('shows CTA button for single badge', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 2));
      // For a single (last) badge the button reads "LET'S KEEP GOING"
      expect(find.textContaining("LET'S KEEP GOING", findRichText: true), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 3 – ChallengerRoadMilestoneScreen
  // All animations are vsync-driven (no Future.delayed). pump 2 seconds so
  // the scale, text, and button animations complete.
  // ═══════════════════════════════════════════════════════════════════════════

  group('ChallengerRoadMilestoneScreen', () {
    Widget buildScreen({ChallengerRoadMilestoneResult result = _firstMilestone}) => MaterialApp(
          home: ChallengerRoadMilestoneScreen(result: result),
        );

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ChallengerRoadMilestoneScreen), findsOneWidget);
    });

    testWidgets('shows 10K shot headline', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('10,000 SHOTS', findRichText: true), findsOneWidget);
    });

    testWidgets('shows Challenger Road Milestone subtitle', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.textContaining('Challenger Road Milestone', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows first-10K congratulations copy', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.textContaining('First 10K', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows KEEP GOING button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('KEEP GOING', findRichText: true), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 4 – ChallengeResultScreen (passed)
  // pump 1s drains the 300ms Future.delayed confetti timer; confetti itself is
  // vsync-only and auto-cancels on widget dispose.
  // Use 800×1200 logical pixels so the stats-card Row never overflows.
  // ═══════════════════════════════════════════════════════════════════════════

  group('ChallengeResultScreen - Pass', () {
    Widget buildScreen() => MaterialApp(
          home: ChallengeResultScreen(
            session: _makeSession(passed: true),
            challenge: _testChallenge,
            levelDoc: _testLevelDoc,
            updatedAttempt: _testAttempt,
            milestoneResult: _noMilestone,
          ),
        );

    void useWideScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('renders without crashing', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ChallengeResultScreen), findsOneWidget);
    });

    testWidgets('shows CHALLENGE COMPLETE! headline', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('CHALLENGE COMPLETE', findRichText: true), findsOneWidget);
    });

    testWidgets('shows BACK TO ROAD button', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('BACK TO ROAD', findRichText: true), findsOneWidget);
    });

    testWidgets('shows check icon for pass', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 5 – ChallengeResultScreen (failed)
  // No confetti, no Future.delayed. Safe to pump without duration.
  // ═══════════════════════════════════════════════════════════════════════════

  group('ChallengeResultScreen - Fail', () {
    Widget buildScreen() => MaterialApp(
          home: ChallengeResultScreen(
            session: _makeSession(passed: false),
            challenge: _testChallenge,
            levelDoc: _testLevelDoc,
            updatedAttempt: _testAttempt,
            milestoneResult: _noMilestone,
          ),
        );

    void useWideScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('renders without crashing', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      expect(find.byType(ChallengeResultScreen), findsOneWidget);
    });

    testWidgets('shows NOT QUITE... headline', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      // shotsMade=10, shotsToPass=35 → not close → "NOT QUITE..."
      expect(find.textContaining('NOT QUITE', findRichText: true), findsOneWidget);
    });

    testWidgets('shows TRY AGAIN button', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      expect(find.textContaining('TRY AGAIN', findRichText: true), findsOneWidget);
    });

    testWidgets('shows BACK TO ROAD button in fail state', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      expect(find.textContaining('BACK TO ROAD', findRichText: true), findsOneWidget);
    });

    testWidgets('shows close icon for fail', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 6 – ChallengerRoadTeaserView (not signed in)
  // When userId is null, TeaserView shows a simple sign-in prompt.
  // No MapView is rendered, so no Firestore activity.
  // ═══════════════════════════════════════════════════════════════════════════

  group('ChallengerRoadTeaserView - not signed in', () {
    Widget buildScreen() {
      final noAuth = MockFirebaseAuth(signedIn: false);
      return MaterialApp(
        home: Provider<FirebaseAuth>.value(
          value: noAuth,
          child: const Scaffold(
            body: ChallengerRoadTeaserView(embedded: false),
          ),
        ),
      );
    }

    testWidgets('shows sign-in prompt when user is null', (tester) async {
      await tester.pumpWidget(buildScreen());
      await pumpN(tester);
      expect(
        find.textContaining('Sign in', findRichText: true),
        findsOneWidget,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 7 – ChallengerRoadMapView (preview / teaser mode with signed-in user)
  // MapView reads FirebaseFirestore via Provider → use FakeFirebaseFirestore so
  // queries resolve instantly without pending timers.
  // Pump 6 times to drain the chain of async Firestore calls in _loadMapData.
  // With empty Firestore the map shows "Challenges coming soon!" once loaded.
  // ═══════════════════════════════════════════════════════════════════════════

  group('ChallengerRoadMapView - preview mode', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser(
        uid: 'preview_uid',
        displayName: 'Preview User',
        email: 'preview@example.com',
        photoURL: '',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      fakeFirestore = FakeFirebaseFirestore();
    });

    Widget buildMapView() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChallengerRoadMapView(
              userId: mockUser.uid,
              isPreviewMode: true,
              previewMaxLevel: 1,
            ),
          ),
        ),
      );
    }

    testWidgets('renders ChallengerRoadMapView', (tester) async {
      await tester.pumpWidget(buildMapView());
      await pumpN(tester);
      expect(find.byType(ChallengerRoadMapView), findsOneWidget);
    });

    testWidgets('shows loading indicator before data resolves', (tester) async {
      await tester.pumpWidget(buildMapView());
      // Immediately after pumpWidget – Future not yet resolved
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows Challenges coming soon after data loads', (tester) async {
      await tester.pumpWidget(buildMapView());
      // Multiple pumps drain the chained Firestore microtasks
      await pumpN(tester, 8);
      // With empty Firestore levels=[] → "Challenges coming soon!" text shown
      expect(
        find.textContaining('Challenges coming soon', findRichText: true),
        findsOneWidget,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 8 – ChallengerRoadTeaserView (signed-in, walkthrough visible)
  // TeaserView embeds MapView in preview mode.  SharedPreferences doesn't have
  // the walkthrough-seen key so the walkthrough overlay is shown.
  // ═══════════════════════════════════════════════════════════════════════════

  group('ChallengerRoadTeaserView - signed-in with walkthrough', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser(
        uid: 'teaser_uid',
        displayName: 'Teaser User',
        email: 'teaser@example.com',
        photoURL: '',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      fakeFirestore = FakeFirebaseFirestore();
      // Ensure walkthrough has NOT been seen
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildTeaserView() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChallengerRoadTeaserView(embedded: true),
          ),
        ),
      );
    }

    testWidgets('renders ChallengerRoadTeaserView', (tester) async {
      await tester.pumpWidget(buildTeaserView());
      await pumpN(tester, 6);
      expect(find.byType(ChallengerRoadTeaserView), findsOneWidget);
    });

    testWidgets('shows walkthrough overlay on first visit', (tester) async {
      await tester.pumpWidget(buildTeaserView());
      await pumpN(tester, 6);
      // Walkthrough card shows a "Skip" button
      expect(find.textContaining('Skip', findRichText: true), findsAtLeastNWidgets(1));
    });

    testWidgets('shows first slide title in walkthrough', (tester) async {
      await tester.pumpWidget(buildTeaserView());
      await pumpN(tester, 6);
      expect(
        find.textContaining('How Challenger Road Works', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows GO PRO bottom banner', (tester) async {
      await tester.pumpWidget(buildTeaserView());
      await pumpN(tester, 6);
      expect(find.textContaining('GO PRO', findRichText: true), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping Skip dismisses walkthrough', (tester) async {
      await tester.pumpWidget(buildTeaserView());
      await pumpN(tester, 6);
      // Tap the Skip text button to dismiss the walkthrough
      final skipFinder = find.textContaining('Skip', findRichText: true);
      expect(skipFinder, findsAtLeastNWidgets(1));
      await tester.tap(skipFinder.first);
      await pumpN(tester, 3);
      // After Skip the walkthrough card should be gone → "Skip" text not found
      expect(find.textContaining('Skip', findRichText: true), findsNothing);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/IntroScreen.dart';
import 'package:tenthousandshotchallenge/router.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../mock_firebase_auth_with_signedin.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:introduction_screen/introduction_screen.dart';

class TestIntroShownNotifier extends IntroShownNotifier {
  TestIntroShownNotifier(super.value) : super.withValue();
}

class TestNetworkStatusService extends NetworkStatusService {
  final StreamController<NetworkStatus> controller;
  TestNetworkStatusService(this.controller) : super(isTesting: true);
  @override
  StreamController<NetworkStatus> get networkStatusController => controller;
}

class MockFirebaseAnalytics implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({String? screenClass, String? screenName, Map<String, Object>? parameters, AnalyticsCallOptions? callOptions}) async {}
  // Add other required overrides as needed
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Intro Screen Logic Tests', () {
    late TestIntroShownNotifier introShownNotifier;
    late GoRouter router;
    late PreferencesStateNotifier prefsNotifier;
    late TestNetworkStatusService testNetworkStatusService;
    late StreamController<NetworkStatus> networkStatusController;
    late AuthChangeNotifier testAuthNotifier;
    late MockFirebaseAnalytics analytics;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      introShownNotifier = TestIntroShownNotifier(false);
      prefsNotifier = PreferencesStateNotifier();
      networkStatusController = StreamController<NetworkStatus>.broadcast();
      testNetworkStatusService = TestNetworkStatusService(networkStatusController);
      testAuthNotifier = AuthChangeNotifier(TestAuthFactory.signedOutAuth);
      analytics = MockFirebaseAnalytics();
      mockAuth = MockFirebaseAuth();
      router = createAppRouter(
        analytics,
        authNotifier: testAuthNotifier,
        introShownNotifier: introShownNotifier,
        initialLocation: '/app',
      );
    });
    tearDown(() async {
      await networkStatusController.close();
    });

    testWidgets('Intro screen is shown when not previously viewed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => prefsNotifier),
            ChangeNotifierProvider<IntroShownNotifier>.value(value: introShownNotifier),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
            Provider<FirebaseAuth>.value(value: mockAuth),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IntroScreen), findsOneWidget);
    });

    testWidgets('Intro screen is not shown after being marked as viewed', (WidgetTester tester) async {
      introShownNotifier = TestIntroShownNotifier(true); // Mark as viewed before building
      router = createAppRouter(
        analytics,
        authNotifier: testAuthNotifier,
        introShownNotifier: introShownNotifier,
        initialLocation: '/intro', // Start at intro for correct routing logic
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => prefsNotifier),
            ChangeNotifierProvider<IntroShownNotifier>.value(value: introShownNotifier),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
            Provider<FirebaseAuth>.value(value: mockAuth),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Extra pump to allow GoRouter to react to notifier
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byType(Navigation), findsOneWidget);
    });

    testWidgets('Intro screen is not shown after completing intro', (WidgetTester tester) async {
      introShownNotifier = TestIntroShownNotifier(false);
      router = createAppRouter(
        analytics,
        authNotifier: testAuthNotifier,
        introShownNotifier: introShownNotifier,
        initialLocation: '/intro', // Start at intro for correct routing logic
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => prefsNotifier),
            ChangeNotifierProvider<IntroShownNotifier>.value(value: introShownNotifier),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
            Provider<FirebaseAuth>.value(value: mockAuth),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IntroScreen), findsOneWidget);
      // Simulate swiping to last page and tapping the 'Done' control
      final introScreenFinder = find.byType(IntroductionScreen);
      expect(introScreenFinder, findsOneWidget);
      // Move to last page (assume 3 pages, index 2)
      final introScreenState = tester.state<IntroductionScreenState>(introScreenFinder);
      introScreenState.controller.animateToPage(
        2, // Update this index if your intro has more/fewer pages
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      // Tap at the bottom right corner to trigger 'Done'
      final size = tester.getSize(introScreenFinder);
      final bottomRight = Offset(size.width - 10, size.height - 10);
      await tester.tapAt(bottomRight);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // Extra pump to allow GoRouter to complete navigation
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byType(Navigation), findsOneWidget);
    });
  });
}

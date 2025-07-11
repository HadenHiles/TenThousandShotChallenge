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

    // Helper to build the widget tree after notifier and router setup
    Widget buildTestApp(GoRouter router) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => prefsNotifier),
          ChangeNotifierProvider<IntroShownNotifier>.value(value: introShownNotifier),
          Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          Provider<FirebaseAuth>.value(value: mockAuth),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('Intro screen is shown when not previously viewed', (WidgetTester tester) async {
      introShownNotifier = TestIntroShownNotifier(false);
      router = createAppRouter(
        analytics,
        authNotifier: testAuthNotifier,
        introShownNotifier: introShownNotifier,
        initialLocation: '/intro',
      );
      await tester.pumpWidget(buildTestApp(router));
      await tester.pumpAndSettle();
      expect(find.byType(IntroScreen), findsOneWidget);
    });
  });
}

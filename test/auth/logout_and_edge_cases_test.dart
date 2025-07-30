import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/router.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import '../mock_firebase.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../main_test.dart';
import '../main_test.mocks.dart';
import 'package:mockito/mockito.dart';
import '../mock_firebase_auth_with_signedin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  group('Logout & Edge Case Tests', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;
    late GoRouter router;
    late FirebaseAnalytics analytics;
    late AuthChangeNotifier testAuthNotifier;
    late IntroShownNotifier testIntroShownNotifier;
    late TestNetworkStatusService testNetworkStatusService;
    late StreamController<NetworkStatus> networkStatusController;

    setUp(() async {
      NetworkStatusService.isTestingOverride = true;

      fakeFirestore = FakeFirebaseFirestore();
      mockUser = TestAuthFactory.defaultUser;
      mockAuth = TestAuthFactory.signedOutAuth;
      SharedPreferences.setMockInitialValues({'intro_shown': true});
      analytics = FirebaseAnalytics.instance;
      testAuthNotifier = AuthChangeNotifier(mockAuth);
      testIntroShownNotifier = IntroShownNotifier.withValue(true);
      networkStatusController = StreamController<NetworkStatus>.broadcast();
      testNetworkStatusService = TestNetworkStatusService(networkStatusController);
      router = createAppRouter(
        analytics,
        authNotifier: testAuthNotifier,
        introShownNotifier: testIntroShownNotifier,
        initialLocation: '/login',
      );
    });
    tearDown(() async {
      await networkStatusController.close();
    });

    testWidgets('Logout returns user to login screen', (WidgetTester tester) async {
      await fakeFirestore.collection('users').doc('test_uid').set({
        'display_name': 'Test User',
        'email': 'test@example.com',
        'public': true,
        'fcm_token': '',
      });
      final mockCustomerInfo = MockCustomerInfo();
      // Set up entitlements to avoid null errors in settings page
      when(mockCustomerInfo.entitlements).thenReturn(FakeEntitlementInfos({}));
      when(mockCustomerInfo.originalAppUserId).thenReturn('test_uid');
      when(mockCustomerInfo.latestExpirationDate).thenReturn('2099-01-01');
      when(mockCustomerInfo.allPurchaseDates).thenReturn({});
      when(mockCustomerInfo.activeSubscriptions).thenReturn([]);
      when(mockCustomerInfo.allPurchasedProductIdentifiers).thenReturn([]);
      when(mockCustomerInfo.nonSubscriptionTransactions).thenReturn([]);
      when(mockCustomerInfo.firstSeen).thenReturn(DateTime(2020, 1, 1).toIso8601String());
      when(mockCustomerInfo.allExpirationDates).thenReturn({});
      when(mockCustomerInfo.requestDate).thenReturn(DateTime(2099, 1, 1).toIso8601String());
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MultiProvider(
            providers: [
              ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
              ChangeNotifierProvider<IntroShownNotifier>.value(value: testIntroShownNotifier),
              Provider<FirebaseAuth>.value(value: mockAuth),
              Provider<FirebaseFirestore>.value(value: fakeFirestore),
              Provider<NetworkStatusService>.value(value: testNetworkStatusService),
              Provider<CustomerInfo?>.value(value: mockCustomerInfo),
            ],
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final emailButton = find.widgetWithText(ElevatedButton, 'Sign in with Email');
      expect(emailButton, findsOneWidget);
      await tester.tap(emailButton);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign in');
      await tester.tap(signInButton);
      // Simulate login
      simulateLogin(mockAuth as MockFirebaseAuthWithSignedIn, testAuthNotifier);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // After login, immediately navigate to the settings route
      router.go('/settings');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // Try to scroll the settings page to the very bottom to reveal the logout button
      final settingsList = find.byType(Scrollable);
      if (settingsList.evaluate().isNotEmpty) {
        await tester.drag(settingsList.first, const Offset(0, -1000)); // Large offset to ensure bottom
        await tester.pumpAndSettle();
      }
      // Try to find and tap the logout button by text label, tapping its nearest tappable ancestor
      final logoutText = find.text('Logout');
      expect(logoutText, findsOneWidget);
      // Find the nearest InkWell or GestureDetector ancestor
      final logoutTappable = find.ancestor(of: logoutText, matching: find.byType(InkWell));
      expect(logoutTappable, findsOneWidget);
      await tester.tap(logoutTappable);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // Simulate logout for mock auth and notifier (ensure state is updated before navigation)
      simulateLogout(mockAuth as MockFirebaseAuthWithSignedIn, testAuthNotifier);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // Should return to Login screen
      expect(find.byType(Login), findsOneWidget);
    });

    testWidgets('Disabled account shows error', (WidgetTester tester) async {
      mockAuth = TestAuthFactory.disabledAccountAuth(user: mockUser);
      testAuthNotifier = AuthChangeNotifier(mockAuth);
      router = createAppRouter(
        analytics,
        authNotifier: testAuthNotifier,
        introShownNotifier: testIntroShownNotifier,
        initialLocation: '/login',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
            ChangeNotifierProvider<IntroShownNotifier>.value(value: testIntroShownNotifier),
            Provider<FirebaseAuth>.value(value: mockAuth),
            Provider<FirebaseFirestore>.value(value: fakeFirestore),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final emailButton = find.widgetWithText(ElevatedButton, 'Sign in with Email');
      expect(emailButton, findsOneWidget);
      await tester.tap(emailButton);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign in');
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Check for error in SnackBar or dialog
      final snackBar = find.byType(SnackBar);
      if (snackBar.evaluate().isNotEmpty) {
        expect(find.textContaining('disabled', findRichText: true), findsOneWidget);
      } else {
        // Try to find a dialog or other error widget
        final errorText = find.textContaining('disabled', findRichText: true);
        expect(errorText, findsWidgets);
      }
    });

    testWidgets('Network error during login shows error', (WidgetTester tester) async {
      mockAuth = TestAuthFactory.networkErrorAuth(user: mockUser);
      testAuthNotifier = AuthChangeNotifier(mockAuth);
      router = createAppRouter(
        analytics,
        authNotifier: testAuthNotifier,
        introShownNotifier: testIntroShownNotifier,
        initialLocation: '/login',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
            ChangeNotifierProvider<IntroShownNotifier>.value(value: testIntroShownNotifier),
            Provider<FirebaseAuth>.value(value: mockAuth),
            Provider<FirebaseFirestore>.value(value: fakeFirestore),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final emailButton = find.widgetWithText(ElevatedButton, 'Sign in with Email');
      expect(emailButton, findsOneWidget);
      await tester.tap(emailButton);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign in');
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Check for error in SnackBar or dialog
      final snackBar = find.byType(SnackBar);
      if (snackBar.evaluate().isNotEmpty) {
        expect(find.textContaining('network', findRichText: true), findsOneWidget);
      } else {
        final errorText = find.textContaining('network', findRichText: true);
        expect(errorText, findsWidgets);
      }
    });
  });
}

class TestNetworkStatusService extends NetworkStatusService {
  final StreamController<NetworkStatus> controller;
  TestNetworkStatusService(this.controller) : super(isTesting: true);
  @override
  StreamController<NetworkStatus> get networkStatusController => controller;
}

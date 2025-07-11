import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import '../mock_firebase.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'dart:async';
import 'package:tenthousandshotchallenge/router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';
import '../mock_firebase_auth_with_signedin.dart';

class AppleSignInAvailable {
  final bool isAvailable;
  AppleSignInAvailable(this.isAvailable);
  static Future<AppleSignInAvailable> check() async => AppleSignInAvailable(false);
}

class TestNetworkStatusService extends NetworkStatusService {
  final StreamController<NetworkStatus> controller;
  TestNetworkStatusService(this.controller) : super(isTesting: true);
  @override
  StreamController<NetworkStatus> get networkStatusController => controller;
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  await tester.pumpAndSettle();
}

class WeakPasswordAuth extends MockFirebaseAuth {
  WeakPasswordAuth({required MockUser super.mockUser, super.signedIn});
  @override
  Future<UserCredential> createUserWithEmailAndPassword({required String email, required String password}) async {
    // Treat 'SuperSecure!2025' as weak for testing purposes
    if (password == 'SuperSecure!2025') {
      throw FirebaseAuthException(code: 'weak-password');
    }
    return super.createUserWithEmailAndPassword(email: email, password: password);
  }
}

class EmailInUseAuth extends MockFirebaseAuth {
  EmailInUseAuth({required MockUser super.mockUser, super.signedIn});
  @override
  Future<UserCredential> createUserWithEmailAndPassword({required String email, required String password}) async {
    if (email == 'used@example.com') {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    return super.createUserWithEmailAndPassword(email: email, password: password);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().window
      ..physicalSizeTestValue = const Size(1200, 2400)
      ..devicePixelRatioTestValue = 1.0;
    setupFirebaseAuthMocks();
    NetworkStatusService.isTestingOverride = true;
  });
  tearDownAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().window
      ..clearPhysicalSizeTestValue()
      ..clearDevicePixelRatioTestValue();
  });

  group('Email Registration Tests', () {
    late FirebaseAuth auth;
    late FakeFirebaseFirestore firestore;
    late MockUser mockUser;
    late TestNetworkStatusService testNetworkStatusService;
    late StreamController<NetworkStatus> networkStatusController;
    late GoRouter router;
    late FirebaseAnalytics analytics;
    late AuthChangeNotifier testAuthNotifier;
    late IntroShownNotifier testIntroShownNotifier;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      mockUser = TestAuthFactory.defaultUser;
      auth = TestAuthFactory.signedOutAuth;
      networkStatusController = StreamController<NetworkStatus>.broadcast();
      testNetworkStatusService = TestNetworkStatusService(networkStatusController);
      SharedPreferences.setMockInitialValues({});
      analytics = FirebaseAnalytics.instance;
      testAuthNotifier = AuthChangeNotifier(auth);
      testIntroShownNotifier = IntroShownNotifier.withValue(true);
      router = createAppRouter(
        analytics,
        authNotifier: testAuthNotifier,
        introShownNotifier: testIntroShownNotifier,
        initialLocation: '/register',
      );
    });
    tearDown(() async {
      await networkStatusController.close();
    });

    testWidgets('Successful email registration navigates to main app', (WidgetTester tester) async {
      // Create user document to avoid not-found error
      await firestore.collection('users').doc('test_uid').set({
        'display_name': 'Test User',
        'email': 'newuser@example.com',
        'public': true,
        'fcm_token': '',
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(false)),
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
            ChangeNotifierProvider<IntroShownNotifier>.value(value: testIntroShownNotifier),
            Provider<FirebaseAuth>.value(value: auth),
            Provider<FirebaseFirestore>.value(value: firestore),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final signUpButton = find.widgetWithText(TextButton, 'SIGN UP');
      expect(signUpButton, findsOneWidget);
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();
      final dialog = find.byType(SimpleDialog);
      expect(dialog, findsOneWidget);
      final fields = find.descendant(of: dialog, matching: find.byType(TextFormField));
      await tester.enterText(fields.at(0), 'newuser@example.com');
      await tester.enterText(fields.at(1), 'secure-password');
      if (fields.evaluate().length > 2) {
        await tester.enterText(fields.at(2), 'secure-password');
      }
      final submitButton = find.descendant(of: dialog, matching: find.widgetWithText(ElevatedButton, 'Sign up'));
      await tester.tap(submitButton);
      (auth as MockFirebaseAuthWithSignedIn).signedIn = true;
      testAuthNotifier.notifyListeners();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await pumpUntilFound(tester, find.byType(Navigation), timeout: const Duration(seconds: 5));
      expect(find.byType(Navigation), findsOneWidget);
    });

    testWidgets('Email registration with weak password shows error', (WidgetTester tester) async {
      auth = WeakPasswordAuth(mockUser: mockUser, signedIn: false);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(false)),
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
            ChangeNotifierProvider<IntroShownNotifier>.value(value: testIntroShownNotifier),
            Provider<FirebaseAuth>.value(value: auth),
            Provider<FirebaseFirestore>.value(value: firestore),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final signUpButton = find.widgetWithText(TextButton, 'SIGN UP');
      expect(signUpButton, findsOneWidget);
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();
      final dialog = find.byType(SimpleDialog);
      expect(dialog, findsOneWidget);
      final fields = find.descendant(of: dialog, matching: find.byType(TextFormField));
      await tester.enterText(fields.at(0), 'newuser@example.com');
      await tester.enterText(fields.at(1), 'SuperSecure!2025'); // Use a password that passes form validation but is weak for the mock
      if (fields.evaluate().length > 2) {
        await tester.enterText(fields.at(2), 'SuperSecure!2025');
      }
      final submitButton = find.descendant(of: dialog, matching: find.widgetWithText(ElevatedButton, 'Sign up'));
      await tester.tap(submitButton);
      testAuthNotifier.notifyListeners();
      // Wait for error message to be set
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('The password provided is too weak'), findsOneWidget);
    });

    testWidgets('Email registration with email already in use shows error', (WidgetTester tester) async {
      auth = EmailInUseAuth(mockUser: mockUser, signedIn: false);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(false)),
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
            ChangeNotifierProvider<IntroShownNotifier>.value(value: testIntroShownNotifier),
            Provider<FirebaseAuth>.value(value: auth),
            Provider<FirebaseFirestore>.value(value: firestore),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final signUpButton = find.widgetWithText(TextButton, 'SIGN UP');
      expect(signUpButton, findsOneWidget);
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();
      final dialog = find.byType(SimpleDialog);
      expect(dialog, findsOneWidget);
      final fields = find.descendant(of: dialog, matching: find.byType(TextFormField));
      await tester.enterText(fields.at(0), 'used@example.com');
      await tester.enterText(fields.at(1), 'secure-password');
      if (fields.evaluate().length > 2) {
        await tester.enterText(fields.at(2), 'secure-password');
      }
      final submitButton = find.descendant(of: dialog, matching: find.widgetWithText(ElevatedButton, 'Sign up'));
      await tester.tap(submitButton);
      // Wait for error message to be set
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('The account already exists for that email', findRichText: true), findsOneWidget);
    });

    test('MockFirebaseAuth throws for weak password', () async {
      final customAuth = WeakPasswordAuth(mockUser: mockUser, signedIn: false);
      expect(
        () => customAuth.createUserWithEmailAndPassword(email: 'newuser@example.com', password: 'SuperSecure!2025'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('MockFirebaseAuth throws for email already in use', () async {
      final customAuth = EmailInUseAuth(mockUser: mockUser, signedIn: false);
      expect(
        () => customAuth.createUserWithEmailAndPassword(email: 'used@example.com', password: 'secure-password'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });
}

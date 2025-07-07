import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/Login.dart' as login;
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../mock_firebase.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'dart:async';

// Minimal mock for AppleSignInAvailable for widget tests
class AppleSignInAvailable {
  final bool isAvailable;
  AppleSignInAvailable(this.isAvailable);
  static Future<AppleSignInAvailable> check() async => AppleSignInAvailable(false);
}

class FakeCustomerInfo {}

class TestNetworkStatusService extends NetworkStatusService {
  final StreamController<NetworkStatus> controller;
  TestNetworkStatusService(this.controller) : super(isTesting: true);
  @override
  StreamController<NetworkStatus> get networkStatusController => controller;
}

// Move isIntegrationTest to a top-level function
bool isIntegrationTest() => const String.fromEnvironment('FLUTTER_TEST') != 'true' && const String.fromEnvironment('USE_FIREBASE_EMULATOR') == 'true';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Set a realistic test surface size to avoid widget overflows
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

  setUp(() async {
    if (isIntegrationTest()) {
      await Firebase.initializeApp();
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    }
  });

  group('Login Tests', () {
    late FirebaseAuth auth;
    late FakeFirebaseFirestore firestore;
    late MockUser mockUser;
    late TestNetworkStatusService testNetworkStatusService;
    late StreamController<NetworkStatus> networkStatusController;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      mockUser = MockUser(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        isEmailVerified: true,
      );
      auth = MockFirebaseAuth(mockUser: mockUser, signedIn: false);
      networkStatusController = StreamController<NetworkStatus>.broadcast();
      testNetworkStatusService = TestNetworkStatusService(networkStatusController);
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() async {
      await networkStatusController.close();
    });

    testWidgets('Successful email login navigates to main app', (WidgetTester tester) async {
      await firestore.collection('users').doc('test_uid').set({
        'display_name': 'Test User',
        'email': 'test@example.com',
        'public': true,
        'fcm_token': '',
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(false)),
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
            Provider<FirebaseAuth>.value(value: auth),
            Provider<FirebaseFirestore>.value(value: firestore),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          ],
          child: MaterialApp(
            home: login.Login(),
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
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(Navigation), findsOneWidget);
    });

    testWidgets('Email login with wrong password shows error', (WidgetTester tester) async {
      auth = WrongPasswordAuth(mockUser: mockUser, signedIn: false);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(false)),
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
            Provider<FirebaseAuth>.value(value: auth),
            Provider<FirebaseFirestore>.value(value: firestore),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          ],
          child: MaterialApp(
            home: const login.Login(),
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
      await tester.enterText(fields.at(1), 'wrong-password');
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign in');
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await pumpUntilFound(tester, find.textContaining('Wrong password', findRichText: true));
      expect(find.textContaining('Wrong password', findRichText: true), findsOneWidget);
    });

    testWidgets('Email login with non-existent user shows error', (WidgetTester tester) async {
      auth = UserNotFoundAuth(mockUser: mockUser, signedIn: false);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(false)),
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
            Provider<FirebaseAuth>.value(value: auth),
            Provider<FirebaseFirestore>.value(value: firestore),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          ],
          child: MaterialApp(
            home: const login.Login(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final emailButton = find.widgetWithText(ElevatedButton, 'Sign in with Email');
      expect(emailButton, findsOneWidget);
      await tester.tap(emailButton);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'nouser@example.com');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign in');
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await pumpUntilFound(tester, find.textContaining('No user found for that email', findRichText: true));
      expect(find.textContaining('No user found for that email', findRichText: true), findsOneWidget);
    });

    testWidgets('Email login with invalid email shows error', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(false)),
            ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
            Provider<FirebaseAuth>.value(value: auth),
            Provider<FirebaseFirestore>.value(value: firestore),
            Provider<NetworkStatusService>.value(value: testNetworkStatusService),
          ],
          child: MaterialApp(
            home: const login.Login(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final emailButton = find.widgetWithText(ElevatedButton, 'Sign in with Email');
      expect(emailButton, findsOneWidget);
      await tester.tap(emailButton);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'not-an-email');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign in');
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Invalid email', findRichText: true), findsOneWidget);
    });

    test('MockFirebaseAuth throws for wrong password', () async {
      final customAuth = WrongPasswordAuth(mockUser: mockUser, signedIn: false);
      expect(
        () => customAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'wrong-password'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  }); // Close the test group
} // Close main()

// Custom mock for wrong password
class WrongPasswordAuth extends MockFirebaseAuth {
  WrongPasswordAuth({required super.mockUser, super.signedIn});
  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    if (email == 'test@example.com' && password == 'wrong-password') {
      throw FirebaseAuthException(code: 'wrong-password');
    }
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

// Custom mock for user-not-found
class UserNotFoundAuth extends MockFirebaseAuth {
  UserNotFoundAuth({required super.mockUser, super.signedIn});
  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    if (email == 'nouser@example.com') {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

// Utility function to pump the widget tree until a condition is met or a timeout occurs
Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  // One last check
  await tester.pumpAndSettle();
}

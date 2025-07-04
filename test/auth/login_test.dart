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
import 'package:tenthousandshotchallenge/main.dart';

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
    late FirebaseFirestore firestore;
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
      auth = ThrowingMockFirebaseAuth(mockUser: mockUser, signedIn: false);
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
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(Navigation), findsOneWidget);
    });

    testWidgets('Email login with wrong password shows error', (WidgetTester tester) async {
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
            navigatorKey: navigatorKey, // Ensure global navigatorKey is used
            home: const login.Login(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Tap the 'Sign in with Email' button to open the dialog
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
      // Wait for dialog to close and SnackBar to appear
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key('login_error_snackbar')), findsOneWidget);
    });

    testWidgets('Email login with non-existent user shows error', (WidgetTester tester) async {
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
            navigatorKey: navigatorKey, // Ensure global navigatorKey is used
            home: const login.Login(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Tap the 'Sign in with Email' button to open the dialog
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
      // Wait for dialog to close and SnackBar to appear
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key('login_error_snackbar')), findsOneWidget);
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
            navigatorKey: navigatorKey, // Ensure global navigatorKey is used
            home: const login.Login(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Tap the 'Sign in with Email' button to open the dialog
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

    // Test that the mock throws as expected
    test('MockFirebaseAuth throws for wrong password', () async {
      expect(
        () => auth.signInWithEmailAndPassword(email: 'test@example.com', password: 'wrong-password'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  }); // Close the test group
} // Close main()

// Custom mock for Google login failure
class GoogleErrorAuthMock extends MockFirebaseAuth {
  GoogleErrorAuthMock({required MockUser mockUser}) : super(mockUser: mockUser);
  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) {
    throw FirebaseAuthException(code: 'google-error', message: 'Google sign-in error');
  }
}

// Custom mock for Apple login failure
class AppleErrorAuthMock extends MockFirebaseAuth {
  AppleErrorAuthMock({required MockUser mockUser}) : super(mockUser: mockUser);
  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) {
    throw FirebaseAuthException(code: 'apple-error', message: 'Apple sign-in error');
  }
}

class ThrowingMockFirebaseAuth extends MockFirebaseAuth {
  final MockUser? _mockUser;
  ThrowingMockFirebaseAuth({super.mockUser, super.signedIn})
      : _mockUser = mockUser,
        _signedIn = signedIn,
        _authStateController = StreamController<User?>.broadcast() {
    if (_signedIn && _mockUser != null) {
      _authStateController.add(_mockUser);
    } else {
      _authStateController.add(null);
    }
  }

  bool _signedIn;
  final StreamController<User?> _authStateController;

  @override
  Stream<User?> authStateChanges() => _authStateController.stream;

  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    if (email == 'test@example.com' && password == 'wrong-password') {
      throw FirebaseAuthException(code: 'wrong-password');
    }
    if (email == 'nouser@example.com') {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    // Simulate successful sign-in
    _signedIn = true;
    if (_mockUser != null) {
      _authStateController.add(_mockUser);
    }
    return super.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _authStateController.add(null);
    return super.signOut();
  }
}

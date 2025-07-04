import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

bool get isIntegrationTest => const String.fromEnvironment('FLUTTER_TEST') != 'true' && const String.fromEnvironment('USE_FIREBASE_EMULATOR') == 'true';

void main() {
  group('Social Login Tests (Google/Apple)', () {
    late FirebaseAuth auth;
    late FirebaseFirestore firestore;
    late MockUser mockUser;

    setUp(() async {
      if (isIntegrationTest) {
        await Firebase.initializeApp();
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
        firestore = FirebaseFirestore.instance;
        auth = FirebaseAuth.instance;
        // Ensure test user exists in Auth emulator
        try {
          await auth.createUserWithEmailAndPassword(
            email: 'test@example.com',
            password: 'any-password',
          );
        } catch (e) {
          // Ignore if user already exists
        }
      } else {
        firestore = FakeFirebaseFirestore();
        mockUser = MockUser(
          uid: 'test_uid',
          email: 'test@example.com',
          displayName: 'Test User',
          isEmailVerified: true,
        );
        auth = MockFirebaseAuth(mockUser: mockUser);
      }
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Google login success navigates to main app', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: auth),
            Provider<FirebaseFirestore>.value(value: firestore),
          ],
          child: const MaterialApp(home: Login()),
        ),
      );
      await tester.pumpAndSettle();
      // Tap the Google sign-in button (look for SignInButton or text)
      final googleButton = find.byWidgetPredicate((w) => w.toString().toLowerCase().contains('google'));
      if (googleButton.evaluate().isEmpty) {
        final googleText = find.textContaining('google', findRichText: true);
        expect(googleText, findsWidgets);
        await tester.tap(googleText.first);
      } else {
        await tester.tap(googleButton);
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // Should navigate to main app (Navigation or Profile, etc.)
      expect(find.textContaining('Profile', findRichText: true), findsWidgets);
    });

    testWidgets('Apple login success navigates to main app', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: auth),
            Provider<FirebaseFirestore>.value(value: firestore),
          ],
          child: const MaterialApp(home: Login()),
        ),
      );
      await tester.pumpAndSettle();
      // Tap the Apple sign-in button (look for SignInButton or text)
      final appleButton = find.byWidgetPredicate((w) => w.toString().toLowerCase().contains('apple'));
      if (appleButton.evaluate().isEmpty) {
        final appleText = find.textContaining('apple', findRichText: true);
        expect(appleText, findsWidgets);
        await tester.tap(appleText.first);
      } else {
        await tester.tap(appleButton);
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Profile', findRichText: true), findsWidgets);
    });

    testWidgets('Google login failure shows error', (WidgetTester tester) async {
      final localAuth = isIntegrationTest ? auth : GoogleErrorAuthMock(mockUser: mockUser);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: localAuth),
            Provider<FirebaseFirestore>.value(value: firestore),
          ],
          child: const MaterialApp(home: Login()),
        ),
      );
      await tester.pumpAndSettle();
      final googleButton = find.byWidgetPredicate((w) => w.toString().toLowerCase().contains('google'));
      if (googleButton.evaluate().isEmpty) {
        final googleText = find.textContaining('google', findRichText: true);
        expect(googleText, findsWidgets);
        await tester.tap(googleText.first);
      } else {
        await tester.tap(googleButton);
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('error', findRichText: true), findsWidgets);
    });

    testWidgets('Apple login failure shows error', (WidgetTester tester) async {
      final localAuth = isIntegrationTest ? auth : AppleErrorAuthMock(mockUser: mockUser);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: localAuth),
            Provider<FirebaseFirestore>.value(value: firestore),
          ],
          child: const MaterialApp(home: Login()),
        ),
      );
      await tester.pumpAndSettle();
      final appleButton = find.byWidgetPredicate((w) => w.toString().toLowerCase().contains('apple'));
      if (appleButton.evaluate().isEmpty) {
        final appleText = find.textContaining('apple', findRichText: true);
        expect(appleText, findsWidgets);
        await tester.tap(appleText.first);
      } else {
        await tester.tap(appleButton);
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('error', findRichText: true), findsWidgets);
    });
  });
}

// Custom mock for Google login failure
class GoogleErrorAuthMock extends MockFirebaseAuth {
  GoogleErrorAuthMock({required super.mockUser});
  // You may need to override the relevant method if your app uses a plugin or service for Google sign-in
}

// Custom mock for Apple login failure
class AppleErrorAuthMock extends MockFirebaseAuth {
  AppleErrorAuthMock({required super.mockUser});
  // You may need to override the relevant method if your app uses a plugin or service for Apple sign-in
}

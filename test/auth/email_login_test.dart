import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

bool get isIntegrationTest => const String.fromEnvironment('FLUTTER_TEST') != 'true' && const String.fromEnvironment('USE_FIREBASE_EMULATOR') == 'true';

void main() {
  group('Email Login Tests', () {
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

    testWidgets('Successful email login navigates to main app', (WidgetTester tester) async {
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
      final fields = find.byType(TextFormField);
      expect(fields.evaluate().length >= 2, isTrue, reason: 'Should have at least two text fields for email and password');
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.byWidgetPredicate((w) => w is ElevatedButton && (w.child is Text) && ((w.child as Text).data?.toLowerCase().contains('sign in') ?? false));
      expect(signInButton, findsOneWidget);
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(Navigation), findsOneWidget);
    });

    testWidgets('Email login with wrong password shows error', (WidgetTester tester) async {
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
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'wrong-password');
      final signInButton = find.byWidgetPredicate((w) => w is ElevatedButton && (w.child is Text) && ((w.child as Text).data?.toLowerCase().contains('sign in') ?? false));
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Wrong password', findRichText: true), findsOneWidget);
    });

    testWidgets('Email login with non-existent user shows error', (WidgetTester tester) async {
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
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'nouser@example.com');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.byWidgetPredicate((w) => w is ElevatedButton && (w.child is Text) && ((w.child as Text).data?.toLowerCase().contains('sign in') ?? false));
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('No user found', findRichText: true), findsOneWidget);
    });

    testWidgets('Email login with invalid email shows error', (WidgetTester tester) async {
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
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'not-an-email');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.byWidgetPredicate((w) => w is ElevatedButton && (w.child is Text) && ((w.child as Text).data?.toLowerCase().contains('sign in') ?? false));
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Invalid email', findRichText: true), findsOneWidget);
    });

    // Add more tests as needed
  });
}

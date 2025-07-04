import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Logout & Edge Case Tests', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        isEmailVerified: true,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Logout returns user to login screen', (WidgetTester tester) async {
      // Simulate a logged-in user and navigate to the settings/logout button
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            Provider<FirebaseFirestore>.value(value: fakeFirestore),
          ],
          child: MaterialApp(home: Login()),
        ),
      );
      await tester.pumpAndSettle();
      // Simulate successful login
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.byWidgetPredicate((w) => w is ElevatedButton && (w.child is Text) && ((w.child as Text).data?.toLowerCase().contains('sign in') ?? false));
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // Now, after login, the Navigation widget should be present
      expect(find.textContaining('Profile', findRichText: true), findsWidgets);
      // Open settings/profile menu if needed (depends on your UI)
      // Find and tap the logout button (case-insensitive)
      final logoutButton = find.byWidgetPredicate((w) => w is ListTile && (w.title is Text) && ((w.title as Text).data?.toLowerCase().contains('logout') ?? false));
      if (logoutButton.evaluate().isEmpty) {
        // Try to find a button or text with 'logout' if ListTile is not used
        final logoutText = find.textContaining('logout', findRichText: true);
        expect(logoutText, findsWidgets);
        await tester.tap(logoutText.first);
      } else {
        await tester.tap(logoutButton);
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // Should return to Login screen
      expect(find.byType(Login), findsOneWidget);
    });

    testWidgets('Disabled account shows error', (WidgetTester tester) async {
      mockAuth = DisabledAccountAuthMock(mockUser: mockUser);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            Provider<FirebaseFirestore>.value(value: fakeFirestore),
          ],
          child: const MaterialApp(home: Login()),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.byWidgetPredicate((w) => w is ElevatedButton && (w.child is Text) && ((w.child as Text).data?.toLowerCase().contains('sign in') ?? false));
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('disabled', findRichText: true), findsOneWidget);
    });

    testWidgets('Network error during login shows error', (WidgetTester tester) async {
      mockAuth = NetworkErrorAuthMock(mockUser: mockUser);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            Provider<FirebaseFirestore>.value(value: fakeFirestore),
          ],
          child: const MaterialApp(home: Login()),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test@example.com');
      await tester.enterText(fields.at(1), 'any-password');
      final signInButton = find.byWidgetPredicate((w) => w is ElevatedButton && (w.child is Text) && ((w.child as Text).data?.toLowerCase().contains('sign in') ?? false));
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('network', findRichText: true), findsOneWidget);
    });
  });
}

// Custom mock for disabled account
class DisabledAccountAuthMock extends MockFirebaseAuth {
  DisabledAccountAuthMock({required super.mockUser});
  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    throw FirebaseAuthException(code: 'user-disabled', message: 'This user has been disabled');
  }
}

// Custom mock for network error
class NetworkErrorAuthMock extends MockFirebaseAuth {
  NetworkErrorAuthMock({required super.mockUser});
  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    throw FirebaseAuthException(code: 'network-request-failed', message: 'A network error occurred');
  }
}

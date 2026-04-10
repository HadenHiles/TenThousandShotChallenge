import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/tabs/Team.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/main.dart' as main_globals;
import '../mock_firebase.dart';

void main() {
  group('Team Screen', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;

    setUpAll(() async {
      await setupFirebaseAuthMocks();
      main_globals.preferences = Preferences(
        false,
        25,
        true,
        DateTime.now().add(const Duration(days: 100)),
        null,
      );
    });

    setUp(() async {
      final mockUser = MockUser(
        uid: 'test_uid',
        displayName: 'Test User',
        email: 'test@example.com',
        photoURL: '',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      fakeFirestore = FakeFirebaseFirestore();
    });

    Widget buildWidget() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(home: TeamPage()),
      );
    }

    void suppressErrors() {
      FlutterError.onError = (details) {
        final msg = details.exception.toString();
        if (msg.contains('RenderFlex overflowed') || msg.contains('FirebaseException') || msg.contains('No Firebase App') || msg.contains('setState') || msg.contains('PlatformException')) return;
        FlutterError.dumpErrorToConsole(details);
      };
    }

    // ── Basic render ────────────────────────────────────────────────────────

    testWidgets('TeamPage widget is in the tree after pumpWidget', (tester) async {
      suppressErrors();
      await tester.pumpWidget(buildWidget());
      // Before any stream resolves the widget must be present
      expect(find.byType(TeamPage), findsOneWidget);
    });

    testWidgets('shows loading indicator before streams resolve', (tester) async {
      suppressErrors();
      await tester.pumpWidget(buildWidget());
      // StreamBuilder shows waiting state synchronously before first microtask
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('team_tab_body container is always present', (tester) async {
      suppressErrors();
      await tester.pumpWidget(buildWidget());
      expect(find.byKey(const Key('team_tab_body')), findsOneWidget);
    });

    // ── No-team UI ──────────────────────────────────────────────────────────
    // Exactly 2 pumps: one to deliver the user-profile snapshot, one to rebuild.
    // This stops before the rxdart CombineLatestStream players stream fires,
    // which would create an infinite microtask chain under fake timers.

    group('with no team assigned', () {
      setUp(() async {
        await fakeFirestore.collection('users').doc('test_uid').set({
          'id': 'test_uid',
          'display_name': 'Test User',
          'display_name_lowercase': 'test user',
          'email': 'test@example.com',
          'photo_url': '',
          'public': true,
          'friend_notifications': true,
          'team_id': null,
          'fcm_token': null,
        });
      });

      testWidgets('shows create-team prompt when user has no team', (tester) async {
        suppressErrors();
        await tester.pumpWidget(buildWidget());
        await tester.pump(); // deliver user-profile snapshot
        await tester.pump(); // rebuild with no-team UI
        expect(
          find.textContaining(
            RegExp('create a team', caseSensitive: false),
            findRichText: true,
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows join-team button when user has no team', (tester) async {
        suppressErrors();
        await tester.pumpWidget(buildWidget());
        await tester.pump(); // deliver user-profile snapshot
        await tester.pump(); // rebuild with no-team UI
        expect(
          find.textContaining(
            RegExp('join team', caseSensitive: false),
            findRichText: true,
          ),
          findsOneWidget,
        );
      });
    });
  });
}

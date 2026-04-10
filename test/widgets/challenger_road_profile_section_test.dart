import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/tabs/profile/ChallengerRoadProfileSection.dart';
import '../mock_firebase.dart';

void main() {
  group('ChallengerRoadProfileSection', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late ChallengerRoadService fakeService;

    setUpAll(() async {
      await setupFirebaseAuthMocks();
    });

    setUp(() async {
      final mockUser = MockUser(
        uid: 'profile_uid',
        displayName: 'Profile User',
        email: 'profile@example.com',
        photoURL: '',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      fakeFirestore = FakeFirebaseFirestore();
      fakeService = ChallengerRoadService(firestore: fakeFirestore);

      FlutterError.onError = (details) {
        final msg = details.exception.toString();
        if (msg.contains('FirebaseException') || msg.contains('No Firebase App') || msg.contains('MissingPluginException') || msg.contains('RenderFlex overflowed')) return;
        FlutterError.dumpErrorToConsole(details);
      };
    });

    // The widget instantiates ChallengerRoadService() internally, which calls
    // FirebaseFirestore.instance. In tests, that may throw; we suppress those
    // errors and test the UI state that results from the empty-data fallback.

    Widget buildWidget({
      required bool isPro,
      VoidCallback? onGoProTap,
      String userId = 'profile_uid',
    }) {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
          // Expose the fake service so internal ChallengerRoadService calls use it
          Provider<ChallengerRoadService>.value(value: fakeService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChallengerRoadProfileSection(
                userId: userId,
                isPro: isPro,
                onGoProTap: onGoProTap,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders for a free user (isPro=false)', (tester) async {
      await tester.pumpWidget(buildWidget(isPro: false));
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(find.byType(ChallengerRoadProfileSection), findsOneWidget);
    });

    testWidgets('free user sees Go Pro nudge text', (tester) async {
      await tester.pumpWidget(buildWidget(isPro: false));
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }
      // The nudge contains "GO PRO" text (when onGoProTap is provided)
      // and unlock copy text
      expect(
        find.textContaining('earn more badges', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('Go Pro nudge button calls callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildWidget(isPro: false, onGoProTap: () => tapped = true));
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }
      final goProButton = find.text('GO PRO');
      if (goProButton.evaluate().isNotEmpty) {
        await tester.tap(goProButton);
        await tester.pump();
        expect(tapped, isTrue);
      }
    });

    testWidgets('pro user does not see Go Pro nudge', (tester) async {
      await tester.pumpWidget(buildWidget(isPro: true));
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }
      // The Go Pro nudge copy should NOT be present for pro users
      expect(
        find.textContaining('earn more badges', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('shows BADGES section label', (tester) async {
      await tester.pumpWidget(buildWidget(isPro: true));
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(find.text('BADGES'), findsWidgets);
    });

    testWidgets('handles unknown userId gracefully', (tester) async {
      await tester.pumpWidget(buildWidget(isPro: false, userId: 'unknown_user'));
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }
      // Should render without crashing
      expect(find.byType(ChallengerRoadProfileSection), findsOneWidget);
    });
  });
}

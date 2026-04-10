import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/tabs/Community.dart';
import 'package:tenthousandshotchallenge/main.dart' as main_globals;
import '../mock_firebase.dart';

void main() {
  group('Community', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;

    setUpAll(() async {
      await setupFirebaseAuthMocks();
      NetworkStatusService.isTestingOverride = true;
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

      FlutterError.onError = (details) {
        final msg = details.exception.toString();
        if (msg.contains('FirebaseException') || msg.contains('No Firebase App') || msg.contains('MissingPluginException') || msg.contains('RenderFlex overflowed') || msg.contains('setState')) return;
        FlutterError.dumpErrorToConsole(details);
      };
    });

    Widget buildWidget({
      CommunitySection section = CommunitySection.team,
      ValueChanged<CommunitySection>? onSectionChanged,
    }) {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Community(
              selectedSection: section,
              onSectionChanged: onSectionChanged ?? (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders TEAM tab label', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.text('TEAM'), findsOneWidget);
    });

    testWidgets('renders FRIENDS tab label', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.text('FRIENDS'), findsOneWidget);
    });

    testWidgets('shows team tab icon when team section selected', (tester) async {
      await tester.pumpWidget(buildWidget(section: CommunitySection.team));
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    });

    testWidgets('shows friends tab icon', (tester) async {
      await tester.pumpWidget(buildWidget(section: CommunitySection.friends));
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byIcon(Icons.people_rounded), findsOneWidget);
    });

    testWidgets('tapping FRIENDS tab calls onSectionChanged', (tester) async {
      CommunitySection? changed;
      await tester.pumpWidget(buildWidget(
        section: CommunitySection.team,
        onSectionChanged: (s) => changed = s,
      ));
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('FRIENDS'));
      await tester.pump();
      expect(changed, CommunitySection.friends);
    });

    testWidgets('tapping TEAM tab calls onSectionChanged', (tester) async {
      CommunitySection? changed;
      await tester.pumpWidget(buildWidget(
        section: CommunitySection.friends,
        onSectionChanged: (s) => changed = s,
      ));
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('TEAM'));
      await tester.pump();
      expect(changed, CommunitySection.team);
    });
  });
}

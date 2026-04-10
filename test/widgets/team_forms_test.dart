import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/tabs/team/CreateTeam.dart';
import 'package:tenthousandshotchallenge/tabs/team/JoinTeam.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditPuckCount.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/main.dart' as main_globals;
import '../mock_firebase.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() async {
    await setupFirebaseAuthMocks();
    NetworkStatusService.isTestingOverride = true;
    SharedPreferences.setMockInitialValues({});
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
      if (msg.contains('FirebaseException') || msg.contains('No Firebase App') || msg.contains('MissingPluginException') || msg.contains('RenderFlex overflowed') || msg.contains('PlatformException') || msg.contains('setState')) return;
      FlutterError.dumpErrorToConsole(details);
    };
  });

  // ── CreateTeam ────────────────────────────────────────────────────────────

  group('CreateTeam', () {
    Widget buildWidget() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(home: CreateTeam()),
      );
    }

    testWidgets('renders CreateTeam widget', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byType(CreateTeam), findsOneWidget);
    });

    testWidgets('shows BasicTitle in the Create Team app bar', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byType(BasicTitle), findsWidgets);
    });

    testWidgets('shows team name form field', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.textContaining('team name', findRichText: true), findsWidgets);
    });

    testWidgets('shows check (save) icon button', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('shows back arrow icon button', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byIcon(Icons.arrow_back), findsWidgets);
    });
  });

  // ── JoinTeam ──────────────────────────────────────────────────────────────

  group('JoinTeam', () {
    Widget buildWidget() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(home: JoinTeam()),
      );
    }

    testWidgets('renders JoinTeam widget', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byType(JoinTeam), findsOneWidget);
    });

    testWidgets('shows text input for team search', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows back arrow icon button', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byIcon(Icons.arrow_back), findsWidgets);
    });
  });

  // ── EditPuckCount ─────────────────────────────────────────────────────────

  group('EditPuckCount', () {
    Widget buildWidget() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
          ChangeNotifierProvider<PreferencesStateNotifier>(
            create: (_) => PreferencesStateNotifier(),
          ),
        ],
        child: const MaterialApp(home: EditPuckCount()),
      );
    }

    testWidgets('renders EditPuckCount widget', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byType(EditPuckCount), findsOneWidget);
    });

    testWidgets('shows BasicTitle in the puck count app bar', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byType(BasicTitle), findsWidgets);
    });

    testWidgets('shows text field for puck count', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows default puck count value (25)', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.text('25'), findsWidgets);
    });

    testWidgets('shows save check icon', (tester) async {
      await tester.pumpWidget(buildWidget());
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.byIcon(Icons.check), findsWidgets);
    });
  });
}

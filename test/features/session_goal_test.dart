import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/tabs/shots/StartShooting.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/main.dart' as main_globals;
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import '../mock_firebase.dart';
import '../widgets/shots_test.mocks.dart';

void main() {
  group('Session Goal (Feature 4)', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;
    late MockPanelController mockPanelController;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({
        'puck_count': 25,
        'dark_mode': false,
        'friend_notifications': true,
        'target_date': DateTime.now().add(const Duration(days: 100)).toIso8601String(),
        'fcm_token': 'mock_token',
      });
      main_globals.preferences = Preferences(
        false,
        25,
        true,
        DateTime.now().add(const Duration(days: 100)),
        null,
      );
      await setupFirebaseAuthMocks();
      NetworkStatusService.isTestingOverride = true;
    });

    setUp(() async {
      mockUser = MockUser(uid: 'test_uid', displayName: 'Test User', email: 'test@example.com');
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      if (mockAuth.currentUser == null) {
        await mockAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'password');
      }
      fakeFirestore = FakeFirebaseFirestore();
      mockPanelController = MockPanelController();
      when(mockPanelController.close()).thenAnswer((_) async {});
    });

    Widget buildWidget() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
          ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
          Provider<CustomerInfoNotifier?>.value(value: null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StartShooting(
                  sessionPanelController: mockPanelController,
                  shots: const [],
                ),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> pump(WidgetTester tester) async {
      for (int i = 0; i < 3; i++) {
        await tester.pump();
      }
    }

    testWidgets('shows "Set a session goal" prompt when no goal is set', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      expect(find.textContaining('Set a session goal', findRichText: true), findsOneWidget);
    });

    testWidgets('tapping session goal shows goal picker dialog', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      await tester.tap(find.textContaining('Set a session goal', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('Set Session Goal'), findsOneWidget);
    });

    testWidgets('goal picker dialog contains preset chips', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      await tester.tap(find.textContaining('Set a session goal', findRichText: true));
      await tester.pumpAndSettle();
      // Common preset chip values
      expect(find.widgetWithText(ActionChip, '100'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, '200'), findsOneWidget);
    });

    testWidgets('goal picker has Set Goal and Cancel buttons', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      await tester.tap(find.textContaining('Set a session goal', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('Set Goal'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('setting a goal shows progress bar', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      await tester.tap(find.textContaining('Set a session goal', findRichText: true));
      await tester.pumpAndSettle();
      // Tap the 100 chip to select it
      await tester.tap(find.widgetWithText(ActionChip, '100'));
      await tester.pump();
      // Confirm the goal
      await tester.tap(find.text('Set Goal'));
      await tester.pumpAndSettle();
      // Progress bar (LinearProgressIndicator) should now appear
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows "Goal: 0 / 100 shots" after setting goal', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      await tester.tap(find.textContaining('Set a session goal', findRichText: true));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, '100'));
      await tester.pump();
      await tester.tap(find.text('Set Goal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('0 / 100', findRichText: true), findsOneWidget);
    });

    testWidgets('Hands-Free Mode button is present', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      expect(find.textContaining('Hands-Free Mode', findRichText: true), findsOneWidget);
    });
  });
}

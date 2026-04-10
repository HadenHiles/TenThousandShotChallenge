import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/tabs/shots/StartShooting.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/ShotButton.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/main.dart' as main_globals;
import '../mock_firebase.dart';
import 'shots_test.mocks.dart';

@GenerateMocks([])
void main() {
  group('StartShooting Panel', () {
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
    });

    setUp(() async {
      mockUser = MockUser(
        uid: 'test_uid',
        displayName: 'Test User',
        email: 'test@example.com',
        photoURL: '',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      if (mockAuth.currentUser == null) {
        await mockAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'password');
      }
      fakeFirestore = FakeFirebaseFirestore();
      mockPanelController = MockPanelController();
      when(mockPanelController.close()).thenAnswer((_) async {});
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
          ChangeNotifierProvider<PreferencesStateNotifier>(
            create: (_) => PreferencesStateNotifier(),
          ),
          // CustomerInfoNotifier is nullable; provide null for free user
          Provider<CustomerInfoNotifier?>.value(value: null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              // StartShooting returns Expanded, so it needs a Column parent
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

    Future<void> pump(WidgetTester tester, [int times = 3]) async {
      for (int i = 0; i < times; i++) {
        await tester.pump();
      }
    }

    testWidgets('renders StartShooting panel', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.byType(StartShooting), findsOneWidget);
    });

    testWidgets('shows WRIST shot type button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.textContaining('WRIST', findRichText: true), findsOneWidget);
    });

    testWidgets('shows SNAP shot type button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.textContaining('SNAP', findRichText: true), findsOneWidget);
    });

    testWidgets('shows SLAP shot type button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.textContaining('SLAP', findRichText: true), findsOneWidget);
    });

    testWidgets('shows BACKHAND shot type button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.textContaining('BACKHAND', findRichText: true), findsOneWidget);
    });

    testWidgets('shows all 4 ShotTypeButton widgets', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.byType(ShotTypeButton), findsNWidgets(4));
    });

    testWidgets('WRIST is selected by default', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      final wristButtons = tester.widgetList<ShotTypeButton>(find.byType(ShotTypeButton));
      final wristButton = wristButtons.firstWhere((b) => b.type == 'wrist', orElse: () {
        fail('WRIST ShotTypeButton not found');
      });
      expect(wristButton.active, isTrue);
    });

    testWidgets('tapping SNAP changes selection', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      await tester.tap(find.textContaining('SNAP', findRichText: true));
      await pump(tester);
      final snapButtons = tester.widgetList<ShotTypeButton>(find.byType(ShotTypeButton));
      final snapButton = snapButtons.firstWhere((b) => b.type == 'snap', orElse: () {
        fail('SNAP ShotTypeButton not found');
      });
      expect(snapButton.active, isTrue);
    });

    testWidgets('puck count is visible', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.textContaining('25', findRichText: true), findsWidgets);
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/Settings.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import '../mock_firebase.dart';

void main() {
  group('Settings Screen', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUpAll(() async {
      NetworkStatusService.isTestingOverride = true;
      await setupFirebaseAuthMocks();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'dark_mode': false,
        'puck_count': 25,
        'friend_notifications': true,
        'target_date': DateTime.now().add(const Duration(days: 100)).toIso8601String(),
        'fcm_token': 'mock_token',
      });

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
      await fakeFirestore.collection('users').doc('test_uid').set({
        'id': 'test_uid',
        'display_name': 'Test User',
        'email': 'test@example.com',
        'photo_url': '',
        'public': true,
        'friend_notifications': true,
        'team_id': null,
        'fcm_token': 'mock_token',
      });
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
          ChangeNotifierProvider<PreferencesStateNotifier>(
            create: (_) => PreferencesStateNotifier(),
          ),
          // CustomerInfoNotifier is nullable in Settings; provide null for free user
          Provider<CustomerInfoNotifier?>.value(value: null),
        ],
        child: const MaterialApp(
          home: ProfileSettings(),
        ),
      );
    }

    Future<void> pumpForDuration(WidgetTester tester, [Duration duration = const Duration(milliseconds: 400)]) async {
      await tester.pump();
      await tester.pump();
      await tester.pump(duration);
    }

    testWidgets('renders Settings screen', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      expect(find.byType(ProfileSettings), findsOneWidget);
    });

    testWidgets('shows Settings title', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      // BasicTitle renders title.toUpperCase() = 'SETTINGS'
      expect(find.textContaining('SETTINGS', findRichText: true), findsOneWidget);
    });

    testWidgets('shows Dark Mode tile', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      expect(find.textContaining('Dark Mode', findRichText: true), findsOneWidget);
    });

    testWidgets('shows Logout tile', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      // Scroll down to bring the Account section into view
      await tester.dragUntilVisible(
        find.textContaining('Logout', findRichText: true),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      expect(find.textContaining('Logout', findRichText: true), findsOneWidget);
    });

    testWidgets('shows Edit Profile tile', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      await tester.dragUntilVisible(
        find.textContaining('Edit Profile', findRichText: true),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      expect(find.textContaining('Edit Profile', findRichText: true), findsOneWidget);
    });

    testWidgets('shows Subscription Level tile', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      expect(find.textContaining('Subscription Level', findRichText: true), findsOneWidget);
    });

    testWidgets('shows Public profile toggle', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      await tester.dragUntilVisible(
        find.textContaining('Public', findRichText: true),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      expect(find.textContaining('Public', findRichText: true), findsOneWidget);
    });

    testWidgets('shows Friend Notifications tile', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      await tester.dragUntilVisible(
        find.textContaining('Friend Session Notifications', findRichText: true),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      expect(find.textContaining('Friend Session Notifications', findRichText: true), findsOneWidget);
    });

    testWidgets('shows puck count tile', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      expect(find.textContaining('How many pucks', findRichText: true), findsOneWidget);
    });

    testWidgets('Dark Mode switch is present', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pumpForDuration(tester);
      // At least one switch widget (Dark Mode, Friend notifications, Public)
      expect(find.byType(Switch), findsWidgets);
    });
  });
}

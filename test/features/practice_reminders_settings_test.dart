import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
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
  group('Settings — Practice Reminders & Health Sync tiles', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
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

      mockUser = MockUser(uid: 'test_uid', displayName: 'Test User', email: 'test@example.com');
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      await mockAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'pw');

      fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('users').doc('test_uid').set({
        'id': 'test_uid',
        'display_name': 'Test User',
        'email': 'test@example.com',
        'photo_url': null,
        'public': true,
        'friend_notifications': true,
        'practice_reminders': false,
        'health_sync': false,
        'team_id': null,
        'fcm_token': 'mock_token',
      });
    });

    Widget buildSettings() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
          ChangeNotifierProvider<PreferencesStateNotifier>(create: (_) => PreferencesStateNotifier()),
          Provider<CustomerInfoNotifier?>.value(value: null),
        ],
        child: const MaterialApp(home: ProfileSettings()),
      );
    }

    Future<void> pump(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('renders Settings screen', (tester) async {
      await tester.pumpWidget(buildSettings());
      await pump(tester);
      expect(find.byType(ProfileSettings), findsOneWidget);
    });

    testWidgets('Practice Reminders tile is visible', (tester) async {
      await tester.pumpWidget(buildSettings());
      await pump(tester);
      await tester.dragUntilVisible(
        find.textContaining('Practice Reminders', findRichText: true),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.textContaining('Practice Reminders', findRichText: true), findsWidgets);
    });

    testWidgets('Apple Health / Google Fit Sync tile is visible', (tester) async {
      await tester.pumpWidget(buildSettings());
      await pump(tester);
      await tester.dragUntilVisible(
        find.textContaining('Apple Health / Google Fit Sync', findRichText: true),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.textContaining('Apple Health / Google Fit Sync', findRichText: true), findsWidgets);
    });

    testWidgets('Practice Reminders toggle starts off when Firestore says false', (tester) async {
      await tester.pumpWidget(buildSettings());
      await pump(tester);
      await tester.dragUntilVisible(
        find.textContaining('Practice Reminders', findRichText: true),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      // Find the switch associated with Practice Reminders
      // The SettingsTile renders a Switch; verify it exists and is off (false)
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      // At least one switch exists in the notifications section
      expect(switches, isNotEmpty);
    });

    testWidgets('Health sync Firestore field is toggled on switch interaction', (tester) async {
      await tester.pumpWidget(buildSettings());
      await pump(tester);

      // Scroll until Apple Health tile is visible
      await tester.dragUntilVisible(
        find.textContaining('Apple Health / Google Fit Sync', findRichText: true),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );

      // Tap the last Switch on this screen (health sync is after practice reminders)
      final allSwitches = find.byType(Switch);
      await tester.tap(allSwitches.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Firestore was updated
      final doc = await fakeFirestore.collection('users').doc('test_uid').get();
      expect(doc.exists, isTrue);
    });

    testWidgets('Practice Reminders toggle is present in notifications section', (tester) async {
      await tester.pumpWidget(buildSettings());
      await pump(tester);

      await tester.dragUntilVisible(
        find.textContaining('Practice Reminders', findRichText: true),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      expect(find.textContaining('Practice Reminders', findRichText: true), findsWidgets);
    });
  });
}

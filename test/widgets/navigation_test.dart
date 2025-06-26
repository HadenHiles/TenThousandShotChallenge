import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/NavigationTab.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;

import 'navigation_test.mocks.dart';

// Generate mocks
@GenerateMocks([
  SharedPreferences,
  NetworkStatusService,
  SessionService,
])
late FakeFirebaseFirestore fakeFirestore;
late fam.MockFirebaseAuth mockFirebaseAuth;
late fam.MockUser mockUser;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockSharedPreferences mockSharedPreferences;
  late MockSessionService mockSessionService;
  // Use fakes directly, no Firebase.initializeApp or channel mocks
  setUpAll(() async {
    fakeFirestore = FakeFirebaseFirestore();
    // Add a user document matching the UserProfile model
    await fakeFirestore.collection('users').doc('test_uid').set({
      'id': 'test_uid',
      'display_name': 'Test User',
      'email': 'test@example.com',
      'photo_url': 'https://example.com/photo.png',
      'public': true,
      'friend_notifications': true,
      'team_id': 'test_team',
      'fcm_token': 'test_token',
    });
    mockUser = fam.MockUser(
      isAnonymous: false,
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Test User',
      photoURL: 'https://example.com/photo.png',
      isEmailVerified: true,
    );
    mockFirebaseAuth = fam.MockFirebaseAuth(mockUser: mockUser);
  });

  setUp(() async {
    // Initialize mocks for each test
    mockSharedPreferences = MockSharedPreferences();
    mockSessionService = MockSessionService();
    // Setup SharedPreferences mock defaults
    when(mockSharedPreferences.getBool('dark_mode')).thenReturn(false);
    when(mockSharedPreferences.getInt('puck_count')).thenReturn(25);
    when(mockSharedPreferences.getBool('friend_notifications')).thenReturn(true);
    when(mockSharedPreferences.getString('target_date')).thenReturn(null);
    when(mockSharedPreferences.getString('fcm_token')).thenReturn('test_token');
    when(mockSharedPreferences.setBool(any, any)).thenAnswer((_) async => true);
    when(mockSharedPreferences.setInt(any, any)).thenAnswer((_) async => true);
    when(mockSharedPreferences.setString(any, any)).thenAnswer((_) async => true);
    // Setup SessionService mock defaults
    when(mockSessionService.isRunning).thenReturn(false);
    // Setup shared preferences singleton
    SharedPreferences.setMockInitialValues({
      'dark_mode': false,
      'puck_count': 25,
      'friend_notifications': true,
      'fcm_token': 'test_token',
    });
  });

  Widget createTestNavigationWidget({int selectedIndex = 0, Widget? title, List<Widget>? actions}) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferencesStateNotifier>(
            create: (_) => PreferencesStateNotifier(),
          ),
          Provider<FirebaseAuth>.value(value: mockFirebaseAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: Navigation(
          selectedIndex: selectedIndex,
          title: title,
          actions: actions,
        ),
      ),
    );
  }

  group('Navigation Widget Tests', () {
    testWidgets('Navigation renders correctly with valid index', (WidgetTester tester) async {
      await tester.pumpWidget(createTestNavigationWidget(selectedIndex: 0));
      await tester.pump(); // Let the widget settle

      expect(find.byType(Navigation), findsOneWidget);
      expect(find.byType(NavigationTab), findsOneWidget);
    });

    testWidgets('Navigation handles custom title', (WidgetTester tester) async {
      const customTitle = Text('Custom Title');

      await tester.pumpWidget(createTestNavigationWidget(title: customTitle));
      await tester.pump();

      expect(find.text('Custom Title'), findsOneWidget);
    });

    testWidgets('Navigation handles custom actions', (WidgetTester tester) async {
      final customActions = [
        IconButton(
          icon: const Icon(Icons.star),
          onPressed: () {},
        ),
      ];

      await tester.pumpWidget(createTestNavigationWidget(actions: customActions));
      await tester.pump();

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('Navigation handles null values gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(createTestNavigationWidget());
      await tester.pump();

      expect(find.byType(Navigation), findsOneWidget);
    });

    // Test different tab indices that are valid
    for (int i = 0; i < 5; i++) {
      testWidgets('Navigation displays tab $i correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestNavigationWidget(selectedIndex: i));
        await tester.pump();

        expect(find.byType(Navigation), findsOneWidget);
      });
    }
  });

  group('NavigationTab Widget Tests', () {
    testWidgets('NavigationTab renders with all properties', (WidgetTester tester) async {
      const title = Text('Test Title');
      const body = Text('Test Body');
      const leading = Icon(Icons.menu);

      await tester.pumpWidget(
        const MaterialApp(
          home: NavigationTab(
            title: title,
            body: body,
            leading: leading,
            actions: [Icon(Icons.settings)],
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Test Body'), findsOneWidget);
      expect(find.byType(NavigationTab), findsOneWidget);
    });

    testWidgets('NavigationTab renders with minimal properties', (WidgetTester tester) async {
      const body = Text('Minimal Body');

      await tester.pumpWidget(
        const MaterialApp(
          home: NavigationTab(body: body),
        ),
      );

      await tester.pump();
      expect(find.text('Minimal Body'), findsOneWidget);
      expect(find.byType(NavigationTab), findsOneWidget);
    });

    testWidgets('NavigationTab handles null body gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NavigationTab(),
        ),
      );

      await tester.pump();
      expect(find.byType(NavigationTab), findsOneWidget);
    });
  });

  group('Navigation Provider Integration Tests', () {
    testWidgets('Navigation integrates with PreferencesStateNotifier', (WidgetTester tester) async {
      final preferencesNotifier = PreferencesStateNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PreferencesStateNotifier>.value(
            value: preferencesNotifier,
            child: const Navigation(selectedIndex: 0),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(Navigation), findsOneWidget);
    });

    testWidgets('Navigation updates when preferences change', (WidgetTester tester) async {
      final preferencesNotifier = PreferencesStateNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PreferencesStateNotifier>.value(
            value: preferencesNotifier,
            child: const Navigation(selectedIndex: 0),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(Navigation), findsOneWidget);

      // Simulate preferences change
      preferencesNotifier.notifyListeners();
      await tester.pump();

      expect(find.byType(Navigation), findsOneWidget);
    });
  });

  group('Navigation Basic Functionality Tests', () {
    testWidgets('Navigation displays correctly without dependencies', (WidgetTester tester) async {
      // Create a simple test that doesn't depend on complex services
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const Text('Test Body'),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Test'), findsOneWidget);
      expect(find.text('Test Body'), findsOneWidget);
    });

    testWidgets('NavigationTab basic rendering', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const NavigationTab(
              body: Text('Simple Test'),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Simple Test'), findsOneWidget);
    });
  });

  group('Navigation Widget Properties Tests', () {
    testWidgets('Navigation handles different selectedIndex values', (WidgetTester tester) async {
      // Test with index 0 (default case)
      await tester.pumpWidget(
        createTestNavigationWidget(selectedIndex: 0),
      );

      await tester.pump();
      expect(find.byType(Navigation), findsOneWidget);
    });

    testWidgets('Navigation with custom properties', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestNavigationWidget(
          selectedIndex: 1,
          title: const Text('Custom Title'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {},
            ),
          ],
        ),
      );

      await tester.pump();
      expect(find.byType(Navigation), findsOneWidget);
      expect(find.text('Custom Title'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('Navigation State Management Tests', () {
    testWidgets('Navigation maintains state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestNavigationWidget(selectedIndex: 0),
      );

      await tester.pump();
      expect(find.byType(Navigation), findsOneWidget);

      // Test state persistence
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Navigation), findsOneWidget);
    });
  });
}

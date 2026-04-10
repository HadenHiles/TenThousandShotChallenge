import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/tabs/Explore.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/main.dart' as main_globals;
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import '../mock_firebase.dart';

void main() {
  group('Explore Screen', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUpAll(() async {
      // Explore.dart uses FirebaseFirestore.instance directly for content loading
      await setupFirebaseAuthMocks();
      // Prevent DataConnectionChecker from making real socket connections
      NetworkStatusService.isTestingOverride = true;
      main_globals.preferences = Preferences(
        false,
        25,
        true,
        DateTime.now().add(const Duration(days: 100)),
        null,
      );
    });

    setUp(() {
      FlutterError.onError = (details) {
        final msg = details.exception.toString();
        if (msg.contains('FirebaseException') || msg.contains('No Firebase App') || msg.contains('RenderFlex overflowed') || msg.contains('video_player') || msg.contains('MissingPluginException') || msg.contains('PlatformException') || msg.contains('NetworkException') || msg.contains('TimeoutException')) return;
        FlutterError.dumpErrorToConsole(details);
      };
      mockUser = MockUser(
        uid: 'test_uid',
        displayName: 'Test User',
        email: 'test@example.com',
        photoURL: '',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      fakeFirestore = FakeFirebaseFirestore();
    });

    tearDown(() {
      FlutterError.onError = FlutterError.presentError;
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(home: Scaffold(body: Explore())),
      );
    }

    /// Advance fake time past all Firestore timeouts (max is 30s for merch)
    /// so no timers are left pending at teardown.
    Future<void> drainTimers(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 31));
    }

    testWidgets('renders Explore screen', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await drainTimers(tester);
      expect(find.byType(Explore), findsOneWidget);
    });

    testWidgets('shows explore_tab_body key', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await drainTimers(tester);
      expect(find.byKey(const Key('explore_tab_body')), findsOneWidget);
    });

    testWidgets('shows tab bar with navigation tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await drainTimers(tester);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('shows TRAIN tab label', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await drainTimers(tester);
      expect(find.textContaining('TRAIN', findRichText: true), findsWidgets);
    });
  });
}

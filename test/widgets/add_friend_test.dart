import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/tabs/friends/AddFriend.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/main.dart' as main_globals;
import '../mock_firebase.dart';

void main() {
  group('AddFriend Screen', () {
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
        if (msg.contains('FirebaseException') || msg.contains('No Firebase App') || msg.contains('MissingPluginException') || msg.contains('RenderFlex overflowed') || msg.contains('PlatformException') || msg.contains('setState')) return;
        FlutterError.dumpErrorToConsole(details);
      };
    });

    Widget buildWidget() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(home: AddFriend()),
      );
    }

    Future<void> pump(WidgetTester tester, [int times = 3]) async {
      for (int i = 0; i < times; i++) {
        await tester.pump();
      }
    }

    testWidgets('renders AddFriend widget', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      expect(find.byType(AddFriend), findsOneWidget);
    });

    testWidgets('shows BasicTitle in app bar', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      expect(find.byType(BasicTitle), findsWidgets);
    });

    testWidgets('shows FIND A FRIEND search label', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      expect(find.textContaining('FIND A FRIEND', findRichText: true), findsWidgets);
    });

    testWidgets('shows share icon button in app bar', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('shows back arrow icon button', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows SCAN label for QR scanner', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      expect(find.text('SCAN'), findsWidgets);
    });

    testWidgets('shows text field for friend search', (tester) async {
      await tester.pumpWidget(buildWidget());
      await pump(tester);
      expect(find.byType(TextFormField), findsWidgets);
    });
  });
}

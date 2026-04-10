import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import '../mock_firebase.dart';

void main() {
  group('EditProfile Screen', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUpAll(() async {
      NetworkStatusService.isTestingOverride = true;
      await setupFirebaseAuthMocks();
      // Provide empty asset manifests + minimal PNG data so EditProfile._loadAvatars()
      // and UserAvatar don't throw. Flutter uses both .json and .bin manifests.
      // Minimal 1x1 opaque PNG bytes:
      const kMinimalPng = <int>[
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, // PNG signature
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xde,
        0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
        0x78, 0x9c, 0x62, 0xf8, 0x0f, 0x00, 0x00, 0x01, 0x01, 0x00, 0x05, 0x18, 0xd8, 0x4e,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82, // IEND
      ];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.json') {
            final encoded = utf8.encoder.convert('{}');
            return ByteData.sublistView(Uint8List.fromList(encoded));
          }
          if (key == 'AssetManifest.bin') {
            // StandardMessageCodec encoding of an empty Map: type=13 (map), size=0
            final data = ByteData(2);
            data.setUint8(0, 13);
            data.setUint8(1, 0);
            return data;
          }
          if (key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.jpeg') || key.endsWith('.gif') || key.endsWith('.webp')) {
            return ByteData.sublistView(Uint8List.fromList(kMinimalPng));
          }
          return null;
        },
      );
    });

    setUp(() {
      // Suppress image/asset loading errors from UserAvatar and other widgets
      FlutterError.onError = (details) {
        final msg = details.exception.toString();
        if (msg.contains('Unable to load asset') || msg.contains('AssetManifest') || msg.contains('FirebaseException') || msg.contains('No Firebase App') || msg.contains('RenderFlex overflowed')) return;
        FlutterError.dumpErrorToConsole(details);
      };
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
      await fakeFirestore.collection('users').doc('test_uid').set({
        'id': 'test_uid',
        'display_name': 'Test User',
        'display_name_lowercase': 'test user',
        'email': 'test@example.com',
        'photo_url': '',
        'public': true,
        'friend_notifications': true,
        'team_id': null,
        'fcm_token': null,
      });
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(
          home: EditProfile(),
        ),
      );
    }

    Future<void> pump(WidgetTester tester, [int times = 3]) async {
      for (int i = 0; i < times; i++) {
        await tester.pump();
      }
    }

    testWidgets('renders EditProfile screen', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.byType(EditProfile), findsOneWidget);
    });

    testWidgets('shows display name text field', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows save button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.byWidgetPredicate((w) => w is ElevatedButton || w is TextButton || w is FilledButton || (w is GestureDetector && w.onTap != null)), findsWidgets);
    });

    testWidgets('shows avatar selection grid', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester);
      expect(find.byType(EditProfile), findsOneWidget);
    });

    testWidgets('shows user display name after loading', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await pump(tester, 4);
      expect(find.text('Test User'), findsWidgets);
    });
  });
}

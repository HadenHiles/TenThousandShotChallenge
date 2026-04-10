import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/tabs/profile/AchievementsScreen.dart';
import 'package:tenthousandshotchallenge/tabs/profile/AccuracyScreen.dart';
import '../mock_firebase.dart';

void main() {
  group('AchievementsScreen', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUpAll(() async {
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
    });

    Widget createAchievementsWidget() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(home: AchievementsScreen()),
      );
    }

    Future<void> pump(WidgetTester tester, [int times = 3]) async {
      for (int i = 0; i < times; i++) {
        await tester.pump();
      }
    }

    testWidgets('renders AchievementsScreen', (WidgetTester tester) async {
      await tester.pumpWidget(createAchievementsWidget());
      await pump(tester);
      expect(find.byType(AchievementsScreen), findsOneWidget);
    });

    testWidgets('shows ACHIEVEMENTS title', (WidgetTester tester) async {
      await tester.pumpWidget(createAchievementsWidget());
      await pump(tester);
      expect(find.textContaining('ACHIEVEMENTS', findRichText: true), findsOneWidget);
    });

    testWidgets('shows a scrollable content area', (WidgetTester tester) async {
      await tester.pumpWidget(createAchievementsWidget());
      await pump(tester);
      expect(find.byType(Scrollable), findsWidgets);
    });
  });

  group('AccuracyScreen', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUpAll(() async {
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

      final now = DateTime.now();
      await fakeFirestore.collection('iterations').doc('test_uid').collection('iterations').doc('iteration1').set({
        'id': 'iteration1',
        'start_date': Timestamp.fromDate(now.subtract(const Duration(days: 10))),
        'target_date': Timestamp.fromDate(now.add(const Duration(days: 20))),
        'end_date': null,
        'total': 100,
        'total_wrist': 40,
        'total_snap': 30,
        'total_slap': 20,
        'total_backhand': 10,
        'complete': false,
        'updated_at': Timestamp.now(),
      });
    });

    Widget createAccuracyWidget() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(home: AccuracyScreen()),
      );
    }

    Future<void> pump(WidgetTester tester, [int times = 3]) async {
      for (int i = 0; i < times; i++) {
        await tester.pump();
      }
    }

    testWidgets('renders AccuracyScreen', (WidgetTester tester) async {
      await tester.pumpWidget(createAccuracyWidget());
      await pump(tester);
      expect(find.byType(AccuracyScreen), findsOneWidget);
    });

    testWidgets('shows Shot Accuracy title text', (WidgetTester tester) async {
      await tester.pumpWidget(createAccuracyWidget());
      await pump(tester);
      expect(find.textContaining('ACCURACY', findRichText: true), findsWidgets);
    });

    testWidgets('shows scrollable content area', (WidgetTester tester) async {
      await tester.pumpWidget(createAccuracyWidget());
      await pump(tester);
      expect(find.byType(Scrollable), findsWidgets);
    });
  });
}

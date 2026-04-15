import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/widgets/ActivityCalendar.dart';
import '../mock_firebase.dart';

void main() {
  group('ActivityCalendar widget', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUpAll(() async {
      await setupFirebaseAuthMocks();
    });

    setUp(() async {
      mockUser = MockUser(uid: 'uid_cal', displayName: 'Cal User', email: 'cal@test.com');
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      await mockAuth.signInWithEmailAndPassword(email: 'cal@test.com', password: 'pw');
      fakeFirestore = FakeFirebaseFirestore();
    });

    Widget buildWidget() {
      return MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: fakeFirestore),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ActivityCalendar())),
        ),
      );
    }

    testWidgets('renders without crashing (no data)', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byType(ActivityCalendar), findsOneWidget);
    });

    testWidgets('shows streak labels after load', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.textContaining('streak', findRichText: true), findsWidgets);
    });

    testWidgets('reflects session data — shows non-zero streak on training day', (tester) async {
      // Insert today's session into fakeFirestore
      final today = DateTime.now();
      final iterRef = fakeFirestore.collection('iterations').doc('uid_cal').collection('iterations').doc('iter1');
      await iterRef.set({'complete': false});
      await iterRef.collection('sessions').add({
        'date': Timestamp.fromDate(today),
        'total': 200,
      });

      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Current streak should be at least 1 (today)
      expect(find.textContaining('1', findRichText: true), findsWidgets);
    });

    testWidgets('shows month labels', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      // Month abbreviations should appear (Jan–Dec)
      final monthPattern = RegExp(r'Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec');
      final texts = tester.widgetList<Text>(find.byType(Text));
      final hasMonth = texts.any((t) => monthPattern.hasMatch(t.data ?? ''));
      expect(hasMonth, isTrue);
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import '../mock_firebase.dart';

void main() {
  group('recalculateIterationTotals', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUpAll(() async {
      await setupFirebaseAuthMocks();
    });

    setUp(() async {
      mockUser = MockUser(uid: 'test_user_recalc', displayName: 'Recalc User', email: 'recalc@example.com');
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      if (mockAuth.currentUser == null) {
        await mockAuth.signInWithEmailAndPassword(email: 'recalc@example.com', password: 'password');
      }
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('recalculates totals across sessions with and without shots subcollections', () async {
      const uid = 'test_user_recalc';
      final iterRef = fakeFirestore.collection('iterations').doc(uid).collection('iterations').doc('iter_1');

      // Iteration initially has wrong/outdated total (e.g. 0)
      await iterRef.set({
        'id': 'iter_1',
        'start_date': Timestamp.fromDate(DateTime(2026, 6, 1)),
        'target_date': Timestamp.fromDate(DateTime(2026, 9, 1)),
        'end_date': null,
        'total_duration': 0,
        'total': 0,
        'total_wrist': 0,
        'total_snap': 0,
        'total_slap': 0,
        'total_backhand': 0,
        'complete': false,
        'updated_at': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });

      // Session 1: Has shots subcollection (100 wrist shots)
      final session1Ref = iterRef.collection('sessions').doc('session_1');
      await session1Ref.set({
        'id': 'session_1',
        'total': 100,
        'total_wrist': 100,
        'total_snap': 0,
        'total_slap': 0,
        'total_backhand': 0,
        'date': Timestamp.fromDate(DateTime(2026, 6, 10)),
        'duration': 600, // 10 minutes
      });
      await session1Ref.collection('shots').doc('0').set({
        'type': 'wrist',
        'count': 100,
      });

      // Session 2: Does NOT have shots subcollection (e.g. offline synced session: 50 slap, 25 backhand)
      final session2Ref = iterRef.collection('sessions').doc('session_2');
      await session2Ref.set({
        'id': 'session_2',
        'total': 75,
        'total_wrist': 0,
        'total_snap': 0,
        'total_slap': 50,
        'total_backhand': 25,
        'date': Timestamp.fromDate(DateTime(2026, 6, 11)),
        'duration': 900, // 15 minutes
      });

      // Session 3: Has shots subcollection with multiple shot types (40 snap, 10 wrist)
      final session3Ref = iterRef.collection('sessions').doc('session_3');
      await session3Ref.set({
        'id': 'session_3',
        'total': 50,
        'total_wrist': 10,
        'total_snap': 40,
        'total_slap': 0,
        'total_backhand': 0,
        'date': Timestamp.fromDate(DateTime(2026, 6, 12)),
        'duration': 300, // 5 minutes
      });
      await session3Ref.collection('shots').doc('0').set({
        'type': 'snap',
        'count': 40,
      });
      await session3Ref.collection('shots').doc('1').set({
        'type': 'wrist',
        'count': 10,
      });

      final success = await recalculateIterationTotals(mockAuth, fakeFirestore);
      expect(success, isTrue);

      final updatedIterDoc = await iterRef.get();
      final data = updatedIterDoc.data()!;

      expect(data['total'], equals(225)); // 100 + 75 + 50
      expect(data['total_wrist'], equals(110)); // 100 + 0 + 10
      expect(data['total_snap'], equals(40)); // 0 + 0 + 40
      expect(data['total_slap'], equals(50)); // 0 + 50 + 0
      expect(data['total_backhand'], equals(25)); // 0 + 25 + 0
      expect(data['total_duration'], equals(1800)); // 600 + 900 + 300
    });

    test('returns false if auth user is not logged in', () async {
      final unauth = MockFirebaseAuth();
      final result = await recalculateIterationTotals(unauth, fakeFirestore);
      expect(result, isFalse);
    });
  });
}

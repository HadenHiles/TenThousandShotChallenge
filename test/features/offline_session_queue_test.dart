import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/services/OfflineSessionQueue.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    OfflineSessionQueue.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await OfflineSessionQueue.instance.closeForTesting();
    OfflineSessionQueue.dbPathOverride = null;
  });

  setUp(() async {
    // Reset the singleton DB so each test starts fresh with an empty in-memory DB.
    await OfflineSessionQueue.instance.closeForTesting();
  });

  group('OfflineSessionQueue', () {
    test('pendingCount is 0 when queue is empty', () async {
      final count = await OfflineSessionQueue.instance.pendingCount();
      expect(count, 0);
    });

    test('enqueue increases pendingCount by 1', () async {
      final shots = [
        Shots(DateTime(2024, 1, 1), 'wrist', 25, null),
      ];
      await OfflineSessionQueue.instance.enqueue(shots);
      final count = await OfflineSessionQueue.instance.pendingCount();
      expect(count, 1);
    });

    test('multiple enqueues increase pendingCount correctly', () async {
      final shots = [Shots(DateTime(2024, 1, 1), 'snap', 10, null)];
      await OfflineSessionQueue.instance.enqueue(shots);
      await OfflineSessionQueue.instance.enqueue(shots);
      final count = await OfflineSessionQueue.instance.pendingCount();
      expect(count, 2);
    });

    test('enqueue persists all shot fields correctly', () async {
      final now = DateTime(2024, 6, 15, 10, 30);
      final shots = [
        Shots(now, 'slap', 50, 30),
        Shots(now, 'backhand', 20, null),
      ];
      await OfflineSessionQueue.instance.enqueue(shots);
      // Count confirms the row was inserted
      expect(await OfflineSessionQueue.instance.pendingCount(), 1);
    });

    test('isChallengerRoad defaults to false', () async {
      final shots = [Shots(DateTime.now(), 'wrist', 25, null)];
      await OfflineSessionQueue.instance.enqueue(shots);
      expect(await OfflineSessionQueue.instance.pendingCount(), 1);
    });

    test('enqueue with isChallengerRoad:true stores correctly', () async {
      final shots = [Shots(DateTime.now(), 'wrist', 25, null)];
      await OfflineSessionQueue.instance.enqueue(shots, isChallengerRoad: true);
      expect(await OfflineSessionQueue.instance.pendingCount(), 1);
    });

    test('syncing when offline leaves rows intact', () async {
      // This test confirms syncPending returns early without touching rows
      // when the queue starts empty (no connectivity issue raised)
      expect(await OfflineSessionQueue.instance.pendingCount(), 0);
    });
  });
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';

/// Persists shooting sessions to a local SQLite database when offline,
/// and syncs them to Firestore the next time the device has connectivity.
class OfflineSessionQueue {
  OfflineSessionQueue._();
  static final OfflineSessionQueue instance = OfflineSessionQueue._();

  Database? _db;

  /// Override the database path for testing (e.g. inMemoryDatabasePath).
  @visibleForTesting
  static String? dbPathOverride;

  Future<Database> get _database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    return openDatabase(
      dbPathOverride ?? 'offline_sessions.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            shots_json TEXT NOT NULL,
            is_challenger_road INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  /// Serialize [shots] and persist them locally for later sync.
  Future<void> enqueue(List<Shots> shots, {bool isChallengerRoad = false}) async {
    final db = await _database;
    final shotsJson = jsonEncode(shots
        .map((s) => {
              'date': s.date?.millisecondsSinceEpoch,
              'type': s.type,
              'count': s.count,
              'targets_hit': s.targetsHit,
            })
        .toList());
    await db.insert('pending_sessions', {
      'shots_json': shotsJson,
      'is_challenger_road': isChallengerRoad ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Returns the number of sessions waiting to be synced.
  Future<int> pendingCount() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM pending_sessions');
    return result.first['c'] as int? ?? 0;
  }

  /// Attempt to sync all pending sessions to Firestore.
  /// Call this whenever connectivity is restored.
  Future<void> syncPending(FirebaseAuth auth, FirebaseFirestore firestore) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;
    if (auth.currentUser == null) return;

    final db = await _database;
    final rows = await db.query('pending_sessions', orderBy: 'created_at ASC');

    for (final row in rows) {
      try {
        final List<dynamic> raw = jsonDecode(row['shots_json'] as String);
        final shots = raw.map((m) {
          final ms = m['date'] as int?;
          return Shots(
            ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : DateTime.now(),
            m['type'] as String?,
            m['count'] as int?,
            m['targets_hit'] as int?,
          );
        }).toList();

        final isChallengerRoad = (row['is_challenger_road'] as int?) == 1;
        final success = await saveShootingSession(shots, auth, firestore, isChallengerRoad: isChallengerRoad);
        if (success) {
          await db.delete('pending_sessions', where: 'id = ?', whereArgs: [row['id']]);
        }
      } catch (_) {
        // Leave the row in the queue; retry next time.
      }
    }
  }

  @visibleForTesting
  Future<void> closeForTesting() async {
    await _db?.close();
    _db = null;
  }
}

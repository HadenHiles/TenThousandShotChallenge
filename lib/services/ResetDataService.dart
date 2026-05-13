import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles destructive reset operations for user data.
///
/// Firestore does not support recursive collection deletion from the client;
/// this service deletes documents in batches of [_batchSize] to stay safely
/// under the 500-operation Firestore batch limit.
///
/// Team shot counts are deliberately left untouched by all operations here.
/// Team totals are derived at read-time from each member's session data, so
/// they will naturally reflect the reset the next time the team tab loads.
class ResetDataService {
  static const int _batchSize = 400;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ResetDataService(this._firestore, this._auth);

  String get _uid => _auth.currentUser!.uid;

  // ---------------------------------------------------------------------------
  // Option 1 – Restart current challenge
  // ---------------------------------------------------------------------------

  /// Deletes all non–Challenger Road sessions from the current (incomplete)
  /// iteration and resets the iteration totals to zero.
  ///
  /// Sessions with [is_challenger_road == true] are preserved as documents but
  /// NOT counted in the iteration totals (per product spec: "exclude any
  /// challenger road sessions from the new count but don't delete those").
  ///
  /// The global trophy counters (all_time_total, all_time_sessions, etc.) are
  /// decremented by the deleted session totals so that future trophy evaluation
  /// runs against an accurate baseline rather than inflated counts.
  Future<void> restartCurrentChallenge() async {
    // Find the current incomplete iteration.
    final iterSnap = await _firestore.collection('iterations').doc(_uid).collection('iterations').where('complete', isEqualTo: false).get();

    if (iterSnap.docs.isEmpty) return;

    final iterDoc = iterSnap.docs.first;

    // Fetch all sessions under this iteration.
    final sessionsSnap = await iterDoc.reference.collection('sessions').get();

    // Collect non-CR sessions and accumulate their totals for counter adjustment.
    int deletedTotal = 0;
    int deletedWrist = 0;
    int deletedSnap = 0;
    int deletedSlap = 0;
    int deletedBackhand = 0;
    int deletedSessionCount = 0;

    final nonCrDocs = sessionsSnap.docs.where((doc) {
      final data = doc.data();
      return data['is_challenger_road'] != true;
    }).toList();

    for (final doc in nonCrDocs) {
      final data = doc.data();
      deletedTotal += (data['total'] as num?)?.toInt() ?? 0;
      deletedWrist += (data['total_wrist'] as num?)?.toInt() ?? 0;
      deletedSnap += (data['total_snap'] as num?)?.toInt() ?? 0;
      deletedSlap += (data['total_slap'] as num?)?.toInt() ?? 0;
      deletedBackhand += (data['total_backhand'] as num?)?.toInt() ?? 0;
      deletedSessionCount++;
    }

    // Delete the shots sub-collection under each session, then the session itself.
    for (final doc in nonCrDocs) {
      await _deleteSessionWithShots(doc.reference);
    }

    // Zero out the iteration totals.
    await iterDoc.reference.update({
      'total': 0,
      'total_wrist': 0,
      'total_snap': 0,
      'total_slap': 0,
      'total_backhand': 0,
      'total_duration': 0,
      'start_date': DateTime.now(),
      'end_date': null,
      'complete': false,
      'updated_at': DateTime.now(),
    });

    // Decrement global trophy counters so future trophy evaluation uses an
    // accurate baseline instead of inflated counts that include deleted sessions.
    if (deletedSessionCount > 0) {
      final globalRef = _firestore.collection('users').doc(_uid).collection('global_trophies').doc('summary');
      final globalSnap = await globalRef.get();
      if (globalSnap.exists) {
        final d = globalSnap.data()!;
        final safeInt = (String key) => (d[key] as num?)?.toInt() ?? 0;
        await globalRef.update({
          'all_time_total': (safeInt('all_time_total') - deletedTotal).clamp(0, double.maxFinite.toInt()),
          'all_time_wrist': (safeInt('all_time_wrist') - deletedWrist).clamp(0, double.maxFinite.toInt()),
          'all_time_snap': (safeInt('all_time_snap') - deletedSnap).clamp(0, double.maxFinite.toInt()),
          'all_time_slap': (safeInt('all_time_slap') - deletedSlap).clamp(0, double.maxFinite.toInt()),
          'all_time_backhand': (safeInt('all_time_backhand') - deletedBackhand).clamp(0, double.maxFinite.toInt()),
          'all_time_sessions': (safeInt('all_time_sessions') - deletedSessionCount).clamp(0, double.maxFinite.toInt()),
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Option 2 – Reset all trophies
  // ---------------------------------------------------------------------------

  /// Clears all earned trophies (global and Challenger Road) and resets all
  /// trophy-related tracking counters.  Session history is left intact.
  Future<void> resetAllTrophies() async {
    final batch = _firestore.batch();

    // Global trophies summary
    final globalRef = _firestore.collection('users').doc(_uid).collection('global_trophies').doc('summary');

    final globalSnap = await globalRef.get();
    if (globalSnap.exists) {
      batch.update(globalRef, {
        'trophies': [],
        'featured_trophies': [],
        'all_time_total': 0,
        'all_time_wrist': 0,
        'all_time_snap': 0,
        'all_time_slap': 0,
        'all_time_backhand': 0,
        'all_time_sessions': 0,
        'current_week_total': 0,
        'current_week_days': [],
        'week_streak': 0,
        'early_morning_sessions': 0,
        'late_night_sessions': 0,
        'consecutive_weekend_count': 0,
        'current_accuracy_streak': 0,
        'tracking_started_at': null,
        'current_week_start': null,
        'backfill_version': null,
      });
    }

    // Challenger Road summary – clear badges only, preserve attempt stats.
    final crRef = _firestore.collection('users').doc(_uid).collection('challenger_road').doc('summary');

    final crSnap = await crRef.get();
    if (crSnap.exists) {
      batch.update(crRef, {
        'badges': [],
        'featured_badges': [],
      });
    }

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Option 3 – Erase all Challenger Road data
  // ---------------------------------------------------------------------------

  /// Deletes all Challenger Road attempts (and their sub-collections), clears
  /// the per-challenge all-time history, and resets the CR user summary.
  ///
  /// CR sessions that were also saved as regular [ShootingSession] records under
  /// the iterations tree are left in place - those represent real shots taken
  /// and continue to count toward the regular challenge totals.
  ///
  /// Any Challenger Road trophy IDs featured in the global trophy summary are
  /// also removed because they would no longer be valid.
  Future<void> eraseAllChallengerRoad() async {
    final attemptsRef = _firestore.collection('users').doc(_uid).collection('challenger_road_attempts');

    final attemptsSnap = await attemptsRef.get();

    for (final attemptDoc in attemptsSnap.docs) {
      // Delete challenge_sessions sub-collection.
      final sessionsSnap = await attemptDoc.reference.collection('challenge_sessions').get();
      await _deleteDocs(sessionsSnap.docs.map((d) => d.reference).toList());

      // Delete challenge_progress sub-collection.
      final progressSnap = await attemptDoc.reference.collection('challenge_progress').get();
      await _deleteDocs(progressSnap.docs.map((d) => d.reference).toList());
    }

    // Delete the attempt documents themselves.
    await _deleteDocs(attemptsSnap.docs.map((d) => d.reference).toList());

    // Delete cross-attempt challenge history.
    final historySnap = await _firestore.collection('users').doc(_uid).collection('challenger_road_challenge_history').get();
    await _deleteDocs(historySnap.docs.map((d) => d.reference).toList());

    // Reset the CR user summary.
    final crSummaryRef = _firestore.collection('users').doc(_uid).collection('challenger_road').doc('summary');

    final crSnap = await crSummaryRef.get();
    if (crSnap.exists) {
      await crSummaryRef.set({
        'current_attempt_id': null,
        'total_attempts': 0,
        'all_time_best_level': 0,
        'all_time_best_level_shots': null,
        'all_time_total_challenger_road_shots': 0,
        'badges': [],
        'featured_badges': [],
      });
    }

    // Remove any CR-sourced trophy IDs from the global featured trophies list.
    // Because CR badge IDs and global trophy IDs share the same featured list we
    // clear featured_trophies entirely after erasing all CR data.
    final globalRef = _firestore.collection('users').doc(_uid).collection('global_trophies').doc('summary');

    final globalSnap = await globalRef.get();
    if (globalSnap.exists) {
      await globalRef.update({'featured_trophies': []});
    }
  }

  // ---------------------------------------------------------------------------
  // Option 4 – Erase all shooting data (clean slate)
  // ---------------------------------------------------------------------------

  /// Deletes every iteration and all its sessions, resets both trophy
  /// summaries, and erases all Challenger Road data.
  Future<void> eraseAllShootingData() async {
    // 1. Delete all iterations, their sessions, and the shots sub-collections
    //    nested under each session.
    final iterationsSnap = await _firestore.collection('iterations').doc(_uid).collection('iterations').get();

    for (final iterDoc in iterationsSnap.docs) {
      final sessionsSnap = await iterDoc.reference.collection('sessions').get();
      for (final sessionDoc in sessionsSnap.docs) {
        await _deleteSessionWithShots(sessionDoc.reference);
      }
    }

    await _deleteDocs(iterationsSnap.docs.map((d) => d.reference).toList());

    // 2. Reset global trophy summary.
    final globalRef = _firestore.collection('users').doc(_uid).collection('global_trophies').doc('summary');

    final globalSnap = await globalRef.get();
    if (globalSnap.exists) {
      await globalRef.set({
        'trophies': [],
        'featured_trophies': [],
        'all_time_total': 0,
        'all_time_wrist': 0,
        'all_time_snap': 0,
        'all_time_slap': 0,
        'all_time_backhand': 0,
        'all_time_sessions': 0,
        'current_week_total': 0,
        'current_week_days': [],
        'week_streak': 0,
        'early_morning_sessions': 0,
        'late_night_sessions': 0,
        'consecutive_weekend_count': 0,
        'current_accuracy_streak': 0,
        'tracking_started_at': null,
        'current_week_start': null,
        'backfill_version': null,
      });
    }

    // 3. Erase all Challenger Road data (reuses the dedicated method).
    await eraseAllChallengerRoad();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Deletes the `shots` sub-collection of a session document and then deletes
  /// the session document itself.  Firestore does not auto-delete sub-collections
  /// when a parent document is deleted, so this must be done explicitly.
  Future<void> _deleteSessionWithShots(DocumentReference sessionRef) async {
    final shotsSnap = await sessionRef.collection('shots').get();
    await _deleteDocs(shotsSnap.docs.map((d) => d.reference).toList());
    await sessionRef.delete();
  }

  /// Deletes a list of document references in batches of [_batchSize].
  Future<void> _deleteDocs(List<DocumentReference> refs) async {
    for (int i = 0; i < refs.length; i += _batchSize) {
      final chunk = refs.skip(i).take(_batchSize).toList();
      final batch = _firestore.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}

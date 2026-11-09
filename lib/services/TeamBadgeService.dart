import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tenthousandshotchallenge/models/TeamBadge.dart';

class TeamBadgeService {
  TeamBadgeService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<TeamBadgeAwards> watchAwards(String teamId) {
    return _firestore.collection('team_badge_awards').where('team_id', isEqualTo: teamId).snapshots().map(
          (snap) => TeamBadgeAwards.fromDocs(snap.docs.map((d) => d.data())),
        );
  }

  /// Awards (or, with [remove], takes back) today's badge. Returns an error
  /// message to show the coach, or null on success.
  Future<String?> setAward({
    required String teamId,
    required String playerId,
    required String badgeId,
    bool remove = false,
  }) async {
    try {
      final result = await _functions.httpsCallable('awardTeamBadge').call({
        'teamId': teamId,
        'playerId': playerId,
        'badgeId': badgeId,
        'day': TeamBadgeAwards.dayKey(),
        'remove': remove,
      });
      final data = result.data;
      if (data is Map && data['success'] == false) {
        return (data['message'] as String?) ?? 'Could not update badge.';
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') return e.message ?? 'You do not have permission to award badges.';
      return 'Could not update badge. Please try again.';
    } catch (_) {
      return 'Could not update badge. Please try again.';
    }
  }
}

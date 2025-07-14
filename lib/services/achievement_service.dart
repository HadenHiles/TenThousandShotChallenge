import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore/Achievement.dart';

class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Achievement>> getWeeklyAchievements(String userId) async {
    final snapshot = await _firestore.collection('user_achievements').where('user_id', isEqualTo: userId).where('time_frame', isEqualTo: 'week').orderBy('date_assigned', descending: true).limit(4).get();
    return snapshot.docs.map((doc) => Achievement.fromFirestore(doc)).toList();
  }

  Future<void> assignWeeklyAchievements(String userId, List<Achievement> achievements) async {
    final batch = _firestore.batch();
    for (var achievement in achievements) {
      final docRef = _firestore.collection('user_achievements').doc();
      batch.set(docRef, achievement.toFirestore());
    }
    await batch.commit();
  }

  Future<void> updateAchievementProgress(String achievementId, Map<String, dynamic> updates) async {
    await _firestore.collection('user_achievements').doc(achievementId).update(updates);
  }

  Future<void> completeAchievement(String achievementId) async {
    await _firestore.collection('user_achievements').doc(achievementId).update({
      'completed': true,
      'date_completed': Timestamp.now(),
    });
  }

  Future<List<Achievement>> getAchievementHistory(String userId) async {
    final snapshot = await _firestore.collection('user_achievements').where('user_id', isEqualTo: userId).orderBy('date_assigned', descending: true).get();
    return snapshot.docs.map((doc) => Achievement.fromFirestore(doc)).toList();
  }
}

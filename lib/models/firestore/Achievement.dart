import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String shotType;
  final String goalType; // e.g., 'count', 'accuracy'
  final int goalValue;
  final String difficulty; // Easy, Hard, Hardest, Impossible
  final String timeFrame; // e.g., 'week'
  final bool completed;
  final Timestamp dateAssigned;
  final Timestamp? dateCompleted;
  final String userId;
  final bool proLevel;
  final bool isBonus;

  final int? improvement;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.shotType,
    required this.goalType,
    required this.goalValue,
    required this.difficulty,
    required this.timeFrame,
    required this.completed,
    required this.dateAssigned,
    this.dateCompleted,
    required this.userId,
    required this.proLevel,
    required this.isBonus,
    this.improvement,
  });

  factory Achievement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Achievement(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      shotType: data['shot_type'] ?? '',
      goalType: data['goal_type'] ?? '',
      goalValue: data['goal_value'] ?? 0,
      difficulty: data['difficulty'] ?? 'Easy',
      timeFrame: data['time_frame'] ?? 'week',
      completed: data['completed'] ?? false,
      dateAssigned: data['date_assigned'] ?? Timestamp.now(),
      dateCompleted: data['date_completed'],
      userId: data['user_id'] ?? '',
      proLevel: data['pro_level'] ?? false,
      isBonus: data['is_bonus'] ?? false,
      improvement: (data.containsKey('improvement') && data['improvement'] is int) ? data['improvement'] as int : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'shot_type': shotType,
      'goal_type': goalType,
      'goal_value': goalValue,
      'difficulty': difficulty,
      'time_frame': timeFrame,
      'completed': completed,
      'date_assigned': dateAssigned,
      'date_completed': dateCompleted,
      'user_id': userId,
      'pro_level': proLevel,
      'is_bonus': isBonus,
    };
  }
}

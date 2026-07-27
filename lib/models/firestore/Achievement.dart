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
    T? read<T>(String camelCase, String snakeCase) {
      final value = data[camelCase] ?? data[snakeCase];
      return value is T ? value : null;
    }

    return Achievement(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      shotType: read<String>('shotType', 'shot_type') ?? '',
      goalType: read<String>('goalType', 'goal_type') ?? '',
      goalValue: read<num>('goalValue', 'goal_value')?.toInt() ?? 0,
      difficulty: data['difficulty'] ?? 'Easy',
      timeFrame: data['time_frame'] ?? 'week',
      completed: data['completed'] ?? false,
      dateAssigned:
          read<Timestamp>('dateAssigned', 'date_assigned') ?? Timestamp.now(),
      dateCompleted: read<Timestamp>('dateCompleted', 'date_completed') ??
          read<Timestamp>('completed_at', 'completed_at'),
      userId: read<String>('userId', 'user_id') ?? '',
      proLevel: read<bool>('proLevel', 'pro_level') ?? false,
      isBonus: read<bool>('isBonus', 'is_bonus') ?? false,
      improvement:
          (data.containsKey('improvement') && data['improvement'] is int)
              ? data['improvement'] as int
              : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'shotType': shotType,
      'goalType': goalType,
      'goalValue': goalValue,
      'difficulty': difficulty,
      'time_frame': timeFrame,
      'completed': completed,
      'dateAssigned': dateAssigned,
      'dateCompleted': dateCompleted,
      'userId': userId,
      'proLevel': proLevel,
      'isBonus': isBonus,
      if (improvement != null) 'improvement': improvement,
    };
  }
}

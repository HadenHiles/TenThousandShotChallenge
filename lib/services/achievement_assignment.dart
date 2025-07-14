import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore/Achievement.dart';

class AchievementTemplate {
  final String id;
  final String style;
  final String title;
  final String description;
  final String shotType;
  final String goalType; // 'count', 'accuracy', 'ratio', 'sessions', 'streak', 'consistency'
  final int? goalValue;
  final int? secondaryValue;
  final double? targetAccuracy;
  final int? sessions;
  final int? improvement;
  final String difficulty;
  final bool proLevel;
  final bool isBonus;

  AchievementTemplate({
    required this.id,
    required this.style,
    required this.title,
    required this.description,
    required this.shotType,
    required this.goalType,
    this.goalValue,
    this.secondaryValue,
    this.targetAccuracy,
    this.sessions,
    this.improvement,
    required this.difficulty,
    required this.proLevel,
    required this.isBonus,
  });

  Achievement toAchievement(String userId, DateTime dateAssigned) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      shotType: shotType,
      goalType: goalType,
      goalValue: goalValue ?? 0,
      difficulty: difficulty,
      timeFrame: 'week',
      completed: false,
      dateAssigned: Timestamp.fromDate(dateAssigned),
      dateCompleted: null,
      userId: userId,
      proLevel: proLevel,
      isBonus: isBonus,
    );
  }
}

class AchievementAssignmentService {
  final List<AchievementTemplate> templates = [
    // --- Quantity based ---
    AchievementTemplate(
      id: 'qty_wrist_easy',
      style: 'quantity',
      title: 'Wrist Shot Week',
      description: 'Take 30 wrist shots this week. You can spread them out over any sessions!',
      shotType: 'wrist',
      goalType: 'count',
      goalValue: 30,
      difficulty: 'Easy',
      proLevel: false,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'qty_snap_hard',
      style: 'quantity',
      title: 'Snap Shot Challenge',
      description: 'Take 60 snap shots this week. You can do it in any session(s)!',
      shotType: 'snap',
      goalType: 'count',
      goalValue: 60,
      difficulty: 'Hard',
      proLevel: false,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'qty_backhand_hardest',
      style: 'quantity',
      title: 'Backhand Mastery',
      description: 'Take 100 backhands this week. You can split them up however you want!',
      shotType: 'backhand',
      goalType: 'count',
      goalValue: 100,
      difficulty: 'Hardest',
      proLevel: false,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'qty_slap_impossible',
      style: 'quantity',
      title: 'Slap Shot Marathon',
      description: 'Take 200 slap shots this week. Spread them out over the week!',
      shotType: 'slap',
      goalType: 'count',
      goalValue: 200,
      difficulty: 'Impossible',
      proLevel: false,
      isBonus: true,
    ),
    // --- New: n shots for x sessions in a row ---
    AchievementTemplate(
      id: 'wrist_20_three_sessions',
      style: 'quantity',
      title: 'Wrist Shot Consistency',
      description: 'Take at least 20 wrist shots for any 3 sessions in a row this week. You can keep trying until you get it!',
      shotType: 'wrist',
      goalType: 'count_per_session',
      goalValue: 20,
      sessions: 3,
      difficulty: 'Medium',
      proLevel: false,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'snap_15_two_sessions',
      style: 'quantity',
      title: 'Snap Shot Streak',
      description: 'Take at least 15 snap shots for any 2 sessions in a row this week. Keep working at it!',
      shotType: 'snap',
      goalType: 'count_per_session',
      goalValue: 15,
      sessions: 2,
      difficulty: 'Easy',
      proLevel: false,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'backhand_10_four_sessions',
      style: 'quantity',
      title: 'Backhand Streak',
      description: 'Take at least 10 backhands for any 4 sessions in a row this week. You can keep trying until you get it!',
      shotType: 'backhand',
      goalType: 'count_per_session',
      goalValue: 10,
      sessions: 4,
      difficulty: 'Hard',
      proLevel: false,
      isBonus: false,
    ),
    // --- Creative/Generic ---
    AchievementTemplate(
      id: 'chip_shot_king',
      style: 'fun',
      title: 'Chip Shot King',
      description: 'Alternate forehand (snap) and backhand shots for an entire shooting session. Try to keep the number of snap and backhand shots within 1 of each other!',
      shotType: 'mixed',
      goalType: 'alternate',
      goalValue: 1,
      difficulty: 'Hard',
      proLevel: false,
      isBonus: true,
    ),
    AchievementTemplate(
      id: 'variety_master',
      style: 'fun',
      title: 'Variety Master',
      description: 'Take at least 5 of each shot type (wrist, snap, backhand, slap) in a single session this week.',
      shotType: 'all',
      goalType: 'variety',
      goalValue: 5,
      difficulty: 'Medium',
      proLevel: false,
      isBonus: true,
    ),
    // --- More Fun Templates ---
    AchievementTemplate(
      id: 'fun_celebration_easy',
      style: 'fun',
      title: 'Celebration Station',
      description: 'Come up with a new goal celebration and use it after every session this week!',
      shotType: '',
      goalType: 'celebration',
      goalValue: 1,
      difficulty: 'Easy',
      proLevel: false,
      isBonus: true,
    ),
    AchievementTemplate(
      id: 'fun_coach_hard',
      style: 'fun',
      title: 'Coach’s Tip',
      description: 'Ask your coach or parent for a tip and try to use it in your next session.',
      shotType: '',
      goalType: 'coach_tip',
      goalValue: 1,
      difficulty: 'Hard',
      proLevel: false,
      isBonus: true,
    ),
    AchievementTemplate(
      id: 'fun_video_medium',
      style: 'fun',
      title: 'Video Star',
      description: 'Record a video of your best shot and share it with a friend or coach.',
      shotType: '',
      goalType: 'video',
      goalValue: 1,
      difficulty: 'Medium',
      proLevel: false,
      isBonus: true,
    ),
    AchievementTemplate(
      id: 'fun_trickshot_hard',
      style: 'fun',
      title: 'Trick Shot Showdown',
      description: 'Invent a new trick shot and attempt it in a session this week.',
      shotType: '',
      goalType: 'trickshot',
      goalValue: 1,
      difficulty: 'Hard',
      proLevel: false,
      isBonus: true,
    ),
    AchievementTemplate(
      id: 'fun_teamwork_easy',
      style: 'fun',
      title: 'Teamwork Makes the Dream Work',
      description: 'Help a teammate or sibling with their shooting this week.',
      shotType: '',
      goalType: 'teamwork',
      goalValue: 1,
      difficulty: 'Easy',
      proLevel: false,
      isBonus: true,
    ),
    // --- Accuracy based (pro) ---
    AchievementTemplate(
      id: 'acc_wrist_easy',
      style: 'accuracy',
      title: 'Wrist Shot Precision',
      description: 'Achieve 60% accuracy on wrist shots in any 2 sessions in a row this week. Keep trying until you get it!',
      shotType: 'wrist',
      goalType: 'accuracy',
      targetAccuracy: 60.0,
      sessions: 2,
      difficulty: 'Easy',
      proLevel: true,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'acc_snap_hard',
      style: 'accuracy',
      title: 'Snap Shot Sniper',
      description: 'Achieve 70% accuracy on snap shots in any 3 sessions in a row this week. You can keep working at it all week!',
      shotType: 'snap',
      goalType: 'accuracy',
      targetAccuracy: 70.0,
      sessions: 3,
      difficulty: 'Hard',
      proLevel: true,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'acc_backhand_hardest',
      style: 'accuracy',
      title: 'Backhand Bullseye',
      description: 'Achieve 80% accuracy on backhands in any 4 sessions in a row this week. Don\'t give up if you miss early!',
      shotType: 'backhand',
      goalType: 'accuracy',
      targetAccuracy: 80.0,
      sessions: 4,
      difficulty: 'Hardest',
      proLevel: true,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'acc_slap_impossible',
      style: 'accuracy',
      title: 'Slap Shot Sharpshooter',
      description: 'Achieve 90% accuracy on slap shots in any 5 sessions in a row this week. You have all week to get there!',
      shotType: 'slap',
      goalType: 'accuracy',
      targetAccuracy: 90.0,
      sessions: 5,
      difficulty: 'Impossible',
      proLevel: true,
      isBonus: true,
    ),
    // --- Ratio based ---
    AchievementTemplate(
      id: 'ratio_backhand_wrist_easy',
      style: 'ratio',
      title: 'Backhand Booster',
      description: 'Take 2 backhands for every 1 wrist shot you take this week.',
      shotType: 'backhand',
      goalType: 'ratio',
      goalValue: 2,
      secondaryValue: 1,
      difficulty: 'Easy',
      proLevel: false,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'ratio_backhand_snap_hard',
      style: 'ratio',
      title: 'Backhand vs Snap',
      description: 'Take 3 backhands for every 1 snap shot you take this week.',
      shotType: 'backhand',
      goalType: 'ratio',
      goalValue: 3,
      secondaryValue: 1,
      difficulty: 'Hard',
      proLevel: false,
      isBonus: false,
    ),
    // --- Consistency ---
    AchievementTemplate(
      id: 'consistency_daily_easy',
      style: 'consistency',
      title: 'Daily Shooter',
      description: 'Shoot pucks every day this week, but if you miss a day, just start your streak again! Stay motivated!',
      shotType: '',
      goalType: 'streak',
      goalValue: 7,
      difficulty: 'Easy',
      proLevel: false,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'consistency_sessions_hard',
      style: 'consistency',
      title: 'Session Grinder',
      description: 'Complete 5 shooting sessions this week. If you miss a day, you can still finish strong!',
      shotType: '',
      goalType: 'sessions',
      goalValue: 5,
      difficulty: 'Hard',
      proLevel: false,
      isBonus: false,
    ),
    // --- Progress ---
    AchievementTemplate(
      id: 'progress_wrist_improve_easy',
      style: 'progress',
      title: 'Wrist Shot Progress',
      description: 'Improve your wrist shot accuracy by 5% this week. Progress counts, even if it takes a few tries!',
      shotType: 'wrist',
      goalType: 'improvement',
      improvement: 5,
      difficulty: 'Easy',
      proLevel: true,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'progress_snap_improve_hard',
      style: 'progress',
      title: 'Snap Shot Progress',
      description: 'Improve your snap shot accuracy by 10% this week. You can keep working at it all week!',
      shotType: 'snap',
      goalType: 'improvement',
      improvement: 10,
      difficulty: 'Hard',
      proLevel: true,
      isBonus: false,
    ),
    // --- Creative/Fun ---
    AchievementTemplate(
      id: 'fun_trickshot_easy',
      style: 'fun',
      title: 'Trick Shot Time',
      description: 'Attempt to master a trick shot in your next session.',
      shotType: '',
      goalType: 'attempt',
      goalValue: 1,
      difficulty: 'Easy',
      proLevel: false,
      isBonus: false,
    ),
    AchievementTemplate(
      id: 'fun_friend_hard',
      style: 'fun',
      title: 'Bring a Friend',
      description: 'Invite a friend to join your next shooting session.',
      shotType: '',
      goalType: 'invite',
      goalValue: 1,
      difficulty: 'Hard',
      proLevel: false,
      isBonus: false,
    ),
  ];

  // Main assignment function
  // Tunable variables for age/skill-based assignment
  // Tunable variables for hockey age groups
  Map<String, int> maxShotsPerSession = {
    'u7': 15,
    'u9': 20,
    'u11': 25,
    'u13': 30,
    'u15': 40,
    'u18': 50,
    'adult': 60,
  };
  Map<String, double> accuracyTarget = {
    'u7': 30.0,
    'u9': 35.0,
    'u11': 40.0,
    'u13': 45.0,
    'u15': 55.0,
    'u18': 60.0,
    'adult': 65.0,
  };
  Map<String, int> maxSessions = {
    'u7': 2,
    'u9': 2,
    'u11': 2,
    'u13': 3,
    'u15': 3,
    'u18': 4,
    'adult': 4,
  };

  List<Achievement> assignAchievementsForUser({
    required String userId,
    required Map<String, int> shotCounts,
    required Map<String, double> accuracy,
    required bool isPro,
    required int playerAge,
    int numAchievements = 3,
    int avgShotsPerSession = 30,
  }) {
    final now = DateTime.now();
    // Determine hockey age group
    String ageGroup;
    if (playerAge < 7) {
      ageGroup = 'u7';
    } else if (playerAge < 9) {
      ageGroup = 'u9';
    } else if (playerAge < 11) {
      ageGroup = 'u11';
    } else if (playerAge < 13) {
      ageGroup = 'u13';
    } else if (playerAge < 15) {
      ageGroup = 'u15';
    } else if (playerAge < 18) {
      ageGroup = 'u18';
    } else {
      ageGroup = 'adult';
    }

    // Difficulty mapping for each age group
    Map<String, List<String>> difficultyMap = {
      'u7': ['Easy', 'Medium', 'Hard'], // Hardest/Impossible mapped to Hard
      'u9': ['Easy', 'Medium', 'Hard'],
      'u11': ['Easy', 'Medium', 'Hard'],
      'u13': ['Easy', 'Medium', 'Hard', 'Hardest'], // Impossible mapped to Hardest
      'u15': ['Easy', 'Medium', 'Hard', 'Hardest'],
      'u18': ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
      'adult': ['Easy', 'Medium', 'Hard', 'Hardest', 'Impossible'],
    };

    // Filter templates based on mapped difficulty
    List<AchievementTemplate> eligible = templates.where((t) {
      if (isPro) return true;
      List<String> allowed = difficultyMap[ageGroup] ?? ['Easy'];
      // Map 'Impossible' and 'Hardest' for younger groups
      String mappedDifficulty = t.difficulty;
      if (['u7', 'u9', 'u11'].contains(ageGroup) && (t.difficulty == 'Hardest' || t.difficulty == 'Impossible')) {
        mappedDifficulty = 'Hard';
      } else if (['u13', 'u15'].contains(ageGroup) && t.difficulty == 'Impossible') {
        mappedDifficulty = 'Hardest';
      }
      return allowed.contains(mappedDifficulty);
    }).toList();

    // Prioritize under-practiced shot types
    int shotsThreshold = maxShotsPerSession[ageGroup] ?? avgShotsPerSession;
    List<String> underPracticed = shotCounts.entries.where((e) => e.value < shotsThreshold).map((e) => e.key).toList();

    // Skill-based adjustment for pro users
    if (isPro) {
      eligible = eligible.where((t) {
        if (t.goalType == 'accuracy' && t.targetAccuracy != null) {
          final userAcc = accuracy[t.shotType] ?? 0.0;
          return userAcc < t.targetAccuracy! + 10; // Only assign if not already much better
        }
        return true;
      }).toList();
    }

    eligible.shuffle();
    List<Achievement> assigned = [];
    Set<String> usedStyles = {};
    for (var template in eligible) {
      if (assigned.length >= numAchievements) break;
      if (underPracticed.isNotEmpty && underPracticed.contains(template.shotType)) {
        assigned.add(template.toAchievement(userId, now));
        usedStyles.add(template.style);
      } else if (usedStyles.length < numAchievements && !usedStyles.contains(template.style)) {
        assigned.add(template.toAchievement(userId, now));
        usedStyles.add(template.style);
      }
    }
    while (assigned.length < numAchievements && eligible.isNotEmpty) {
      assigned.add(eligible.removeLast().toAchievement(userId, now));
    }
    return assigned;
  }
}

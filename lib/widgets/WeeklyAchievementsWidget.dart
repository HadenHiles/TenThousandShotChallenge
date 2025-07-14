import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/achievement_service.dart';
import '../../models/firestore/Achievement.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WeeklyAchievementsWidget extends StatefulWidget {
  const WeeklyAchievementsWidget({super.key});

  @override
  State<WeeklyAchievementsWidget> createState() => _WeeklyAchievementsWidgetState();
}

class _WeeklyAchievementsWidgetState extends State<WeeklyAchievementsWidget> {
  late AchievementService _achievementService;
  late User? _user;
  Future<List<Achievement>>? _achievementsFuture;

  @override
  void initState() {
    super.initState();
    _achievementService = AchievementService();
    _user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (_user != null) {
      _achievementsFuture = _achievementService.getWeeklyAchievements(_user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Achievement>>(
      future: _achievementsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No achievements assigned this week.'));
        }
        final achievements = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            final achievement = achievements[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text(achievement.title),
                subtitle: Text(achievement.description),
                trailing: achievement.completed ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }
}

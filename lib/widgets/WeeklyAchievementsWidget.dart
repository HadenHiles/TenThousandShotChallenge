import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

class WeeklyAchievementsWidget extends StatefulWidget {
  const WeeklyAchievementsWidget({super.key});

  @override
  State<WeeklyAchievementsWidget> createState() => _WeeklyAchievementsWidgetState();
}

class _WeeklyAchievementsWidgetState extends State<WeeklyAchievementsWidget> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  DateTime _nextMondayEST() {
    final now = DateTime.now().toUtc().add(const Duration(hours: -5)); // EST
    int daysToAdd = (8 - now.weekday) % 7;
    final nextMonday = DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day, 0, 0, 0).toUtc().add(const Duration(hours: 5)); // back to UTC
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Center(child: Text('Sign in to view achievements'));
    }
    final achievementsRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid).collection('achievements').limit(4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Countdown timer
        _WeeklyResetCountdown(nextMonday: _nextMondayEST()),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: achievementsRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No achievements assigned this week.'));
              }
              final achievements = snapshot.data!.docs;
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                separatorBuilder: (context, idx) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final data = achievements[idx].data() as Map<String, dynamic>;
                  final id = data['id'] ?? '';
                  final completed = data['completed'] == true;
                  final title = data['title'] ?? '';
                  final description = data['description'] ?? '';
                  final goalType = data['goalType'] ?? data['goal_type'] ?? '';
                  final goalValue = data['goalValue'] ?? data['goal_value'] ?? 0;
                  final progress = data['progress'] ?? 0;
                  final isFun = id.startsWith('fun_') || id.startsWith('social_');

                  return Container(
                    width: 240,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: completed ? Colors.green.withOpacity(0.12) : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: completed ? Colors.green : Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              completed ? Icons.emoji_events : Icons.emoji_events_outlined,
                              color: completed ? Colors.green : Theme.of(context).primaryColor,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'NovecentoSans',
                                  color: Theme.of(context).primaryColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: 'NovecentoSans',
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        isFun
                            ? Row(
                                children: [
                                  Checkbox(
                                    value: completed,
                                    onChanged: (val) async {
                                      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).collection('achievements').doc(achievements[idx].id).update({'completed': val});
                                    },
                                  ),
                                  Text(
                                    completed ? 'Completed' : 'Incomplete',
                                    style: TextStyle(
                                      color: completed ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                  ),
                                ],
                              )
                            : _AchievementProgressBar(
                                completed: completed,
                                goalType: goalType,
                                goalValue: goalValue,
                                progress: progress,
                              ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeeklyResetCountdown extends StatefulWidget {
  final DateTime nextMonday;
  const _WeeklyResetCountdown({required this.nextMonday});

  @override
  State<_WeeklyResetCountdown> createState() => _WeeklyResetCountdownState();
}

class _WeeklyResetCountdownState extends State<_WeeklyResetCountdown> {
  late Duration _remaining;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _remaining = widget.nextMonday.difference(DateTime.now());
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    setState(() {
      _remaining = widget.nextMonday.difference(DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String text = _remaining.isNegative ? 'Achievements reset soon!' : 'Resets in: ${_formatDuration(_remaining)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Theme.of(context).primaryColor,
          fontFamily: 'NovecentoSans',
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String days = d.inDays > 0 ? '${d.inDays}d ' : '';
    String hours = twoDigits(d.inHours.remainder(24));
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return '$days$hours:$minutes:$seconds';
  }
}

class _AchievementProgressBar extends StatelessWidget {
  final bool completed;
  final String goalType;
  final int goalValue;
  final int progress;
  const _AchievementProgressBar({required this.completed, required this.goalType, required this.goalValue, required this.progress});

  @override
  Widget build(BuildContext context) {
    double percent = goalValue > 0 ? (progress / goalValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: completed ? 1.0 : percent,
          backgroundColor: Colors.grey[300],
          color: completed ? Colors.green : Theme.of(context).primaryColor,
          minHeight: 8,
        ),
        const SizedBox(height: 4),
        Text(
          completed ? 'Completed' : '${(percent * 100).toStringAsFixed(0)}% ($progress/$goalValue)',
          style: TextStyle(
            color: completed ? Colors.green : Theme.of(context).primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            fontFamily: 'NovecentoSans',
          ),
        ),
      ],
    );
  }
}

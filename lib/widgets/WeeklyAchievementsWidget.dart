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

  late List<bool> _expanded = [];

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
              // Sort so bonus achievement is always last
              final achievements = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
              achievements.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aIsBonus = aData['isBonus'] ?? (aData['id'] ?? '').toString().startsWith('fun_') || (aData['id'] ?? '').toString().startsWith('social_');
                final bIsBonus = bData['isBonus'] ?? (bData['id'] ?? '').toString().startsWith('fun_') || (bData['id'] ?? '').toString().startsWith('social_');
                if (aIsBonus == bIsBonus) return 0;
                return aIsBonus ? 1 : -1;
              });
              // Ensure _expanded is the correct length
              if (_expanded.length != achievements.length) {
                _expanded = List.filled(achievements.length, false);
              }
              return ListView.separated(
                scrollDirection: Axis.vertical,
                itemCount: achievements.length,
                separatorBuilder: (context, idx) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final data = achievements[idx].data() as Map<String, dynamic>;
                  final id = data['id'] ?? '';
                  final completed = data['completed'] == true;
                  final description = data['description'] ?? '';
                  final isBonus = data['isBonus'] ?? id.startsWith('fun_') || id.startsWith('social_');

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: completed ? Colors.green.withOpacity(0.12) : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isBonus ? const Color(0xFFFFD700) : (completed ? Colors.green : Theme.of(context).primaryColor),
                            width: 2.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            isBonus
                                ? GestureDetector(
                                    onTap: () async {
                                      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).collection('achievements').doc(achievements[idx].id).update({'completed': !completed});
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: completed
                                              ? Colors.green
                                              : (isBonus)
                                                  ? const Color(0xFFFFD700)
                                                  : Theme.of(context).primaryColor,
                                          width: 2.2,
                                        ),
                                        color: completed ? Colors.green.withOpacity(0.18) : Colors.transparent,
                                      ),
                                      child: completed ? Icon(Icons.check, size: 18, color: Colors.green) : null,
                                    ),
                                  )
                                : Container(),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        description,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontFamily: 'NovecentoSans',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isBonus)
                        Positioned(
                          top: -7,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFD700), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withOpacity(0.9),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'BONUS',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.9),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                fontFamily: 'NovecentoSans',
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
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
      padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
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

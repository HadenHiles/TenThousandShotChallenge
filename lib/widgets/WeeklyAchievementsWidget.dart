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

  // Placeholder progress functions for each style
  double _getAchievementProgress(Map<String, dynamic> data) {
    final style = data['style'] ?? '';
    switch (style) {
      case 'quantity':
        return _dummyProgress(data);
      case 'accuracy':
        return _dummyProgress(data);
      case 'ratio':
        return _dummyProgress(data);
      case 'consistency':
        return _dummyProgress(data);
      case 'progress':
        return _dummyProgress(data);
      default:
        return 0.0;
    }
  }

  double _dummyProgress(Map<String, dynamic> data) {
    // TODO: Replace with real logic later
    // For demo, return a random-ish value based on id hash
    final id = data['id'] ?? '';
    if (id is String && id.isNotEmpty) {
      return ((id.codeUnitAt(0) % 100) / 100).clamp(0.1, 0.95);
    }
    return 0.5;
  }

  // Dummy ratio progress and feedback for demo
  double _getRatioValue(Map<String, dynamic> data) {
    // TODO: Replace with real logic
    // For demo, return a value between 0.0 and 1.0
    final id = data['id'] ?? '';
    if (id is String && id.isNotEmpty) {
      return ((id.codeUnitAt(0) % 100) / 100).clamp(0.0, 1.0);
    }
    return 0.5;
  }

  String _getRatioFeedback(Map<String, dynamic> data, double ratioValue, double sweetSpot) {
    // Show feedback based on how close the user is to the sweet spot
    final diff = (ratioValue - sweetSpot).abs();
    if (diff < 0.08) {
      return 'Right on the money!';
    } else if (diff < 0.18) {
      return 'Crushing it!';
    } else if (ratioValue < sweetSpot) {
      return 'Keep taking more of the first shot!';
    } else {
      return 'Try to balance your shots!';
    }
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
        StreamBuilder<QuerySnapshot>(
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
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: achievements.length,
              separatorBuilder: (context, idx) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final data = achievements[idx].data() as Map<String, dynamic>;
                final id = data['id'] ?? '';
                final completed = data['completed'] == true;
                final description = data['description'] ?? '';
                final isBonus = data['isBonus'] ?? id.startsWith('fun_') || id.startsWith('social_');

                final style = data['style'] ?? '';
                if (style == 'ratio') {
                  // Ratio achievement: show a custom sliding scale
                  final goalValue = (data['goalValue'] is num) ? data['goalValue'].toDouble() : 1.0;
                  final secondaryValue = (data['secondaryValue'] is num) ? data['secondaryValue'].toDouble() : 1.0;
                  final sweetSpot = goalValue / (goalValue + secondaryValue);
                  final ratioValue = _getRatioValue(data);
                  final feedback = _getRatioFeedback(data, ratioValue, sweetSpot);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: completed ? Colors.green.withOpacity(0.12) : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isBonus ? const Color(0xFFFFD700) : (completed ? Colors.green : Theme.of(context).primaryColor),
                            width: 2.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                        Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontFamily: 'NovecentoSans',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Sliding scale
                                        Stack(
                                          alignment: Alignment.centerLeft,
                                          children: [
                                            Container(
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.13),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              child: FractionallySizedBox(
                                                alignment: Alignment.centerLeft,
                                                widthFactor: sweetSpot,
                                                child: Container(
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.28),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // User's current ratio indicator
                                            Positioned(
                                              left: (ratioValue * MediaQuery.of(context).size.width * 0.7).clamp(0.0, MediaQuery.of(context).size.width * 0.7),
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2),
                                                ),
                                              ),
                                            ),
                                            // Sweet spot indicator
                                            Positioned(
                                              left: (sweetSpot * MediaQuery.of(context).size.width * 0.7).clamp(0.0, MediaQuery.of(context).size.width * 0.7),
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: Colors.yellow,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.black, width: 1),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          feedback,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green[900],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
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
                }
                // Default: all other styles
                final showProgress = ['quantity', 'accuracy', 'consistency', 'progress'].contains(style);
                final progress = showProgress ? _getAchievementProgress(data) : 0.0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: completed ? Colors.green.withOpacity(0.12) : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isBonus ? const Color(0xFFFFD700) : (completed ? Colors.green : Theme.of(context).primaryColor),
                          width: 2.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (showProgress)
                            Positioned.fill(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

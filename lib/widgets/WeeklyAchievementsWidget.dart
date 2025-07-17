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
  // Returns the previous Monday at 12am EST (UTC-5)
  DateTime _previousMondayEST() {
    final now = DateTime.now().toUtc().add(const Duration(hours: -5)); // Convert to EST
    int daysToSubtract = (now.weekday - 1) % 7;
    final prevMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
    // Set to 12am EST, then convert back to UTC
    return DateTime(prevMonday.year, prevMonday.month, prevMonday.day, 0, 0, 0).toUtc().add(const Duration(hours: 5));
  }

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

  // Progress calculation for each style using stats
  double _getAchievementProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    final style = data['style'] ?? '';
    switch (style) {
      case 'quantity':
        return _quantityProgress(data, stats);
      case 'accuracy':
        return _accuracyProgress(data, stats);
      case 'consistency':
        return _consistencyProgress(data, stats);
      case 'progress':
        return _progressStyleProgress(data, stats);
      default:
        return 0.0;
    }
  }

  double _quantityProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    // e.g. goalType: 'count', 'count_time', 'count_each_hand', etc.
    final goalValue = (data['goalValue'] is num) ? data['goalValue'].toDouble() : 1.0;
    final shotType = data['shotType'] ?? 'any';
    final prevMonday = _previousMondayEST();
    final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
    // Filter sessions to only those after previous Monday 12am EST
    final sessions = rawSessions.where((session) {
      if (session.containsKey('date')) {
        final date = session['date'];
        if (date is Timestamp) {
          return date.toDate().isAfter(prevMonday) || date.toDate().isAtSameMomentAs(prevMonday);
        } else if (date is DateTime) {
          return date.isAfter(prevMonday) || date.isAtSameMomentAs(prevMonday);
        }
      }
      return false;
    }).toList();
    if (shotType == 'all') {
      // For 'all', progress is the average of the four shot type progresses
      final types = ['wrist', 'snap', 'slap', 'backhand'];
      double progressSum = 0.0;
      for (final t in types) {
        double count = 0.0;
        for (final session in sessions) {
          if (session.containsKey('shots') && session['shots'] is Map && session['shots'][t] is num) {
            count += (session['shots'][t] as num).toDouble();
          }
        }
        final progress = (count / goalValue).clamp(0.0, 1.0);
        progressSum += progress;
      }
      return progressSum / types.length;
    } else if (shotType == 'any') {
      // Sum all types
      double sum = 0.0;
      for (final session in sessions) {
        if (session.containsKey('shots') && session['shots'] is Map) {
          for (final v in (session['shots'] as Map).values) {
            if (v is num) sum += v.toDouble();
          }
        }
      }
      return (sum / goalValue).clamp(0.0, 1.0);
    } else {
      // Specific shot type
      double count = 0.0;
      for (final session in sessions) {
        if (session.containsKey('shots') && session['shots'] is Map && session['shots'][shotType] is num) {
          count += (session['shots'][shotType] as num).toDouble();
        }
      }
      return (count / goalValue).clamp(0.0, 1.0);
    }
  }

  double _accuracyProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    final targetAccuracy = (data['targetAccuracy'] is num) ? data['targetAccuracy'].toDouble() : 100.0;
    final shotType = data['shotType'] ?? 'any';
    final accuracy = stats['accuracy'] ?? {};
    if (accuracy is Map && accuracy.containsKey(shotType)) {
      final acc = (accuracy[shotType] is num) ? accuracy[shotType].toDouble() : 0.0;
      return (acc / targetAccuracy).clamp(0.0, 1.0);
    } else if (shotType == 'all' && accuracy is Map) {
      // For 'all', require each type to reach targetAccuracy
      final types = ['wrist', 'snap', 'slap', 'backhand'];
      double minProgress = 1.0;
      for (final t in types) {
        final acc = (accuracy[t] is num) ? accuracy[t].toDouble() : 0.0;
        minProgress = minProgress < (acc / targetAccuracy).clamp(0.0, 1.0) ? minProgress : (acc / targetAccuracy).clamp(0.0, 1.0);
      }
      return minProgress;
    }
    return 0.0;
  }

  double _consistencyProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    // e.g. goalType: 'sessions', 'streak', etc.
    final goalValue = (data['goalValue'] is num) ? data['goalValue'].toDouble() : 1.0;
    final totalSessions = (stats['total_sessions'] is num) ? stats['total_sessions'].toDouble() : 0.0;
    return (totalSessions / goalValue).clamp(0.0, 1.0);
  }

  double _progressStyleProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    // e.g. improvement: 5 (improve accuracy by 5%)
    final improvement = (data['improvement'] is num) ? data['improvement'].toDouble() : 1.0;
    // For demo, just use overall season_accuracy
    final seasonAccuracy = (stats['season_accuracy'] is num) ? stats['season_accuracy'].toDouble() : 0.0;
    return (seasonAccuracy / improvement).clamp(0.0, 1.0);
  }

  String _getRatioFeedback(Map<String, dynamic> data, double ratioValue, double sweetSpot) {
    final primaryType = data['shotType'] ?? data['primaryType'] ?? 'wrist';
    final secondaryType = data['shotTypeComparison'] ?? data['secondaryType'] ?? 'snap';
    final isOneToOne = (data['goalValue']?.toDouble() ?? 1.0) == 1.0 && (data['secondaryValue']?.toDouble() ?? 1.0) == 1.0;
    if (isOneToOne) {
      final diff = (ratioValue - sweetSpot).abs();
      if (diff < 0.09) {
        return 'Right on the money!';
      } else if (ratioValue > sweetSpot) {
        return 'A little heavy on $primaryType shots. Try a few more $secondaryType shots for perfect balance!';
      } else {
        return 'A little heavy on $secondaryType shots. Try a few more $primaryType shots for perfect balance!';
      }
    } else {
      if (ratioValue >= sweetSpot) {
        if ((ratioValue - sweetSpot) < 0.09) {
          return 'Right on the money!';
        } else {
          return 'Crushing it! You exceeded the minimum ratio for $primaryType shots.';
        }
      } else if ((sweetSpot - ratioValue) < 0.09) {
        return 'Almost there! Keep taking more $primaryType shots than $secondaryType shots!';
      } else {
        return 'Keep going!';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Center(child: Text('Sign in to view achievements'));
    }
    final achievementsRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid).collection('achievements').limit(4);
    final statsRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid).collection('stats').doc('weekly');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeeklyResetCountdown(nextMonday: _nextMondayEST()),
        StreamBuilder<DocumentSnapshot>(
          stream: statsRef.snapshots(),
          builder: (context, statsSnapshot) {
            final statsRaw = (statsSnapshot.data?.data() as Map<String, dynamic>?) ?? {};
            // Filter sessions to only those after previous Monday 12am EST
            final prevMonday = _previousMondayEST();
            List<dynamic> sessions = (statsRaw['sessions'] is List) ? List.from(statsRaw['sessions']) : [];
            sessions = sessions.where((s) {
              if (s is Map && s.containsKey('date')) {
                final date = s['date'];
                if (date is Timestamp) {
                  return date.toDate().isAfter(prevMonday) || date.toDate().isAtSameMomentAs(prevMonday);
                } else if (date is DateTime) {
                  return date.isAfter(prevMonday) || date.isAtSameMomentAs(prevMonday);
                }
              }
              return false;
            }).toList();
            // Copy statsRaw and replace sessions with filtered list
            final stats = Map<String, dynamic>.from(statsRaw);
            return StreamBuilder<QuerySnapshot>(
              stream: achievementsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No achievements assigned this week.'));
                }
                final achievements = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
                achievements.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aIsBonus = aData['isBonus'] ?? (aData['id'] ?? '').toString().startsWith('fun_') || (aData['id'] ?? '').toString().startsWith('social_');
                  final bIsBonus = bData['isBonus'] ?? (bData['id'] ?? '').toString().startsWith('fun_') || (bData['id'] ?? '').toString().startsWith('social_');
                  if (aIsBonus == bIsBonus) return 0;
                  return aIsBonus ? 1 : -1;
                });
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
                      // Calculate ratio using shotType and shotTypeComparison (with fallback to primaryType/secondaryType)
                      final goalValue = (data['goalValue'] is num) ? data['goalValue'].toDouble() : 1.0;
                      final secondaryValue = (data['secondaryValue'] is num) ? data['secondaryValue'].toDouble() : 1.0;
                      final sweetSpot = goalValue / (goalValue + secondaryValue);
                      final primaryType = data['shotType'] ?? data['primaryType'] ?? 'wrist';
                      final secondaryType = data['shotTypeComparison'] ?? data['secondaryType'] ?? 'snap';
                      // Use filtered weekly sessions from stats
                      final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
                      double primaryCount = 0.0;
                      double secondaryCount = 0.0;
                      for (final session in rawSessions) {
                        if (session.containsKey('shots') && session['shots'] is Map) {
                          final shots = session['shots'] as Map;
                          if (primaryType.contains('+')) {
                            for (final t in primaryType.split('+')) {
                              if (shots[t] is num) primaryCount += (shots[t] as num).toDouble();
                            }
                          } else if (shots[primaryType] is num) {
                            primaryCount += (shots[primaryType] as num).toDouble();
                          }
                          if (secondaryType.contains('+')) {
                            for (final t in secondaryType.split('+')) {
                              if (shots[t] is num) secondaryCount += (shots[t] as num).toDouble();
                            }
                          } else if (shots[secondaryType] is num) {
                            secondaryCount += (shots[secondaryType] as num).toDouble();
                          }
                        }
                      }
                      final total = primaryCount + secondaryCount;
                      final ratioValue = total > 0 ? (primaryCount / total) : 0.0;
                      final feedback = _getRatioFeedback(
                        {
                          ...data,
                          'primaryType': primaryType,
                          'secondaryType': secondaryType,
                        },
                        ratioValue,
                        sweetSpot,
                      );
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: completed ? Colors.green.withOpacity(0.12) : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isBonus ? (completed ? Colors.green : const Color(0xFFFFD700)) : (completed ? Colors.green : Theme.of(context).primaryColor),
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
                                            // Show actual ratio numbers for clarity
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0),
                                              child: Text(
                                                'Your ratio:  ${primaryType.toString()} ${(ratioValue * 100).toStringAsFixed(1)}%  |  ${secondaryType.toString()} ${(100 - ratioValue * 100).toStringAsFixed(1)}%',
                                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
                    final progress = showProgress ? _getAchievementProgress(data, stats) : 0.0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: completed ? Colors.green.withOpacity(0.12) : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isBonus ? (completed ? Colors.green : const Color(0xFFFFD700)) : (completed ? Colors.green : Theme.of(context).primaryColor),
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
                                              if (data['style'] == 'quantity' && data['shotType'] == 'all')
                                                Builder(
                                                  builder: (context) {
                                                    // Calculate per-type and overall progress for this achievement
                                                    final goalValue = (data['goalValue'] is num) ? data['goalValue'].toDouble() : 1.0;
                                                    final shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
                                                    final prevMonday = _previousMondayEST();
                                                    final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
                                                    final sessions = rawSessions.where((session) {
                                                      if (session.containsKey('date')) {
                                                        final date = session['date'];
                                                        if (date is Timestamp) {
                                                          return date.toDate().isAfter(prevMonday) || date.toDate().isAtSameMomentAs(prevMonday);
                                                        } else if (date is DateTime) {
                                                          return date.isAfter(prevMonday) || date.isAtSameMomentAs(prevMonday);
                                                        }
                                                      }
                                                      return false;
                                                    }).toList();
                                                    Map<String, double> progressMap = {};
                                                    double progressSum = 0.0;
                                                    for (final t in shotTypes) {
                                                      double count = 0.0;
                                                      for (final session in sessions) {
                                                        if (session.containsKey('shots') && session['shots'] is Map && session['shots'][t] is num) {
                                                          count += (session['shots'][t] as num).toDouble();
                                                        }
                                                      }
                                                      final prog = (count / goalValue).clamp(0.0, 1.0);
                                                      progressMap[t] = prog;
                                                      progressSum += prog;
                                                    }
                                                    final overallProgress = progressSum / shotTypes.length;
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const SizedBox(height: 8),
                                                        ...shotTypes.map((t) {
                                                          final prog = progressMap[t] ?? 0.0;
                                                          Color barColor;
                                                          switch (t) {
                                                            case 'wrist':
                                                              barColor = Colors.cyan;
                                                              break;
                                                            case 'snap':
                                                              barColor = Colors.blue;
                                                              break;
                                                            case 'backhand':
                                                              barColor = Colors.indigo;
                                                              break;
                                                            case 'slap':
                                                              barColor = Colors.teal;
                                                              break;
                                                            default:
                                                              barColor = Colors.green;
                                                          }
                                                          // Calculate shot count for this type
                                                          double count = 0.0;
                                                          for (final session in sessions) {
                                                            if (session.containsKey('shots') && session['shots'] is Map && session['shots'][t] is num) {
                                                              count += (session['shots'][t] as num).toDouble();
                                                            }
                                                          }
                                                          final goalValue = (data['goalValue'] is num) ? data['goalValue'].toDouble() : 1.0;
                                                          return Padding(
                                                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                            child: Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 60,
                                                                  child: Text(
                                                                    t[0].toUpperCase() + t.substring(1),
                                                                    style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: Stack(
                                                                    children: [
                                                                      Container(
                                                                        height: 10,
                                                                        decoration: BoxDecoration(
                                                                          color: Colors.grey.withOpacity(0.18),
                                                                          borderRadius: BorderRadius.circular(6),
                                                                        ),
                                                                      ),
                                                                      FractionallySizedBox(
                                                                        alignment: Alignment.centerLeft,
                                                                        widthFactor: prog,
                                                                        child: Container(
                                                                          height: 10,
                                                                          decoration: BoxDecoration(
                                                                            color: barColor,
                                                                            borderRadius: BorderRadius.circular(6),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                Text('${count.toStringAsFixed(0)}/${goalValue.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.green[900])),
                                                              ],
                                                            ),
                                                          );
                                                        }),
                                                      ],
                                                    );
                                                  },
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

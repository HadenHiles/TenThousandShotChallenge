import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserAchievementsReadOnly extends StatelessWidget {
  final String userId;
  const UserAchievementsReadOnly({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final achievementsRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('achievements');
    final statsRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('stats').doc('weekly');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: statsRef.snapshots(),
      builder: (context, statsSnap) {
        final stats = statsSnap.data?.data() ?? const <String, dynamic>{};
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: achievementsRef.snapshots(),
          builder: (context, achSnap) {
            if (achSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)));
            }
            final docs = achSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'No achievements assigned this week.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
              );
            }
            // Sort: non-bonus first
            docs.sort((a, b) {
              final aData = a.data();
              final bData = b.data();
              final aId = aData['id']?.toString() ?? '';
              final bId = bData['id']?.toString() ?? '';
              final aBonus = (aData['isBonus'] == true) || aId.startsWith('fun_') || aId.startsWith('social_');
              final bBonus = (bData['isBonus'] == true) || bId.startsWith('fun_') || bId.startsWith('social_');
              if (aBonus == bBonus) return 0;
              return aBonus ? 1 : -1;
            });

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                final data = docs[idx].data();
                final description = data['description']?.toString() ?? '';
                final completed = data['completed'] == true;
                final style = data['style']?.toString() ?? '';

                final progress = _computeProgress(data, stats);
                final isBonus = data['isBonus'] == true || (data['id']?.toString().startsWith('fun_') ?? false) || (data['id']?.toString().startsWith('social_') ?? false);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: completed ? Colors.green.withOpacity(0.1) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isBonus ? (completed ? Colors.green : const Color(0xFFFFD700)) : (completed ? Colors.green : Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                      width: 2.0,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (['quantity', 'accuracy', 'consistency', 'progress'].contains(style))
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: completed ? Colors.green : (isBonus ? const Color(0xFFFFD700) : Theme.of(context).colorScheme.onSurface.withOpacity(0.25)),
                                  width: 2.0,
                                ),
                                color: completed ? Colors.green.withOpacity(0.18) : Colors.transparent,
                              ),
                              child: completed ? const Icon(Icons.check, size: 16, color: Colors.green) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                description,
                                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface, fontFamily: 'NovecentoSans'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isBonus)
                        Positioned(
                          top: -6,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFD700), width: 2),
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  double _computeProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    final style = data['style']?.toString() ?? '';
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

  // Lightweight copies of WeeklyAchievementsWidget progress helpers (kept in sync)
  double _quantityProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    final goalValue = (data['goalValue'] is num) ? (data['goalValue'] as num).toDouble() : 1.0;
    final shotType = data['shotType']?.toString() ?? 'any';
    final goalType = data['goalType']?.toString() ?? 'count';
    final requiredSessions = (data['sessions'] is num) ? (data['sessions'] as num).toInt() : 1;
    final cutoffDate = (data['dateAssigned'] ?? stats['week_start']);

    DateTime? cutoff;
    if (cutoffDate is Timestamp) cutoff = cutoffDate.toDate();
    if (cutoffDate is DateTime) cutoff = cutoffDate;

    final rawSessions = (stats['sessions'] is List) ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
    final sessions = rawSessions.where((s) {
      final d = s['date'];
      if (cutoff != null && d != null) {
        if (d is Timestamp) return !d.toDate().isBefore(cutoff);
        if (d is DateTime) return !d.isBefore(cutoff);
      }
      return false;
    }).toList();

    if (goalType == 'count_per_session') {
      int streak = 0, maxStreak = 0;
      for (final s in sessions) {
        final shots = (s['shots'] is Map && s['shots'][shotType] is num) ? (s['shots'][shotType] as num).toDouble() : 0.0;
        if (shots >= goalValue) {
          streak++;
          if (streak > maxStreak) maxStreak = streak;
          if (streak >= requiredSessions) return 1.0;
        } else {
          streak = 0;
        }
      }
      return (maxStreak / requiredSessions).clamp(0.0, 1.0);
    } else if (goalType == 'count_evening') {
      for (final s in sessions) {
        final d = s['date'];
        final dt = (d is Timestamp) ? d.toDate() : (d is DateTime ? d : null);
        if (dt != null && dt.hour >= 19) {
          double sum = 0.0;
          if (s['shots'] is Map) {
            for (final v in (s['shots'] as Map).values) {
              if (v is num) sum += v.toDouble();
            }
          }
          if (sum >= goalValue) return 1.0;
        }
      }
      return 0.0;
    } else if (goalType == 'count_time') {
      final timeLimit = (data['timeLimit'] is num) ? (data['timeLimit'] as num).toDouble() : 10.0;
      for (final s in sessions) {
        final hasDuration = s.containsKey('duration') && s['duration'] is num;
        if (!hasDuration) continue;
        final durationMinutes = (s['duration'] as num).toDouble();
        if (durationMinutes <= timeLimit) {
          double count = 0.0;
          if (shotType == 'any' || shotType == 'all') {
            if (s['shots'] is Map) {
              for (final v in (s['shots'] as Map).values) {
                if (v is num) count += v.toDouble();
              }
            }
          } else {
            if (s['shots'] is Map && s['shots'][shotType] is num) {
              count = (s['shots'][shotType] as num).toDouble();
            }
          }
          if (count >= goalValue) return 1.0;
        }
      }
      return 0.0;
    } else if (shotType == 'all') {
      const types = ['wrist', 'snap', 'slap', 'backhand'];
      double progressSum = 0.0;
      for (final t in types) {
        double count = 0.0;
        for (final s in sessions) {
          if (s['shots'] is Map && s['shots'][t] is num) count += (s['shots'][t] as num).toDouble();
        }
        progressSum += (count / goalValue).clamp(0.0, 1.0);
      }
      return progressSum / types.length;
    } else if (shotType == 'any') {
      double sum = 0.0;
      for (final s in sessions) {
        if (s['shots'] is Map) {
          for (final v in (s['shots'] as Map).values) {
            if (v is num) sum += v.toDouble();
          }
        }
      }
      return (sum / goalValue).clamp(0.0, 1.0);
    } else {
      double count = 0.0;
      for (final s in sessions) {
        if (s['shots'] is Map && s['shots'][shotType] is num) count += (s['shots'][shotType] as num).toDouble();
      }
      return (count / goalValue).clamp(0.0, 1.0);
    }
  }

  double _accuracyProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    final targetAccuracy = (data['targetAccuracy'] is num) ? (data['targetAccuracy'] as num).toDouble() : 100.0;
    final shotType = data['shotType']?.toString() ?? 'any';
    final goalType = data['goalType']?.toString() ?? 'accuracy';
    final requiredSessions = (data['sessions'] is num) ? (data['sessions'] as num).toInt() : 1;
    final isStreak = data['isStreak'] == true;

    final rawSessions = (stats['sessions'] is List) ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
    final cutoffDate = (data['dateAssigned'] ?? stats['week_start']);
    DateTime? cutoff;
    if (cutoffDate is Timestamp) cutoff = cutoffDate.toDate();
    if (cutoffDate is DateTime) cutoff = cutoffDate;
    final sessions = rawSessions.where((s) {
      final d = s['date'];
      if (cutoff != null && d != null) {
        if (d is Timestamp) return !d.toDate().isBefore(cutoff);
        if (d is DateTime) return !d.isBefore(cutoff);
      }
      return false;
    }).toList();

    List<double> sessionAccuracies = [];
    if (goalType == 'accuracy_variety') {
      const types = ['wrist', 'snap', 'slap', 'backhand'];
      for (final s in sessions) {
        final accMap = (s['accuracy'] is Map) ? s['accuracy'] as Map : const {};
        final allMet = types.every((t) => accMap[t] is num && (accMap[t] as num).toDouble() >= targetAccuracy);
        sessionAccuracies.add(allMet ? 1.0 : 0.0);
      }
      return sessionAccuracies.any((v) => v == 1.0) ? 1.0 : 0.0;
    } else if (goalType == 'accuracy_morning') {
      for (final s in sessions) {
        final d = s['date'];
        final dt = (d is Timestamp) ? d.toDate() : (d is DateTime ? d : null);
        if (dt != null && dt.hour < 10) {
          final accMap = (s['accuracy'] is Map) ? s['accuracy'] as Map : const {};
          double acc = 0.0;
          if (shotType == 'any') {
            final vals = accMap.values.whereType<num>().map((e) => e.toDouble()).toList();
            acc = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
          } else {
            acc = (accMap[shotType] is num) ? (accMap[shotType] as num).toDouble() : 0.0;
          }
          sessionAccuracies.add(acc);
        }
      }
      return sessionAccuracies.any((v) => v >= targetAccuracy) ? 1.0 : 0.0;
    } else {
      for (final s in sessions) {
        final accMap = (s['accuracy'] is Map) ? s['accuracy'] as Map : const {};
        final acc = (accMap[shotType] is num) ? (accMap[shotType] as num).toDouble() : 0.0;
        sessionAccuracies.add(acc);
      }
      if (isStreak) {
        int streak = 0, maxStreak = 0;
        for (final v in sessionAccuracies) {
          if (v >= targetAccuracy) {
            streak++;
            if (streak > maxStreak) maxStreak = streak;
            if (streak >= requiredSessions) return 1.0;
          } else {
            streak = 0;
          }
        }
        return (maxStreak / requiredSessions).clamp(0.0, 1.0);
      } else {
        final met = sessionAccuracies.where((v) => v >= targetAccuracy).length;
        return (met / requiredSessions).clamp(0.0, 1.0);
      }
    }
  }

  double _consistencyProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    final goalType = data['goalType']?.toString() ?? '';
    final goalValue = (data['goalValue'] is num) ? (data['goalValue'] as num).toDouble() : 1.0;
    final rawSessions = (stats['sessions'] is List) ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
    final cutoffDate = (data['dateAssigned'] ?? stats['week_start']);
    DateTime? cutoff;
    if (cutoffDate is Timestamp) cutoff = cutoffDate.toDate();
    if (cutoffDate is DateTime) cutoff = cutoffDate;
    final sessions = rawSessions.where((s) {
      final d = s['date'];
      if (cutoff != null && d != null) {
        if (d is Timestamp) return !d.toDate().isBefore(cutoff);
        if (d is DateTime) return !d.isBefore(cutoff);
      }
      return false;
    }).toList();

    DateTime? get(Map<String, dynamic> s) {
      final d = s['date'];
      if (d is Timestamp) return d.toDate();
      if (d is DateTime) return d;
      return null;
    }

    switch (goalType) {
      case 'early_sessions':
        final count = sessions.where((s) => get(s)?.hour != null && get(s)!.hour < 7).length;
        return (count / goalValue).clamp(0.0, 1.0);
      case 'double_sessions':
        final map = <String, int>{};
        for (final s in sessions) {
          final dt = get(s);
          if (dt == null) continue;
          final key = '${dt.year}-${dt.month}-${dt.day}';
          map[key] = (map[key] ?? 0) + 1;
        }
        final doubleDays = map.values.where((v) => v >= 2).length.toDouble();
        return (doubleDays / goalValue).clamp(0.0, 1.0);
      case 'weekend_sessions':
        final days = sessions.map((s) => get(s)?.weekday).whereType<int>().toSet();
        final count = (days.contains(DateTime.saturday) ? 1 : 0) + (days.contains(DateTime.sunday) ? 1 : 0);
        return (count / goalValue).clamp(0.0, 1.0);
      case 'streak':
        final uniqueDays = sessions.map((s) => get(s)).whereType<DateTime>().map((dt) => DateTime(dt.year, dt.month, dt.day)).toSet().toList()..sort();
        int longest = 0, current = 0;
        DateTime? prev;
        for (final day in uniqueDays) {
          if (prev == null || day.difference(prev).inDays == 1) {
            current++;
            if (current > longest) longest = current;
          } else {
            current = 1;
          }
          prev = day;
        }
        return (longest / goalValue).clamp(0.0, 1.0);
      case 'morning_sessions':
        final count = sessions.where((s) => get(s)?.hour != null && get(s)!.hour < 10).length;
        return (count / goalValue).clamp(0.0, 1.0);
      case 'sessions':
      default:
        return (sessions.length / goalValue).clamp(0.0, 1.0);
    }
  }

  double _progressStyleProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    final improvement = (data['improvement'] is num) ? (data['improvement'] as num).toDouble() : 1.0;
    final goalType = data['goalType']?.toString() ?? 'improvement';
    final shotType = data['shotType']?.toString() ?? 'any';
    final requiredSessions = (data['sessions'] is num) ? (data['sessions'] as num).toInt() : 1;
    final rawSessions = (stats['sessions'] is List) ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];

    if (goalType == 'improvement') {
      final seasonAcc = (stats['season_accuracy'] is num) ? (stats['season_accuracy'] as num).toDouble() : 0.0;
      return (seasonAcc / improvement).clamp(0.0, 1.0);
    } else if (goalType == 'improvement_variety') {
      const types = ['wrist', 'snap', 'slap', 'backhand'];
      double met = 0;
      for (final t in types) {
        final acc = (stats['season_accuracy_$t'] is num) ? (stats['season_accuracy_$t'] as num).toDouble() : 0.0;
        if (acc >= improvement) met += 1;
      }
      return (met / types.length).clamp(0.0, 1.0);
    } else if (goalType == 'improvement_evening') {
      int met = 0, total = 0;
      for (final s in rawSessions) {
        final d = s['date'];
        final dt = (d is Timestamp) ? d.toDate() : (d is DateTime ? d : null);
        if (dt != null && dt.hour >= 19) {
          final accMap = (s['accuracy'] is Map) ? s['accuracy'] as Map : const {};
          double acc;
          if (shotType == 'any') {
            final vals = accMap.values.whereType<num>().map((e) => e.toDouble()).toList();
            acc = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
          } else {
            acc = (accMap[shotType] is num) ? (accMap[shotType] as num).toDouble() : 0.0;
          }
          if (acc >= improvement) met++;
          total++;
        }
      }
      return total > 0 ? (met / total).clamp(0.0, 1.0) : 0.0;
    } else if (goalType == 'target_hits_increase') {
      final hits = (stats['target_hits'] is num) ? (stats['target_hits'] as num).toDouble() : 0.0;
      return (hits / improvement).clamp(0.0, 1.0);
    } else if (goalType == 'improvement_sessions') {
      int met = 0;
      for (final s in rawSessions) {
        final accMap = (s['accuracy'] is Map) ? s['accuracy'] as Map : const {};
        double acc;
        if (shotType == 'any') {
          final vals = accMap.values.whereType<num>().map((e) => e.toDouble()).toList();
          acc = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
        } else {
          acc = (accMap[shotType] is num) ? (accMap[shotType] as num).toDouble() : 0.0;
        }
        if (acc >= improvement) met++;
      }
      return (met / requiredSessions).clamp(0.0, 1.0);
    } else {
      final seasonAcc = (stats['season_accuracy'] is num) ? (stats['season_accuracy'] as num).toDouble() : 0.0;
      return (seasonAcc / improvement).clamp(0.0, 1.0);
    }
  }
}

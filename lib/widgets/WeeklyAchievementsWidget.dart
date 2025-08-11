import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'SwapCooldownTimer.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

class WeeklyAchievementsWidget extends StatefulWidget {
  const WeeklyAchievementsWidget({super.key});

  @override
  State<WeeklyAchievementsWidget> createState() => _WeeklyAchievementsWidgetState();
}

class _WeeklyAchievementsWidgetState extends State<WeeklyAchievementsWidget> {
  String? _userTimezone;
  // Widget builder for checkbox circle
  Widget _buildCheckboxCircle(bool checked) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: checked ? Colors.green : Colors.grey[400]!, width: 2),
        color: checked ? Colors.green.withOpacity(0.18) : Colors.transparent,
      ),
      child: checked ? Icon(Icons.check, size: 13, color: Colors.green) : null,
    );
  }

  // Helper for UI: get details for checkboxes
  Map<String, dynamic> getConsistencyDetails(String goalType, List<Map<String, dynamic>> sessions, double goalValue) {
    DateTime? getSessionTime(Map<String, dynamic> session) {
      final date = session['date'];
      if (date is Timestamp) return date.toDate();
      if (date is DateTime) return date;
      return null;
    }

    tz.Location? location;
    if (_userTimezone != null) {
      location = tz.getLocation(_userTimezone!);
    }
    DateTime toUserTz(DateTime dt) {
      if (location != null) {
        return tz.TZDateTime.from(dt, location);
      }
      return dt;
    }

    switch (goalType) {
      case 'weekend_sessions':
        // Sat/Sun checkboxes
        Set<int> days = sessions
            .map((s) {
              final dt = getSessionTime(s);
              return dt != null ? toUserTz(dt).weekday : null;
            })
            .where((d) => d != null)
            .cast<int>()
            .toSet();
        return {
          'sat': days.contains(DateTime.saturday),
          'sun': days.contains(DateTime.sunday),
        };
      case 'streak':
        // Streak checkboxes
        Set<DateTime> uniqueDays = sessions
            .map((s) {
              final dt = getSessionTime(s);
              return dt != null ? DateTime(toUserTz(dt).year, toUserTz(dt).month, toUserTz(dt).day) : null;
            })
            .where((d) => d != null)
            .cast<DateTime>()
            .toSet();
        List<DateTime> sortedDays = uniqueDays.toList()..sort();
        int longestStreak = 0;
        int currentStreak = 0;
        DateTime? prevDay;
        for (final day in sortedDays) {
          if (prevDay == null || day.difference(prevDay).inDays == 1) {
            currentStreak += 1;
          } else {
            currentStreak = 1;
          }
          if (currentStreak > longestStreak) longestStreak = currentStreak;
          prevDay = day;
        }
        return {
          'streak': longestStreak,
        };
      default:
        // Count checkboxes
        int count = 0;
        if (goalType == 'early_sessions') {
          count = sessions.where((s) {
            final dt = getSessionTime(s);
            return dt != null && toUserTz(dt).hour < 7;
          }).length;
        } else if (goalType == 'double_sessions') {
          Map<String, int> dayCounts = {};
          for (final s in sessions) {
            final dt = getSessionTime(s);
            if (dt != null) {
              final userTzDt = toUserTz(dt);
              final key = '${userTzDt.year}-${userTzDt.month}-${userTzDt.day}';
              dayCounts[key] = (dayCounts[key] ?? 0) + 1;
            }
          }
          count = dayCounts.values.where((v) => v >= 2).length;
        } else if (goalType == 'lunch_sessions') {
          count = sessions.where((s) {
            final dt = getSessionTime(s);
            return dt != null && toUserTz(dt).hour >= 12 && toUserTz(dt).hour < 14;
          }).length;
        } else if (goalType == 'morning_sessions') {
          count = sessions.where((s) {
            final dt = getSessionTime(s);
            return dt != null && toUserTz(dt).hour < 10;
          }).length;
        } else if (goalType == 'sessions') {
          count = sessions.length;
        }
        return {
          'count': count,
        };
    }
  }

  DateTime _previousMondayEST() {
    try {
      final east = tz.getLocation('America/New_York');
      final nowNY = tz.TZDateTime.now(east);
      final daysToSubtract = (nowNY.weekday - DateTime.monday) % 7;
      final prevMondayLocal = tz.TZDateTime(east, nowNY.year, nowNY.month, nowNY.day).subtract(Duration(days: daysToSubtract));
      // Midnight local time (America/New_York) converted to UTC
      final prevMondayMidnightLocal = tz.TZDateTime(east, prevMondayLocal.year, prevMondayLocal.month, prevMondayLocal.day);
      return prevMondayMidnightLocal.toUtc();
    } catch (_) {
      // Fallback without tz: use device local time
      final now = DateTime.now();
      final daysToSubtract = (now.weekday - DateTime.monday) % 7;
      final prevMondayLocal = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
      return DateTime(prevMondayLocal.year, prevMondayLocal.month, prevMondayLocal.day);
    }
  }

  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  DateTime _nextMondayEST() {
    try {
      final east = tz.getLocation('America/New_York');
      final nowNY = tz.TZDateTime.now(east);
      int daysToAdd = (DateTime.monday + 7 - nowNY.weekday) % 7;
      if (daysToAdd == 0) daysToAdd = 7; // On Monday, go to next Monday
      final startOfTodayLocal = tz.TZDateTime(east, nowNY.year, nowNY.month, nowNY.day);
      final nextMondayLocal = startOfTodayLocal.add(Duration(days: daysToAdd));
      // Midnight local time (America/New_York) converted to UTC
      final nextMondayMidnightLocal = tz.TZDateTime(east, nextMondayLocal.year, nextMondayLocal.month, nextMondayLocal.day);
      return nextMondayMidnightLocal.toUtc();
    } catch (_) {
      // Fallback without tz: use device local time and ensure Monday goes to next week
      final now = DateTime.now();
      int daysToAdd = (DateTime.monday + 7 - now.weekday) % 7;
      if (daysToAdd == 0) daysToAdd = 7;
      final nextMondayLocal = DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
      return DateTime(nextMondayLocal.year, nextMondayLocal.month, nextMondayLocal.day);
    }
  }

  late List<bool> _expanded = [];

  // Auto-assign state when no weekly achievements exist
  bool _assigningAchievements = false;
  bool _assignmentAttempted = false;
  String? _assignmentError;

  Future<void> _assignPlayerAchievementsIfNeeded() async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('assignPlayerAchievements');
      final result = await callable();
      final data = result.data;
      if (mounted) {
        if (data != null && data is Map && data['success'] == true) {
          setState(() {
            _assignmentError = null;
            _assigningAchievements = false;
          });
        } else {
          final msg = (data is Map && data['message'] is String) ? data['message'] as String : 'Failed to assign achievements.';
          setState(() {
            _assignmentError = msg;
            _assigningAchievements = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assignmentError = 'Failed to assign achievements.';
        _assigningAchievements = false;
      });
    }
  }

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
    final goalValue = (data['goalValue'] is num) ? data['goalValue'].toDouble() : 1.0;
    final shotType = data['shotType'] ?? 'any';
    final goalType = data['goalType'] ?? 'count';
    final requiredSessions = (data['sessions'] is num) ? data['sessions'].toInt() : 1;
    final cutoffDate = (data['dateAssigned'] ?? stats['week_start']);
    DateTime? cutoff;
    if (cutoffDate is Timestamp) {
      cutoff = cutoffDate.toDate();
    } else if (cutoffDate is DateTime) {
      cutoff = cutoffDate;
    }
    tz.Location? location;
    if (_userTimezone != null) {
      location = tz.getLocation(_userTimezone!);
    }
    DateTime toUserTz(DateTime dt) {
      if (location != null) {
        return tz.TZDateTime.from(dt, location);
      }
      return dt;
    }

    final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
    final sessions = rawSessions.where((session) {
      if (session.containsKey('date') && cutoff != null) {
        final date = session['date'];
        DateTime? dt;
        if (date is Timestamp) dt = date.toDate();
        if (date is DateTime) dt = date;
        if (dt != null) {
          final userTzDt = toUserTz(dt);
          final userTzCutoff = toUserTz(cutoff);
          return userTzDt.isAfter(userTzCutoff) || userTzDt.isAtSameMomentAs(userTzCutoff);
        }
      }
      return false;
    }).toList();

    if (goalType == 'count_per_session') {
      List<int> metList = [];
      for (final session in sessions) {
        if (session.containsKey('shots') && session['shots'] is Map && session['shots'][shotType] is num) {
          double count = (session['shots'][shotType] as num).toDouble();
          metList.add(count >= goalValue ? 1 : 0);
        } else {
          metList.add(0);
        }
      }
      int streak = 0;
      int maxStreak = 0;
      for (int i = 0; i < metList.length; i++) {
        if (metList[i] == 1) {
          streak++;
          if (streak > maxStreak) maxStreak = streak;
          if (streak >= requiredSessions) {
            return 1.0;
          }
        } else {
          streak = 0;
        }
      }
      return (maxStreak / requiredSessions).clamp(0.0, 1.0);
    } else if (goalType == 'count_evening') {
      for (final session in sessions) {
        if (session.containsKey('shots') && session['shots'] is Map && session.containsKey('date')) {
          final date = session['date'];
          DateTime? dt;
          if (date is Timestamp) dt = date.toDate();
          if (date is DateTime) dt = date;
          if (dt != null) {
            final userTzDt = toUserTz(dt);
            if (userTzDt.hour >= 19) {
              double sum = 0.0;
              for (final v in (session['shots'] as Map).values) {
                if (v is num) sum += v.toDouble();
              }
              if (sum >= goalValue) {
                return 1.0;
              }
            }
          }
        }
      }
      return 0.0;
    } else if (shotType == 'all') {
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
    final goalType = data['goalType'] ?? 'accuracy';
    final requiredSessions = (data['sessions'] is num) ? data['sessions'].toInt() : 1;
    final isStreak = data['isStreak'] == true;
    final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
    DateTime? cutoff;
    final cutoffDate = (data['dateAssigned'] ?? stats['week_start']);
    if (cutoffDate is Timestamp) {
      cutoff = cutoffDate.toDate();
    } else if (cutoffDate is DateTime) {
      cutoff = cutoffDate;
    }
    final sessions = rawSessions.where((session) {
      if (session.containsKey('date') && cutoff != null) {
        final date = session['date'];
        if (date is Timestamp) {
          return date.toDate().isAfter(cutoff) || date.toDate().isAtSameMomentAs(cutoff);
        } else if (date is DateTime) {
          return date.isAfter(cutoff) || date.isAtSameMomentAs(cutoff);
        }
      }
      return false;
    }).toList();

    // Helper: get session time
    DateTime? getSessionTime(Map<String, dynamic> session) {
      final date = session['date'];
      if (date is Timestamp) return date.toDate();
      if (date is DateTime) return date;
      return null;
    }

    // For UI: store session accuracy info
    List<double> sessionAccuracies = [];

    if (goalType == 'accuracy_variety') {
      // Must hit targetAccuracy for all types in a single session
      final types = ['wrist', 'snap', 'slap', 'backhand'];
      for (final session in sessions) {
        if (session.containsKey('accuracy') && session['accuracy'] is Map) {
          final accMap = session['accuracy'] as Map;
          bool allMet = true;
          for (final t in types) {
            final acc = (accMap[t] is num) ? accMap[t].toDouble() : 0.0;
            if (acc < targetAccuracy) {
              allMet = false;
              break;
            }
          }
          if (allMet) {
            sessionAccuracies.add(1.0); // 1.0 means met
          } else {
            sessionAccuracies.add(0.0);
          }
        }
      }
      // Only need one session to meet requirement
      final met = sessionAccuracies.any((v) => v == 1.0);
      return met ? 1.0 : 0.0;
    } else if (goalType == 'accuracy_morning') {
      // Morning session (before 10am) with required accuracy
      for (final session in sessions) {
        final dt = getSessionTime(session);
        if (dt != null && dt.hour < 10 && session.containsKey('accuracy') && session['accuracy'] is Map) {
          final accMap = session['accuracy'] as Map;
          double acc = 0.0;
          if (shotType == 'any') {
            // Use average of all types
            final types = ['wrist', 'snap', 'slap', 'backhand'];
            double sum = 0.0;
            int count = 0;
            for (final t in types) {
              if (accMap[t] is num) {
                sum += (accMap[t] as num).toDouble();
                count++;
              }
            }
            acc = count > 0 ? sum / count : 0.0;
          } else {
            acc = (accMap[shotType] is num) ? accMap[shotType].toDouble() : 0.0;
          }
          sessionAccuracies.add(acc);
        }
      }
      final met = sessionAccuracies.any((v) => v >= targetAccuracy);
      return met ? 1.0 : 0.0;
    } else {
      // Standard accuracy achievements (single or multiple sessions)
      for (final session in sessions) {
        if (session.containsKey('accuracy') && session['accuracy'] is Map) {
          final accMap = session['accuracy'] as Map;
          double acc = (accMap[shotType] is num) ? accMap[shotType].toDouble() : 0.0;
          sessionAccuracies.add(acc);
        }
      }
      if (isStreak) {
        // Streak logic: find max streak of sessions with accuracy >= targetAccuracy
        int streak = 0;
        int maxStreak = 0;
        for (int i = 0; i < sessionAccuracies.length; i++) {
          if (sessionAccuracies[i] >= targetAccuracy) {
            streak++;
            if (streak > maxStreak) maxStreak = streak;
            if (streak >= requiredSessions) {
              return 1.0;
            }
          } else {
            streak = 0;
          }
        }
        // If not found, return partial progress
        return (maxStreak / requiredSessions).clamp(0.0, 1.0);
      } else {
        // For achievements requiring N sessions (not necessarily in a row)
        int metCount = sessionAccuracies.where((v) => v >= targetAccuracy).length;
        return (metCount / requiredSessions).clamp(0.0, 1.0);
      }
    }
  }

  double _consistencyProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    // Helper for UI: get details for checkboxes

    final goalType = data['goalType'] ?? '';
    final goalValue = (data['goalValue'] is num) ? data['goalValue'].toDouble() : 1.0;
    final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
    // Only consider sessions after cutoff (week start)
    DateTime? cutoff;
    final cutoffDate = (data['dateAssigned'] ?? stats['week_start']);
    if (cutoffDate is Timestamp) {
      cutoff = cutoffDate.toDate();
    } else if (cutoffDate is DateTime) {
      cutoff = cutoffDate;
    }
    final sessions = rawSessions.where((session) {
      if (session.containsKey('date') && cutoff != null) {
        final date = session['date'];
        if (date is Timestamp) {
          return date.toDate().isAfter(cutoff) || date.toDate().isAtSameMomentAs(cutoff);
        } else if (date is DateTime) {
          return date.isAfter(cutoff) || date.isAtSameMomentAs(cutoff);
        }
      }
      return false;
    }).toList();

    // Helper: get session time
    DateTime? getSessionTime(Map<String, dynamic> session) {
      final date = session['date'];
      if (date is Timestamp) return date.toDate();
      if (date is DateTime) return date;
      return null;
    }

    switch (goalType) {
      case 'early_sessions':
        // Before 7am
        int count = sessions.where((s) {
          final dt = getSessionTime(s);
          return dt != null && dt.hour < 7;
        }).length;
        return (count / goalValue).clamp(0.0, 1.0);
      case 'double_sessions':
        // Days with 2+ sessions
        Map<String, int> dayCounts = {};
        for (final s in sessions) {
          final dt = getSessionTime(s);
          if (dt != null) {
            final key = '${dt.year}-${dt.month}-${dt.day}';
            dayCounts[key] = (dayCounts[key] ?? 0) + 1;
          }
        }
        int doubleDays = dayCounts.values.where((v) => v >= 2).length;
        return (doubleDays / goalValue).clamp(0.0, 1.0);
      case 'weekend_sessions':
        // Session on both Saturday and Sunday
        Set<int> days = sessions
            .map((s) {
              final dt = getSessionTime(s);
              return dt?.weekday;
            })
            .where((d) => d != null)
            .cast<int>()
            .toSet();
        int count = (days.contains(DateTime.saturday) ? 1 : 0) + (days.contains(DateTime.sunday) ? 1 : 0);
        return (count / goalValue).clamp(0.0, 1.0);
      case 'streak':
        // Longest streak of consecutive days with sessions
        Set<DateTime> uniqueDays = sessions
            .map((s) {
              final dt = getSessionTime(s);
              return dt != null ? DateTime(dt.year, dt.month, dt.day) : null;
            })
            .where((d) => d != null)
            .cast<DateTime>()
            .toSet();
        List<DateTime> sortedDays = uniqueDays.toList()..sort();
        int longestStreak = 0;
        int currentStreak = 0;
        DateTime? prevDay;
        for (final day in sortedDays) {
          if (prevDay == null || day.difference(prevDay).inDays == 1) {
            currentStreak += 1;
          } else {
            currentStreak = 1;
          }
          if (currentStreak > longestStreak) longestStreak = currentStreak;
          prevDay = day;
        }
        return (longestStreak / goalValue).clamp(0.0, 1.0);
      case 'morning_sessions':
        // Before 10am
        int count = sessions.where((s) {
          final dt = getSessionTime(s);
          return dt != null && dt.hour < 10;
        }).length;
        return (count / goalValue).clamp(0.0, 1.0);
      case 'sessions':
      default:
        // Total sessions
        int count = sessions.length;
        return (count / goalValue).clamp(0.0, 1.0);
    }
  }

  double _progressStyleProgress(Map<String, dynamic> data, Map<String, dynamic> stats) {
    final improvement = (data['improvement'] is num) ? data['improvement'].toDouble() : 1.0;
    final goalType = data['goalType'] ?? 'improvement';
    final shotType = data['shotType'] ?? 'any';
    final requiredSessions = (data['sessions'] is num) ? data['sessions'].toInt() : 1;
    final days = (data['days'] is num) ? data['days'].toInt() : 0;
    final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
    // improvement: overall season_accuracy
    if (goalType == 'improvement') {
      final seasonAccuracy = (stats['season_accuracy'] is num) ? stats['season_accuracy'].toDouble() : 0.0;
      return (seasonAccuracy / improvement).clamp(0.0, 1.0);
    } else if (goalType == 'improvement_variety') {
      // Improve accuracy by X% on all shot types
      final types = ['wrist', 'snap', 'slap', 'backhand'];
      double metTypes = 0.0;
      for (final t in types) {
        final acc = (stats['season_accuracy_$t'] is num) ? stats['season_accuracy_$t'].toDouble() : 0.0;
        if (acc >= improvement) metTypes += 1.0;
      }
      return (metTypes / types.length).clamp(0.0, 1.0);
    } else if (goalType == 'improvement_streak') {
      // Improve accuracy for N days in a row
      // For demo, use session accuracy improvement streak
      List<double> improvements = [];
      for (final session in rawSessions) {
        if (session.containsKey('accuracy') && session['accuracy'] is Map) {
          final accMap = session['accuracy'] as Map;
          double acc = shotType == 'any' ? (accMap.values.whereType<num>().fold(0.0, (a, b) => a + b) / (accMap.isNotEmpty ? accMap.length : 1)) : (accMap[shotType] is num ? accMap[shotType].toDouble() : 0.0);
          improvements.add(acc >= improvement ? 1.0 : 0.0);
        }
      }
      // Find max streak
      int streak = 0;
      int maxStreak = 0;
      for (final met in improvements) {
        if (met == 1.0) {
          streak++;
          if (streak > maxStreak) maxStreak = streak;
        } else {
          streak = 0;
        }
      }
      if (days > 0) {
        return (maxStreak / days).clamp(0.0, 1.0);
      } else {
        return (maxStreak / requiredSessions).clamp(0.0, 1.0);
      }
    } else if (goalType == 'improvement_evening') {
      // Improve accuracy in evening sessions (after 7pm)
      int metCount = 0;
      int total = 0;
      for (final session in rawSessions) {
        if (session.containsKey('date')) {
          final date = session['date'];
          DateTime? dt;
          if (date is Timestamp) dt = date.toDate();
          if (date is DateTime) dt = date;
          if (dt != null && dt.hour >= 19 && session.containsKey('accuracy') && session['accuracy'] is Map) {
            final accMap = session['accuracy'] as Map;
            double acc = shotType == 'any' ? (accMap.values.whereType<num>().fold(0.0, (a, b) => a + b) / (accMap.isNotEmpty ? accMap.length : 1)) : (accMap[shotType] is num ? accMap[shotType].toDouble() : 0.0);
            if (acc >= improvement) metCount++;
            total++;
          }
        }
      }
      return total > 0 ? (metCount / total).clamp(0.0, 1.0) : 0.0;
    } else if (goalType == 'target_hits_increase') {
      // Hit X targets
      final hits = (stats['target_hits'] is num) ? stats['target_hits'].toDouble() : 0.0;
      return (hits / improvement).clamp(0.0, 1.0);
    } else if (goalType == 'improvement_sessions') {
      // Improve accuracy in at least N sessions
      int metCount = 0;
      for (final session in rawSessions) {
        if (session.containsKey('accuracy') && session['accuracy'] is Map) {
          final accMap = session['accuracy'] as Map;
          double acc = shotType == 'any' ? (accMap.values.whereType<num>().fold(0.0, (a, b) => a + b) / (accMap.isNotEmpty ? accMap.length : 1)) : (accMap[shotType] is num ? accMap[shotType].toDouble() : 0.0);
          if (acc >= improvement) metCount++;
        }
      }
      return (metCount / requiredSessions).clamp(0.0, 1.0);
    } else {
      // Default: overall season_accuracy
      final seasonAccuracy = (stats['season_accuracy'] is num) ? stats['season_accuracy'].toDouble() : 0.0;
      return (seasonAccuracy / improvement).clamp(0.0, 1.0);
    }
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
    final achievementsRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid).collection('achievements');
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
                  // If no achievements exist, trigger an on-demand assignment once
                  if (!_assignmentAttempted && !_assigningAchievements) {
                    _assignmentAttempted = true;
                    _assigningAchievements = true;
                    // Defer the function call until after this frame
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      _assignPlayerAchievementsIfNeeded();
                    });
                  }
                  if (_assigningAchievements) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Assigning weekly achievements...'),
                          ],
                        ),
                      ),
                    );
                  }
                  if (_assignmentError != null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _assignmentError!,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _assignmentError = null;
                                _assigningAchievements = true;
                                _assignmentAttempted = true; // keep as attempted but retry now
                              });
                              SchedulerBinding.instance.addPostFrameCallback((_) {
                                _assignPlayerAchievementsIfNeeded();
                              });
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  // Fallback (should be rare since we auto-assign)
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 8),
                      child: Text('No achievements assigned this week.'),
                    ),
                  );
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
                  separatorBuilder: (context, idx) => const SizedBox(height: 8),
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
                      // Use dateAssigned if present, else week_start from stats
                      final cutoffDate = (data['dateAssigned'] ?? stats['week_start']);
                      DateTime? cutoff;
                      if (cutoffDate is Timestamp) {
                        cutoff = cutoffDate.toDate();
                      } else if (cutoffDate is DateTime) {
                        cutoff = cutoffDate;
                      }
                      final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
                      // Filter sessions to only those after cutoff
                      final sessions = rawSessions.where((session) {
                        if (session.containsKey('date') && cutoff != null) {
                          final date = session['date'];
                          if (date is Timestamp) {
                            return date.toDate().isAfter(cutoff) || date.toDate().isAtSameMomentAs(cutoff);
                          } else if (date is DateTime) {
                            return date.isAfter(cutoff) || date.isAtSameMomentAs(cutoff);
                          }
                        }
                        return false;
                      }).toList();
                      // If there are no sessions, show a message instead of the ratio bar/feedback
                      if (sessions.isEmpty) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isBonus ? (completed ? Colors.green : const Color(0xFFFFD700)) : (completed ? Colors.green : Theme.of(context).colorScheme.onSurface.withAlpha(50)),
                                  width: 2.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                                                  color: isBonus ? (completed ? Colors.green : const Color(0xFFFFD700)) : (completed ? Colors.green : Theme.of(context).colorScheme.onSurface.withAlpha(50)),
                                                  width: 2.2,
                                                ),
                                                color: Colors.transparent,
                                              ),
                                              child: null,
                                            ),
                                          )
                                        : Container(),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
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
                                          const SizedBox(height: 10),
                                          Text(
                                            'No shooting sessions recorded for this week yet.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
                      double primaryCount = 0.0;
                      double secondaryCount = 0.0;
                      for (final session in sessions) {
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
                      return _buildAchievementItem(
                        achievements[idx],
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: completed ? Colors.green.withOpacity(0.12) : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isBonus ? (completed ? Colors.green : const Color(0xFFFFD700)) : (completed ? Colors.green : Theme.of(context).colorScheme.onSurface.withAlpha(50)),
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
                                                              : Theme.of(context).colorScheme.onSurface.withAlpha(50),
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
                                                  'Your ratio: ${primaryType.toString()} ${(ratioValue * 100).toStringAsFixed(1)}%  |  ${secondaryType.toString()} ${(100 - ratioValue * 100).toStringAsFixed(1)}%',
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
                        ),
                      );
                    } else if (style == 'quantity' && (data['goalType'] == 'variety' || data['goalType'] == 'qty_variety' || data['goalType'] == 'qty_mixed_medium')) {
                      // Special block for quantity style with goalType variety (or similar)
                      final qtyRequiredSessions = (data['sessions'] is num) ? data['sessions'].toInt() : 1;
                      final qtyCutoffDate = (data['dateAssigned'] ?? stats['week_start']);
                      DateTime? qtyCutoff;
                      if (qtyCutoffDate is Timestamp) {
                        qtyCutoff = qtyCutoffDate.toDate();
                      } else if (qtyCutoffDate is DateTime) {
                        qtyCutoff = qtyCutoffDate;
                      }
                      final qtyRawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
                      final qtySessions = qtyRawSessions.where((session) {
                        if (session.containsKey('date') && qtyCutoff != null) {
                          final date = session['date'];
                          if (date is Timestamp) {
                            return date.toDate().isAfter(qtyCutoff) || date.toDate().isAtSameMomentAs(qtyCutoff);
                          } else if (date is DateTime) {
                            return date.isAfter(qtyCutoff) || date.isAtSameMomentAs(qtyCutoff);
                          }
                        }
                        return false;
                      }).toList();
                      // Count how many unique types were hit in each session
                      final types = ['wrist', 'snap', 'slap', 'backhand'];
                      int metSessions = 0;
                      for (final session in qtySessions) {
                        if (session.containsKey('shots') && session['shots'] is Map) {
                          final shots = session['shots'] as Map;
                          int typeCount = 0;
                          for (final t in types) {
                            if (shots[t] is num && (shots[t] as num) > 0) typeCount++;
                          }
                          if (typeCount == types.length) {
                            metSessions++;
                          }
                        }
                      }
                      final progress = (metSessions / qtyRequiredSessions).clamp(0.0, 1.0);

                      return _buildAchievementItem(
                        achievements[idx],
                        Stack(
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
                                  Positioned.fill(
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress,
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
                                        Padding(
                                          padding: const EdgeInsets.only(right: 10),
                                          child: GestureDetector(
                                            onTap: isBonus
                                                ? () async {
                                                    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).collection('achievements').doc(achievements[idx].id).update({'completed': !completed});
                                                  }
                                                : null,
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
                                                          : Theme.of(context).colorScheme.onSurface.withAlpha(50),
                                                  width: 2.2,
                                                ),
                                                color: completed ? Colors.green.withOpacity(0.18) : Colors.transparent,
                                              ),
                                              child: completed ? Icon(Icons.check, size: 18, color: Colors.green) : null,
                                            ),
                                          ),
                                        ),
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
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Text(
                                                  'Complete a session with all shot types: ${types.join(", ")}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
                        ),
                      );
                    }
                    // Default: all other styles
                    final showProgress = ['quantity', 'accuracy', 'consistency', 'progress'].contains(style);
                    final progress = showProgress ? _getAchievementProgress(data, stats) : 0.0;
                    Widget? accuracyIndicators;
                    if (style == 'accuracy') {
                      final targetAccuracy = (data['targetAccuracy'] is num) ? data['targetAccuracy'].toDouble() : 100.0;
                      final shotType = data['shotType'] ?? 'any';
                      final requiredSessions = (data['sessions'] is num) ? data['sessions'].toInt() : 1;
                      final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
                      DateTime? weekStart;
                      final weekStartRaw = stats['week_start'];
                      if (weekStartRaw is Timestamp) {
                        weekStart = weekStartRaw.toDate();
                      } else if (weekStartRaw is DateTime) {
                        weekStart = weekStartRaw;
                      }
                      // Only include sessions from the current week
                      final sessions = rawSessions.where((session) {
                        if (session.containsKey('date') && weekStart != null) {
                          final date = session['date'];
                          if (date is Timestamp) {
                            return date.toDate().isAfter(weekStart) || date.toDate().isAtSameMomentAs(weekStart);
                          } else if (date is DateTime) {
                            return date.isAfter(weekStart) || date.isAtSameMomentAs(weekStart);
                          }
                        }
                        return false;
                      }).toList();
                      // Helper: get session time
                      DateTime? getSessionTime(Map<String, dynamic> session) {
                        final date = session['date'];
                        if (date is Timestamp) return date.toDate();
                        if (date is DateTime) return date;
                        return null;
                      }

                      // sessionAccuracies now defined above with sortedSessions
                      List<Map<String, dynamic>> sortedSessions = List<Map<String, dynamic>>.from(sessions);
                      sortedSessions.sort((a, b) {
                        DateTime? aDate = getSessionTime(a);
                        DateTime? bDate = getSessionTime(b);
                        if (aDate == null && bDate == null) return 0;
                        if (aDate == null) return 1;
                        if (bDate == null) return -1;
                        return bDate.compareTo(aDate); // descending
                      });
                      List<double> sessionAccuracies = [];
                      List<DateTime?> sessionDates = [];
                      for (final session in sortedSessions) {
                        // Calculate accuracy from shots and targets_hit
                        double acc = 0.0;
                        if (session.containsKey('shots') && session.containsKey('targets_hit')) {
                          final shotsMap = session['shots'] as Map?;
                          final hitsMap = session['targets_hit'] as Map?;
                          final shots = (shotsMap != null && shotsMap[shotType] is num) ? (shotsMap[shotType] as num).toDouble() : 0.0;
                          final hits = (hitsMap != null && hitsMap[shotType] is num) ? (hitsMap[shotType] as num).toDouble() : 0.0;
                          if (shots > 0) {
                            acc = (hits / shots) * 100.0;
                          }
                        }
                        sessionAccuracies.add(acc);
                        sessionDates.add(getSessionTime(session));
                      }
                      // Use isStreak property for streak/non-streak logic
                      final isStreak = data['isStreak'] == true;
                      if (requiredSessions > 1) {
                        accuracyIndicators = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: () {
                            if (isStreak) {
                              if (completed) {
                                // If achievement is completed, show all boxes checked
                                return List.generate(
                                  requiredSessions,
                                  (i) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                    child: Column(
                                      children: [
                                        _buildCheckboxCircle(true),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                // Show the current (most recent) streak of consecutive sessions with accuracy >= targetAccuracy
                                int currentStreak = 0;
                                for (int i = 0; i < sortedSessions.length; i++) {
                                  final session = sortedSessions[i];
                                  final shotsMap = session['shots'] as Map?;
                                  final hitsMap = session['targets_hit'] as Map?;
                                  final shots = (shotsMap != null && shotsMap[shotType] is num) ? (shotsMap[shotType] as num).toDouble() : 0.0;
                                  final hits = (hitsMap != null && hitsMap[shotType] is num) ? (hitsMap[shotType] as num).toDouble() : 0.0;
                                  double acc = 0.0;
                                  if (shots > 0) {
                                    acc = (hits / shots) * 100.0;
                                  }
                                  if (shots > 0 && acc >= targetAccuracy) {
                                    currentStreak++;
                                  } else {
                                    break;
                                  }
                                }
                                return List.generate(
                                  requiredSessions,
                                  (i) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                    child: Column(
                                      children: [
                                        _buildCheckboxCircle(i < currentStreak),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            } else {
                              // Non-streak: show up to requiredSessions checked, then unchecked for the rest
                              int metCount = 0;
                              List<bool> checkedList = List.filled(requiredSessions, false);
                              for (int i = 0; i < sessionAccuracies.length && metCount < requiredSessions; i++) {
                                if (sessionAccuracies[i] >= targetAccuracy) {
                                  checkedList[metCount] = true;
                                  metCount++;
                                }
                              }
                              return List.generate(
                                requiredSessions,
                                (i) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                  child: Column(
                                    children: [
                                      _buildCheckboxCircle(checkedList[i]),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }(),
                        );
                      } else {
                        accuracyIndicators = null;
                      }
                    }
                    Widget? consistencyIndicators;
                    if (style == 'consistency') {
                      final goalType = data['goalType'] ?? '';
                      final goalValue = (data['goalValue'] is num) ? data['goalValue'].toDouble() : 1.0;
                      final rawSessions = stats['sessions'] is List ? List<Map<String, dynamic>>.from(stats['sessions']) : <Map<String, dynamic>>[];
                      DateTime? cutoff;
                      final cutoffDate = (data['dateAssigned'] ?? stats['week_start']);
                      if (cutoffDate is Timestamp) {
                        cutoff = cutoffDate.toDate();
                      } else if (cutoffDate is DateTime) {
                        cutoff = cutoffDate;
                      }
                      final sessions = rawSessions.where((session) {
                        if (session.containsKey('date') && cutoff != null) {
                          final date = session['date'];
                          if (date is Timestamp) {
                            return date.toDate().isAfter(cutoff) || date.toDate().isAtSameMomentAs(cutoff);
                          } else if (date is DateTime) {
                            return date.isAfter(cutoff) || date.isAtSameMomentAs(cutoff);
                          }
                        }
                        return false;
                      }).toList();
                      final details = getConsistencyDetails(goalType, sessions, goalValue);
                      if (goalType == 'weekend_sessions') {
                        consistencyIndicators = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Column(
                              children: [
                                _buildCheckboxCircle(details['sat'] == true),
                                const SizedBox(height: 2),
                                Text('Sat', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Column(
                              children: [
                                _buildCheckboxCircle(details['sun'] == true),
                                const SizedBox(height: 2),
                                Text('Sun', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        );
                      } else if (goalType == 'streak') {
                        int streak = details['streak'] ?? 0;
                        consistencyIndicators = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                              goalValue.toInt(),
                              (i) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: _buildCheckboxCircle(i < streak),
                                  )),
                        );
                      } else {
                        int count = details['count'] ?? 0;
                        consistencyIndicators = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                              goalValue.toInt(),
                              (i) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: _buildCheckboxCircle(i < count),
                                  )),
                        );
                      }
                    }
                    return _buildAchievementItem(
                      achievements[idx],
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: completed ? Colors.green.withOpacity(0.12) : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isBonus ? (completed ? Colors.green : const Color(0xFFFFD700)) : (completed ? Colors.green : Theme.of(context).colorScheme.onSurface.withAlpha(50)),
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
                                      Padding(
                                        padding: EdgeInsetsGeometry.only(right: 10),
                                        child: GestureDetector(
                                          onTap: isBonus
                                              ? () async {
                                                  await FirebaseFirestore.instance.collection('users').doc(_user!.uid).collection('achievements').doc(achievements[idx].id).update({'completed': !completed});
                                                }
                                              : null,
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
                                                        : Theme.of(context).colorScheme.onSurface.withAlpha(50),
                                                width: 2.2,
                                              ),
                                              color: completed ? Colors.green.withOpacity(0.18) : Colors.transparent,
                                            ),
                                            child: completed ? Icon(Icons.check, size: 18, color: Colors.green) : null,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: isBonus ? const EdgeInsets.only(left: 8) : EdgeInsets.zero,
                                                  child: Text(
                                                    description,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontFamily: 'NovecentoSans',
                                                    ),
                                                  ),
                                                ),
                                                if (consistencyIndicators != null) ...[
                                                  const SizedBox(height: 8),
                                                  consistencyIndicators,
                                                ],
                                                if (accuracyIndicators != null) ...[
                                                  const SizedBox(height: 8),
                                                  accuracyIndicators,
                                                ],
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
                      ),
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

Widget _buildAchievementItem(QueryDocumentSnapshot<Object?> achievement, Widget child) {
  User? user = FirebaseAuth.instance.currentUser;
  final data = achievement.data() as Map<String, dynamic>;
  final id = data['id'] ?? '';
  final completed = data['completed'] == true;

  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('meta').doc('achievementSwaps').snapshots(),
    builder: (context, swapMetaSnap) {
      int swapCount = 0;
      DateTime? lastSwap;
      if (swapMetaSnap.hasData && swapMetaSnap.data != null && swapMetaSnap.data!.exists) {
        final meta = swapMetaSnap.data!.data() as Map<String, dynamic>?;
        swapCount = (meta?['swapCount'] is int) ? meta!['swapCount'] : 0;
        final ls = meta?['lastSwap'];
        if (ls is Timestamp) {
          lastSwap = ls.toDate();
        } else if (ls is DateTime) {
          lastSwap = ls;
        }
      }
      const swapDelays = [0, 0, 0, 60000, 180000, 300000, 600000, 1200000, 86400000];
      // Calculate cooldown
      int delayMs = 0;
      if (swapCount >= 0 && swapCount < swapDelays.length) {
        delayMs = swapDelays[swapCount];
      } else if (swapCount >= swapDelays.length) {
        delayMs = swapDelays.last;
      }
      bool inCooldown = false;
      if (lastSwap != null && delayMs > 0) {
        final now = DateTime.now();
        final nextAllowed = lastSwap.add(Duration(milliseconds: delayMs));
        inCooldown = now.isBefore(nextAllowed);
      }
      return Dismissible(
        key: Key(id ?? 'achievement_${achievement.id}'),
        direction: completed ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          color: Colors.transparent,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 5),
          child: SwapCooldownTimer(
            swapCount: swapCount,
            lastSwap: lastSwap,
            swapDelays: swapDelays,
          ),
        ),
        confirmDismiss: (direction) async {
          if (inCooldown) {
            // If in cooldown, do nothing (no dialog, no swap)
            return false;
          }
          // Otherwise, show confirm dialog
          return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Swap Achievement?'),
                  content: const Text('Are you sure you want to swap this achievement for a new one?'),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                        backgroundColor: Colors.transparent,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Swap'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
        onDismissed: (direction) async {
          // Call swapAchievement cloud function
          final achievementId = achievement.id;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Swapping achievement...'),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );
          try {
            final functions = FirebaseFunctions.instance;
            final swapAchievement = functions.httpsCallable('swapAchievement');
            final result = await swapAchievement({'achievementId': achievementId});
            if (result.data != null && result.data['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Achievement swapped!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              final msg = result.data != null && result.data['message'] != null ? result.data['message'] : 'Swap failed.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: Theme.of(context).primaryColor,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            print('Error occurred while swapping achievement: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Swap failed.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
        child: child,
      );
    },
  );
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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

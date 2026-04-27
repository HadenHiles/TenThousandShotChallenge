import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A consolidated, single-row (Wrap) of tappable stat chips that shows both
/// achievement and shooting-streak metrics for a given user.
///
/// Tap any chip to see a plain-English description of what the stat means.
class UserStatsChipsRow extends StatefulWidget {
  final String userId;
  final EdgeInsetsGeometry padding;
  final bool showAchievementChips;
  final bool showShootingChips;

  /// When viewing another player's profile, pass their preferred display name
  /// so tooltip text uses third-person language instead of "your / you've".
  final String? playerName;

  const UserStatsChipsRow({
    super.key,
    required this.userId,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.showAchievementChips = true,
    this.showShootingChips = true,
    this.playerName,
  });

  @override
  State<UserStatsChipsRow> createState() => _UserStatsChipsRowState();
}

class _UserStatsChipsRowState extends State<UserStatsChipsRow> {
  // ── Shooting / training stats (loaded async) ──────────────────────────────
  int _shootStreak = 0;
  int _shootBest = 0;
  Duration _totalDuration = Duration.zero;
  bool _shootingLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShootingStats();
  }

  @override
  void didUpdateWidget(UserStatsChipsRow old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      setState(() => _shootingLoading = true);
      _loadShootingStats();
    }
  }

  Future<void> _loadShootingStats() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final iters = await firestore.collection('iterations').doc(widget.userId).collection('iterations').get();

      final activeDayKeys = <String>{};
      int totalSeconds = 0;
      for (final iter in iters.docs) {
        final iterData = iter.data();
        final sessions = await iter.reference.collection('sessions').get();
        for (final sess in sessions.docs) {
          final sessData = sess.data();
          final date = _extractDate(sessData, iterData);
          if (date != null) {
            final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            activeDayKeys.add(key);
          }
          totalSeconds += (sessData['duration'] as int? ?? 0);
        }
      }

      if (activeDayKeys.isEmpty && totalSeconds == 0) {
        if (mounted) setState(() => _shootingLoading = false);
        return;
      }

      final sortedDays = activeDayKeys.toList()..sort();

      // ── Best streak ───────────────────────────────────────────────────────
      int bestStreak = sortedDays.isEmpty ? 0 : 1;
      int run = 1;
      for (int i = 1; i < sortedDays.length; i++) {
        final prev = DateTime.parse(sortedDays[i - 1]);
        final curr = DateTime.parse(sortedDays[i]);
        if (curr.difference(prev).inDays == 1) {
          run++;
          if (run > bestStreak) bestStreak = run;
        } else {
          run = 1;
        }
      }

      // ── Current streak (must end today or yesterday) ──────────────────────
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      int currentStreak = 0;
      if (sortedDays.isNotEmpty) {
        final lastDay = sortedDays.last;
        if (lastDay == todayStr || lastDay == yesterdayStr) {
          currentStreak = 1;
          DateTime anchor = DateTime.parse(lastDay);
          for (int i = sortedDays.length - 2; i >= 0; i--) {
            final prevDay = DateTime.parse(sortedDays[i]);
            if (anchor.difference(prevDay).inDays == 1) {
              currentStreak++;
              anchor = prevDay;
            } else {
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _shootStreak = currentStreak;
          _shootBest = bestStreak;
          _totalDuration = Duration(seconds: totalSeconds);
          _shootingLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _shootingLoading = false);
    }
  }

  DateTime? _extractDate(
    Map<String, dynamic> sessionData,
    Map<String, dynamic> iterData,
  ) {
    for (final key in [
      'date',
      'session_date',
      'sessionDate',
      'created_at',
      'createdAt',
      'updated_at',
      'updatedAt',
    ]) {
      final d = _parseDate(sessionData[key]);
      if (d != null) return d;
    }
    for (final key in ['updated_at', 'start_date']) {
      final d = _parseDate(iterData[key]);
      if (d != null) return d;
    }
    return null;
  }

  /// Formats a duration into a compact string: "4h 32m", "3d 2h", "45m", etc.
  String _fmtDuration(Duration d) {
    if (d.inSeconds == 0) return '0m';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    final days = d.inHours ~/ 24;
    final h = d.inHours.remainder(24);
    return h > 0 ? '${days}d ${h}h' : '${days}d';
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final historyRef = FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('stats').doc('history');

    return Padding(
      padding: widget.padding,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: historyRef.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};

          final achStreak = (data['weeklyAllCompletedStreak'] is num) ? (data['weeklyAllCompletedStreak'] as num).toInt() : 0;
          final achBest = (data['bestWeeklyAllCompletedStreak'] is num) ? (data['bestWeeklyAllCompletedStreak'] as num).toInt() : 0;

          final sLoad = _shootingLoading;

          final n = widget.playerName;
          final chips = <_ChipSpec>[
            _ChipSpec(
              icon: Icons.local_fire_department,
              color: Colors.orange,
              label: 'Current Streak',
              value: '${achStreak}w',
              tooltipMessage: n != null ? 'Consecutive weeks $n has completed all weekly achievements. Missing a week resets this to zero.' : "Consecutive weeks you've completed all your weekly achievements. Missing a week resets this to zero.",
              isAchievement: true,
            ),
            _ChipSpec(
              icon: Icons.military_tech,
              color: Colors.amber.shade700,
              label: 'Best Streak',
              value: '${achBest}w',
              tooltipMessage: n != null ? "$n's longest-ever streak of completing all weekly achievements in a row, in weeks." : "Your longest-ever streak of completing all weekly achievements in a row, in weeks.",
              isAchievement: true,
            ),
            _ChipSpec(
              icon: Icons.sports_hockey,
              color: Colors.deepOrange,
              label: 'Streak',
              value: sLoad ? '…' : '${_shootStreak}d',
              tooltipMessage: n != null ? 'Consecutive days $n has logged at least one shooting session. Resets if a day is missed.' : "Consecutive days you've logged at least one shooting session. Resets if you miss a day.",
              isAchievement: false,
            ),
            _ChipSpec(
              icon: Icons.stars,
              color: Colors.deepOrange.shade700,
              label: 'Best Streak',
              value: sLoad ? '…' : '${_shootBest}d',
              tooltipMessage: n != null ? "$n's longest-ever consecutive daily shooting streak, in days." : 'Your longest-ever consecutive daily shooting streak, in days.',
              isAchievement: false,
            ),
            _ChipSpec(
              icon: Icons.timer_outlined,
              color: Colors.teal.shade400,
              label: 'Shooting Time',
              value: sLoad ? '…' : _fmtDuration(_totalDuration),
              tooltipMessage: n != null ? 'Total time $n has spent shooting across all sessions.' : 'Total time spent shooting across all sessions in your history.',
              isAchievement: false,
            ),
          ];

          final visible = chips.where((c) => c.isAchievement ? widget.showAchievementChips : widget.showShootingChips).toList();

          return Row(
            children: [
              for (int i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _StatChip(spec: visible[i])),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Internal data + chip widget ───────────────────────────────────────────────

class _ChipSpec {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String tooltipMessage;

  final bool isAchievement;

  const _ChipSpec({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.tooltipMessage,
    required this.isAchievement,
  });
}

class _StatChip extends StatelessWidget {
  final _ChipSpec spec;

  const _StatChip({required this.spec});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15);
    final labelColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);
    final valueColor = Theme.of(context).colorScheme.onSurface;

    final theme = Theme.of(context);
    return Tooltip(
      message: spec.tooltipMessage,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 13,
        height: 1.45,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label - auto-scales to fit without truncating
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                spec.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Icon + value
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(spec.icon, size: 14, color: spec.color),
                const SizedBox(width: 3),
                Text(
                  spec.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

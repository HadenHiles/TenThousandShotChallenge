import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Displays the current and all-time best shooting streak (consecutive days
/// with at least one session) for a given user. Session dates are loaded from
/// all iterations so the streak is computed across the user's full history,
/// matching the behaviour used in the Compare Stats view.
class ShootingStreakRow extends StatefulWidget {
  final String userId;
  final EdgeInsetsGeometry padding;
  final bool inline;

  const ShootingStreakRow({
    super.key,
    required this.userId,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.inline = false,
  });

  @override
  State<ShootingStreakRow> createState() => _ShootingStreakRowState();
}

class _ShootingStreakRowState extends State<ShootingStreakRow> {
  int _currentStreak = 0;
  int _bestStreak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final iters = await firestore.collection('iterations').doc(widget.userId).collection('iterations').get();

      final activeDays = <String>{};
      for (final iter in iters.docs) {
        final iterData = iter.data();
        final sessions = await iter.reference.collection('sessions').get();
        for (final sess in sessions.docs) {
          final date = _extractDate(sess.data(), iterData);
          if (date != null) {
            final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            activeDays.add(key);
          }
        }
      }

      if (activeDays.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final sortedDays = activeDays.toList()..sort();

      // ── Best streak ──────────────────────────────────────────────────────
      int bestStreak = 1;
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

      // ── Current streak (consecutive days ending at today or yesterday) ──
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      int currentStreak = 0;
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

      if (mounted) {
        setState(() {
          _currentStreak = currentStreak;
          _bestStreak = bestStreak;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
      final date = _parseDate(sessionData[key]);
      if (date != null) return date;
    }
    // Fallback: use iteration updated_at or start_date as a rough proxy
    for (final key in ['updated_at', 'start_date']) {
      final date = _parseDate(iterData[key]);
      if (date != null) return date;
    }
    return null;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: widget.padding,
        child: const SizedBox(
          height: 42,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final chips = <Widget>[
      _ShootingStatChip(
        icon: Icons.local_fire_department,
        color: Colors.deepOrange,
        label: 'Shooting',
        value: '${_currentStreak}d',
        dense: widget.inline,
      ),
      SizedBox(width: widget.inline ? 6 : 10, height: widget.inline ? 6 : 8),
      _ShootingStatChip(
        icon: Icons.military_tech,
        color: Colors.amber,
        label: 'Best',
        value: '${_bestStreak}d',
        dense: widget.inline,
      ),
    ];

    return Padding(
      padding: widget.padding,
      child: widget.inline
          ? FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: chips,
              ),
            )
          : Row(mainAxisAlignment: MainAxisAlignment.start, children: chips),
    );
  }
}

class _ShootingStatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool dense;

  const _ShootingStatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).cardColor;
    final border = Theme.of(context).colorScheme.onSurface.withOpacity(0.15);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 16 : 18, color: color),
          SizedBox(width: dense ? 4 : 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: dense ? 11.5 : 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: dense ? 12.5 : 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AchievementStatsRow extends StatelessWidget {
  final String userId;
  final EdgeInsetsGeometry padding;
  final bool inline; // when true, render chips in a Wrap for compact header use
  const AchievementStatsRow({super.key, required this.userId, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8), this.inline = false});

  @override
  Widget build(BuildContext context) {
    final historyRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('stats').doc('history');
    return Padding(
      padding: padding,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: historyRef.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final totalCompleted = (data['totalAchievementsCompleted'] is num) ? (data['totalAchievementsCompleted'] as num).toInt() : 0;
          final streak = (data['weeklyAllCompletedStreak'] is num) ? (data['weeklyAllCompletedStreak'] as num).toInt() : 0;

          final chips = <Widget>[
            _StatChip(
              icon: Icons.emoji_events,
              color: Colors.amber,
              label: 'Completed',
              value: totalCompleted.toString(),
              dense: inline,
            ),
            SizedBox(width: inline ? 6 : 10, height: inline ? 6 : 8),
            _StatChip(
              icon: Icons.local_fire_department,
              color: Colors.orange,
              label: 'Streak',
              value: '${streak}x',
              dense: inline,
            ),
          ];

          if (inline) {
            // Keep on one line; scale down to fit in available width.
            return FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: chips,
              ),
            );
          }
          return Row(mainAxisAlignment: MainAxisAlignment.start, children: chips);
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool dense;
  const _StatChip({required this.icon, required this.color, required this.label, required this.value, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).cardColor;
    final border = Theme.of(context).colorScheme.onSurface.withOpacity(0.15);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 6 : 8),
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

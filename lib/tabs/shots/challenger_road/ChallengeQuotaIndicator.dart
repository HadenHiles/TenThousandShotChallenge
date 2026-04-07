import 'package:flutter/material.dart';

/// Pinned bar shown during a challenge session displaying the live on-target
/// count against the required quota.
///
/// [shotsMade]   — running total of on-target shots (may be null/unknown).
/// [shotsToPass] — minimum on-target shots needed to pass.
/// [shotsRequired] — total shots the player must take.
/// [totalShots]  — running total of shots taken this session.
/// [tryCount] — number of tries logged in this session.
class ChallengeQuotaIndicator extends StatelessWidget {
  final int shotsMade;
  final int shotsToPass;
  final int shotsRequired;
  final int totalShots;
  final int tryCount;

  const ChallengeQuotaIndicator({
    super.key,
    required this.shotsMade,
    required this.shotsToPass,
    required this.shotsRequired,
    required this.totalShots,
    required this.tryCount,
  });

  @override
  Widget build(BuildContext context) {
    final bool passing = shotsMade >= shotsToPass;
    final bool sessionDone = totalShots >= shotsRequired;
    final String tryLabel = tryCount <= 0 ? 'Try 1' : 'Try $tryCount';
    final double quotaProgress = shotsToPass > 0 ? (shotsMade / shotsToPass).clamp(0.0, 1.0) : 0.0;
    final Color barColor = passing ? Colors.green.shade600 : Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: barColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // On-target count
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tryLabel,
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        passing ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        color: barColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$shotsMade / $shotsToPass on target',
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 16,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Shots taken badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalShots / $shotsRequired shots',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: quotaProgress,
              minHeight: 5,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (sessionDone && !passing)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Try complete - target score not reached',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

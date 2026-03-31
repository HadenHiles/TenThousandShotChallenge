import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';

/// Sticky header shown at the top of the Challenger Road Start tab (pro users only).
/// Displays the current level badge, the rolling Challenger Road shot counter,
/// and the current attempt number.
class ChallengerRoadHeader extends StatelessWidget {
  final ChallengerRoadAttempt? attempt;
  final VoidCallback? onRestartTap;

  const ChallengerRoadHeader({
    super.key,
    this.attempt,
    this.onRestartTap,
  });

  @override
  Widget build(BuildContext context) {
    final shotCount = attempt?.challengerRoadShotCount ?? 0;
    final level = attempt?.currentLevel ?? 1;
    final attemptNum = attempt?.attemptNumber ?? 1;
    final resetCount = attempt?.resetCount ?? 0;
    final numberFormat = NumberFormat('#,###');
    final progress = shotCount / 10000.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Level badge ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'LVL $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'NovecentoSans',
                    fontSize: 20,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              // ── Shot counter ─────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHALLENGER SHOTS',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      fontFamily: 'NovecentoSans',
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${numberFormat.format(shotCount)} / 10,000',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'NovecentoSans',
                      fontSize: 20,
                    ),
                  ),
                  if (resetCount > 0)
                    Text(
                      '× $resetCount milestone${resetCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontFamily: 'NovecentoSans',
                        fontSize: 11,
                      ),
                    ),
                ],
              ),

              // ── Attempt badge ────────────────────────────────────────
              GestureDetector(
                onTap: onRestartTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TRY',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        fontFamily: 'NovecentoSans',
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '#$attemptNum',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'NovecentoSans',
                        fontSize: 24,
                      ),
                    ),
                    if (onRestartTap != null)
                      Text(
                        'RESTART',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontFamily: 'NovecentoSans',
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Progress bar (CR shot counter 0 → 10,000) ────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

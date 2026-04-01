import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';

/// Sticky header shown at the top of the Challenger Road Start tab.
/// Displays the current level badge, the rolling Challenger Road shot counter,
/// and the current attempt number.
class ChallengerRoadHeader extends StatelessWidget {
  final ChallengerRoadAttempt? attempt;
  final double topPadding;
  final VoidCallback? onRestartTap;
  final VoidCallback? onCloseTap;

  const ChallengerRoadHeader({
    super.key,
    this.attempt,
    this.topPadding = 0,
    this.onRestartTap,
    this.onCloseTap,
  });

  @override
  Widget build(BuildContext context) {
    final shotCount = attempt?.challengerRoadShotCount ?? 0;
    final level = attempt?.currentLevel ?? 1;
    final attemptNum = attempt?.attemptNumber ?? 1;
    final resetCount = attempt?.resetCount ?? 0;
    final numberFormat = NumberFormat('#,###');
    final progress = shotCount / 10000.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      padding: EdgeInsets.fromLTRB(16, 7 + topPadding, 16, 6),
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
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 13),
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
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHALLENGER ROAD',
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
                      fontSize: 18,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onRestartTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ATTEMPT',
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
                            fontSize: 22,
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
                  if (onCloseTap != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.16),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 20,
                        tooltip: 'Close Road',
                        onPressed: onCloseTap,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

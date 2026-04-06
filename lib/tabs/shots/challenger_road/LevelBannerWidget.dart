import 'package:flutter/material.dart';

/// Horizontal banner separating level groups on the Challenger Road snake map.
class LevelBannerWidget extends StatelessWidget {
  final String levelName;

  /// True if this is the level the player is currently on.
  final bool isCurrentLevel;

  /// True if this level is not yet accessible (above current level).
  final bool isLocked;

  const LevelBannerWidget({
    super.key,
    required this.levelName,
    required this.isCurrentLevel,
    required this.isLocked,
  });

  Color _bannerColor(BuildContext context) {
    if (isLocked) return Colors.grey.shade700;
    if (isCurrentLevel) return Theme.of(context).primaryColor;
    return Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final color = _bannerColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        children: [
          // Left connector line
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, color.withValues(alpha: 0.6)],
                ),
              ),
            ),
          ),

          // Banner pill
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 18),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isCurrentLevel
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLocked) ...[
                  const Icon(Icons.lock, color: Colors.white70, size: 14),
                  const SizedBox(width: 5),
                ] else if (!isCurrentLevel) ...[
                  const Icon(Icons.check_circle, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                ],
                Text(
                  levelName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'NovecentoSans',
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Right connector line
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

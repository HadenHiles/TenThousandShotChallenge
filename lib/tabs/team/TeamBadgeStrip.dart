import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/TeamBadge.dart';

/// Compact row of the badges a player has earned, with a count in the corner
/// when the same badge was earned on more than one day.
class TeamBadgeStrip extends StatelessWidget {
  const TeamBadgeStrip({super.key, required this.counts, this.size = 30});

  final Map<String, int> counts;
  final double size;

  @override
  Widget build(BuildContext context) {
    final earned = [for (final badge in teamBadges) if ((counts[badge.id] ?? 0) > 0) badge];
    if (earned.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final badge in earned) TeamBadgeIcon(badge: badge, count: counts[badge.id]!, size: size),
        ],
      ),
    );
  }
}

class TeamBadgeIcon extends StatelessWidget {
  const TeamBadgeIcon({super.key, required this.badge, this.count = 1, this.size = 30});

  final TeamBadge badge;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.title,
      child: SizedBox(
        width: size + 6,
        height: size + 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: Image.asset(badge.asset, width: size, height: size, semanticLabel: badge.title),
            ),
            if (count > 1)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 12, height: 1.1, color: Theme.of(context).colorScheme.surface),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

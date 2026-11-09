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
    final earned = [
      for (final badge in teamBadges)
        if ((counts[badge.id] ?? 0) > 0) badge
    ];
    if (earned.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final badge in earned)
          TeamBadgeIcon(
              badge: badge,
              count: counts[badge.id]!,
              size: size,
              showDetailOnTap: true),
      ],
    );
  }
}

/// Explains what a badge is and how many times the player has earned it.
Future<void> showTeamBadgeDetail(BuildContext context, TeamBadge badge,
    {int count = 1}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.primary,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      final onPrimary = Theme.of(sheetContext).colorScheme.onPrimary;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(badge.asset,
                  width: 96, height: 96, semanticLabel: badge.title),
              const SizedBox(height: 8),
              Text(badge.title.toUpperCase(),
                  style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 28,
                      color: onPrimary)),
              const SizedBox(height: 4),
              Text(badge.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: onPrimary.withValues(alpha: 0.8))),
              if (count > 1) ...[
                const SizedBox(height: 12),
                Text('Earned $count times',
                    style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 18,
                        color: onPrimary.withValues(alpha: 0.7))),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class TeamBadgeIcon extends StatelessWidget {
  const TeamBadgeIcon(
      {super.key,
      required this.badge,
      this.count = 1,
      this.size = 30,
      this.showDetailOnTap = false});

  final TeamBadge badge;
  final int count;
  final double size;
  final bool showDetailOnTap;

  @override
  Widget build(BuildContext context) {
    final icon = _buildIcon(context);
    if (!showDetailOnTap) return icon;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTeamBadgeDetail(context, badge, count: count),
      child: icon,
    );
  }

  Widget _buildIcon(BuildContext context) {
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
              child: Image.asset(badge.asset,
                  width: size, height: size, semanticLabel: badge.title),
            ),
            if (count > 1)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 12,
                        height: 1.1,
                        color: Theme.of(context).colorScheme.surface),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

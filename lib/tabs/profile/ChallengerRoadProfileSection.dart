import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';

// ── Main widget ────────────────────────────────────────────────────────────

/// Drop-in Challenger Road section for the Profile tab.
///
/// Pass [userId] and the current [isPro] flag.
/// Both free and pro users can see their stats and badges — free users also
/// see a compact "Go Pro" nudge encouraging them to unlock full gameplay.
class ChallengerRoadProfileSection extends StatelessWidget {
  const ChallengerRoadProfileSection({
    super.key,
    required this.userId,
    required this.isPro,
    this.onGoProTap,
  });

  final String userId;
  final bool isPro;
  final VoidCallback? onGoProTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChallengerRoadUserSummary>(
      stream: ChallengerRoadService().watchUserSummary(userId),
      builder: (context, snap) {
        final summary = snap.data ?? ChallengerRoadUserSummary.empty();
        return _buildContent(context, summary);
      },
    );
  }

  // ── Content (all users) ──────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, ChallengerRoadUserSummary summary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Free-user Go-Pro nudge banner
          if (!isPro) ...[
            const SizedBox(height: 8),
            _GoProNudge(onGoProTap: onGoProTap),
          ],
          const SizedBox(height: 8),
          // Personal Best Badge
          _PersonalBestBadge(
            level: summary.allTimeBestLevel,
            shots: summary.allTimeBestLevelShots,
          ),
          const SizedBox(height: 20),
          // Stats row
          _StatsRow(summary: summary),
          const SizedBox(height: 20),
          // Badge bar
          Text(
            'BADGES',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<ChallengerRoadBadgeDefinition>>(
            // Badge catalog is global — same for every user.
            future: ChallengerRoadService().getBadgeCatalog(),
            builder: (context, badgeSnap) {
              final badgeDefs = badgeSnap.data ?? const <ChallengerRoadBadgeDefinition>[];
              if (badgeDefs.isEmpty && summary.badges.isEmpty && badgeSnap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return _BadgeWrapGrid(
                earnedBadges: summary.badges,
                summary: summary,
                badgeDefs: badgeDefs,
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Compact Go-Pro nudge (free users only) ──────────────────────────────────

class _GoProNudge extends StatelessWidget {
  const _GoProNudge({this.onGoProTap});
  final VoidCallback? onGoProTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.lock_open_rounded, color: primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'earn more badges & unlock the full challenger road.',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          if (onGoProTap != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onGoProTap,
              style: TextButton.styleFrom(
                foregroundColor: primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'GO PRO',
                style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Personal Best Badge widget ──────────────────────────────────────────────

class _PersonalBestBadge extends StatelessWidget {
  const _PersonalBestBadge({required this.level, required this.shots});
  final int level;
  final int? shots;

  @override
  Widget build(BuildContext context) {
    final hasLevel = level > 0;
    final primary = Theme.of(context).primaryColor;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: hasLevel ? 0.35 : 0.1),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            // Badge circle
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasLevel
                    ? RadialGradient(colors: [primary.withValues(alpha: 0.65), primary])
                    : RadialGradient(colors: [
                        Colors.grey.shade700,
                        Colors.grey.shade800,
                      ]),
              ),
              child: Center(
                child: hasLevel
                    ? Text(
                        '$level',
                        style: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 46,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      )
                    : Icon(Icons.route_rounded, size: 48, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'PERSONAL BEST',
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 1.5,
          ),
        ),
        Text(
          hasLevel ? 'Level $level' : 'No level completed yet',
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 18,
            color: hasLevel ? primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        if (hasLevel && shots != null) ...[
          const SizedBox(height: 4),
          Text(
            'Set in ${_formatShotCount(shots!)} shots',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ],
    );
  }
}

String _formatShotCount(int shots) {
  final digits = shots.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

// ── Stats row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary});
  final ChallengerRoadUserSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _statChip(
          context,
          label: 'ATTEMPTS',
          value: '${summary.totalAttempts}',
          icon: Icons.repeat_rounded,
        ),
        const SizedBox(width: 8),
        _statChip(
          context,
          label: 'CR SHOTS',
          value: _formatShots(summary.allTimeTotalChallengerRoadShots),
          icon: Icons.sports_hockey_rounded,
        ),
        const SizedBox(width: 8),
        _statChip(
          context,
          label: 'BADGES',
          value: '${summary.badges.length}',
          icon: Icons.military_tech_rounded,
        ),
      ],
    );
  }

  Widget _statChip(BuildContext context, {required String label, required String value, required IconData icon}) {
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 22,
                color: scheme.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 11,
                color: scheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShots(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

// ── Badge scroll row ────────────────────────────────────────────────────────

class _BadgeWrapGrid extends StatelessWidget {
  const _BadgeWrapGrid({
    required this.earnedBadges,
    required this.summary,
    required this.badgeDefs,
  });

  final List<String> earnedBadges;
  final ChallengerRoadUserSummary summary;
  final List<ChallengerRoadBadgeDefinition> badgeDefs;

  List<ChallengerRoadBadgeDefinition> _buildDisplayDefs() {
    final knownById = <String, ChallengerRoadBadgeDefinition>{
      for (final badge in badgeDefs) badge.id: badge,
    };

    final unknownEarned = earnedBadges.where((id) => !knownById.containsKey(id)).map((id) {
      return ChallengerRoadBadgeDefinition(
        id: id,
        name: _titleFromBadgeId(id),
        description: 'Legacy Challenger Road badge.',
        category: ChallengerRoadBadgeCategory.special,
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return [...badgeDefs, ...unknownEarned];
  }

  @override
  Widget build(BuildContext context) {
    final displayDefs = _buildDisplayDefs();

    if (displayDefs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'No badge definitions available yet.',
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayDefs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final def = displayDefs[index];
        final earned = earnedBadges.contains(def.id);
        return Align(
          alignment: Alignment.topCenter,
          child: _BadgeChip(def: def, earned: earned, summary: summary),
        );
      },
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.def, required this.earned, required this.summary});
  final ChallengerRoadBadgeDefinition def;
  final bool earned;
  final ChallengerRoadUserSummary summary;

  IconData _iconForBadge() {
    switch (def.category) {
      case ChallengerRoadBadgeCategory.attempts:
        return Icons.repeat_rounded;
      case ChallengerRoadBadgeCategory.shotsMilestone:
        return Icons.workspace_premium_rounded;
      case ChallengerRoadBadgeCategory.levelAllClear:
        return Icons.route_rounded;
      case ChallengerRoadBadgeCategory.shotTypeLevelMastery:
        switch ((def.shotType ?? '').toLowerCase()) {
          case 'snap':
            return Icons.bolt_rounded;
          case 'backhand':
            return Icons.undo_rounded;
          case 'slap':
            return Icons.flash_on_rounded;
          case 'wrist':
          default:
            return Icons.sports_hockey_rounded;
        }
      case ChallengerRoadBadgeCategory.outperform:
        return Icons.emoji_events_rounded;
      case ChallengerRoadBadgeCategory.special:
        if (def.id == 'cr_comeback') return Icons.trending_up_rounded;
        if (def.id == 'cr_perfect_level') return Icons.stars_rounded;
        return Icons.military_tech_rounded;
    }
  }

  Color _colorForBadge() {
    switch (def.category) {
      case ChallengerRoadBadgeCategory.attempts:
        return const Color(0xFF29B6F6);
      case ChallengerRoadBadgeCategory.shotsMilestone:
        return const Color(0xFFFF7043);
      case ChallengerRoadBadgeCategory.levelAllClear:
        return const Color(0xFF26A69A);
      case ChallengerRoadBadgeCategory.shotTypeLevelMastery:
        switch ((def.shotType ?? '').toLowerCase()) {
          case 'snap':
            return const Color(0xFF64B5F6);
          case 'backhand':
            return const Color(0xFF9575CD);
          case 'slap':
            return const Color(0xFFFFB74D);
          case 'wrist':
          default:
            return const Color(0xFF4FC3F7);
        }
      case ChallengerRoadBadgeCategory.outperform:
        return const Color(0xFFFF8A65);
      case ChallengerRoadBadgeCategory.special:
        return const Color(0xFF8D6E63);
    }
  }

  String _requirementText() {
    return def.description;
  }

  String? _progressText() {
    if (def.category == ChallengerRoadBadgeCategory.attempts && def.threshold != null) {
      return 'Progress: ${summary.totalAttempts}/${def.threshold} attempts';
    }

    if (def.category == ChallengerRoadBadgeCategory.shotsMilestone && def.threshold != null) {
      return 'Progress: ${summary.allTimeTotalChallengerRoadShots}/${def.threshold} Challenger Road shots';
    }

    return null;
  }

  void _showBadgeDetails(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_iconForBadge(), color: earned ? _colorForBadge() : scheme.onSurface.withValues(alpha: 0.6), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        def.name,
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 22,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  earned ? 'Unlocked' : 'Locked',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 14,
                    color: earned ? Colors.green : scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _requirementText(),
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 15,
                    color: scheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                if (_progressText() != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _progressText()!,
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 13,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: earned ? def.description : 'Locked: ${def.description}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showBadgeDetails(context),
        child: Opacity(
          opacity: earned ? 1.0 : 0.45,
          child: SizedBox(
            width: 104,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: earned ? _colorForBadge().withValues(alpha: 0.18) : Theme.of(context).primaryColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: earned ? _colorForBadge() : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                      width: earned ? 2.0 : 1.2,
                    ),
                    boxShadow: earned
                        ? [
                            BoxShadow(
                              color: _colorForBadge().withValues(alpha: 0.3),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    _iconForBadge(),
                    size: 26,
                    color: earned ? _colorForBadge() : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  def.name,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 11,
                    color: earned ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _titleFromBadgeId(String id) {
  return id.replaceAll('cr_', '').split('_').where((p) => p.isNotEmpty).map((part) => '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
}

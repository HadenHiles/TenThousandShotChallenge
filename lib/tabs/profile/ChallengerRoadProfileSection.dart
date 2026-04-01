import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';

// ── Badge metadata ─────────────────────────────────────────────────────────

class _BadgeDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _BadgeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const List<_BadgeDef> _kBadges = [
  _BadgeDef(
    id: 'cr_attempts_1',
    name: 'First Step',
    description: 'Start your first Challenger Road attempt',
    icon: Icons.flag_rounded,
    color: Color(0xFF66BB6A),
  ),
  _BadgeDef(
    id: 'cr_attempts_3',
    name: 'Committed',
    description: '3 Challenger Road attempts',
    icon: Icons.repeat_rounded,
    color: Color(0xFF29B6F6),
  ),
  _BadgeDef(
    id: 'cr_attempts_10',
    name: 'Relentless',
    description: '10 Challenger Road attempts',
    icon: Icons.repeat_on_rounded,
    color: Color(0xFF7E57C2),
  ),
  _BadgeDef(
    id: 'cr_attempts_25',
    name: 'Iron Will',
    description: '25 Challenger Road attempts',
    icon: Icons.military_tech_rounded,
    color: Color(0xFF26A69A),
  ),
  _BadgeDef(
    id: 'cr_attempts_50',
    name: 'Road Warrior',
    description: '50 Challenger Road attempts',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFFFD700),
  ),
  _BadgeDef(
    id: 'cr_10k_x1',
    name: 'First 10,000',
    description: 'Hit 10,000 Challenger Road shots',
    icon: Icons.my_location_rounded,
    color: Color(0xFFFF7043),
  ),
  _BadgeDef(
    id: 'cr_10k_x3',
    name: 'Triple Threat',
    description: 'Hit 10,000 shots 3× on the Challenger Road',
    icon: Icons.star_rounded,
    color: Color(0xFFFFCA28),
  ),
  _BadgeDef(
    id: 'cr_10k_x10',
    name: 'Shot Machine',
    description: 'Hit 10,000 shots 10× on the Challenger Road',
    icon: Icons.bolt_rounded,
    color: Color(0xFFEF5350),
  ),
  _BadgeDef(
    id: 'cr_level_5',
    name: 'Level 5 Reached',
    description: 'Complete Level 5 in any attempt',
    icon: Icons.looks_5_rounded,
    color: Color(0xFF26C6DA),
  ),
  _BadgeDef(
    id: 'cr_level_10',
    name: 'Double Digits',
    description: 'Complete Level 10 in any attempt',
    icon: Icons.filter_none_rounded,
    color: Color(0xFFAB47BC),
  ),
  _BadgeDef(
    id: 'cr_perfect_level',
    name: 'Flawless',
    description: 'Complete an entire level with no retries',
    icon: Icons.verified_rounded,
    color: Color(0xFF42A5F5),
  ),
  _BadgeDef(
    id: 'cr_comeback',
    name: 'The Comeback',
    description: 'Start at Level 1 and complete Level 5+',
    icon: Icons.trending_up_rounded,
    color: Color(0xFFFF8F00),
  ),
  _BadgeDef(
    id: 'cr_all_challenges_v1',
    name: 'Road Complete',
    description: 'Complete all available Challenger Road challenges',
    icon: Icons.route_rounded,
    color: Color(0xFFFFD700),
  ),
];

// ── Main widget ────────────────────────────────────────────────────────────

/// Drop-in Challenger Road section for the Profile tab.
///
/// Pass [userId] and the current [isPro] flag. If the user is not pro,
/// a teaser callout is shown instead of badge data.
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
    if (!isPro) {
      return _buildUpsell(context);
    }

    return StreamBuilder<ChallengerRoadUserSummary>(
      stream: ChallengerRoadService().watchUserSummary(userId),
      builder: (context, snap) {
        final summary = snap.data ?? ChallengerRoadUserSummary.empty();
        return _buildContent(context, summary);
      },
    );
  }

  // ── Pro content ─────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, ChallengerRoadUserSummary summary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Personal Best Badge
          _PersonalBestBadge(level: summary.allTimeBestLevel),
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
          _BadgeScrollRow(earnedBadges: summary.badges, summary: summary),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Free user upsell ────────────────────────────────────────────────────

  Widget _buildUpsell(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.route_rounded, color: primary, size: 28),
                const SizedBox(width: 10),
                Text(
                  'CHALLENGER ROAD',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Challenger Road is a Pro feature. Earn badges, track your personal best level, and compete on the road to 10,000 shots.',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            if (onGoProTap != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onGoProTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'GO PRO',
                  style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Personal Best Badge widget ──────────────────────────────────────────────

class _PersonalBestBadge extends StatelessWidget {
  const _PersonalBestBadge({required this.level});
  final int level;

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
      ],
    );
  }
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

class _BadgeScrollRow extends StatelessWidget {
  const _BadgeScrollRow({required this.earnedBadges, required this.summary});
  final List<String> earnedBadges;
  final ChallengerRoadUserSummary summary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _kBadges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final def = _kBadges[index];
          final earned = earnedBadges.contains(def.id);
          return _BadgeChip(def: def, earned: earned, summary: summary);
        },
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.def, required this.earned, required this.summary});
  final _BadgeDef def;
  final bool earned;
  final ChallengerRoadUserSummary summary;

  String _requirementText() {
    switch (def.id) {
      case 'cr_attempts_1':
        return 'Start 1 Challenger Road attempt.';
      case 'cr_attempts_3':
        return 'Start 3 Challenger Road attempts.';
      case 'cr_attempts_10':
        return 'Start 10 Challenger Road attempts.';
      case 'cr_attempts_25':
        return 'Start 25 Challenger Road attempts.';
      case 'cr_attempts_50':
        return 'Start 50 Challenger Road attempts.';
      case 'cr_10k_x1':
        return 'Reach 10,000 total Challenger Road shots.';
      case 'cr_10k_x3':
        return 'Reach 30,000 total Challenger Road shots (10,000 x 3).';
      case 'cr_10k_x10':
        return 'Reach 100,000 total Challenger Road shots (10,000 x 10).';
      case 'cr_level_5':
        return 'Complete Level 5 in any Challenger Road attempt.';
      case 'cr_level_10':
        return 'Complete Level 10 in any Challenger Road attempt.';
      case 'cr_perfect_level':
        return 'Complete one full level with zero retries.';
      case 'cr_comeback':
        return 'Start from Level 1 and complete Level 5 or higher in that attempt.';
      case 'cr_all_challenges_v1':
        return 'Complete all currently available Challenger Road challenges.';
      default:
        return def.description;
    }
  }

  String? _progressText() {
    int targetAttempts(String id) {
      switch (id) {
        case 'cr_attempts_1':
          return 1;
        case 'cr_attempts_3':
          return 3;
        case 'cr_attempts_10':
          return 10;
        case 'cr_attempts_25':
          return 25;
        case 'cr_attempts_50':
          return 50;
        default:
          return 0;
      }
    }

    int targetShots(String id) {
      switch (id) {
        case 'cr_10k_x1':
          return 10000;
        case 'cr_10k_x3':
          return 30000;
        case 'cr_10k_x10':
          return 100000;
        default:
          return 0;
      }
    }

    int targetLevels(String id) {
      switch (id) {
        case 'cr_level_5':
          return 5;
        case 'cr_level_10':
          return 10;
        default:
          return 0;
      }
    }

    final attemptTarget = targetAttempts(def.id);
    if (attemptTarget > 0) {
      return 'Progress: ${summary.totalAttempts}/$attemptTarget attempts';
    }
    final shotsTarget = targetShots(def.id);
    if (shotsTarget > 0) {
      return 'Progress: ${summary.allTimeTotalChallengerRoadShots}/$shotsTarget Challenger Road shots';
    }
    final levelTarget = targetLevels(def.id);
    if (levelTarget > 0) {
      return 'Progress: best level ${summary.allTimeBestLevel}/$levelTarget';
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
                    Icon(def.icon, color: earned ? def.color : scheme.onSurface.withValues(alpha: 0.6), size: 22),
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
            width: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: earned ? def.color.withValues(alpha: 0.18) : Theme.of(context).primaryColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: earned ? def.color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                      width: earned ? 2.0 : 1.2,
                    ),
                    boxShadow: earned
                        ? [
                            BoxShadow(
                              color: def.color.withValues(alpha: 0.3),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    def.icon,
                    size: 26,
                    color: earned ? def.color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  def.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 10,
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

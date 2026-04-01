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
    name: 'Road Grinder',
    description: '10 Challenger Road attempts',
    icon: Icons.military_tech_rounded,
    color: Color(0xFF7E57C2),
  ),
  _BadgeDef(
    id: 'cr_level1_all_clear',
    name: 'Level 1 Clear',
    description: 'Pass every active Level 1 challenge at least once',
    icon: Icons.route_rounded,
    color: Color(0xFF26A69A),
  ),
  _BadgeDef(
    id: 'cr_wrist_l1_x3',
    name: 'Wrist Work',
    description: 'Pass any wrist-shot Level 1 challenge 3 times',
    icon: Icons.sports_hockey_rounded,
    color: Color(0xFF4FC3F7),
  ),
  _BadgeDef(
    id: 'cr_snap_l1_x3',
    name: 'Snap Skills',
    description: 'Pass any snap-shot Level 1 challenge 3 times',
    icon: Icons.bolt_rounded,
    color: Color(0xFF64B5F6),
  ),
  _BadgeDef(
    id: 'cr_backhand_l1_x3',
    name: 'Backhand Builder',
    description: 'Pass any backhand Level 1 challenge 3 times',
    icon: Icons.undo_rounded,
    color: Color(0xFF9575CD),
  ),
  _BadgeDef(
    id: 'cr_slap_l1_x3',
    name: 'Slap Specialist',
    description: 'Pass any slap-shot Level 1 challenge 3 times',
    icon: Icons.flash_on_rounded,
    color: Color(0xFFFFB74D),
  ),
  _BadgeDef(
    id: 'cr_wrist_warmup_l1_x3',
    name: 'Warmup Wizard',
    description: 'Pass "Wrist Shot Warmup" Level 1 three times',
    icon: Icons.adjust_rounded,
    color: Color(0xFF81C784),
  ),
  _BadgeDef(
    id: 'cr_outperform_plus2_x5',
    name: 'Clutch Finisher',
    description: 'Outperform challenge target by +2 hits, 5 times',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFFF8A65),
  ),
  _BadgeDef(
    id: 'cr_10k_x1',
    name: 'First 10,000',
    description: 'Hit 10,000 Challenger Road shots',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFFF7043),
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
          _BadgeWrapGrid(earnedBadges: summary.badges, summary: summary),
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

class _BadgeWrapGrid extends StatelessWidget {
  const _BadgeWrapGrid({required this.earnedBadges, required this.summary});
  final List<String> earnedBadges;
  final ChallengerRoadUserSummary summary;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _kBadges.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final def = _kBadges[index];
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
      case 'cr_level1_all_clear':
        return 'Pass every active Level 1 challenge at least once.';
      case 'cr_wrist_l1_x3':
        return 'Pass wrist-shot Level 1 challenges 3 times total.';
      case 'cr_snap_l1_x3':
        return 'Pass snap-shot Level 1 challenges 3 times total.';
      case 'cr_backhand_l1_x3':
        return 'Pass backhand Level 1 challenges 3 times total.';
      case 'cr_slap_l1_x3':
        return 'Pass slap-shot Level 1 challenges 3 times total.';
      case 'cr_wrist_warmup_l1_x3':
        return 'Complete Wrist Shot Warmup (Level 1) three times.';
      case 'cr_outperform_plus2_x5':
        return 'Outperform any challenge by 2+ target hits, five times.';
      case 'cr_10k_x1':
        return 'Reach 10,000 total Challenger Road shots.';
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
            width: 104,
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

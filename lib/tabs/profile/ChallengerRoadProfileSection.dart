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
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _BadgeScrollRow(earnedBadges: summary.badges),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Free user upsell ────────────────────────────────────────────────────

  Widget _buildUpsell(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.route_rounded, color: Color(0xFFFFD700), size: 28),
                const SizedBox(width: 10),
                Text(
                  'CHALLENGER ROAD',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onPrimary,
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
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
              ),
            ),
            if (onGoProTap != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onGoProTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black87,
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
                    color: const Color(0xFFFFD700).withValues(alpha: hasLevel ? 0.35 : 0.1),
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
                    ? const RadialGradient(colors: [Color(0xFFFFE066), Color(0xFFFF9800)])
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
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6),
            letterSpacing: 1.5,
          ),
        ),
        Text(
          hasLevel ? 'Level $level' : 'No level completed yet',
          style: const TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 18,
            color: Color(0xFFFFD700),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFFFFD700)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.6),
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
  const _BadgeScrollRow({required this.earnedBadges});
  final List<String> earnedBadges;

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
          return _BadgeChip(def: def, earned: earned);
        },
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.def, required this.earned});
  final _BadgeDef def;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: earned ? def.description : 'Locked: ${def.description}',
      child: Opacity(
        opacity: earned ? 1.0 : 0.35,
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
                  color: earned ? def.color.withValues(alpha: 0.18) : Colors.grey.shade800,
                  border: Border.all(
                    color: earned ? def.color : Colors.grey.shade600,
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
                  color: earned ? def.color : Colors.grey.shade500,
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
                  color: earned ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

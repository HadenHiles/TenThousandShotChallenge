import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';

// ── Badge resolution ─────────────────────────────────────────────────────────

/// Internal descriptor for the overlay badge to render.
class _CrBadgeAttrs {
  final Color color;
  final IconData? icon;

  /// Short text (1-2 chars) shown when no icon. Mutually exclusive with [icon].
  final String? label;
  final String tooltip;

  const _CrBadgeAttrs({
    required this.color,
    this.icon,
    this.label,
    required this.tooltip,
  }) : assert(icon != null || label != null, 'icon or label required');
}

// IDs from ChallengerRoadService.badgeCatalog grouped by tier.
const _kRoadCompleteIds = {'cr_the_general', 'cr_playoff_mode'};
const _kLegendaryIds = {
  'cr_hockey_god',
  'cr_hall_of_famer',
  'cr_the_machine',
  'cr_all_stars',
  'cr_clean_sweep',
  'cr_three_periods',
  'cr_well_never_runs_dry',
  'cr_all_net',
  'cr_the_sniper',
  'cr_career_year',
};
const _kEpicIds = {
  'cr_freight_train',
  'cr_dialed_in',
  'cr_redemption_arc',
  'cr_game_7',
  'cr_team_captain',
  'cr_buzzer_beater',
  'cr_top_cheese',
  'cr_pure',
  'cr_unstoppable',
  'cr_full_send',
  'cr_earned_a_salary',
};

class CrProfileAccomplishment {
  final Color color;
  final IconData? icon;
  final String? label;
  final String headline;
  final String? subtitle;

  const CrProfileAccomplishment({
    required this.color,
    this.icon,
    this.label,
    required this.headline,
    this.subtitle,
  }) : assert(icon != null || label != null, 'icon or label required');
}

int _badgeTierRank(ChallengerRoadBadgeTier tier) {
  switch (tier) {
    case ChallengerRoadBadgeTier.legendary:
      return 6;
    case ChallengerRoadBadgeTier.epic:
      return 5;
    case ChallengerRoadBadgeTier.hidden:
      return 4;
    case ChallengerRoadBadgeTier.rare:
      return 3;
    case ChallengerRoadBadgeTier.uncommon:
      return 2;
    case ChallengerRoadBadgeTier.common:
      return 1;
  }
}

IconData _badgeCategoryIcon(ChallengerRoadBadgeCategory category) {
  switch (category) {
    case ChallengerRoadBadgeCategory.firstSteps:
      return Icons.route_rounded;
    case ChallengerRoadBadgeCategory.withinRunEfficiency:
      return Icons.bolt_rounded;
    case ChallengerRoadBadgeCategory.crossAttemptImprovement:
      return Icons.trending_up_rounded;
    case ChallengerRoadBadgeCategory.grindAndResilience:
      return Icons.shield_rounded;
    case ChallengerRoadBadgeCategory.levelAdvancement:
      return Icons.stairs_rounded;
    case ChallengerRoadBadgeCategory.crShotMilestones:
      return Icons.workspace_premium_rounded;
    case ChallengerRoadBadgeCategory.crSessionAccuracy:
      return Icons.gps_fixed_rounded;
    case ChallengerRoadBadgeCategory.hotStreaks:
      return Icons.local_fire_department_rounded;
    case ChallengerRoadBadgeCategory.challengeMastery:
      return Icons.emoji_events_rounded;
    case ChallengerRoadBadgeCategory.multiAttemptCareer:
      return Icons.repeat_rounded;
    case ChallengerRoadBadgeCategory.eliteEndgame:
      return Icons.military_tech_rounded;
    case ChallengerRoadBadgeCategory.chirpy:
      return Icons.sports_hockey_rounded;
  }
}

Color _tierColor(ChallengerRoadBadgeTier tier) {
  switch (tier) {
    case ChallengerRoadBadgeTier.legendary:
      return const Color(0xFFFFD700);
    case ChallengerRoadBadgeTier.epic:
      return const Color(0xFFAB47BC);
    case ChallengerRoadBadgeTier.rare:
      return const Color(0xFF42A5F5);
    case ChallengerRoadBadgeTier.uncommon:
      return const Color(0xFF66BB6A);
    case ChallengerRoadBadgeTier.hidden:
      return const Color(0xFF78909C);
    case ChallengerRoadBadgeTier.common:
      return const Color(0xFF90A4AE);
  }
}

CrProfileAccomplishment? resolveCrProfileAccomplishment(
  ChallengerRoadUserSummary summary, {
  bool showProFallback = false,
}) {
  final badges = summary.badges.toSet();

  if (badges.intersection(_kRoadCompleteIds).isNotEmpty) {
    final shots = summary.allTimeBestLevelShots;
    final fast = shots != null && shots < 10000;
    final shotCopy = shots == null ? null : '${_fmtN(shots)} shots';
    return CrProfileAccomplishment(
      color: const Color(0xFFFFD700),
      icon: fast ? Icons.bolt_rounded : Icons.check_circle_rounded,
      headline: fast ? 'Road Complete (Sub-10k)' : 'Road Complete',
      subtitle: shotCopy == null ? 'Completed the full Challenger Road' : 'Completed the full Challenger Road in $shotCopy',
    );
  }

  final badgeById = {
    for (final def in ChallengerRoadService.badgeCatalog) def.id: def,
  };
  ChallengerRoadBadgeDefinition? bestBadge;
  for (final id in badges) {
    final def = badgeById[id];
    if (def == null) continue;
    if (bestBadge == null || _badgeTierRank(def.tier) > _badgeTierRank(bestBadge.tier)) {
      bestBadge = def;
    }
  }

  if (bestBadge != null) {
    return CrProfileAccomplishment(
      color: _tierColor(bestBadge.tier),
      icon: _badgeCategoryIcon(bestBadge.category),
      headline: bestBadge.name,
      subtitle: bestBadge.description,
    );
  }

  if (summary.allTimeBestLevel > 0) {
    final lvl = summary.allTimeBestLevel;
    final color = lvl >= 10
        ? const Color(0xFFAB47BC)
        : lvl >= 5
            ? const Color(0xFF26A69A)
            : const Color(0xFF42A5F5);
    return CrProfileAccomplishment(
      color: color,
      label: '$lvl',
      headline: 'Best Level: $lvl',
      subtitle: 'Best Challenger Road progression so far',
    );
  }

  if (showProFallback) {
    return const CrProfileAccomplishment(
      color: Color(0xFF78909C),
      icon: Icons.workspace_premium_rounded,
      headline: 'Pro Subscriber',
      subtitle: 'No Challenger Road milestone yet',
    );
  }

  return null;
}

/// Resolves which badge to show for [summary], or null if nothing useful.
///
/// Priority:
///   1. Road complete (cr_the_general / cr_playoff_mode) → gold, lightning/check
///   2. Other legendary badge                            → gold, auto-awesome star
///   3. Epic badge                                       → purple, fire
///   4. Any level reached (allTimeBestLevel > 0)         → colored, level number
///   5. showProFallback = true, no CR activity           → steel, pro star
_CrBadgeAttrs? _resolveCrBadge(
  ChallengerRoadUserSummary summary, {
  bool showProFallback = false,
}) {
  final badges = summary.badges.toSet();

  // Tier 1 — road complete
  if (badges.intersection(_kRoadCompleteIds).isNotEmpty) {
    final shots = summary.allTimeBestLevelShots;
    final fast = shots != null && shots < 10000;
    return _CrBadgeAttrs(
      color: const Color(0xFFFFD700),
      icon: fast ? Icons.bolt_rounded : Icons.check_circle_rounded,
      tooltip: fast ? 'Challenger Road: Complete in ${_fmtN(shots)} shots!' : 'Challenger Road: Full Road Completed',
    );
  }

  // Tier 2 — legendary
  if (badges.intersection(_kLegendaryIds).isNotEmpty) {
    return const _CrBadgeAttrs(
      color: Color(0xFFFFD700),
      icon: Icons.auto_awesome_rounded,
      tooltip: 'Legendary Challenger Road achievement',
    );
  }

  // Tier 3 — epic
  if (badges.intersection(_kEpicIds).isNotEmpty) {
    return const _CrBadgeAttrs(
      color: Color(0xFFAB47BC),
      icon: Icons.local_fire_department_rounded,
      tooltip: 'Epic Challenger Road achievement',
    );
  }

  // Tier 4 — best level
  if (summary.allTimeBestLevel > 0) {
    final lvl = summary.allTimeBestLevel;
    final color = lvl >= 10
        ? const Color(0xFFAB47BC)
        : lvl >= 5
            ? const Color(0xFF26A69A)
            : const Color(0xFF42A5F5);
    return _CrBadgeAttrs(
      color: color,
      label: '$lvl',
      tooltip: 'Best Challenger Road Level: $lvl',
    );
  }

  // Tier 5 — pro fallback
  if (showProFallback) {
    return const _CrBadgeAttrs(
      color: Color(0xFF78909C),
      icon: Icons.workspace_premium_rounded,
      tooltip: 'Pro Subscriber',
    );
  }

  return null;
}

String _fmtN(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ── Badge widget ─────────────────────────────────────────────────────────────

/// Small circular badge overlaid on an avatar (bottom-right corner) that
/// reflects the user's greatest Challenger Road accomplishment.
///
/// Call [_resolveCrBadge] to determine whether a badge is warranted before
/// rendering; this widget renders [SizedBox.shrink] when [summary] yields no
/// displayable badge.
class CrAvatarBadge extends StatelessWidget {
  const CrAvatarBadge({
    super.key,
    required this.summary,
    this.size = 22,
    this.showProFallback = false,
  });

  final ChallengerRoadUserSummary summary;

  /// Diameter of the badge circle in logical pixels.
  final double size;

  /// When true, renders a "PRO" badge even if there is no CR activity yet.
  /// Use for the current user's own profile photo only.
  final bool showProFallback;

  @override
  Widget build(BuildContext context) {
    final attrs = _resolveCrBadge(summary, showProFallback: showProFallback);
    if (attrs == null) return const SizedBox.shrink();

    final innerSize = size - 4.0; // subtract 2px border on each side

    return Tooltip(
      message: attrs.tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: attrs.color,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: attrs.label != null
              ? Text(
                  attrs.label!,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'NovecentoSans',
                    fontSize: innerSize * 0.55,
                    height: 1.0,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Icon(
                  attrs.icon!,
                  color: Colors.white,
                  size: innerSize * 0.60,
                ),
        ),
      ),
    );
  }
}

// ── Stream-fed convenience wrapper ───────────────────────────────────────────

/// Listens to [ChallengerRoadService.watchUserSummary] and renders a
/// [CrAvatarBadge] for [userId]. Safe to use in trees that do not already
/// have a summary stream — it creates its own Firestore listener.
class CrAvatarBadgeStream extends StatelessWidget {
  const CrAvatarBadgeStream({
    super.key,
    required this.userId,
    this.size = 22,
    this.showProFallback = false,
  });

  final String userId;
  final double size;
  final bool showProFallback;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChallengerRoadUserSummary>(
      stream: ChallengerRoadService().watchUserSummary(userId),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return CrAvatarBadge(
          summary: snap.data!,
          size: size,
          showProFallback: showProFallback,
        );
      },
    );
  }
}

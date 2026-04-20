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

int _profileDisplayLevel(ChallengerRoadUserSummary summary) {
  if (summary.allTimeBestLevel > 0) return summary.allTimeBestLevel;
  if (summary.currentAttemptId != null || summary.totalAttempts > 0) return 1;
  return 0;
}

Color _levelColor(int level) {
  if (level >= 10) return const Color(0xFF7E57C2);
  if (level >= 7) return const Color(0xFF26A69A);
  if (level >= 4) return const Color(0xFF42A5F5);
  return const Color(0xFF5C6BC0);
}

CrProfileAccomplishment? resolveCrProfileAccomplishment(
  ChallengerRoadUserSummary summary, {
  bool showProFallback = false,
}) {
  final lvl = _profileDisplayLevel(summary);
  if (lvl > 0) {
    final color = lvl >= 10
        ? const Color(0xFFAB47BC)
        : lvl >= 5
            ? const Color(0xFF26A69A)
            : const Color(0xFF42A5F5);
    return CrProfileAccomplishment(
      color: color,
      label: '$lvl',
      headline: 'Challenger Road Level $lvl',
      subtitle: summary.allTimeBestLevel > 0 ? 'Highest completed Challenger Road level' : 'Currently on Challenger Road level $lvl',
    );
  }

  if (showProFallback) {
    return const CrProfileAccomplishment(
      color: Color(0xFF78909C),
      label: 'PRO',
      headline: 'Pro',
      subtitle: 'Pro user with no Challenger Road run yet',
    );
  }

  return null;
}

/// Resolves which badge to show for [summary], or null if nothing useful.
///
/// Priority:
///   1. Highest completed level (or level 1 if attempt started) → colored label
///   2. showProFallback = true, no CR attempt yet               → steel PRO label
_CrBadgeAttrs? _resolveCrBadge(
  ChallengerRoadUserSummary summary, {
  bool showProFallback = false,
}) {
  final lvl = _profileDisplayLevel(summary);
  if (lvl > 0) {
    return _CrBadgeAttrs(
      color: _levelColor(lvl),
      label: '$lvl',
      tooltip: summary.allTimeBestLevel > 0 ? 'Highest completed Challenger Road level: $lvl' : 'Currently on Challenger Road level $lvl',
    );
  }

  // Pro fallback
  if (showProFallback) {
    return const _CrBadgeAttrs(
      color: Color(0xFF78909C),
      label: 'PRO',
      tooltip: 'Pro user',
    );
  }

  return null;
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
    this.enabled = true,
    this.showProFallback = false,
  });

  final ChallengerRoadUserSummary summary;

  /// Diameter of the badge circle in logical pixels.
  final double size;

  /// Master visibility switch for this overlay.
  final bool enabled;

  /// When true, renders a "PRO" badge even if there is no CR activity yet.
  /// Use for the current user's own profile photo only.
  final bool showProFallback;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
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
/// have a summary stream - it creates its own Firestore listener.
class CrAvatarBadgeStream extends StatelessWidget {
  const CrAvatarBadgeStream({
    super.key,
    required this.userId,
    this.size = 22,
    this.enabled = true,
    this.showProFallback = false,
  });

  final String userId;
  final double size;
  final bool enabled;
  final bool showProFallback;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return StreamBuilder<ChallengerRoadUserSummary>(
      stream: ChallengerRoadService().watchUserSummary(userId),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return CrAvatarBadge(
          summary: snap.data!,
          size: size,
          enabled: enabled,
          showProFallback: showProFallback,
        );
      },
    );
  }
}

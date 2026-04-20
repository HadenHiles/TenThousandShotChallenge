import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';

// ── Main widget ────────────────────────────────────────────────────────────

/// Drop-in Challenger Road section for the Profile tab.
///
/// Pass [userId] and the current [isPro] flag.
/// Both free and pro users can see their stats and badges - free users also
/// see a compact "Go Pro" nudge encouraging them to unlock full gameplay.
class ChallengerRoadProfileSection extends StatelessWidget {
  const ChallengerRoadProfileSection({
    super.key,
    required this.userId,
    required this.isPro,
    this.isEditable = false,
    this.onGoProTap,
  });

  final String userId;
  final bool isPro;

  /// When true, shows a "PLAYER CARD" featured-badge showcase with an edit
  /// button - only meaningful when this is the signed-in user's own profile.
  final bool isEditable;
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
          // Badge catalog powers both the featured showcase and the full grid.
          FutureBuilder<List<ChallengerRoadBadgeDefinition>>(
            future: ChallengerRoadService().getBadgeCatalogForUser(userId),
            builder: (context, badgeSnap) {
              final badgeDefs = badgeSnap.data ?? const <ChallengerRoadBadgeDefinition>[];
              if (badgeDefs.isEmpty && summary.badges.isEmpty && badgeSnap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Player card showcase (own profile with isEditable)
                  if (isEditable && summary.badges.isNotEmpty) ...[
                    _FeaturedShowcase(
                      userId: userId,
                      summary: summary,
                      badgeDefs: badgeDefs,
                    ),
                    const SizedBox(height: 20),
                  ],
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
                  _BadgeWrapGrid(
                    earnedBadges: summary.badges,
                    summary: summary,
                    badgeDefs: badgeDefs,
                  ),
                ],
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
    return ChallengerRoadService.buildDisplayBadgeDefs(
      earnedBadgeIds: earnedBadges,
      catalog: badgeDefs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayDefs = _buildDisplayDefs();
    final groups = ChallengerRoadService.groupDisplayBadgesByTier(
      badges: displayDefs,
      earnedBadgeIds: earnedBadges,
      includeHidden: false,
    );

    if (groups.isEmpty) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          Text(
            group.label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.badges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final def = group.badges[index];
              final earned = earnedBadges.contains(def.id);
              return Align(
                alignment: Alignment.topCenter,
                child: _BadgeChip(def: def, earned: earned, summary: summary),
              );
            },
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.def, required this.earned, required this.summary});
  final ChallengerRoadBadgeDefinition def;
  final bool earned;
  final ChallengerRoadUserSummary summary;

  Color _colorForBadge() {
    // Tier takes visual precedence for epic/legendary/hidden.
    switch (def.tier) {
      case ChallengerRoadBadgeTier.legendary:
        return const Color(0xFFFFD700);
      case ChallengerRoadBadgeTier.epic:
        return const Color(0xFFAB47BC);
      case ChallengerRoadBadgeTier.hidden:
        return const Color(0xFF78909C);
      default:
        break;
    }
    switch (def.category) {
      case ChallengerRoadBadgeCategory.firstSteps:
        return const Color(0xFF42A5F5);
      case ChallengerRoadBadgeCategory.withinRunEfficiency:
        return const Color(0xFF26C6DA);
      case ChallengerRoadBadgeCategory.crossAttemptImprovement:
        return const Color(0xFF66BB6A);
      case ChallengerRoadBadgeCategory.grindAndResilience:
        return const Color(0xFF8D6E63);
      case ChallengerRoadBadgeCategory.levelAdvancement:
        return const Color(0xFF26A69A);
      case ChallengerRoadBadgeCategory.crShotMilestones:
        return const Color(0xFFFF7043);
      case ChallengerRoadBadgeCategory.crSessionAccuracy:
        return const Color(0xFF5C6BC0);
      case ChallengerRoadBadgeCategory.hotStreaks:
        return const Color(0xFFEF5350);
      case ChallengerRoadBadgeCategory.challengeMastery:
        return const Color(0xFF5C6BC0);
      case ChallengerRoadBadgeCategory.multiAttemptCareer:
        return const Color(0xFF29B6F6);
      case ChallengerRoadBadgeCategory.eliteEndgame:
        return const Color(0xFFFFD700);
      case ChallengerRoadBadgeCategory.chirpy:
        return const Color(0xFF78909C);
    }
  }

  String _requirementText() {
    return def.effectiveDescription;
  }

  String? _progressText() {
    if (def.category == ChallengerRoadBadgeCategory.multiAttemptCareer) {
      return 'Progress: ${summary.totalAttempts} attempts';
    }
    if (def.category == ChallengerRoadBadgeCategory.crShotMilestones) {
      return 'Progress: ${summary.allTimeTotalChallengerRoadShots} CR shots';
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
                    ChallengerRoadService.badgeIconWidget(
                      def,
                      size: 22,
                      color: earned ? _colorForBadge() : scheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        def.effectiveName,
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
      message: earned ? def.effectiveDescription : 'Locked: ${def.effectiveDescription}',
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
                  child: ChallengerRoadService.badgeIconWidget(
                    def,
                    size: 26,
                    color: earned ? _colorForBadge() : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  def.effectiveName,
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

// ── Single-slot swap sheet ────────────────────────────────────────────────────

class _FeaturedSlotSwapSheet extends StatefulWidget {
  const _FeaturedSlotSwapSheet({
    required this.userId,
    required this.slotId,
    required this.currentDef,
    required this.summary,
    required this.badgeDefs,
  });

  final String userId;
  final String slotId;
  final ChallengerRoadBadgeDefinition currentDef;
  final ChallengerRoadUserSummary summary;
  final List<ChallengerRoadBadgeDefinition> badgeDefs;

  @override
  State<_FeaturedSlotSwapSheet> createState() => _FeaturedSlotSwapSheetState();
}

class _FeaturedSlotSwapSheetState extends State<_FeaturedSlotSwapSheet> {
  bool _saving = false;

  Future<void> _swap(String newBadgeId) async {
    if (newBadgeId == widget.slotId) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final newFeatured = List<String>.from(widget.summary.featuredBadges);
    newFeatured.remove(newBadgeId); // pull out if already in another slot
    final idx = newFeatured.indexOf(widget.slotId);
    if (idx >= 0) {
      newFeatured[idx] = newBadgeId;
    } else {
      newFeatured.add(newBadgeId);
    }
    await ChallengerRoadService().updateFeaturedBadges(widget.userId, newFeatured.take(3).toList());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byId = {for (final d in widget.badgeDefs) d.id: d};
    final earnedIds = widget.summary.badges.toSet();
    final earnedDefs = earnedIds.map((id) => byId[id]).whereType<ChallengerRoadBadgeDefinition>().where((d) => d.id != widget.slotId).toList()..sort((a, b) => a.effectiveName.compareTo(b.effectiveName));

    final currentColor = _crBadgeColor(widget.currentDef);
    final currentIcon = _crBadgeIcon(widget.currentDef);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentColor.withValues(alpha: 0.18),
                    border: Border.all(color: currentColor, width: 2),
                    boxShadow: [BoxShadow(color: currentColor.withValues(alpha: 0.3), blurRadius: 6)],
                  ),
                  child: Icon(currentIcon, color: currentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.currentDef.effectiveName,
                        style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: scheme.onSurface),
                      ),
                      Text(
                        widget.currentDef.effectiveDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SWAP WITH',
                style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.55), letterSpacing: 1.2),
              ),
            ),
          ),
          if (_saving)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator())
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: earnedDefs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, i) {
                  final def = earnedDefs[i];
                  final color = _crBadgeColor(def);
                  final icon = _crBadgeIcon(def);
                  final isAlreadyFeatured = widget.summary.featuredBadges.contains(def.id);
                  return InkWell(
                    onTap: () => _swap(def.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Opacity(
                      opacity: isAlreadyFeatured ? 0.45 : 1.0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.15),
                              border: Border.all(color: color, width: 1.5),
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            def.effectiveName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 10, color: scheme.onSurface.withValues(alpha: 0.85), height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Badge color/icon helpers (used by showcase + picker) ────────────────────

Color _crBadgeColor(ChallengerRoadBadgeDefinition def) {
  switch (def.tier) {
    case ChallengerRoadBadgeTier.legendary:
      return const Color(0xFFFFD700);
    case ChallengerRoadBadgeTier.epic:
      return const Color(0xFFAB47BC);
    case ChallengerRoadBadgeTier.hidden:
      return const Color(0xFF78909C);
    default:
      break;
  }
  switch (def.category) {
    case ChallengerRoadBadgeCategory.firstSteps:
      return const Color(0xFF42A5F5);
    case ChallengerRoadBadgeCategory.withinRunEfficiency:
      return const Color(0xFF26C6DA);
    case ChallengerRoadBadgeCategory.crossAttemptImprovement:
      return const Color(0xFF66BB6A);
    case ChallengerRoadBadgeCategory.grindAndResilience:
      return const Color(0xFF8D6E63);
    case ChallengerRoadBadgeCategory.levelAdvancement:
      return const Color(0xFF26A69A);
    case ChallengerRoadBadgeCategory.crShotMilestones:
      return const Color(0xFFFF7043);
    case ChallengerRoadBadgeCategory.crSessionAccuracy:
      return const Color(0xFF5C6BC0);
    case ChallengerRoadBadgeCategory.hotStreaks:
      return const Color(0xFFEF5350);
    case ChallengerRoadBadgeCategory.challengeMastery:
      return const Color(0xFF5C6BC0);
    case ChallengerRoadBadgeCategory.multiAttemptCareer:
      return const Color(0xFF29B6F6);
    case ChallengerRoadBadgeCategory.eliteEndgame:
      return const Color(0xFFFFD700);
    case ChallengerRoadBadgeCategory.chirpy:
      return const Color(0xFF78909C);
  }
}

IconData _crBadgeIcon(ChallengerRoadBadgeDefinition def) {
  return ChallengerRoadService.iconForBadge(def);
}

// ── Featured Badges Showcase ─────────────────────────────────────────────────

class _FeaturedShowcase extends StatelessWidget {
  const _FeaturedShowcase({
    required this.userId,
    required this.summary,
    required this.badgeDefs,
  });

  final String userId;
  final ChallengerRoadUserSummary summary;
  final List<ChallengerRoadBadgeDefinition> badgeDefs;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final d in badgeDefs) d.id: d};
    final featured = summary.featuredBadges;
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'PLAYER CARD',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 14,
                color: scheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () => _showPicker(context),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'EDIT',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 13,
                    color: primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (featured.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Tap EDIT to choose up to 3 badges to feature on your player card.',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          )
        else
          Row(
            children: [
              for (final id in featured.take(3)) ...[
                _showcaseSlot(context, id, byId[id]),
                const SizedBox(width: 12),
              ],
              for (int i = featured.length; i < 3; i++) ...[
                _emptySlot(context),
                const SizedBox(width: 12),
              ],
            ],
          ),
      ],
    );
  }

  Widget _showcaseSlot(BuildContext context, String slotId, ChallengerRoadBadgeDefinition? def) {
    if (def == null) return _emptySlot(context);
    final color = _crBadgeColor(def);
    final icon = _crBadgeIcon(def);
    return InkWell(
      onTap: () => _showSwapSlot(context, slotId, def),
      borderRadius: BorderRadius.circular(32),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6)],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              def.effectiveName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSwapSlot(BuildContext context, String slotId, ChallengerRoadBadgeDefinition currentDef) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _FeaturedSlotSwapSheet(
        userId: userId,
        slotId: slotId,
        currentDef: currentDef,
        summary: summary,
        badgeDefs: badgeDefs,
      ),
    );
  }

  Widget _emptySlot(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.add_rounded,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
        size: 22,
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _FeaturedBadgesPickerSheet(
        userId: userId,
        summary: summary,
        badgeDefs: badgeDefs,
      ),
    );
  }
}

// ── Featured Badges Picker Sheet ─────────────────────────────────────────────

class _FeaturedBadgesPickerSheet extends StatefulWidget {
  const _FeaturedBadgesPickerSheet({
    required this.userId,
    required this.summary,
    required this.badgeDefs,
  });

  final String userId;
  final ChallengerRoadUserSummary summary;
  final List<ChallengerRoadBadgeDefinition> badgeDefs;

  @override
  State<_FeaturedBadgesPickerSheet> createState() => _FeaturedBadgesPickerSheetState();
}

class _FeaturedBadgesPickerSheetState extends State<_FeaturedBadgesPickerSheet> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.summary.featuredBadges);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ChallengerRoadService().updateFeaturedBadges(widget.userId, _selected.toList());
    if (mounted) Navigator.of(context).pop();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < 3) {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;
    final earnedIds = widget.summary.badges.toSet();
    final byId = {for (final d in widget.badgeDefs) d.id: d};
    final earnedDefs = earnedIds.map((id) => byId[id]).whereType<ChallengerRoadBadgeDefinition>().toList()..sort((a, b) => a.effectiveName.compareTo(b.effectiveName));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHOOSE FEATURED BADGES',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 20,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    'Select up to 3 to show on your player card.',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: earnedDefs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, i) {
                  final def = earnedDefs[i];
                  final color = _crBadgeColor(def);
                  final icon = _crBadgeIcon(def);
                  final isSelected = _selected.contains(def.id);
                  final isDisabled = !isSelected && _selected.length >= 3;
                  return InkWell(
                    onTap: isDisabled ? null : () => _toggle(def.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Opacity(
                      opacity: isDisabled ? 0.35 : 1.0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withValues(alpha: isSelected ? 0.3 : 0.15),
                                    border: Border.all(
                                      color: isSelected ? primary : color,
                                      width: isSelected ? 2.5 : 1.5,
                                    ),
                                  ),
                                  child: Icon(icon, color: color, size: 24),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  def.effectiveName,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'NovecentoSans',
                                    fontSize: 10,
                                    color: scheme.onSurface.withValues(alpha: 0.85),
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 0,
                              right: 8,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primary,
                                ),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'SAVE  (${_selected.length}/3)',
                          style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 17),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

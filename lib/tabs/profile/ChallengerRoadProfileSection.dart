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
    this.showOnlyEarned = false,
    this.highlightTrophyId,
    this.onGoProTap,
  });

  final String userId;
  final bool isPro;

  /// When true, shows a "TROPHY CASE" featured-badge showcase with an edit
  /// button - only meaningful when this is the signed-in user's own profile.
  final bool isEditable;

  /// When true, only earned badges are shown and the Go-Pro nudge is hidden.
  /// Used when viewing another player's Challenger Road progress.
  final bool showOnlyEarned;

  /// When set, the badge grid scrolls to this badge ID and pulses it.
  final String? highlightTrophyId;
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
          // Free-user Go-Pro nudge banner (only on own profile)
          if (!isPro && !showOnlyEarned) ...[
            const SizedBox(height: 8),
            _GoProNudge(onGoProTap: onGoProTap),
          ],
          const SizedBox(height: 8),
          // Personal Best Badge
          _PersonalBestTrophy(
            level: summary.allTimeBestLevel,
            shots: summary.allTimeBestLevelShots,
          ),
          const SizedBox(height: 20),
          // Stats row
          _StatsRow(summary: summary),
          const SizedBox(height: 20),
          // Badge catalog powers both the featured showcase and the full grid.
          _TrophyCatalogSection(
            userId: userId,
            summary: summary,
            isEditable: isEditable,
            showOnlyEarned: showOnlyEarned,
            highlightTrophyId: highlightTrophyId,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Badge catalog section (StatefulWidget to cache future across rebuilds) ──

/// Wraps the [FutureBuilder] for badge catalog data in a [StatefulWidget] so
/// the future is only created once - not every time the parent [StreamBuilder]
/// emits. This prevents the badge grid from tearing down and restarting the
/// highlight animation on every Firestore update.
class _TrophyCatalogSection extends StatefulWidget {
  const _TrophyCatalogSection({
    required this.userId,
    required this.summary,
    required this.isEditable,
    required this.showOnlyEarned,
    this.highlightTrophyId,
  });

  final String userId;
  final ChallengerRoadUserSummary summary;
  final bool isEditable;
  final bool showOnlyEarned;
  final String? highlightTrophyId;

  @override
  State<_TrophyCatalogSection> createState() => _TrophyCatalogSectionState();
}

class _TrophyCatalogSectionState extends State<_TrophyCatalogSection> {
  late Future<List<ChallengerRoadTrophyDefinition>> _future;

  @override
  void initState() {
    super.initState();
    _future = ChallengerRoadService().getTrophyCatalogForUser(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChallengerRoadTrophyDefinition>>(
      future: _future,
      builder: (context, trophySnap) {
        final trophyDefs = trophySnap.data ?? const <ChallengerRoadTrophyDefinition>[];
        if (trophyDefs.isEmpty && widget.summary.trophies.isEmpty && trophySnap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isEditable && widget.summary.trophies.isNotEmpty) ...[
              _FeaturedShowcase(
                userId: widget.userId,
                summary: widget.summary,
                trophyDefs: trophyDefs,
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'TROPHIES',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _TrophyWrapGrid(
              earnedTrophies: widget.summary.trophies,
              summary: widget.summary,
              trophyDefs: trophyDefs,
              highlightTrophyId: widget.highlightTrophyId,
              showOnlyEarned: widget.showOnlyEarned,
            ),
          ],
        );
      },
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
              'earn more trophies & unlock the full challenger road.',
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

class _PersonalBestTrophy extends StatelessWidget {
  const _PersonalBestTrophy({required this.level, required this.shots});
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
          label: 'TROPHIES',
          value: '${summary.trophies.length}',
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

class _TrophyWrapGrid extends StatelessWidget {
  const _TrophyWrapGrid({
    required this.earnedTrophies,
    required this.summary,
    required this.trophyDefs,
    this.highlightTrophyId,
    this.showOnlyEarned = false,
  });

  final List<String> earnedTrophies;
  final ChallengerRoadUserSummary summary;
  final List<ChallengerRoadTrophyDefinition> trophyDefs;
  final String? highlightTrophyId;
  final bool showOnlyEarned;

  List<ChallengerRoadTrophyDefinition> _buildDisplayDefs() {
    return ChallengerRoadService.buildDisplayTrophyDefs(
      earnedTrophyIds: earnedTrophies,
      catalog: trophyDefs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDisplayDefs = _buildDisplayDefs();
    final displayDefs = showOnlyEarned ? allDisplayDefs.where((d) => earnedTrophies.contains(d.id)).toList() : allDisplayDefs;
    final groups = ChallengerRoadService.groupDisplayTrophiesByTier(
      trophies: displayDefs,
      earnedTrophyIds: earnedTrophies,
      includeHidden: false,
    );

    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          showOnlyEarned ? 'No trophies earned yet.' : 'No trophy definitions available yet.',
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
        for (int i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Text(
            groups[i].label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: groups[i].trophies.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final def = groups[i].trophies[index];
              final earned = earnedTrophies.contains(def.id);
              return Align(
                alignment: Alignment.topCenter,
                child: _TrophyChip(
                  key: ValueKey(def.id),
                  def: def,
                  earned: earned,
                  summary: summary,
                  highlight: highlightTrophyId != null && def.id == highlightTrophyId,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _TrophyChip extends StatefulWidget {
  const _TrophyChip({
    super.key,
    required this.def,
    required this.earned,
    required this.summary,
    this.highlight = false,
  });
  final ChallengerRoadTrophyDefinition def;
  final bool earned;
  final ChallengerRoadUserSummary summary;
  final bool highlight;

  @override
  State<_TrophyChip> createState() => _TrophyChipState();
}

class _TrophyChipState extends State<_TrophyChip> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _scaleAnim;

  ChallengerRoadTrophyDefinition get def => widget.def;
  bool get earned => widget.earned;
  ChallengerRoadUserSummary get summary => widget.summary;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.highlight) {
      // Delay slightly so the page fully settles before the animation starts.
      // This is especially important for badges already visible on screen.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        final renderObj = context.findRenderObject();
        if (renderObj != null) {
          renderObj.showOnScreen(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
        _pulseController.repeat(reverse: true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            _pulseController.stop();
            _pulseController.animateTo(0);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _colorForBadge() {
    // Tier takes visual precedence for epic/legendary/hidden.
    switch (def.tier) {
      case ChallengerRoadTrophyTier.legendary:
        return const Color(0xFFFFD700);
      case ChallengerRoadTrophyTier.epic:
        return const Color(0xFFAB47BC);
      case ChallengerRoadTrophyTier.hidden:
        return const Color(0xFF78909C);
      default:
        break;
    }
    switch (def.category) {
      case ChallengerRoadTrophyCategory.firstSteps:
        return const Color(0xFF42A5F5);
      case ChallengerRoadTrophyCategory.withinRunEfficiency:
        return const Color(0xFF26C6DA);
      case ChallengerRoadTrophyCategory.crossAttemptImprovement:
        return const Color(0xFF66BB6A);
      case ChallengerRoadTrophyCategory.grindAndResilience:
        return const Color(0xFF8D6E63);
      case ChallengerRoadTrophyCategory.levelAdvancement:
        return const Color(0xFF26A69A);
      case ChallengerRoadTrophyCategory.crShotMilestones:
        return const Color(0xFFFF7043);
      case ChallengerRoadTrophyCategory.crSessionAccuracy:
        return const Color(0xFF5C6BC0);
      case ChallengerRoadTrophyCategory.hotStreaks:
        return const Color(0xFFEF5350);
      case ChallengerRoadTrophyCategory.challengeMastery:
        return const Color(0xFF5C6BC0);
      case ChallengerRoadTrophyCategory.multiAttemptCareer:
        return const Color(0xFF29B6F6);
      case ChallengerRoadTrophyCategory.eliteEndgame:
        return const Color(0xFFFFD700);
      case ChallengerRoadTrophyCategory.chirpy:
        return const Color(0xFF78909C);
    }
  }

  String _requirementText() {
    return def.effectiveDescription;
  }

  String? _progressText() {
    if (def.category == ChallengerRoadTrophyCategory.multiAttemptCareer) {
      return 'Progress: ${summary.totalAttempts} attempts';
    }
    if (def.category == ChallengerRoadTrophyCategory.crShotMilestones) {
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
                    ChallengerRoadService.trophyIconWidget(
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
    final highlight = widget.highlight;
    final badgeColor = _colorForBadge();
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
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    if (!highlight) return child!;
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.7 * _pulseAnim.value),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: earned ? badgeColor.withValues(alpha: 0.18) : Theme.of(context).primaryColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: highlight
                            ? badgeColor
                            : earned
                                ? badgeColor
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                        width: highlight
                            ? 3.0
                            : earned
                                ? 2.0
                                : 1.2,
                      ),
                      boxShadow: !highlight && earned
                          ? [
                              BoxShadow(
                                color: badgeColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: ChallengerRoadService.trophyIconWidget(
                      def,
                      size: 26,
                      color: earned ? badgeColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
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
    required this.slotIndex,
    required this.currentDef,
    required this.summary,
    required this.trophyDefs,
  });

  final String userId;
  final int slotIndex;
  final ChallengerRoadTrophyDefinition? currentDef;
  final ChallengerRoadUserSummary summary;
  final List<ChallengerRoadTrophyDefinition> trophyDefs;

  @override
  State<_FeaturedSlotSwapSheet> createState() => _FeaturedSlotSwapSheetState();
}

class _FeaturedSlotSwapSheetState extends State<_FeaturedSlotSwapSheet> {
  bool _saving = false;

  Future<void> _swap(String newTrophyId) async {
    if (newTrophyId == widget.currentDef?.id) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final existing = widget.summary.featuredTrophies;
    final slots = List<String>.generate(5, (i) => i < existing.length ? existing[i] : '');
    // Clear the chosen trophy from any other slot it may occupy
    for (int j = 0; j < 5; j++) {
      if (slots[j] == newTrophyId && j != widget.slotIndex) slots[j] = '';
    }
    slots[widget.slotIndex] = newTrophyId;
    await ChallengerRoadService().updateFeaturedTrophies(widget.userId, slots);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    final existing = widget.summary.featuredTrophies;
    final slots = List<String>.generate(5, (i) => i < existing.length ? existing[i] : '');
    slots[widget.slotIndex] = '';
    await ChallengerRoadService().updateFeaturedTrophies(widget.userId, slots);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byId = {for (final d in widget.trophyDefs) d.id: d};
    final earnedIds = widget.summary.trophies.toSet();
    final currentId = widget.currentDef?.id;
    final earnedDefs = earnedIds.map((id) => byId[id]).whereType<ChallengerRoadTrophyDefinition>().where((d) => d.id != currentId).toList()..sort((a, b) => a.effectiveName.compareTo(b.effectiveName));

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
          if (widget.currentDef != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _crBadgeColor(widget.currentDef!).withValues(alpha: 0.18),
                      border: Border.all(color: _crBadgeColor(widget.currentDef!), width: 2),
                      boxShadow: [BoxShadow(color: _crBadgeColor(widget.currentDef!).withValues(alpha: 0.3), blurRadius: 6)],
                    ),
                    child: Icon(_crBadgeIcon(widget.currentDef!), color: _crBadgeColor(widget.currentDef!), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentDef!.effectiveName,
                          style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: scheme.onSurface),
                        ),
                        Text(
                          widget.currentDef!.effectiveDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _clear,
                    child: Text('CLEAR', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, color: scheme.error)),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SLOT ${widget.slotIndex + 1}  -  EMPTY',
                  style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: scheme.onSurface.withValues(alpha: 0.45), letterSpacing: 1.1),
                ),
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.currentDef != null ? 'SWAP WITH' : 'CHOOSE TROPHY',
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
                  final isAlreadyFeatured = widget.summary.featuredTrophies.contains(def.id);
                  return InkWell(
                    onTap: () => _swap(def.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Opacity(
                      opacity: isAlreadyFeatured ? 0.5 : 1.0,
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

Color _crBadgeColor(ChallengerRoadTrophyDefinition def) {
  switch (def.tier) {
    case ChallengerRoadTrophyTier.legendary:
      return const Color(0xFFFFD700);
    case ChallengerRoadTrophyTier.epic:
      return const Color(0xFFAB47BC);
    case ChallengerRoadTrophyTier.hidden:
      return const Color(0xFF78909C);
    default:
      break;
  }
  switch (def.category) {
    case ChallengerRoadTrophyCategory.firstSteps:
      return const Color(0xFF42A5F5);
    case ChallengerRoadTrophyCategory.withinRunEfficiency:
      return const Color(0xFF26C6DA);
    case ChallengerRoadTrophyCategory.crossAttemptImprovement:
      return const Color(0xFF66BB6A);
    case ChallengerRoadTrophyCategory.grindAndResilience:
      return const Color(0xFF8D6E63);
    case ChallengerRoadTrophyCategory.levelAdvancement:
      return const Color(0xFF26A69A);
    case ChallengerRoadTrophyCategory.crShotMilestones:
      return const Color(0xFFFF7043);
    case ChallengerRoadTrophyCategory.crSessionAccuracy:
      return const Color(0xFF5C6BC0);
    case ChallengerRoadTrophyCategory.hotStreaks:
      return const Color(0xFFEF5350);
    case ChallengerRoadTrophyCategory.challengeMastery:
      return const Color(0xFF5C6BC0);
    case ChallengerRoadTrophyCategory.multiAttemptCareer:
      return const Color(0xFF29B6F6);
    case ChallengerRoadTrophyCategory.eliteEndgame:
      return const Color(0xFFFFD700);
    case ChallengerRoadTrophyCategory.chirpy:
      return const Color(0xFF78909C);
  }
}

IconData _crBadgeIcon(ChallengerRoadTrophyDefinition def) {
  return ChallengerRoadService.iconForTrophy(def);
}

// ── Featured Badges Showcase ─────────────────────────────────────────────────

class _FeaturedShowcase extends StatelessWidget {
  const _FeaturedShowcase({
    required this.userId,
    required this.summary,
    required this.trophyDefs,
  });

  final String userId;
  final ChallengerRoadUserSummary summary;
  final List<ChallengerRoadTrophyDefinition> trophyDefs;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final d in trophyDefs) d.id: d};
    final featured = summary.featuredTrophies;
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'TROPHY CASE',
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
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (int i = 0; i < 5; i++) (i < featured.length && featured[i].isNotEmpty) ? _showcaseSlot(context, i, byId[featured[i]]) : _emptySlot(context, i),
          ],
        ),
      ],
    );
  }

  Widget _showcaseSlot(BuildContext context, int slotIndex, ChallengerRoadTrophyDefinition? def) {
    if (def == null) return _emptySlot(context, slotIndex);
    final color = _crBadgeColor(def);
    final icon = _crBadgeIcon(def);
    return InkWell(
      onTap: () => _showSwapSlot(context, slotIndex, def),
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

  void _showSwapSlot(BuildContext context, int slotIndex, ChallengerRoadTrophyDefinition? currentDef) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _FeaturedSlotSwapSheet(
        userId: userId,
        slotIndex: slotIndex,
        currentDef: currentDef,
        summary: summary,
        trophyDefs: trophyDefs,
      ),
    );
  }

  Widget _emptySlot(BuildContext context, int slotIndex) {
    return InkWell(
      onTap: () => _showSwapSlot(context, slotIndex, null),
      borderRadius: BorderRadius.circular(32),
      child: Container(
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
      builder: (_) => _FeaturedTrophiesPickerSheet(
        userId: userId,
        summary: summary,
        trophyDefs: trophyDefs,
      ),
    );
  }
}

// ── Featured Badges Picker Sheet ─────────────────────────────────────────────

class _FeaturedTrophiesPickerSheet extends StatefulWidget {
  const _FeaturedTrophiesPickerSheet({
    required this.userId,
    required this.summary,
    required this.trophyDefs,
  });

  final String userId;
  final ChallengerRoadUserSummary summary;
  final List<ChallengerRoadTrophyDefinition> trophyDefs;

  @override
  State<_FeaturedTrophiesPickerSheet> createState() => _FeaturedTrophiesPickerSheetState();
}

class _FeaturedTrophiesPickerSheetState extends State<_FeaturedTrophiesPickerSheet> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.summary.featuredTrophies.where((id) => id.isNotEmpty).toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Preserve existing slot positions; place newly added trophies into empty slots.
    final existing = widget.summary.featuredTrophies;
    final slots = List<String>.generate(5, (i) => i < existing.length ? existing[i] : '');
    // Clear deselected trophies from their slots
    for (int i = 0; i < 5; i++) {
      if (slots[i].isNotEmpty && !_selected.contains(slots[i])) slots[i] = '';
    }
    // Place newly selected trophies into the first empty slots
    for (final id in _selected) {
      if (!slots.contains(id)) {
        final emptyIdx = slots.indexOf('');
        if (emptyIdx >= 0) slots[emptyIdx] = id;
      }
    }
    await ChallengerRoadService().updateFeaturedTrophies(widget.userId, slots);
    if (mounted) Navigator.of(context).pop();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < 5) {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;
    final earnedIds = widget.summary.trophies.toSet();
    final byId = {for (final d in widget.trophyDefs) d.id: d};
    final earnedDefs = earnedIds.map((id) => byId[id]).whereType<ChallengerRoadTrophyDefinition>().toList()..sort((a, b) => a.effectiveName.compareTo(b.effectiveName));

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
                    'CHOOSE FEATURED TROPHIES',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 20,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    'Select up to 5 to show on your trophy case.',
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
                  final isDisabled = !isSelected && _selected.length >= 5;
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
                          'SAVE  (${_selected.length}/5)',
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

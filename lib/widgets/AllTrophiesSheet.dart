import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/models/firestore/GlobalTrophySummary.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/services/GlobalTrophyService.dart';

/// Opens the full trophy browser as a modal bottom sheet.
void showAllTrophiesSheet(
  BuildContext context, {
  required String userId,
  required bool isPro,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AllTrophiesSheet(userId: userId, isPro: isPro),
  );
}

/// Full-screen (92 % height) bottom sheet listing every available trophy
/// grouped into FREE and PRO tabs. All icons are always visible; pro trophies
/// are dimmed for free users rather than hidden behind a lock icon.
class AllTrophiesSheet extends StatelessWidget {
  const AllTrophiesSheet({
    super.key,
    required this.userId,
    required this.isPro,
  });

  final String userId;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = theme.primaryColor; // brand red
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                // ── Red header (fills to top; drag handle lives inside it) ──
                Container(
                  color: headerColor,
                  padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag handle
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'ALL TROPHIES',
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 17,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      // ── Tab bar ──────────────────────────────────────────
                      TabBar(
                        labelStyle: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, letterSpacing: 1.1),
                        unselectedLabelStyle: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, letterSpacing: 1.1),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
                        indicatorColor: Colors.white,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'FREE'),
                          Tab(text: 'CHALLENGER ROAD'),
                          Tab(text: 'PRO'),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Tab views ─────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    children: [
                      _TrophiesTab(
                        userId: userId,
                        isPro: isPro,
                        proOnly: false,
                        scrollController: scrollController,
                      ),
                      _ChallengerRoadTab(
                        userId: userId,
                        isPro: isPro,
                        scrollController: scrollController,
                      ),
                      _TrophiesTab(
                        userId: userId,
                        isPro: isPro,
                        proOnly: true,
                        scrollController: scrollController,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Unified trophies tab (FREE or PRO) ───────────────────────────────────────

class _TrophiesTab extends StatefulWidget {
  const _TrophiesTab({
    required this.userId,
    required this.isPro,
    required this.proOnly,
    required this.scrollController,
  });

  final String userId;
  final bool isPro;

  /// When true, shows pro-only trophies; when false, shows free trophies.
  final bool proOnly;
  final ScrollController scrollController;

  @override
  State<_TrophiesTab> createState() => _TrophiesTabState();
}

class _TrophiesTabState extends State<_TrophiesTab> {
  late final Future<List<GlobalTrophyDefinition>> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = GlobalTrophyService().getTrophyCatalogForUser(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GlobalTrophyDefinition>>(
      future: _catalogFuture,
      builder: (context, catSnap) {
        final catalog = catSnap.data ?? GlobalTrophyService.catalog;
        return StreamBuilder<GlobalTrophySummary>(
          stream: GlobalTrophyService().watchUserSummary(widget.userId),
          builder: (context, snap) {
            final summary = snap.data ?? GlobalTrophySummary.empty();
            final earned = summary.trophies.toSet();

            // Filter catalog to the correct tier group
            final filtered = catalog.where((d) => d.proOnly == widget.proOnly).toList();

            // Group by tier (legendary first)
            final groups = <_TierGroup>[];
            for (final tier in GlobalTrophyTier.values.reversed) {
              final defs = filtered.where((d) => d.tier == tier).toList();
              if (defs.isNotEmpty) groups.add(_TierGroup(tier: tier, defs: defs));
            }

            return ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: groups.length,
              itemBuilder: (context, gi) {
                final group = groups[gi];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (gi > 0) const SizedBox(height: 16),
                    _TierHeader(tier: group.tier),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: group.defs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (context, i) {
                        final def = group.defs[i];
                        final isEarned = earned.contains(def.id);
                        final canEarn = !def.proOnly || widget.isPro;
                        return _TrophyTile(
                          def: def,
                          earned: isEarned,
                          canEarn: canEarn,
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TrophyTile extends StatelessWidget {
  const _TrophyTile({
    required this.def,
    required this.earned,
    required this.canEarn,
  });

  final GlobalTrophyDefinition def;
  final bool earned;

  /// Whether the user's subscription level permits earning this trophy.
  final bool canEarn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = GlobalTrophyService.colorForTrophy(def);
    final icon = GlobalTrophyService.iconForTrophy(def);

    return GestureDetector(
      onTap: () => _showDetail(context, theme, color, icon),
      child: Container(
        decoration: BoxDecoration(
          color: earned ? color.withValues(alpha: 0.09) : theme.colorScheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned ? color.withValues(alpha: 0.45) : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: earned ? 1.2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned ? color.withValues(alpha: 0.15) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                border: Border.all(
                  color: earned ? color.withValues(alpha: 0.55) : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  width: earned ? 1.5 : 1,
                ),
              ),
              child: ClipOval(
                child: def.effectiveIconUrl != null
                    ? Image.network(
                        def.effectiveIconUrl!,
                        fit: BoxFit.cover,
                        color: earned ? null : Colors.white.withValues(alpha: canEarn ? 0.22 : 0.15),
                        colorBlendMode: earned ? null : BlendMode.dstIn,
                        errorBuilder: (_, __, ___) => Icon(
                          icon,
                          size: 22,
                          color: earned ? color : theme.colorScheme.onSurface.withValues(alpha: canEarn ? 0.22 : 0.15),
                        ),
                      )
                    : Icon(
                        icon,
                        size: 22,
                        color: earned ? color : theme.colorScheme.onSurface.withValues(alpha: canEarn ? 0.22 : 0.15),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              def.effectiveName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 10,
                height: 1.2,
                color: earned ? theme.colorScheme.onSurface.withValues(alpha: 0.9) : theme.colorScheme.onSurface.withValues(alpha: canEarn ? 0.38 : 0.25),
              ),
            ),
            if (earned) ...[
              const SizedBox(height: 2),
              Icon(Icons.check_circle_rounded, size: 11, color: color.withValues(alpha: 0.8)),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, ThemeData theme, Color color, IconData icon) {
    final requiresPro = def.proOnly && !earned;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: earned ? 0.15 : 0.07),
                      border: Border.all(color: color.withValues(alpha: earned ? 0.6 : 0.25), width: 1.5),
                    ),
                    child: ClipOval(
                      child: def.effectiveIconUrl != null
                          ? Image.network(
                              def.effectiveIconUrl!,
                              fit: BoxFit.cover,
                              color: earned ? null : color.withValues(alpha: 0.35),
                              colorBlendMode: earned ? null : BlendMode.dstIn,
                              errorBuilder: (_, __, ___) => Icon(icon, size: 28, color: earned ? color : color.withValues(alpha: 0.35)),
                            )
                          : Icon(icon, size: 28, color: earned ? color : color.withValues(alpha: 0.35)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(def.effectiveName, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: theme.colorScheme.onSurface)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _TierBadge(tier: def.tier),
                            if (def.proOnly) ...[
                              const SizedBox(width: 6),
                              _ProBadge(),
                            ],
                            if (earned) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.check_circle_rounded, size: 14, color: color),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                def.effectiveDescription,
                style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 15, height: 1.45, color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
              ),
              if (!earned && !requiresPro) ...[
                const SizedBox(height: 10),
                Text('Not yet earned', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.45))),
              ],
              if (requiresPro && !canEarn) ...[
                const SizedBox(height: 10),
                Text('Upgrade to Pro to earn this trophy.', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, color: Colors.amber.withValues(alpha: 0.85))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _TierHeader extends StatelessWidget {
  const _TierHeader({required this.tier});
  final GlobalTrophyTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _tierColor(tier, theme);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          GlobalTrophyService.tierLabel(tier).toUpperCase(),
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 11,
            letterSpacing: 1.4,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _tierColor(GlobalTrophyTier tier, ThemeData theme) {
    switch (tier) {
      case GlobalTrophyTier.legendary:
        return Colors.amber;
      case GlobalTrophyTier.epic:
        return Colors.deepPurpleAccent;
      case GlobalTrophyTier.rare:
        return Colors.blueAccent;
      case GlobalTrophyTier.uncommon:
        return Colors.tealAccent.shade400;
      case GlobalTrophyTier.common:
        return theme.colorScheme.onSurface.withValues(alpha: 0.55);
    }
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});
  final GlobalTrophyTier tier;

  @override
  Widget build(BuildContext context) {
    final color = GlobalTrophyService.colorForTrophy(
      GlobalTrophyService.catalog.firstWhere((d) => d.tier == tier, orElse: () => GlobalTrophyService.catalog.first),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(
        GlobalTrophyService.tierLabel(tier).toUpperCase(),
        style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 10, letterSpacing: 1, color: color),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: const Text('PRO', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 10, letterSpacing: 1, color: Colors.amber)),
    );
  }
}

class _TierGroup {
  final GlobalTrophyTier tier;
  final List<GlobalTrophyDefinition> defs;
  _TierGroup({required this.tier, required this.defs});
}

// ═════════════════════════════════════════════════════════════════════════════
// Challenger Road tab
// ═════════════════════════════════════════════════════════════════════════════

class _ChallengerRoadTab extends StatefulWidget {
  const _ChallengerRoadTab({
    required this.userId,
    required this.isPro,
    required this.scrollController,
  });

  final String userId;
  final bool isPro;
  final ScrollController scrollController;

  @override
  State<_ChallengerRoadTab> createState() => _ChallengerRoadTabState();
}

class _ChallengerRoadTabState extends State<_ChallengerRoadTab> {
  late final Future<List<ChallengerRoadTrophyDefinition>> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = ChallengerRoadService().getTrophyCatalogForUser(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChallengerRoadTrophyDefinition>>(
      future: _catalogFuture,
      builder: (context, catSnap) {
        final catalog = catSnap.data ?? ChallengerRoadService.trophyCatalog;
        return StreamBuilder<ChallengerRoadUserSummary>(
          stream: ChallengerRoadService().watchUserSummary(widget.userId),
          builder: (context, crSnap) {
            final crSummary = crSnap.data ?? ChallengerRoadUserSummary.empty();
            final earnedCr = crSummary.trophies.toSet();

            // Filter out hidden-tier badges just like the main CR screen.
            final visible = ChallengerRoadService.visibleDisplayTrophyDefs(
              trophies: catalog,
            );

            return ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final def = visible[i];
                return _CrTrophyRow(
                  def: def,
                  earned: earnedCr.contains(def.id),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CrTrophyRow extends StatelessWidget {
  const _CrTrophyRow({required this.def, required this.earned});

  final ChallengerRoadTrophyDefinition def;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ChallengerRoadService.colorForTrophy(def);

    return GestureDetector(
      onTap: () => _showDetail(context, theme, color),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: earned ? color.withValues(alpha: 0.07) : theme.colorScheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned ? color.withValues(alpha: 0.35) : theme.colorScheme.onSurface.withValues(alpha: 0.07),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Opacity(
                opacity: earned ? 1.0 : 0.3,
                child: ChallengerRoadService.trophyIconWidget(def, size: 40, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.effectiveName,
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 15,
                      color: earned ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    def.effectiveDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: earned ? 0.55 : 0.3),
                    ),
                  ),
                ],
              ),
            ),
            if (earned) Icon(Icons.check_circle_rounded, size: 16, color: color.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, ThemeData theme, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: ChallengerRoadService.trophyIconWidget(def, size: 54, color: earned ? color : color.withValues(alpha: 0.35)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.effectiveName,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 22,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (earned) Icon(Icons.check_circle_rounded, size: 14, color: color),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                def.effectiveDescription,
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 15,
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              if (!earned) ...[
                const SizedBox(height: 10),
                Text(
                  'Not yet earned',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

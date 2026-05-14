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
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
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
                            'TROPHIES',
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
                        tabAlignment: TabAlignment.fill,
                        labelStyle: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 11, letterSpacing: 0.5),
                        unselectedLabelStyle: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 11, letterSpacing: 0.5),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
                        indicatorColor: Colors.white,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'STANDARD'),
                          Tab(text: 'CHALLENGER ROAD'),
                          Tab(text: 'ACCURACY'),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Trophy case ────────────────────────────────────────────
                _TrophyCaseSection(userId: userId, isPro: isPro),
                // ── Tab views ─────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    children: [
                      _TrophiesTab(
                        userId: userId,
                        isPro: isPro,
                        accuracyOnly: false,
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
                        accuracyOnly: true,
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

// ── Unified trophies tab (STANDARD or ACCURACY) ─────────────────────────────

class _TrophiesTab extends StatefulWidget {
  const _TrophiesTab({
    required this.userId,
    required this.isPro,
    required this.accuracyOnly,
    required this.scrollController,
  });

  final String userId;
  final bool isPro;

  /// When true, shows accuracy-category trophies only; when false, shows all others.
  final bool accuracyOnly;
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

            // Filter catalog to the correct category group
            final filtered = catalog.where((d) => widget.accuracyOnly ? d.category == GlobalTrophyCategory.accuracy : d.category != GlobalTrophyCategory.accuracy).toList();

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
                    for (final def in group.defs)
                      _GlobalTrophyRow(
                        def: def,
                        earned: earned.contains(def.id),
                        canEarn: !def.proOnly || widget.isPro,
                        userId: widget.userId,
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
                  userId: widget.userId,
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
  const _CrTrophyRow({required this.def, required this.earned, required this.userId});

  final ChallengerRoadTrophyDefinition def;
  final bool earned;
  final String userId;

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
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _TrophyDetailSwapSheet(
        userId: userId,
        trophyId: def.id,
        earned: earned,
        trophyColor: color,
        description: def.effectiveDescription,
        footerText: !earned ? 'Not yet earned' : null,
        header: Row(
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
                    style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  if (earned) Icon(Icons.check_circle_rounded, size: 14, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Global trophy row (for FREE and PRO tabs - matches CR row style) ─────────

class _GlobalTrophyRow extends StatelessWidget {
  const _GlobalTrophyRow({
    required this.def,
    required this.earned,
    required this.canEarn,
    required this.userId,
  });

  final GlobalTrophyDefinition def;
  final bool earned;
  final bool canEarn;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = GlobalTrophyService.colorForTrophy(def);
    final icon = GlobalTrophyService.iconForTrophy(def);

    return GestureDetector(
      onTap: () => _showDetail(context, theme, color, icon),
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
            Container(
              width: 40,
              height: 40,
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
                        errorBuilder: (_, __, ___) => Icon(icon, size: 22, color: earned ? color : theme.colorScheme.onSurface.withValues(alpha: canEarn ? 0.22 : 0.15)),
                      )
                    : Icon(icon, size: 22, color: earned ? color : theme.colorScheme.onSurface.withValues(alpha: canEarn ? 0.22 : 0.15)),
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

  void _showDetail(BuildContext context, ThemeData theme, Color color, IconData icon) {
    final requiresPro = def.proOnly && !earned;
    final footerText = (!earned && !requiresPro)
        ? 'Not yet earned'
        : (requiresPro && !canEarn)
            ? 'Upgrade to Pro to earn this trophy.'
            : null;
    final footerColor = (requiresPro && !canEarn) ? Colors.amber.withValues(alpha: 0.85) : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _TrophyDetailSwapSheet(
        userId: userId,
        trophyId: def.id,
        earned: earned,
        trophyColor: color,
        description: def.effectiveDescription,
        footerText: footerText,
        footerColor: footerColor,
        header: Row(
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
                    ? Image.network(def.effectiveIconUrl!, fit: BoxFit.cover, color: earned ? null : color.withValues(alpha: 0.35), colorBlendMode: earned ? null : BlendMode.dstIn, errorBuilder: (_, __, ___) => Icon(icon, size: 28, color: earned ? color : color.withValues(alpha: 0.35)))
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
                  Row(children: [
                    _TierBadge(tier: def.tier),
                    if (def.proOnly) ...[const SizedBox(width: 6), _ProBadge()],
                    if (earned) ...[const SizedBox(width: 6), Icon(Icons.check_circle_rounded, size: 14, color: color)],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Trophy Case Section (shown above the tabs in AllTrophiesSheet)
// ═════════════════════════════════════════════════════════════════════════════

class _TrophyCaseSection extends StatefulWidget {
  const _TrophyCaseSection({required this.userId, required this.isPro});

  final String userId;
  final bool isPro;

  @override
  State<_TrophyCaseSection> createState() => _TrophyCaseSectionState();
}

class _TrophyCaseSectionState extends State<_TrophyCaseSection> {
  late Future<List<ChallengerRoadTrophyDefinition>> _crCatalogFuture;

  @override
  void initState() {
    super.initState();
    _crCatalogFuture = ChallengerRoadService().getTrophyCatalogForUser(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GlobalTrophySummary>(
      stream: GlobalTrophyService().watchUserSummary(widget.userId),
      builder: (context, globalSnap) {
        final globalSummary = globalSnap.data ?? GlobalTrophySummary.empty();
        return StreamBuilder<ChallengerRoadUserSummary>(
          stream: ChallengerRoadService().watchUserSummary(widget.userId),
          builder: (context, crSnap) {
            final crSummary = crSnap.data ?? ChallengerRoadUserSummary.empty();
            return FutureBuilder<List<ChallengerRoadTrophyDefinition>>(
              future: _crCatalogFuture,
              builder: (context, catSnap) {
                final crCatalog = catSnap.data ?? [];
                return _TrophyCaseSectionBody(
                  userId: widget.userId,
                  globalSummary: globalSummary,
                  crSummary: crSummary,
                  crCatalog: crCatalog,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TrophyCaseSectionBody extends StatelessWidget {
  const _TrophyCaseSectionBody({
    required this.userId,
    required this.globalSummary,
    required this.crSummary,
    required this.crCatalog,
  });

  final String userId;
  final GlobalTrophySummary globalSummary;
  final ChallengerRoadUserSummary crSummary;
  final List<ChallengerRoadTrophyDefinition> crCatalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featured = globalSummary.featuredTrophies;
    final crById = {for (final d in crCatalog) d.id: d};

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 8, 6),
          child: Row(
            children: [
              Text(
                'TROPHY CASE',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openPicker(context),
                style: TextButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('EDIT', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 12)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < 5; i++)
                GestureDetector(
                  onTap: () => _openPicker(context),
                  child: _buildSlot(context, theme, i, featured, crById),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ],
    );
  }

  Widget _buildSlot(
    BuildContext context,
    ThemeData theme,
    int i,
    List<String> featured,
    Map<String, ChallengerRoadTrophyDefinition> crById,
  ) {
    final id = i < featured.length ? featured[i] : '';

    if (id.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(width: 52, height: 20),
        ],
      );
    }

    final bool isGlobal = id.startsWith('g_');
    Widget icon;
    String label;

    if (isGlobal) {
      final gDef = GlobalTrophyService.catalog.where((d) => d.id == id).firstOrNull;
      if (gDef == null) return const SizedBox(width: 52, height: 56);
      final color = GlobalTrophyService.colorForTrophy(gDef);
      label = gDef.name;
      icon = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6)],
        ),
        child: Icon(GlobalTrophyService.iconForTrophy(gDef), size: 20, color: color),
      );
    } else {
      final crDef = crById[id];
      if (crDef == null) return const SizedBox(width: 52, height: 56);
      final color = ChallengerRoadService.colorForTrophy(crDef);
      label = crDef.effectiveName;
      icon = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6)],
        ),
        child: ChallengerRoadService.trophyIconWidget(crDef, size: 36, color: color),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 4),
        SizedBox(
          width: 52,
          height: 20,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 9,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrophyCasePickerSheet(
        userId: userId,
        globalSummary: globalSummary,
        crSummary: crSummary,
        crCatalog: crCatalog,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Trophy detail sheet with inline trophy-case swap
// ═════════════════════════════════════════════════════════════════════════════

/// Detail sheet for any trophy. When the trophy is earned, a mini trophy-case
/// row is shown at the bottom so the user can tap a slot to place (or swap)
/// this trophy directly onto the shelf — without opening the full picker.
class _TrophyDetailSwapSheet extends StatefulWidget {
  const _TrophyDetailSwapSheet({
    required this.userId,
    required this.trophyId,
    required this.earned,
    required this.header,
    required this.description,
    required this.trophyColor,
    this.footerText,
    this.footerColor,
  });

  final String userId;
  final String trophyId;
  final bool earned;
  final Widget header;
  final String description;
  final Color trophyColor;
  final String? footerText;
  final Color? footerColor;

  @override
  State<_TrophyDetailSwapSheet> createState() => _TrophyDetailSwapSheetState();
}

class _TrophyDetailSwapSheetState extends State<_TrophyDetailSwapSheet> {
  late final Future<List<ChallengerRoadTrophyDefinition>> _crCatalogFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _crCatalogFuture = ChallengerRoadService().getTrophyCatalogForUser(widget.userId);
  }

  Future<void> _swapIntoSlot(int slotIndex, List<String> currentSlots) async {
    if (_saving) return;
    setState(() => _saving = true);

    final slots = List<String>.generate(5, (i) => i < currentSlots.length ? currentSlots[i] : '');
    final existingIdx = slots.indexOf(widget.trophyId);

    if (existingIdx == slotIndex) {
      // Tap own slot → remove from case
      slots[slotIndex] = '';
    } else if (existingIdx >= 0) {
      // Already in another slot → swap the two positions
      slots[existingIdx] = slots[slotIndex];
      slots[slotIndex] = widget.trophyId;
    } else {
      // Not in case → place in this slot, displacing whatever was there
      slots[slotIndex] = widget.trophyId;
    }

    try {
      await GlobalTrophyService().setFeaturedTrophies(widget.userId, slots);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.header,
            const SizedBox(height: 14),
            Text(
              widget.description,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 15,
                height: 1.45,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            if (widget.footerText != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.footerText!,
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 13,
                  color: widget.footerColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
            // ── Inline trophy-case swap (earned trophies only) ────────────
            if (widget.earned) ...[
              const SizedBox(height: 18),
              Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              StreamBuilder<GlobalTrophySummary>(
                stream: GlobalTrophyService().watchUserSummary(widget.userId),
                builder: (context, snap) {
                  final featured = snap.data?.featuredTrophies ?? [];
                  return FutureBuilder<List<ChallengerRoadTrophyDefinition>>(
                    future: _crCatalogFuture,
                    builder: (context, catSnap) {
                      final crCatalog = catSnap.data ?? [];
                      final crById = {for (final d in crCatalog) d.id: d};
                      final slots = List<String>.generate(5, (i) => i < featured.length ? featured[i] : '');
                      final thisSlotIdx = slots.indexOf(widget.trophyId);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'TROPHY CASE',
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  thisSlotIdx >= 0 ? 'Tap another slot to swap \u2022 tap to remove' : 'Tap a slot to place here',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'NovecentoSans',
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              for (int i = 0; i < 5; i++) _buildSwapSlot(context, theme, i, slots, crById, thisSlotIdx),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSwapSlot(
    BuildContext context,
    ThemeData theme,
    int i,
    List<String> slots,
    Map<String, ChallengerRoadTrophyDefinition> crById,
    int thisSlotIdx,
  ) {
    final id = slots[i];
    final isCurrentSlot = (i == thisSlotIdx);
    Widget inner;

    if (id.isEmpty) {
      inner = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
        ),
      );
    } else if (id.startsWith('g_')) {
      final gDef = GlobalTrophyService.catalog.where((d) => d.id == id).firstOrNull;
      if (gDef == null) return const SizedBox(width: 44, height: 44);
      final c = GlobalTrophyService.colorForTrophy(gDef);
      final ico = GlobalTrophyService.iconForTrophy(gDef);
      inner = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withValues(alpha: 0.15),
          border: Border.all(
            color: isCurrentSlot ? widget.trophyColor : c.withValues(alpha: 0.6),
            width: isCurrentSlot ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isCurrentSlot ? widget.trophyColor : c).withValues(alpha: isCurrentSlot ? 0.5 : 0.25),
              blurRadius: isCurrentSlot ? 10 : 5,
              spreadRadius: isCurrentSlot ? 1 : 0,
            ),
          ],
        ),
        child: Icon(ico, size: 22, color: c),
      );
    } else {
      final crDef = crById[id];
      if (crDef == null) return const SizedBox(width: 44, height: 44);
      final c = ChallengerRoadService.colorForTrophy(crDef);
      Widget iconWidget = SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ChallengerRoadService.trophyIconWidget(crDef, size: 44, color: c),
            if (isCurrentSlot)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.trophyColor, width: 2.5),
                ),
              ),
          ],
        ),
      );
      inner = isCurrentSlot
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: widget.trophyColor.withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: iconWidget,
            )
          : iconWidget;
    }

    return GestureDetector(
      onTap: _saving ? null : () => _swapIntoSlot(i, slots),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _saving ? 0.5 : 1.0,
        child: inner,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Trophy Case Picker Sheet (select up to 5 from all earned trophies)
// ═════════════════════════════════════════════════════════════════════════════

class _TrophyCasePickerSheet extends StatefulWidget {
  const _TrophyCasePickerSheet({
    required this.userId,
    required this.globalSummary,
    required this.crSummary,
    required this.crCatalog,
  });

  final String userId;
  final GlobalTrophySummary globalSummary;
  final ChallengerRoadUserSummary crSummary;
  final List<ChallengerRoadTrophyDefinition> crCatalog;

  @override
  State<_TrophyCasePickerSheet> createState() => _TrophyCasePickerSheetState();
}

class _TrophyCasePickerSheetState extends State<_TrophyCasePickerSheet> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.globalSummary.featuredTrophies.where((id) => id.isNotEmpty).toSet();
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

  Future<void> _save() async {
    setState(() => _saving = true);
    final existing = widget.globalSummary.featuredTrophies;
    final slots = List<String>.generate(5, (i) => i < existing.length ? existing[i] : '');
    for (int i = 0; i < 5; i++) {
      if (slots[i].isNotEmpty && !_selected.contains(slots[i])) slots[i] = '';
    }
    for (final id in _selected) {
      if (!slots.contains(id)) {
        final emptyIdx = slots.indexOf('');
        if (emptyIdx >= 0) slots[emptyIdx] = id;
      }
    }
    await GlobalTrophyService().setFeaturedTrophies(widget.userId, slots);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final scheme = theme.colorScheme;

    final earnedGlobalIds = widget.globalSummary.trophies.toSet();
    final earnedStandard = GlobalTrophyService.catalog.where((d) => d.category != GlobalTrophyCategory.accuracy && earnedGlobalIds.contains(d.id)).toList();
    final earnedAccuracy = GlobalTrophyService.catalog.where((d) => d.category == GlobalTrophyCategory.accuracy && earnedGlobalIds.contains(d.id)).toList();

    final earnedCrIds = widget.crSummary.trophies.toSet();
    final earnedCr = ChallengerRoadService.visibleDisplayTrophyDefs(trophies: widget.crCatalog).where((d) => earnedCrIds.contains(d.id)).toList();

    // Group free/pro earned trophies by tier (legendary first)
    List<_TierGroup> groupByTier(List<GlobalTrophyDefinition> list) {
      final groups = <_TierGroup>[];
      for (final tier in GlobalTrophyTier.values.reversed) {
        final defs = list.where((d) => d.tier == tier).toList();
        if (defs.isNotEmpty) groups.add(_TierGroup(tier: tier, defs: defs));
      }
      return groups;
    }

    final standardGroups = groupByTier(earnedStandard);
    final accuracyGroups = groupByTier(earnedAccuracy);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Red header ─────────────────────────────────────────────
              Container(
                color: primary,
                padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TROPHY CASE',
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 17,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'Select up to 5 trophies to showcase.',
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              // ── Trophy list ────────────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    // STANDARD section
                    if (earnedStandard.isNotEmpty) ...[
                      _PickerSectionHeader(label: 'STANDARD', scheme: scheme),
                      const SizedBox(height: 8),
                      for (final group in standardGroups) ...[
                        _TierHeader(tier: group.tier),
                        const SizedBox(height: 6),
                        for (final def in group.defs)
                          _PickerGlobalRow(
                            def: def,
                            selected: _selected.contains(def.id),
                            disabled: !_selected.contains(def.id) && _selected.length >= 5,
                            onTap: () => _toggle(def.id),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    // ACCURACY section
                    if (earnedAccuracy.isNotEmpty) ...[
                      if (earnedStandard.isNotEmpty) const SizedBox(height: 4),
                      _PickerSectionHeader(label: 'ACCURACY', scheme: scheme),
                      const SizedBox(height: 8),
                      for (final group in accuracyGroups) ...[
                        _TierHeader(tier: group.tier),
                        const SizedBox(height: 6),
                        for (final def in group.defs)
                          _PickerGlobalRow(
                            def: def,
                            selected: _selected.contains(def.id),
                            disabled: !_selected.contains(def.id) && _selected.length >= 5,
                            onTap: () => _toggle(def.id),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    // CHALLENGER ROAD section
                    if (earnedCr.isNotEmpty) ...[
                      if (earnedStandard.isNotEmpty || earnedAccuracy.isNotEmpty) const SizedBox(height: 4),
                      _PickerSectionHeader(label: 'CHALLENGER ROAD', scheme: scheme),
                      const SizedBox(height: 8),
                      for (final def in earnedCr)
                        _PickerCrRow(
                          def: def,
                          selected: _selected.contains(def.id),
                          disabled: !_selected.contains(def.id) && _selected.length >= 5,
                          onTap: () => _toggle(def.id),
                        ),
                    ],
                    if (earnedStandard.isEmpty && earnedAccuracy.isEmpty && earnedCr.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No trophies earned yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 14,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80), // room for save button
                  ],
                ),
              ),
              // ── Save button ────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.1))),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
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
        );
      },
    );
  }
}

// ── Picker helpers ────────────────────────────────────────────────────────────

class _PickerSectionHeader extends StatelessWidget {
  const _PickerSectionHeader({required this.label, required this.scheme});
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 12,
          color: scheme.onSurface.withValues(alpha: 0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PickerGlobalRow extends StatelessWidget {
  const _PickerGlobalRow({
    required this.def,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final GlobalTrophyDefinition def;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = GlobalTrophyService.colorForTrophy(def);
    final icon = GlobalTrophyService.iconForTrophy(def);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.35 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : theme.colorScheme.onSurface.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : theme.colorScheme.onSurface.withValues(alpha: 0.07),
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
                ),
                child: ClipOval(
                  child: def.effectiveIconUrl != null ? Image.network(def.effectiveIconUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(icon, size: 22, color: color)) : Icon(icon, size: 22, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.effectiveName, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 15, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(def.effectiveDescription, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SelectionIndicator(selected: selected, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerCrRow extends StatelessWidget {
  const _PickerCrRow({
    required this.def,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final ChallengerRoadTrophyDefinition def;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ChallengerRoadService.colorForTrophy(def);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.35 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : theme.colorScheme.onSurface.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : theme.colorScheme.onSurface.withValues(alpha: 0.07),
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: ChallengerRoadService.trophyIconWidget(def, size: 40, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.effectiveName, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 15, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(def.effectiveDescription, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SelectionIndicator(selected: selected, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected, required this.color});
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
    );
  }
}

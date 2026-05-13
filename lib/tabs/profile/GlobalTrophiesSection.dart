import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/GlobalTrophySummary.dart';
import 'package:tenthousandshotchallenge/services/GlobalTrophyService.dart';

/// Profile card showing a user's earned global session trophies.
///
/// Free users see free trophies; pro trophies are shown locked for non-pro users.
/// Tapping any trophy shows a detail bottom sheet.
class GlobalTrophiesSection extends StatelessWidget {
  const GlobalTrophiesSection({
    super.key,
    required this.userId,
    required this.isPro,
    this.isEditable = false,
    this.showOnlyEarned = false,
  });

  final String userId;
  final bool isPro;

  /// When true shows the edit/featuring UI (own profile only).
  final bool isEditable;

  /// When true only earned trophies are rendered (used on other players' profiles).
  final bool showOnlyEarned;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GlobalTrophySummary>(
      stream: GlobalTrophyService().watchUserSummary(userId),
      builder: (context, snap) {
        final summary = snap.data ?? GlobalTrophySummary.empty();
        return _GlobalTrophiesContent(
          summary: summary,
          isPro: isPro,
          isEditable: isEditable,
          showOnlyEarned: showOnlyEarned,
        );
      },
    );
  }
}

// ── Content ───────────────────────────────────────────────────────────────────

class _GlobalTrophiesContent extends StatelessWidget {
  const _GlobalTrophiesContent({
    required this.summary,
    required this.isPro,
    required this.isEditable,
    required this.showOnlyEarned,
  });

  final GlobalTrophySummary summary;
  final bool isPro;
  final bool isEditable;
  final bool showOnlyEarned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earned = summary.trophies.toSet();

    // Build tier groups.
    final groups = <_TierGroup>[];
    for (final tier in GlobalTrophyTier.values.reversed) {
      final defs = GlobalTrophyService.catalog.where((d) {
        if (d.tier != tier) return false;
        if (showOnlyEarned && !earned.contains(d.id)) return false;
        if (d.proOnly && !isPro && !earned.contains(d.id)) return false;
        return true;
      }).toList();
      if (defs.isNotEmpty) groups.add(_TierGroup(tier: tier, defs: defs));
    }

    if (groups.isEmpty && showOnlyEarned) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'No global trophies earned yet.',
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header + count
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                'GLOBAL TROPHIES',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${earned.length} earned',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int g = 0; g < groups.length; g++) ...[
            if (g > 0) const SizedBox(height: 12),
            Text(
              _tierLabel(groups[g].tier).toUpperCase(),
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: groups[g].defs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final def = groups[g].defs[index];
                final isEarned = earned.contains(def.id);
                return _GlobalTrophyChip(
                  def: def,
                  earned: isEarned,
                  isPro: isPro,
                );
              },
            ),
          ],
          // Pro nudge for free users
          if (!isPro && !showOnlyEarned) ...[
            const SizedBox(height: 12),
            _ProNudge(),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _tierLabel(GlobalTrophyTier tier) => GlobalTrophyService.tierLabel(tier);
}

class _TierGroup {
  final GlobalTrophyTier tier;
  final List<GlobalTrophyDefinition> defs;
  _TierGroup({required this.tier, required this.defs});
}

// ── Individual trophy chip ────────────────────────────────────────────────────

class _GlobalTrophyChip extends StatelessWidget {
  const _GlobalTrophyChip({
    required this.def,
    required this.earned,
    required this.isPro,
  });

  final GlobalTrophyDefinition def;
  final bool earned;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final color = GlobalTrophyService.colorForTrophy(def);
    final icon = GlobalTrophyService.iconForTrophy(def);
    final isLocked = def.proOnly && !isPro && !earned;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned ? color.withValues(alpha: 0.15) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
              border: Border.all(
                color: earned ? color.withValues(alpha: 0.6) : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                width: earned ? 1.5 : 1,
              ),
            ),
            child: isLocked
                ? Icon(Icons.lock_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.3))
                : Icon(
                    icon,
                    size: 22,
                    color: earned ? color : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              def.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 9,
                height: 1.2,
                color: earned ? theme.colorScheme.onSurface.withValues(alpha: 0.85) : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final color = GlobalTrophyService.colorForTrophy(def);
    final icon = GlobalTrophyService.iconForTrophy(def);
    final theme = Theme.of(context);
    final isLocked = def.proOnly && !isPro && !earned;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: earned ? 0.15 : 0.07),
                      border: Border.all(color: color.withValues(alpha: earned ? 0.6 : 0.3), width: 1.5),
                    ),
                    child: isLocked ? Icon(Icons.lock_rounded, size: 22, color: color.withValues(alpha: 0.5)) : Icon(icon, size: 26, color: earned ? color : color.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.name,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 20,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                GlobalTrophyService.tierLabel(def.tier).toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 11,
                                  color: color,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            if (def.proOnly) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontFamily: 'NovecentoSans',
                                    fontSize: 11,
                                    color: Colors.amber,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (earned) Icon(Icons.check_circle_rounded, color: color, size: 22),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                def.description,
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
              if (!earned && !isLocked) ...[
                const SizedBox(height: 12),
                Text(
                  'Not yet earned',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
              if (isLocked) ...[
                const SizedBox(height: 12),
                Text(
                  'Upgrade to Pro to earn this trophy.',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 13,
                    color: Colors.amber.withValues(alpha: 0.8),
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

// ── Pro nudge ─────────────────────────────────────────────────────────────────

class _ProNudge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.lock_open_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Upgrade to Pro to unlock additional trophies.',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

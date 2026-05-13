import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/GlobalTrophyBackfillService.dart';
import 'package:tenthousandshotchallenge/services/GlobalTrophyService.dart';
import 'package:tenthousandshotchallenge/tabs/shots/GlobalTrophyGroupAwardScreen.dart';

/// Shows the one-time historical backfill sheet if needed.
///
/// Handles the full async flow: loading → prompt → claim/dismiss.
/// Safe to call on every app launch — exits immediately if backfill is done.
Future<void> maybeShowBackfillSheet(
  BuildContext context, {
  required String userId,
  required bool isPro,
}) async {
  final result = await GlobalTrophyBackfillService().computeIfNeeded(userId, isPro);

  if (result == null) return; // Already done.

  // Even if there are no trophy unlocks, we still need to persist the updated
  // counters so future evaluations work from the right baseline.
  if (!result.hasTrophies) {
    await GlobalTrophyBackfillService().apply(userId, result, award: false);
    return;
  }

  if (!context.mounted) return;

  final claimed = await showModalBottomSheet<List<GlobalTrophyDefinition>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _GlobalTrophyBackfillSheet(
      userId: userId,
      result: result,
    ),
  );

  if (claimed != null && claimed.isNotEmpty && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GlobalTrophyGroupAwardScreen(trophies: claimed),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GlobalTrophyBackfillSheet extends StatefulWidget {
  const _GlobalTrophyBackfillSheet({
    required this.userId,
    required this.result,
  });

  final String userId;
  final BackfillResult result;

  @override
  State<_GlobalTrophyBackfillSheet> createState() => _GlobalTrophyBackfillSheetState();
}

class _GlobalTrophyBackfillSheetState extends State<_GlobalTrophyBackfillSheet> {
  bool _saving = false;

  Future<void> _claim() async {
    setState(() => _saving = true);
    await GlobalTrophyBackfillService().apply(widget.userId, widget.result, award: true);
    if (mounted) Navigator.of(context).pop(widget.result.earnedTrophies);
  }

  Future<void> _dismiss() async {
    setState(() => _saving = true);
    // Persist updated counters but don't award trophies.
    await GlobalTrophyBackfillService().apply(widget.userId, widget.result, award: false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = theme.primaryColor;
    final trophies = widget.result.earnedTrophies;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Red header ───────────────────────────────────────────────
              Container(
                color: primary,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, size: 22, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TROPHIES UNLOCKED',
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 18,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'Based on your history, you\'ve earned '
                                '${trophies.length} '
                                '${trophies.length == 1 ? 'trophy' : 'trophies'}.',
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Trophy list ──────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: trophies.length,
                  itemBuilder: (context, i) {
                    final def = trophies[i];
                    final color = GlobalTrophyService.colorForTrophy(def);
                    final icon = GlobalTrophyService.iconForTrophy(def);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.30)),
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
                              child: def.effectiveIconUrl != null
                                  ? Image.network(
                                      def.effectiveIconUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(icon, size: 22, color: color),
                                    )
                                  : Icon(icon, size: 22, color: color),
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
                                    color: scheme.onSurface,
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
                                    color: scheme.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.check_circle_rounded, size: 16, color: color.withValues(alpha: 0.8)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // ── Action buttons ───────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.1)),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _saving ? null : _claim,
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
                            : const Text(
                                'CLAIM TROPHIES',
                                style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 17),
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _saving ? null : _dismiss,
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onSurface.withValues(alpha: 0.5),
                          minimumSize: const Size.fromHeight(42),
                        ),
                        child: const Text(
                          'NOT NOW',
                          style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14),
                        ),
                      ),
                    ],
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';

/// Read-only bottom sheet that shows all tries for a specific challenge at a
/// specific level within the user's current attempt.
class ChallengeTriesHistorySheet extends StatefulWidget {
  final ChallengerRoadChallenge challenge;
  final ChallengerRoadLevel levelDoc;
  final String userId;
  final String attemptId;

  const ChallengeTriesHistorySheet._({
    required this.challenge,
    required this.levelDoc,
    required this.userId,
    required this.attemptId,
  });

  static Future<void> show(
    BuildContext context, {
    required ChallengerRoadChallenge challenge,
    required ChallengerRoadLevel levelDoc,
    required String userId,
    required String attemptId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChallengeTriesHistorySheet._(
        challenge: challenge,
        levelDoc: levelDoc,
        userId: userId,
        attemptId: attemptId,
      ),
    );
  }

  @override
  State<ChallengeTriesHistorySheet> createState() => _ChallengeTriesHistorySheetState();
}

class _ChallengeTriesHistorySheetState extends State<ChallengeTriesHistorySheet> {
  final _service = ChallengerRoadService();
  late Future<List<ChallengeSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getTriesForChallenge(
      widget.userId,
      widget.attemptId,
      widget.challenge.id!,
      widget.levelDoc.level,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Drag handle ────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.challenge.name.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'LEVEL ${widget.levelDoc.level}  ·  TRY HISTORY',
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 12,
                              letterSpacing: 1.2,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pass target chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'TARGET SCORE: ${widget.levelDoc.shotsToPass}/${widget.levelDoc.shotsRequired}',
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── List ───────────────────────────────────────────────────
              Expanded(
                child: FutureBuilder<List<ChallengeSession>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load try history.',
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    }
                    final tries = snap.data ?? [];
                    if (tries.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sports_hockey_rounded,
                                size: 48,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'NO TRIES YET',
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 18,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Start a session to log your first try.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: tries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final try_ = tries[i];
                        // Number from oldest → newest (index from end).
                        final tryNumber = tries.length - i;
                        return _TryRow(
                          try_: try_,
                          tryNumber: tryNumber,
                          shotsRequired: widget.levelDoc.shotsRequired,
                          shotsToPass: widget.levelDoc.shotsToPass,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Individual try row ────────────────────────────────────────────────────

class _TryRow extends StatelessWidget {
  final ChallengeSession try_;
  final int tryNumber;
  final int shotsRequired;
  final int shotsToPass;

  const _TryRow({
    required this.try_,
    required this.tryNumber,
    required this.shotsRequired,
    required this.shotsToPass,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracy = shotsRequired > 0 ? try_.shotsMade / shotsRequired : 0.0;
    final passed = try_.passed;
    final isClose = !passed && try_.shotsMade >= (shotsToPass - 1).clamp(0, shotsRequired);

    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    if (passed) {
      statusColor = Colors.green.shade400;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'PASSED';
    } else if (isClose) {
      statusColor = Colors.orange.shade400;
      statusIcon = Icons.remove_circle_rounded;
      statusLabel = 'CLOSE';
    } else {
      statusColor = Colors.red.shade400;
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'MISSED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Try number badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$tryNumber',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 15,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Score + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Score
                Row(
                  children: [
                    Text(
                      '${try_.shotsMade}',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 28,
                        height: 1.0,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      ' / $shotsRequired',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 18,
                        height: 1.0,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: accuracy.clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor.withValues(alpha: 0.7)),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('MMM d, yyyy  h:mm a').format(try_.date)}  •  ${_formatDuration(try_.duration)}',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Status badge
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 22),
              const SizedBox(height: 2),
              Text(
                statusLabel,
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(accuracy * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds.remainder(60);
    return '${mins}m ${secs}s';
  }
}

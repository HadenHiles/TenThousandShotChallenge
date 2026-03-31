import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/Navigation.dart' show activeChallengeSession, sessionPanelController, ChallengeSessionConfig;
import 'package:tenthousandshotchallenge/models/firestore/ChallengeProgressEntry.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeStep.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'ChallengeStepViewer.dart';
import 'ChallengeTriesHistorySheet.dart';

/// Bottom sheet showing the details of a Challenger Road challenge at a
/// specific level, with an action button to start or retry the challenge.
///
/// Use the static [show] helper to present this sheet:
/// ```dart
/// await ChallengeDetailSheet.show(
///   context,
///   challenge: challenge,
///   levelDoc: levelDoc,
///   attempt: attempt,
///   userId: userId,
///   progress: progress,
///   onSessionComplete: () => setState(() { /* refresh */ }),
/// );
/// ```
class ChallengeDetailSheet extends StatelessWidget {
  final ChallengerRoadChallenge challenge;
  final ChallengerRoadLevel levelDoc;
  final ChallengerRoadAttempt attempt;
  final String userId;
  final ChallengeProgressEntry? progress;
  final VoidCallback? onSessionComplete;

  const ChallengeDetailSheet._({
    required this.challenge,
    required this.levelDoc,
    required this.attempt,
    required this.userId,
    this.progress,
    this.onSessionComplete,
  });

  /// Presents the sheet modally. Returns true if a session was completed.
  static Future<bool?> show(
    BuildContext context, {
    required ChallengerRoadChallenge challenge,
    required ChallengerRoadLevel levelDoc,
    required ChallengerRoadAttempt attempt,
    required String userId,
    ChallengeProgressEntry? progress,
    VoidCallback? onSessionComplete,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChallengeDetailSheet._(
        challenge: challenge,
        levelDoc: levelDoc,
        attempt: attempt,
        userId: userId,
        progress: progress,
        onSessionComplete: onSessionComplete,
      ),
    );
  }

  // ── State helpers ─────────────────────────────────────────────────────────

  bool get _isPassed {
    return (progress?.bestLevel ?? 0) >= levelDoc.level;
  }

  bool get _isLocked {
    return levelDoc.level > attempt.currentLevel;
  }

  /// Steps to show: level-specific override if present, else parent challenge steps.
  List<ChallengeStep> get _steps {
    final levelSteps = levelDoc.steps;
    if (levelSteps != null && levelSteps.isNotEmpty) return levelSteps;
    return challenge.steps;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Scrollable content ─────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    // ── Header row ────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _isLocked ? Colors.grey.shade600 : Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'LVL ${levelDoc.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'NovecentoSans',
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            challenge.name,
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 28,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (_isPassed) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Description ───────────────────────────────────────
                    Text(
                      challenge.description,
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Quota card ────────────────────────────────────────
                    _buildQuotaCard(context),
                    const SizedBox(height: 12),

                    // ── Try history link ──────────────────────────────────
                    if (progress != null && progress!.totalAttempts > 0) _buildHistoryLink(context),

                    const SizedBox(height: 20),

                    // ── Steps header ──────────────────────────────────────
                    Text(
                      'STEPS',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 13,
                        letterSpacing: 1.5,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Step viewer ───────────────────────────────────────
                    if (_steps.isNotEmpty)
                      ChallengeStepViewer(steps: _steps)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No steps available yet.',
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Pinned CTA footer ──────────────────────────────────────
              _buildCTA(context),
            ],
          ),
        );
      },
    );
  }

  // ── Quota info card ───────────────────────────────────────────────────────

  Widget _buildQuotaCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quotaStat(context, '${levelDoc.shotsRequired}', 'SHOTS / ATTEMPT'),
          Container(width: 1, height: 32, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          _quotaStat(context, '${levelDoc.shotsToPass}', 'ON TARGET TO PASS'),
          Container(width: 1, height: 32, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          _quotaStat(
            context,
            progress != null ? '${progress!.totalAttempts}' : '–',
            'ATTEMPTS',
          ),
        ],
      ),
    );
  }

  Widget _quotaStat(BuildContext context, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 26,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 10,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ── Try history link ──────────────────────────────────────────────────────

  Widget _buildHistoryLink(BuildContext context) {
    final tryCount = progress!.totalAttempts;
    final passCount = progress!.totalPassed;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        ChallengeTriesHistorySheet.show(
          context,
          challenge: challenge,
          levelDoc: levelDoc,
          userId: userId,
          attemptId: attempt.id!,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.09),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$tryCount ${tryCount == 1 ? 'TRY' : 'TRIES'} LOGGED  ·  $passCount PASSED',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 13,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  // ── CTA button ────────────────────────────────────────────────────────────

  Widget _buildCTA(BuildContext context) {
    final String label;
    final bool enabled;
    final Color bgColor;

    if (_isLocked) {
      label = 'Complete Level ${attempt.currentLevel} First';
      enabled = false;
      bgColor = Colors.grey.shade600;
    } else if (_isPassed) {
      label = 'Retry Challenge';
      enabled = true;
      bgColor = Colors.indigo.shade600;
    } else {
      label = 'Start Challenge';
      enabled = true;
      bgColor = Theme.of(context).primaryColor;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              disabledBackgroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: enabled ? () => _launchChallenge(context) : null,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchChallenge(BuildContext context) async {
    Navigator.of(context).pop(); // close the detail sheet
    activeChallengeSession.value = ChallengeSessionConfig(
      challenge: challenge,
      levelDoc: levelDoc,
      attempt: attempt,
      userId: userId,
      startedAt: DateTime.now(),
      onSessionComplete: onSessionComplete,
    );
    sessionPanelController.open();
  }
}

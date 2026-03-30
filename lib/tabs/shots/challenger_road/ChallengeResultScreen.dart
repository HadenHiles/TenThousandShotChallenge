import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';

/// Displayed after a challenge session completes (pass or fail).
///
/// Pops all the way back to the map on "Back to Road", or re-starts via the
/// "Try Again" button which pops back to the detail sheet.
class ChallengeResultScreen extends StatelessWidget {
  const ChallengeResultScreen({
    super.key,
    required this.session,
    required this.challenge,
    required this.levelDoc,
    required this.updatedAttempt,
    required this.milestoneResult,
    this.levelAdvanced = false,
  });

  final ChallengeSession session;
  final ChallengerRoadChallenge challenge;
  final ChallengerRoadLevel levelDoc;
  final ChallengerRoadAttempt updatedAttempt;
  final ChallengerRoadMilestoneResult milestoneResult;

  /// True when this session caused a level-advancement (all challenges in the
  /// level were completed).  Shows a "Level N Unlocked!" callout when true.
  final bool levelAdvanced;

  bool get _passed => session.passed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _passed ? _passBackground : _failBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),

              // ── Icon ───────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _passed ? Icons.check_circle_rounded : Icons.close_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Headline ───────────────────────────────────────────────
              Text(
                _passed ? 'CHALLENGE COMPLETE!' : 'NOT QUITE...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 36,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _passed ? 'Great work! You hit ${session.shotsMade} of ${session.shotsToPass} required on-target shots.' : 'You hit ${session.shotsMade} on target — you needed ${session.shotsToPass}. Keep grinding!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 17,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // ── Level unlocked callout (only when level advanced) ──────
              if (levelAdvanced) ...[
                _buildLevelUnlockedBanner(context),
                const SizedBox(height: 16),
              ],

              // ── Stats card ─────────────────────────────────────────────
              _buildStatsCard(context),
              const SizedBox(height: 24),

              // ── CR shot counter ────────────────────────────────────────
              _buildCRProgress(context),
              const Spacer(),

              // ── Buttons ────────────────────────────────────────────────
              if (_passed) ...[
                _BackToRoadButton(onPressed: () => _backToRoad(context)),
              ] else ...[
                _TryAgainButton(onPressed: () => _tryAgain(context)),
                const SizedBox(height: 12),
                _BackToRoadButton(
                  onPressed: () => _backToRoad(context),
                  outline: true,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Level unlocked banner ─────────────────────────────────────────────────

  Widget _buildLevelUnlockedBanner(BuildContext context) {
    final newLevel = updatedAttempt.currentLevel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFF4A400)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_open_rounded, color: Colors.black87, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LEVEL UNLOCKED!',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Level $newLevel is now available on your Challenger Road.',
                  style: const TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Widget _buildStatsCard(BuildContext context) {
    final accuracy = session.totalShots > 0 ? ((session.shotsMade / session.totalShots) * 100).round() : 0;
    final mins = session.duration.inMinutes;
    final secs = session.duration.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Challenge + level
          Text(
            '${challenge.name}  •  LEVEL ${levelDoc.level}',
            style: const TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 16,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('${session.shotsMade} / ${session.shotsToPass}', 'ON TARGET'),
              _stat('${session.totalShots}', 'TOTAL SHOTS'),
              _stat('$accuracy%', 'ACCURACY'),
              _stat('${mins}m ${secs}s', 'TIME'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 10,
            letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  // ── CR Progress bar ───────────────────────────────────────────────────────

  Widget _buildCRProgress(BuildContext context) {
    final count = milestoneResult.newCount;
    final progress = (count / 10000).clamp(0.0, 1.0);
    final resetCount = milestoneResult.resetCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CHALLENGER ROAD SHOTS',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 12,
                letterSpacing: 1,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Text(
              '$count / 10,000',
              style: const TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        if (resetCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            '$resetCount\u00d7 10K completed this attempt',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _backToRoad(BuildContext context) {
    // Pop all the way back past the challenge screens and the detail sheet
    // to the root map, signalling that data needs to be reloaded.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _tryAgain(BuildContext context) {
    // Pop result + challenge screens back to the detail sheet.
    Navigator.of(context).pop(true);
  }

  // ── Theming ───────────────────────────────────────────────────────────────

  Color get _passBackground => const Color(0xFF1B5E20); // deep green
  Color get _failBackground => const Color(0xFFB71C1C); // deep red
}

// ── Button helpers ────────────────────────────────────────────────────────────

class _BackToRoadButton extends StatelessWidget {
  const _BackToRoadButton({required this.onPressed, this.outline = false});
  final VoidCallback onPressed;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    if (outline) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white54),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'BACK TO ROAD',
          style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Colors.white),
        ),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'BACK TO ROAD',
        style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Colors.black87),
      ),
    );
  }
}

class _TryAgainButton extends StatelessWidget {
  const _TryAgainButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade700,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'TRY AGAIN',
        style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Colors.white),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Shown when the player advances past the last currently-available level.
///
/// This is the "all challenges complete" edge case — admin hasn't published
/// Level N+1 content yet. The player should return to the map and wait for
/// new challenges to be added.
class ChallengerRoadAllClearScreen extends StatelessWidget {
  const ChallengerRoadAllClearScreen({
    super.key,
    required this.completedLevel,
  });

  /// The level that was just fully completed.
  final int completedLevel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A), // deep navy
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              // ── Trophy icon ─────────────────────────────────────────────
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFF4A400)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Headline ────────────────────────────────────────────────
              const Text(
                'YOU\'VE CONQUERED\nTHE ROAD!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 36,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),

              // ── Level badge ─────────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                  ),
                  child: Text(
                    'LEVEL $completedLevel COMPLETE',
                    style: const TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 16,
                      color: Color(0xFFFFD700),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Body copy ───────────────────────────────────────────────
              Text(
                "You've completed every available challenge on the Challenger Road. "
                "New challenges are coming soon. Keep grinding your regular sessions "
                "and check back for updates.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
              const Spacer(),

              // ── CTA ─────────────────────────────────────────────────────
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'BACK TO THE ROAD',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

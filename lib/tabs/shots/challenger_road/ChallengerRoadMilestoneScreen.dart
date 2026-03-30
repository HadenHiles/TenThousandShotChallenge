import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';

/// Full-screen 10,000 Challenger Road shots milestone celebration screen.
///
/// Shown from [StartChallengeScreen] when [ChallengerRoadMilestoneResult.didHitMilestone]
/// is true. The user taps "Keep Going!" to continue to the result screen.
///
/// Uses pure Flutter animations — no external Rive/Lottie dependency.
///
/// Usage:
/// ```dart
/// final continueToResult = await Navigator.of(context).push<bool>(
///   MaterialPageRoute(
///     builder: (_) => ChallengerRoadMilestoneScreen(result: milestoneResult),
///   ),
/// );
/// ```
class ChallengerRoadMilestoneScreen extends StatefulWidget {
  const ChallengerRoadMilestoneScreen({
    super.key,
    required this.result,
  });

  final ChallengerRoadMilestoneResult result;

  @override
  State<ChallengerRoadMilestoneScreen> createState() => _ChallengerRoadMilestoneScreenState();
}

class _ChallengerRoadMilestoneScreenState extends State<ChallengerRoadMilestoneScreen> with TickerProviderStateMixin {
  // ── Scale-in for the main icon ────────────────────────────────────────────
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  // ── Slide + fade for the headline ─────────────────────────────────────────
  late final AnimationController _textController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  // ── Pulsing glow ring ────────────────────────────────────────────────────
  late final AnimationController _pulseController;

  // ── Rings burst (expanding circles) ─────────────────────────────────────
  late final AnimationController _burstController;

  // ── Button fade-in ────────────────────────────────────────────────────────
  late final AnimationController _buttonController;
  late final Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _textController, curve: Curves.easeIn);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _buttonFade = CurvedAnimation(parent: _buttonController, curve: Curves.easeIn);

    // Sequence: icon pops in → burst → text fades in → button appears
    _scaleController.forward().then((_) {
      _burstController.forward();
      _textController.forward().then((_) => _buttonController.forward());
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    _burstController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final resetCount = widget.result.resetCount;
    final totalShots = resetCount * 10000;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14), // near-black
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),

              // ── Animated icon with glow & burst rings ─────────────────
              Expanded(
                flex: 3,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Burst expanding rings
                      AnimatedBuilder(
                        animation: _burstController,
                        builder: (_, __) => CustomPaint(
                          size: const Size(260, 260),
                          painter: _BurstRingsPainter(progress: _burstController.value),
                        ),
                      ),
                      // Pulsing glow ring
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, __) {
                          final glow = 0.3 + 0.5 * _pulseController.value;
                          return Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withValues(alpha: glow),
                                  blurRadius: 40 + 20 * _pulseController.value,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Scale-in main icon
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: const BoxDecoration(
                            gradient: RadialGradient(
                              colors: [Color(0xFFFFE066), Color(0xFFFFAA00)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sports_hockey_rounded,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Text block ─────────────────────────────────────────────
              Expanded(
                flex: 2,
                child: SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '10,000 SHOTS!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 44,
                            color: Color(0xFFFFD700),
                            letterSpacing: 1.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Challenger Road Milestone',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 20,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // ×N badge when they've hit it multiple times
                        if (resetCount > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '×$resetCount  –  ${_formatShots(totalShots)} Challenger Road shots',
                              style: const TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 15,
                                color: Color(0xFFFFD700),
                              ),
                            ),
                          ),
                        if (resetCount == 1) ...[
                          Text(
                            'First 10K on the Challenger Road!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── CTA ────────────────────────────────────────────────────
              FadeTransition(
                opacity: _buttonFade,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  ),
                  child: const Text(
                    'KEEP GOING!',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  String _formatShots(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

// ── Burst rings painter ────────────────────────────────────────────────────

/// Draws 3 rings that expand outward from the centre as [progress] goes 0→1.
class _BurstRingsPainter extends CustomPainter {
  final double progress;
  const _BurstRingsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    const maxRadius = 120.0;

    for (int i = 0; i < 3; i++) {
      final delay = i * 0.18;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final radius = maxRadius * t;
      final easedOpacity = math.pow(1 - t, 1.5).toDouble() * 0.6;

      final paint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: easedOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - t * 0.5);

      canvas.drawCircle(centre, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstRingsPainter old) => old.progress != progress;
}

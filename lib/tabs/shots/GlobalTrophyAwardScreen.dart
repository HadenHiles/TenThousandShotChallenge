import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/GlobalTrophyService.dart';

/// Full-screen badge award celebration shown after a session unlocks one or
/// more new global trophies.
///
/// Uses the plain icon badge design (no custom artwork) — the category icon is
/// always rendered in a radial gradient circle, distinguishing these from the
/// Challenger Road trophies that use bespoke badge images.
///
/// If [trophies] contains more than one trophy, the user pages through them
/// one at a time. Each badge has its own animated entrance.
///
/// Usage:
/// ```dart
/// await Navigator.of(context).push<void>(
///   MaterialPageRoute(
///     fullscreenDialog: true,
///     builder: (_) => GlobalTrophyAwardScreen(trophies: newTrophies),
///   ),
/// );
/// ```
class GlobalTrophyAwardScreen extends StatefulWidget {
  const GlobalTrophyAwardScreen({
    super.key,
    required this.trophies,
  });

  final List<GlobalTrophyDefinition> trophies;

  @override
  State<GlobalTrophyAwardScreen> createState() => _GlobalTrophyAwardScreenState();
}

class _GlobalTrophyAwardScreenState extends State<GlobalTrophyAwardScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  late AnimationController _pulseController;
  late AnimationController _burstController;

  late AnimationController _textController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  late AnimationController _buttonController;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _playEntrance();
  }

  void _initAnimations() {
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

    _burstController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_textController);

    _buttonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _buttonFade = Tween<double>(begin: 0, end: 1).animate(_buttonController);
  }

  void _playEntrance() {
    _scaleController.reset();
    _burstController.reset();
    _textController.reset();
    _buttonController.reset();

    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _burstController.forward();
    });
    Future.delayed(const Duration(milliseconds: 340), () {
      if (mounted) _textController.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _buttonController.forward();
    });
  }

  void _advance() {
    if (_currentIndex < widget.trophies.length - 1) {
      setState(() => _currentIndex++);
      _playEntrance();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    _burstController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.trophies[_currentIndex];
    final color = GlobalTrophyService.colorForTrophy(def);
    final icon = GlobalTrophyService.iconForTrophy(def);
    final isLast = _currentIndex == widget.trophies.length - 1;
    final total = widget.trophies.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Radial glow background ─────────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => CustomPaint(
                  painter: _GlowBackgroundPainter(color: color, progress: _pulseController.value),
                ),
              ),
            ),

            // ── Particle burst ─────────────────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _burstController,
                builder: (_, __) => CustomPaint(
                  painter: _ParticleBurstPainter(color: color, progress: _burstController.value),
                ),
              ),
            ),

            // ── Main content ───────────────────────────────────────────────
            Column(
              children: [
                // Badge counter
                if (total > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Text(
                        '${_currentIndex + 1} / $total',
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),

                const Spacer(),

                // ── Badge icon (plain icon style) ──────────────────────────
                ScaleTransition(
                  scale: _scaleAnim,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) {
                      final pulse = 0.92 + 0.08 * _pulseController.value;
                      return Container(
                        width: 160 * pulse,
                        height: 160 * pulse,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              color.withValues(alpha: 0.85),
                              color.withValues(alpha: 0.45),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.55 + 0.2 * _pulseController.value),
                              blurRadius: 40 + 20 * _pulseController.value,
                              spreadRadius: 8 + 6 * _pulseController.value,
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 72, color: Colors.white),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 36),

                // ── Text block ─────────────────────────────────────────────
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
                            ),
                            child: Text(
                              'TROPHY UNLOCKED',
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 13,
                                color: color,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            def.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 34,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            GlobalTrophyService.tierLabel(def.tier).toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 13,
                              color: color.withValues(alpha: 0.85),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            def.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ── CTA button ─────────────────────────────────────────────
                FadeTransition(
                  opacity: _buttonFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _advance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor: color.withValues(alpha: 0.6),
                        ),
                        child: Text(
                          isLast ? "LET'S KEEP GOING" : 'NEXT TROPHY',
                          style: const TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 20,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painters (identical to ChallengerRoadTrophyAwardScreen) ──────────────────

class _GlowBackgroundPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _GlowBackgroundPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * (0.55 + 0.08 * progress);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.18 + 0.07 * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GlowBackgroundPainter old) => old.progress != progress || old.color != color;
}

class _ParticleBurstPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _ParticleBurstPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint()..color = color.withValues(alpha: (1 - progress) * 0.7);
    const count = 16;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      final dist = size.width * 0.28 * progress;
      final pos = Offset(
        center.dx + dist * math.cos(angle),
        center.dy + dist * math.sin(angle),
      );
      canvas.drawCircle(pos, (4 - 3 * progress).clamp(0.5, 4), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter old) => old.progress != progress || old.color != color;
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';

/// Full-screen badge award celebration shown after a Challenger Road session
/// unlocks one or more new badges.
///
/// If [badges] contains more than one badge, the user pages through them
/// one at a time. Each badge has its own animated entrance.
///
/// Usage:
/// ```dart
/// await Navigator.of(context).push<void>(
///   MaterialPageRoute(
///     fullscreenDialog: true,
///     builder: (_) => ChallengerRoadBadgeAwardScreen(badges: newBadges),
///   ),
/// );
/// ```
class ChallengerRoadBadgeAwardScreen extends StatefulWidget {
  const ChallengerRoadBadgeAwardScreen({
    super.key,
    required this.badges,
  });

  final List<ChallengerRoadBadgeDefinition> badges;

  @override
  State<ChallengerRoadBadgeAwardScreen> createState() => _ChallengerRoadBadgeAwardScreenState();
}

class _ChallengerRoadBadgeAwardScreenState extends State<ChallengerRoadBadgeAwardScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;

  // ── Per-badge entrance: scale-in icon ─────────────────────────────────────
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;
  late Animation<double> _scaleOvershoot;

  // ── Glow pulse ────────────────────────────────────────────────────────────
  late AnimationController _pulseController;

  // ── Particle burst (orbiting flecks) ─────────────────────────────────────
  late AnimationController _burstController;

  // ── Text slide-up + fade ──────────────────────────────────────────────────
  late AnimationController _textController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  // ── Button fade-in ────────────────────────────────────────────────────────
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
    _scaleOvershoot = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_scaleOvershoot);

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

    _burstController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));
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
    if (_currentIndex < widget.badges.length - 1) {
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _badgeColor(ChallengerRoadBadgeDefinition def) {
    switch (def.tier) {
      case ChallengerRoadBadgeTier.legendary:
        return const Color(0xFFFFD700);
      case ChallengerRoadBadgeTier.epic:
        return const Color(0xFFAB47BC);
      case ChallengerRoadBadgeTier.rare:
        return const Color(0xFF42A5F5);
      case ChallengerRoadBadgeTier.uncommon:
        return const Color(0xFF66BB6A);
      case ChallengerRoadBadgeTier.hidden:
        return const Color(0xFF78909C);
      case ChallengerRoadBadgeTier.common:
        return const Color(0xFF90A4AE);
    }
  }

  IconData _badgeIcon(ChallengerRoadBadgeDefinition def) {
    return ChallengerRoadService.iconForBadge(def);
  }

  String _tierLabel(ChallengerRoadBadgeTier tier) {
    switch (tier) {
      case ChallengerRoadBadgeTier.legendary:
        return 'LEGENDARY';
      case ChallengerRoadBadgeTier.epic:
        return 'EPIC';
      case ChallengerRoadBadgeTier.rare:
        return 'RARE';
      case ChallengerRoadBadgeTier.uncommon:
        return 'UNCOMMON';
      case ChallengerRoadBadgeTier.hidden:
        return 'SECRET';
      case ChallengerRoadBadgeTier.common:
        return 'COMMON';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final def = widget.badges[_currentIndex];
    final color = _badgeColor(def);
    final isLast = _currentIndex == widget.badges.length - 1;
    final total = widget.badges.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Radial glow background ───────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => CustomPaint(
                  painter: _GlowBackgroundPainter(
                    color: color,
                    progress: _pulseController.value,
                  ),
                ),
              ),
            ),

            // ── Particle burst ───────────────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _burstController,
                builder: (_, __) => CustomPaint(
                  painter: _ParticleBurstPainter(
                    color: color,
                    progress: _burstController.value,
                  ),
                ),
              ),
            ),

            // ── Main content ─────────────────────────────────────────────
            Column(
              children: [
                // Badge counter (top right)
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

                // ── Badge icon ───────────────────────────────────────────
                ScaleTransition(
                  scale: _scaleAnim,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) {
                      final pulse = 0.92 + 0.08 * _pulseController.value;
                      return Container(
                        width: 140 * pulse,
                        height: 140 * pulse,
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
                        child: Icon(
                          _badgeIcon(def),
                          size: 68,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 36),

                // ── Text block ───────────────────────────────────────────
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          // "BADGE UNLOCKED"
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
                            ),
                            child: Text(
                              'BADGE UNLOCKED',
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 13,
                                color: color,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Badge name
                          Text(
                            def.effectiveName.toUpperCase(),
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

                          // Tier chip
                          Text(
                            _tierLabel(def.tier),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 13,
                              color: color.withValues(alpha: 0.85),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Description
                          Text(
                            def.effectiveDescription,
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

                // ── CTA button ───────────────────────────────────────────
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
                          isLast ? "LET'S KEEP GOING" : 'NEXT BADGE',
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

// ── Painters ──────────────────────────────────────────────────────────────────

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

  static const int _particleCount = 18;

  const _ParticleBurstPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height * 0.42);
    final rng = math.Random(42); // fixed seed so flecks don't jump

    for (int i = 0; i < _particleCount; i++) {
      final angle = (i / _particleCount) * math.pi * 2 + rng.nextDouble() * 0.4;
      final speed = 80.0 + rng.nextDouble() * 100.0;
      final dx = math.cos(angle) * speed * progress;
      final dy = math.sin(angle) * speed * progress;

      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final radius = (3.0 + rng.nextDouble() * 4.0) * (1 - progress * 0.4);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.85)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center + Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter old) => old.progress != progress || old.color != color;
}

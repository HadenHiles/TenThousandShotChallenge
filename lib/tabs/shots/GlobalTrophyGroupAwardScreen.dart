import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/GlobalTrophyService.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal data model
// ─────────────────────────────────────────────────────────────────────────────

class _TierGroup {
  final GlobalTrophyTier tier;
  final List<GlobalTrophyDefinition> trophies;

  const _TierGroup(this.tier, this.trophies);

  Color get color => GlobalTrophyService.colorForTrophy(trophies.first);
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen award celebration shown after a user claims historically-earned
/// trophies via the backfill flow.
///
/// Trophies are grouped by rarity tier (common → uncommon → rare → epic →
/// legendary) and presented one group at a time. Each group has its own
/// animated entrance and uses the tier's colour for the glow/accents.
///
/// Usage:
/// ```dart
/// await Navigator.of(context).push<void>(
///   MaterialPageRoute(
///     fullscreenDialog: true,
///     builder: (_) => GlobalTrophyGroupAwardScreen(trophies: earnedTrophies),
///   ),
/// );
/// ```
class GlobalTrophyGroupAwardScreen extends StatefulWidget {
  const GlobalTrophyGroupAwardScreen({
    super.key,
    required this.trophies,
  });

  final List<GlobalTrophyDefinition> trophies;

  @override
  State<GlobalTrophyGroupAwardScreen> createState() => _GlobalTrophyGroupAwardScreenState();
}

class _GlobalTrophyGroupAwardScreenState extends State<GlobalTrophyGroupAwardScreen> with TickerProviderStateMixin {
  // Tier order: easiest → hardest (mirrors how the user "levelled up")
  static const _tierOrder = [
    GlobalTrophyTier.common,
    GlobalTrophyTier.uncommon,
    GlobalTrophyTier.rare,
    GlobalTrophyTier.epic,
    GlobalTrophyTier.legendary,
  ];

  late final List<_TierGroup> _groups;
  int _groupIndex = 0;

  late AnimationController _glowController;
  late AnimationController _burstController;
  late AnimationController _contentController;
  late AnimationController _buttonController;

  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    _groups = _tierOrder.map((t) => _TierGroup(t, widget.trophies.where((d) => d.tier == t).toList())).where((g) => g.trophies.isNotEmpty).toList();

    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

    _burstController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _contentController = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    _buttonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _buttonFade = Tween<double>(begin: 0, end: 1).animate(_buttonController);

    _playEntrance();
  }

  void _playEntrance() {
    _burstController.reset();
    _contentController.reset();
    _buttonController.reset();

    _burstController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _contentController.forward();
    });
    Future.delayed(const Duration(milliseconds: 860), () {
      if (mounted) _buttonController.forward();
    });
  }

  void _advance() {
    if (_groupIndex < _groups.length - 1) {
      setState(() => _groupIndex++);
      _playEntrance();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _burstController.dispose();
    _contentController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = _groups[_groupIndex];
    final color = group.color;
    final isLast = _groupIndex == _groups.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Pulsing radial glow ────────────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (_, __) => CustomPaint(
                  painter: _GlowBackgroundPainter(
                    color: color,
                    progress: _glowController.value,
                  ),
                ),
              ),
            ),

            // ── Particle burst on entrance ─────────────────────────────────
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

            // ── Main column ────────────────────────────────────────────────
            Column(
              children: [
                // ── Progress pips + counter ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      ...List.generate(_groups.length, (i) {
                        final active = i == _groupIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 5),
                          width: active ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? color : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                      const Spacer(),
                      if (_groups.length > 1)
                        Text(
                          '${_groupIndex + 1} / ${_groups.length}',
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.45),
                            letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Animated group content ─────────────────────────────────
                Expanded(
                  child: SlideTransition(
                    position: _contentSlide,
                    child: FadeTransition(
                      opacity: _contentFade,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Column(
                          children: [
                            // Tier badge pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 13, color: color),
                                  const SizedBox(width: 6),
                                  Text(
                                    GlobalTrophyService.tierLabel(group.tier).toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      fontSize: 13,
                                      color: color,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              '${group.trophies.length} '
                              '${group.trophies.length == 1 ? 'TROPHY' : 'TROPHIES'} UNLOCKED',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 28,
                                color: Colors.white,
                                letterSpacing: 1,
                                height: 1.1,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Trophy wrap grid
                            Wrap(
                              spacing: 14,
                              runSpacing: 22,
                              alignment: WrapAlignment.center,
                              children: group.trophies
                                  .map((def) => _TrophyCell(
                                        def: def,
                                        color: color,
                                      ))
                                  .toList(),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── CTA ────────────────────────────────────────────────────
                FadeTransition(
                  opacity: _buttonFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
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
                          isLast ? "LET'S KEEP GOING" : 'NEXT GROUP',
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

// ─────────────────────────────────────────────────────────────────────────────
// Trophy cell widget
// ─────────────────────────────────────────────────────────────────────────────

class _TrophyCell extends StatelessWidget {
  const _TrophyCell({required this.def, required this.color});

  final GlobalTrophyDefinition def;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = GlobalTrophyService.iconForTrophy(def);
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.80),
                  color.withValues(alpha: 0.35),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.40),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: def.effectiveIconUrl != null
                ? ClipOval(
                    child: Image.network(
                      def.effectiveIconUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(icon, size: 32, color: Colors.white),
                    ),
                  )
                : Icon(icon, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            def.effectiveName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 12,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

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
    final center = Offset(size.width / 2, size.height * 0.38);
    final paint = Paint()..color = color.withValues(alpha: (1 - progress) * 0.65);
    const count = 20;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      final dist = size.width * 0.38 * progress;
      final pos = Offset(
        center.dx + dist * math.cos(angle),
        center.dy + dist * math.sin(angle),
      );
      canvas.drawCircle(pos, (4.5 - 3.5 * progress).clamp(0.5, 4.5), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter old) => old.progress != progress || old.color != color;
}

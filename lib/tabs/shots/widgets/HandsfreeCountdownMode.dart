import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';

/// Full-screen hands-free countdown mode.
///
/// At each interval the widget logs one puck-set as a [Shots] entry via
/// [onShotAdded], firing haptic feedback and a visual pulse.
///
/// Speed is expressed as shots-per-minute (1–60 spm).  The countdown circle
/// drains over the full interval between shots.
class HandsfreeCountdownMode extends StatefulWidget {
  const HandsfreeCountdownMode({
    super.key,
    required this.shotCount,
    required this.shotType,
    required this.onShotAdded,
    required this.onExit,
  });

  /// Number of pucks per set (the current puck-count value).
  final int shotCount;

  /// Shot type string, e.g. 'wrist', 'snap', 'slap', 'backhand'.
  final String shotType;

  /// Called each time a set is automatically logged.
  final void Function(Shots shot) onShotAdded;

  /// Called when the user exits hands-free mode.
  final VoidCallback onExit;

  @override
  State<HandsfreeCountdownMode> createState() => _HandsfreeCountdownModeState();
}

class _HandsfreeCountdownModeState extends State<HandsfreeCountdownMode> with SingleTickerProviderStateMixin {
  // ── Speed / timing ──────────────────────────────────────────────────────
  /// Shots per minute (1–60).
  double _shotsPerMinute = 15;

  Duration get _interval => Duration(milliseconds: (60000 / _shotsPerMinute).round());

  // ── State ────────────────────────────────────────────────────────────────
  bool _running = false;
  int _setsLogged = 0;
  int _countdownSecondsLeft = 0;

  Timer? _countdownTimer;
  Timer? _shotTimer;

  // ── Animation ────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Arc sweep that drains from 1 → 0 over each interval
  double _arcProgress = 1.0;
  Timer? _arcTimer;
  DateTime? _lastShotTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _countdownSecondsLeft = _interval.inSeconds;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shotTimer?.cancel();
    _arcTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Control ──────────────────────────────────────────────────────────────

  void _start() {
    setState(() {
      _running = true;
      _countdownSecondsLeft = _interval.inSeconds;
      _arcProgress = 1.0;
    });
    _lastShotTime = DateTime.now();
    _scheduleShotTimer();
    _startCountdownTick();
    _startArcUpdate();
  }

  void _pause() {
    _countdownTimer?.cancel();
    _shotTimer?.cancel();
    _arcTimer?.cancel();
    setState(() => _running = false);
  }

  void _resume() {
    setState(() {
      _running = true;
      _countdownSecondsLeft = _interval.inSeconds;
      _arcProgress = 1.0;
    });
    _lastShotTime = DateTime.now();
    _scheduleShotTimer();
    _startCountdownTick();
    _startArcUpdate();
  }

  /// Fires every second to update the countdown label.
  void _startCountdownTick() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdownSecondsLeft = max(0, _countdownSecondsLeft - 1);
      });
    });
  }

  /// Smooth arc drain — updates ~30 fps.
  void _startArcUpdate() {
    _arcTimer?.cancel();
    _arcTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || _lastShotTime == null) return;
      final elapsed = DateTime.now().difference(_lastShotTime!);
      final progress = 1.0 - (elapsed.inMilliseconds / _interval.inMilliseconds).clamp(0.0, 1.0);
      setState(() => _arcProgress = progress);
    });
  }

  /// Schedule the actual shot-logging timer.
  void _scheduleShotTimer() {
    _shotTimer?.cancel();
    _shotTimer = Timer(_interval, _onShot);
  }

  void _onShot() {
    if (!mounted || !_running) return;

    // Haptic + visual pulse
    HapticFeedback.heavyImpact();
    _pulseController.forward(from: 0).then((_) => _pulseController.reverse());

    final shot = Shots(DateTime.now(), widget.shotType, widget.shotCount, null);
    widget.onShotAdded(shot);

    setState(() {
      _setsLogged++;
      _countdownSecondsLeft = _interval.inSeconds;
      _arcProgress = 1.0;
    });

    _lastShotTime = DateTime.now();
    _scheduleShotTimer();
  }

  // ── Speed change — restart timers ─────────────────────────────────────
  void _onSpeedChanged(double value) {
    setState(() => _shotsPerMinute = value);
    if (_running) {
      _countdownTimer?.cancel();
      _shotTimer?.cancel();
      _arcTimer?.cancel();
      setState(() {
        _countdownSecondsLeft = _interval.inSeconds;
        _arcProgress = 1.0;
      });
      _lastShotTime = DateTime.now();
      _scheduleShotTimer();
      _startCountdownTick();
      _startArcUpdate();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalShots = _setsLogged * widget.shotCount;
    final intervalSec = _interval.inSeconds;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _pause();
                      widget.onExit();
                    },
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hands-Free Mode'.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatChip(label: 'SETS', value: '$_setsLogged'),
                  _StatChip(label: 'SHOTS', value: '$totalShots'),
                  _StatChip(
                    label: 'TYPE',
                    value: widget.shotType[0].toUpperCase() + widget.shotType.substring(1),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Countdown circle ─────────────────────────────────────────
            ScaleTransition(
              scale: _pulseAnimation,
              child: SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _ArcPainter(
                    progress: _arcProgress,
                    color: _running ? theme.primaryColor : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _running ? '$_countdownSecondsLeft' : '–',
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _running ? 'sec' : 'paused',
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 18,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // ── Speed slider ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Speed'.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        '${_shotsPerMinute.round()} sets/min   ($intervalSec sec/set)',
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _shotsPerMinute,
                    min: 1,
                    max: 60,
                    divisions: 59,
                    activeColor: theme.primaryColor,
                    thumbColor: theme.primaryColor,
                    label: '${_shotsPerMinute.round()} spm',
                    onChanged: _onSpeedChanged,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Slow (1/min)', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      Text('Fast (60/min)', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Start / Pause / Resume button ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _running ? Colors.orange : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    if (_running) {
                      _pause();
                    } else if (_setsLogged == 0) {
                      _start();
                    } else {
                      _resume();
                    }
                  },
                  child: Text(_running ? 'PAUSE' : (_setsLogged == 0 ? 'START' : 'RESUME')),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Puck count hint ──────────────────────────────────────────
            Text(
              '${widget.shotCount} pucks per set · ${widget.shotType} shot',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontFamily: 'NovecentoSans',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Track
    canvas.drawCircle(center, radius, trackPaint);

    // Arc (drains clockwise from top)
    final sweepAngle = -2 * pi * (1.0 - progress);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      -sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress || old.color != color;
}

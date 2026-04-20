import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';

/// Full-screen hands-free metronome mode.
///
/// Plays an audible beep at a configurable interval (seconds per shot).
/// The user shoots in rhythm with each beep.  After [shotCount] beeps the
/// set is automatically logged via [onShotAdded] and the screen exits.
///
/// Maximum speed: 1 shot every 0.5 seconds.
class HandsfreeCountdownMode extends StatefulWidget {
  const HandsfreeCountdownMode({
    super.key,
    required this.shotCount,
    required this.shotType,
    required this.onShotAdded,
    required this.onExit,
  });

  /// Number of pucks per set (auto-stop target).
  final int shotCount;

  /// Shot type string, e.g. 'wrist', 'snap', 'slap', 'backhand'.
  final String shotType;

  /// Called once when the full set is completed.
  final void Function(Shots shot) onShotAdded;

  /// Called when the user exits or the set completes.
  final VoidCallback onExit;

  @override
  State<HandsfreeCountdownMode> createState() => _HandsfreeCountdownModeState();
}

class _HandsfreeCountdownModeState extends State<HandsfreeCountdownMode> with SingleTickerProviderStateMixin {
  // ── Speed / timing ──────────────────────────────────────────────────────
  /// Seconds between each shot beat (0.5 – 10.0).
  double _secondsPerShot = 2.0;

  Duration get _interval => Duration(milliseconds: (_secondsPerShot * 1000).round());

  // ── State ────────────────────────────────────────────────────────────────
  bool _running = false;
  bool _completed = false;
  int _shotsFired = 0; // individual shots completed in the current set

  Timer? _shotTimer;

  // ── Animation ────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Arc sweep that drains from 1 → 0 over each interval
  double _arcProgress = 1.0;
  Timer? _arcTimer;
  DateTime? _lastShotTime;

  // ── Audio ─────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  late Uint8List _beepWavBytes;

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
    _beepWavBytes = _generateBeepWav();
    // Allow audio to play alongside other apps, and override the iOS silent switch.
    _audioPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shotTimer?.cancel();
    _arcTimer?.cancel();
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Control ──────────────────────────────────────────────────────────────

  void _start() {
    setState(() {
      _running = true;
      _completed = false;
      _shotsFired = 0;
      _arcProgress = 1.0;
    });
    _lastShotTime = DateTime.now();
    _scheduleShotTimer();
    _startArcUpdate();
  }

  void _pause() {
    _shotTimer?.cancel();
    _arcTimer?.cancel();
    setState(() => _running = false);
  }

  void _resume() {
    setState(() {
      _running = true;
      _arcProgress = 1.0;
    });
    _lastShotTime = DateTime.now();
    _scheduleShotTimer();
    _startArcUpdate();
  }

  /// Smooth arc drain - updates ~30 fps.
  void _startArcUpdate() {
    _arcTimer?.cancel();
    _arcTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || _lastShotTime == null) return;
      final elapsed = DateTime.now().difference(_lastShotTime!);
      final progress = 1.0 - (elapsed.inMilliseconds / _interval.inMilliseconds).clamp(0.0, 1.0);
      setState(() => _arcProgress = progress);
    });
  }

  void _scheduleShotTimer() {
    _shotTimer?.cancel();
    _shotTimer = Timer(_interval, _onShot);
  }

  void _onShot() {
    if (!mounted || !_running) return;

    // Sound + haptic + visual pulse
    _audioPlayer.play(BytesSource(_beepWavBytes));
    HapticFeedback.heavyImpact();
    _pulseController.forward(from: 0).then((_) => _pulseController.reverse());

    final newCount = _shotsFired + 1;
    setState(() {
      _shotsFired = newCount;
      _arcProgress = 1.0;
    });
    _lastShotTime = DateTime.now();

    if (newCount >= widget.shotCount) {
      _completeSet();
    } else {
      _scheduleShotTimer();
    }
  }

  void _completeSet() {
    _shotTimer?.cancel();
    _arcTimer?.cancel();

    final shot = Shots(DateTime.now(), widget.shotType, widget.shotCount, null);
    widget.onShotAdded(shot);

    setState(() {
      _running = false;
      _completed = true;
    });

    // Triple haptic burst for completion
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) HapticFeedback.heavyImpact();
      });
    });

    // Auto-exit after brief celebration display
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onExit();
    });
  }

  void _onSpeedChanged(double value) {
    setState(() => _secondsPerShot = value);
    if (_running) {
      _shotTimer?.cancel();
      _arcTimer?.cancel();
      setState(() => _arcProgress = 1.0);
      _lastShotTime = DateTime.now();
      _scheduleShotTimer();
      _startArcUpdate();
    }
  }

  // ── WAV generator ─────────────────────────────────────────────────────
  /// Generates a short 880 Hz sine-wave beep as raw WAV bytes.
  /// No asset file required - the sound is synthesised at runtime.
  static Uint8List _generateBeepWav({
    int frequency = 880,
    int durationMs = 70,
    int sampleRate = 44100,
  }) {
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final byteCount = 44 + sampleCount * 2;
    final buffer = ByteData(byteCount);

    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    // RIFF header
    writeAscii(0, 'RIFF');
    buffer.setUint32(4, byteCount - 8, Endian.little);
    writeAscii(8, 'WAVE');
    // fmt chunk
    writeAscii(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little); // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    writeAscii(36, 'data');
    buffer.setUint32(40, sampleCount * 2, Endian.little);
    // PCM samples - 880 Hz sine wave with square-root fade out
    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final envelope = sqrt(1.0 - i / sampleCount);
      final sample = (sin(2 * pi * frequency * t) * envelope * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }
    return buffer.buffer.asUint8List();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _completed ? _buildCompletionView(theme) : _buildActiveView(theme),
      ),
    );
  }

  Widget _buildCompletionView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 90, color: Colors.green.shade400),
          const SizedBox(height: 20),
          Text(
            'SET COMPLETE!',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${widget.shotCount} ${widget.shotType} shots logged',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(ThemeData theme) {
    return Column(
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
              _StatChip(label: 'PUCKS', value: '$_shotsFired'),
              _StatChip(label: 'GOAL', value: '${widget.shotCount}'),
              _StatChip(
                label: 'TYPE',
                value: widget.shotType[0].toUpperCase() + widget.shotType.substring(1),
              ),
            ],
          ),
        ),

        const Spacer(),

        // ── Arc circle - progress display ─────────────────────────────
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
                      '$_shotsFired',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _running ? '/ ${widget.shotCount}' : (_shotsFired > 0 ? '/ ${widget.shotCount}' : 'ready'),
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
                    'Rhythm'.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    '${_secondsPerShot.toStringAsFixed(1)} sec / shot',
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
                value: _secondsPerShot,
                min: 0.5,
                max: 10.0,
                divisions: 19,
                activeColor: theme.primaryColor,
                thumbColor: theme.primaryColor,
                label: '${_secondsPerShot.toStringAsFixed(1)}s',
                onChanged: _onSpeedChanged,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fast (0.5s)', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                  Text('Slow (10s)', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
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
                } else if (_shotsFired == 0) {
                  _start();
                } else {
                  _resume();
                }
              },
              child: Text(_running ? 'PAUSE' : (_shotsFired == 0 ? 'START' : 'RESUME')),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Puck count hint ──────────────────────────────────────────
        Text(
          '${widget.shotCount} pucks · ${widget.shotType} shot · beeps every ${_secondsPerShot.toStringAsFixed(1)}s',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontFamily: 'NovecentoSans',
          ),
        ),
        const SizedBox(height: 24),
      ],
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

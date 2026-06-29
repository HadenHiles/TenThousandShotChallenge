import 'package:audioplayers/audioplayers.dart';
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
class ChallengeDetailSheet extends StatefulWidget {
  final ChallengerRoadChallenge challenge;
  final ChallengerRoadLevel levelDoc;
  final ChallengerRoadAttempt attempt;
  final String userId;
  final ChallengeProgressEntry? progress;
  final VoidCallback? onSessionComplete;
  final bool isPreviewMode;
  final int previewMaxLevel;
  final VoidCallback? onPreviewLevelUnlockAttempted;
  final bool showStartCta;

  /// When true the challenge is locked because the user's subscription has
  /// lapsed (preview mode, level > previewMaxLevel). In this state the sheet
  /// shows the try history but hides steps and replaces the CTA with an
  /// "Upgrade to Pro" prompt.
  final bool isSubscriptionLocked;

  const ChallengeDetailSheet._({
    required this.challenge,
    required this.levelDoc,
    required this.attempt,
    required this.userId,
    this.progress,
    this.onSessionComplete,
    this.isPreviewMode = false,
    this.previewMaxLevel = 1,
    this.onPreviewLevelUnlockAttempted,
    this.showStartCta = true,
    this.isSubscriptionLocked = false,
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
    bool isPreviewMode = false,
    int previewMaxLevel = 1,
    VoidCallback? onPreviewLevelUnlockAttempted,
    bool showStartCta = true,
    bool isSubscriptionLocked = false,
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
        isPreviewMode: isPreviewMode,
        previewMaxLevel: previewMaxLevel,
        onPreviewLevelUnlockAttempted: onPreviewLevelUnlockAttempted,
        showStartCta: showStartCta,
        isSubscriptionLocked: isSubscriptionLocked,
      ),
    );
  }

  @override
  State<ChallengeDetailSheet> createState() => _ChallengeDetailSheetState();
}

class _ChallengeDetailSheetState extends State<ChallengeDetailSheet> {
  // ── Audio state ─────────────────────────────────────────────────────────
  AudioPlayer? _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _audioLoading = false;
  bool _audioError = false;

  // ── State helpers ───────────────────────────────────────────────────────────────────

  bool get _isPassed {
    return (widget.progress?.bestLevel ?? 0) >= widget.levelDoc.level;
  }

  bool get _isLocked {
    final effectiveLevel = widget.isPreviewMode
        ? (widget.attempt.currentLevel < widget.previewMaxLevel ? widget.attempt.currentLevel : widget.previewMaxLevel)
        : widget.attempt.currentLevel;
    return widget.levelDoc.level > effectiveLevel;
  }

  /// Steps to show: level-specific override if present, else parent challenge steps.
  List<ChallengeStep> get _steps {
    final levelSteps = widget.levelDoc.steps;
    if (levelSteps != null && levelSteps.isNotEmpty) return levelSteps;
    return widget.challenge.steps;
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.challenge.audioUrl != null) _initAudio();
  }

  @override
  void dispose() {
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // ── Audio ──────────────────────────────────────────────────────────────────────────────

  Future<void> _initAudio() async {
    if (!mounted) return;
    setState(() {
      _audioLoading = true;
      _audioError = false;
    });
    try {
      final player = AudioPlayer();
      await player.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
      player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _playerState = s);
      });
      player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _position = Duration.zero);
      });
      await player.setSourceUrl(widget.challenge.audioUrl!);
      _audioPlayer = player;
      if (mounted) setState(() => _audioLoading = false);
    } catch (_) {
      if (mounted) setState(() { _audioLoading = false; _audioError = true; });
    }
  }

  Future<void> _togglePlayback() async {
    final player = _audioPlayer;
    if (player == null) return;
    if (_playerState == PlayerState.playing) {
      await player.pause();
    } else {
      await player.resume();
    }
  }

  Future<void> _seekTo(double fraction) async {
    final player = _audioPlayer;
    if (player == null || _duration == Duration.zero) return;
    await player.seek(Duration(milliseconds: (_duration.inMilliseconds * fraction).round()));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ────────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initialSize = widget.isSubscriptionLocked ? 0.6 : (widget.showStartCta ? 0.9 : 0.5);
    final minSize = widget.isSubscriptionLocked ? 0.4 : (widget.showStartCta ? 0.5 : 0.4);

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
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
              // ── Drag handle ──────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Scrollable content ─────────────────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    // ── Header row ────────────────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _isLocked ? Colors.grey.shade600 : Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'LVL ${widget.levelDoc.level}',
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
                            widget.challenge.name,
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

                    // ── Description ─────────────────────────────────────────────────────
                    Text(
                      widget.challenge.description,
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Audio player (shown when audio_url is present) ──────────────────
                    if (!_audioError && widget.challenge.audioUrl != null) ...[
                      _buildAudioPlayer(context),
                      const SizedBox(height: 12),
                    ],

                    // ── Quota card ───────────────────────────────────────────────────────
                    _buildQuotaCard(context),
                    const SizedBox(height: 12),

                    // ── Try history link ────────────────────────────────────────────────
                    _buildHistoryLink(context),

                    const SizedBox(height: 20),

                    // ── Steps section ──────────────────────────────────────────────────────
                    if (widget.isSubscriptionLocked) ...[
                      _buildSubscriptionLockedBanner(context)
                    ] else ...[
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
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Pinned CTA footer ─────────────────────────────────────────────────
              if (widget.isSubscriptionLocked || widget.showStartCta) _buildCTA(context),
            ],
          ),
        );
      },
    );
  }

  // ── Audio player UI ───────────────────────────────────────────────────────────────────────

  Widget _buildAudioPlayer(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Play / pause
          _audioLoading
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _togglePlayback,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                ),
          // Position
          Text(
            _formatDuration(_position),
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          // Scrubber
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                thumbColor: Theme.of(context).primaryColor,
                overlayColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: progress.toDouble(),
                onChanged: _audioLoading ? null : _seekTo,
              ),
            ),
          ),
          // Total duration
          Text(
            _formatDuration(_duration),
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quota info card ───────────────────────────────────────────────────────────────────

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
          _quotaStat(context, '${widget.levelDoc.shotsRequired}', 'SHOTS / TRY'),
          Container(width: 1, height: 32, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          _quotaStat(context, '${widget.levelDoc.shotsToPass}', 'TARGET SCORE'),
          Container(width: 1, height: 32, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          _quotaStat(
            context,
            widget.progress != null ? '${widget.progress!.totalAttempts}' : '–',
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

  // ── Try history link ───────────────────────────────────────────────────────────────────────────

  Widget _buildHistoryLink(BuildContext context) {
    final tryCount = widget.progress?.totalAttempts ?? 0;
    final passCount = widget.progress?.totalPassed ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        ChallengeTriesHistorySheet.show(
          context,
          challenge: widget.challenge,
          levelDoc: widget.levelDoc,
          userId: widget.userId,
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
                '$tryCount ${tryCount == 1 ? "TRY" : "TRIES"} LOGGED  ·  $passCount MET TARGET',
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

  // ── Subscription-locked banner ────────────────────────────────────────────────────────────────

  Widget _buildSubscriptionLockedBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Subscribe to Pro to view steps and play this challenge.',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA button ──────────────────────────────────────────────────────────────────────────────────

  Widget _buildCTA(BuildContext context) {
    final String label;
    final bool enabled;
    final Color bgColor;
    VoidCallback? onPressed;

    if (widget.isSubscriptionLocked) {
      label = 'Upgrade to Pro to Play';
      enabled = widget.onPreviewLevelUnlockAttempted != null;
      bgColor = Theme.of(context).primaryColor;
      onPressed = enabled
          ? () {
              Navigator.of(context).pop();
              widget.onPreviewLevelUnlockAttempted?.call();
            }
          : null;
    } else if (_isLocked) {
      label = 'Complete Level ${widget.attempt.currentLevel} First';
      enabled = false;
      bgColor = Colors.grey.shade600;
      onPressed = null;
    } else if (_isPassed) {
      label = 'Retry Challenge';
      enabled = true;
      bgColor = Colors.indigo.shade600;
      onPressed = () => _launchChallenge(context);
    } else {
      label = 'Start Challenge';
      enabled = true;
      bgColor = Theme.of(context).primaryColor;
      onPressed = () => _launchChallenge(context);
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
            onPressed: onPressed,
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
    Navigator.of(context).pop();
    activeChallengeSession.value = ChallengeSessionConfig(
      challenge: widget.challenge,
      levelDoc: widget.levelDoc,
      attempt: widget.attempt,
      userId: widget.userId,
      startedAt: DateTime.now(),
      onSessionComplete: widget.onSessionComplete,
      isPreviewMode: widget.isPreviewMode,
      previewMaxLevel: widget.previewMaxLevel,
      onPreviewLevelUnlockAttempted: widget.onPreviewLevelUnlockAttempted,
    );
    sessionPanelController.open();
  }
}

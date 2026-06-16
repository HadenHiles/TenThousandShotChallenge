import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeStep.dart';
import 'package:video_player/video_player.dart';

/// Full-screen, swipeable step viewer for Challenger Road challenges.
///
/// Adapts layout for portrait and landscape orientations without forcing
/// device rotation. Landscape detection is purely size-based so it works
/// whether or not the device is physically rotated.
///
/// Push via [ChallengeStepsFullScreenViewer.show]:
/// ```dart
/// ChallengeStepsFullScreenViewer.show(
///   context,
///   steps: steps,
///   initialIndex: currentPage,
/// );
/// ```
class ChallengeStepsFullScreenViewer extends StatefulWidget {
  final List<ChallengeStep> steps;
  final int initialIndex;

  const ChallengeStepsFullScreenViewer({
    super.key,
    required this.steps,
    this.initialIndex = 0,
  });

  /// Pushes the full-screen viewer as a new route, fading in over the current
  /// screen.  Uses the root navigator so it covers bottom sheets and other
  /// overlays.
  static Future<void> show(
    BuildContext context, {
    required List<ChallengeStep> steps,
    int initialIndex = 0,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => ChallengeStepsFullScreenViewer(
          steps: steps,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<ChallengeStepsFullScreenViewer> createState() => _ChallengeStepsFullScreenViewerState();
}

class _ChallengeStepsFullScreenViewerState extends State<ChallengeStepsFullScreenViewer> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex.clamp(0, widget.steps.length - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = widget.steps.length;
    final isLast = _currentPage >= totalSteps - 1;
    final isFirst = _currentPage == 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Size-based orientation: works with or without device rotation.
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return Column(
              children: [
                // ── Top bar ───────────────────────────────────────────────
                _buildTopBar(context, isLandscape),

                // ── Swipeable step pages ──────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: totalSteps,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (ctx, index) => _FullScreenStepPage(
                      step: widget.steps[index],
                      isLandscape: isLandscape,
                    ),
                  ),
                ),

                // ── Bottom navigation ─────────────────────────────────────
                _buildBottomNav(context, totalSteps, isFirst, isLast),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: isLandscape ? 2 : 4,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            'STEP ${_currentPage + 1} OF ${widget.steps.length}',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 13,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
          // Invisible spacer to balance the close button.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ── Bottom navigation bar ─────────────────────────────────────────────────

  Widget _buildBottomNav(
    BuildContext context,
    int totalSteps,
    bool isFirst,
    bool isLast,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          // ── Prev ────────────────────────────────────────────────────────
          _NavButton(
            label: 'PREV',
            icon: Icons.chevron_left_rounded,
            iconOnLeft: true,
            enabled: !isFirst,
            onTap: isFirst ? null : () => _goTo(_currentPage - 1),
          ),

          // ── Dot indicators ───────────────────────────────────────────────
          if (totalSteps > 1)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (i) {
                  final active = i == _currentPage;
                  return GestureDetector(
                    onTap: () => _goTo(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            )
          else
            const Spacer(),

          // ── Next / Done ──────────────────────────────────────────────────
          isLast
              ? _NavButton(
                  label: 'DONE',
                  icon: Icons.check_rounded,
                  iconOnLeft: false,
                  enabled: true,
                  isPrimary: true,
                  onTap: () => Navigator.of(context).pop(),
                )
              : _NavButton(
                  label: 'NEXT',
                  icon: Icons.chevron_right_rounded,
                  iconOnLeft: false,
                  enabled: true,
                  isPrimary: true,
                  onTap: () => _goTo(_currentPage + 1),
                ),
        ],
      ),
    );
  }
}

// ── Prev / Next / Done button ─────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconOnLeft;
  final bool enabled;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.iconOnLeft,
    required this.enabled,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isPrimary ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface;

    final borderColor = enabled ? (isPrimary ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: iconOnLeft
          ? [
              Icon(icon, size: 20),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 15,
                ),
              ),
            ]
          : [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 20),
            ],
    );

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          foregroundColor: activeColor,
          disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        child: content,
      ),
    );
  }
}

// ── Single full-screen step page ──────────────────────────────────────────────

class _FullScreenStepPage extends StatefulWidget {
  final ChallengeStep step;
  final bool isLandscape;

  const _FullScreenStepPage({
    required this.step,
    required this.isLandscape,
  });

  @override
  State<_FullScreenStepPage> createState() => _FullScreenStepPageState();
}

class _FullScreenStepPageState extends State<_FullScreenStepPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.step.mediaType == 'video' && widget.step.mediaUrl.isNotEmpty) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.step.mediaUrl),
      );
      await _videoController!.initialize();
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: false,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, msg) => _buildMediaError(context),
      );
      setState(() => _videoReady = true);
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isLandscape ? _buildLandscape(context) : _buildPortrait(context);
  }

  // Portrait: chip+title → media (expands) → summary
  Widget _buildPortrait(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildChipAndTitle(context),
          const SizedBox(height: 12),
          Expanded(child: _buildMedia(context)),
          const SizedBox(height: 12),
          _buildSummary(context),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // Landscape: left = media, right = chip+title+scrollable summary
  Widget _buildLandscape(BuildContext context) {
    final hasMedia = widget.step.mediaUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasMedia)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildMedia(context),
              ),
            ),
          Expanded(
            flex: hasMedia ? 4 : 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChipAndTitle(context),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildSummary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildChipAndTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Step ${widget.step.stepNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'NovecentoSans',
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.step.title,
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 26,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Text(
      widget.step.summary,
      style: TextStyle(
        fontFamily: 'NovecentoSans',
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
        height: 1.45,
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    final mediaType = widget.step.mediaType;
    final url = widget.step.mediaUrl;

    if (url.isEmpty) return const SizedBox.shrink();

    if (mediaType == 'video') {
      if (_videoReady && _chewieController != null) {
        return Chewie(controller: _chewieController!);
      }
      return const Center(child: CircularProgressIndicator());
    }

    // image / gif
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildMediaError(context),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaError(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Media unavailable',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

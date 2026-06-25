import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeStep.dart';
import 'package:video_player/video_player.dart';
import 'ChallengeStepsFullScreenViewer.dart';

/// Horizontal PageView showing each [ChallengeStep] with its media, title,
/// and summary text.
///
/// Supported media types:
///   - `'image'` / `'gif'`  → [Image.network]
///   - `'video'`            → [Chewie] video player (mp4 / Firebase Storage URL)
///   - `'webm'`             → silent auto-looping [VideoPlayer] (gif-like, no controls)
class ChallengeStepViewer extends StatefulWidget {
  final List<ChallengeStep> steps;

  const ChallengeStepViewer({super.key, required this.steps});

  @override
  State<ChallengeStepViewer> createState() => _ChallengeStepViewerState();
}

class _ChallengeStepViewerState extends State<ChallengeStepViewer> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No steps available.')),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Media is always a 4:3 crop of the available width (minus 24px
            // of horizontal padding inside each _StepPage). Add 160px for the
            // step chip, title, summary text, and vertical spacing.
            final double mediaHeight = (constraints.maxWidth - 24) * (3 / 4);
            return SizedBox(
              height: mediaHeight + 160,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.steps.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  return _StepPage(
                    step: widget.steps[index],
                    onMediaTap: () => ChallengeStepsFullScreenViewer.show(
                      context,
                      steps: widget.steps,
                      initialIndex: index,
                    ),
                  );
                },
              ),
            );
          },
        ),
        if (widget.steps.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.steps.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

// ── Single step page ──────────────────────────────────────────────────────────

class _StepPage extends StatefulWidget {
  final ChallengeStep step;

  /// Called when the user taps the media or the expand button. Opens the
  /// full-screen step viewer at this step's index.
  final VoidCallback? onMediaTap;
  const _StepPage({required this.step, this.onMediaTap});

  @override
  State<_StepPage> createState() => _StepPageState();
}

class _StepPageState extends State<_StepPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.step.mediaType == 'video' && widget.step.mediaUrl.isNotEmpty) {
      _initVideo();
    } else if (widget.step.mediaType == 'webm' && widget.step.mediaUrl.isNotEmpty) {
      _initGifVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.step.mediaUrl),
      );
      await _videoController!.initialize();
      if (!mounted) return;
      // No aspectRatio set: let the parent AspectRatio(4/3) widget determine
      // the player size; the video renders contained within that 4:3 box.
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: false,
        errorBuilder: (context, msg) => _buildMediaError(context),
      );
      setState(() => _videoReady = true);
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  Future<void> _initGifVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.step.mediaUrl),
      );
      await _videoController!.initialize();
      if (!mounted) return;
      await _videoController!.setLooping(true);
      await _videoController!.setVolume(0);
      await _videoController!.play();
      if (mounted) setState(() => _videoReady = true);
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Step number chip ──────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
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
          ),
          const SizedBox(height: 8),

          // ── Title ─────────────────────────────────────────────────────
          Text(
            widget.step.title,
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // ── Media ─────────────────────────────────────────────────────
          _buildMedia(context),

          const SizedBox(height: 10),

          // ── Summary ───────────────────────────────────────────────────
          Text(
            widget.step.summary,            maxLines: 4,
            overflow: TextOverflow.ellipsis,            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    final mediaType = widget.step.mediaType;
    final url = widget.step.mediaUrl;

    // ── Raw media content ───────────────────────────────────────────────
    Widget content;
    if (url.isEmpty) {
      content = _buildMediaError(context);
    } else if (mediaType == 'video') {
      // Chewie fills the 4:3 parent box; video is contain-fitted inside it.
      content = (_videoReady && _chewieController != null) ? Chewie(controller: _chewieController!) : const Center(child: CircularProgressIndicator());
    } else if (mediaType == 'webm') {
      // FittedBox.cover scales the native-sized video to fill the 4:3 box.
      // If the controller hasn't reported dimensions yet, fall back to letting
      // VideoPlayer fill the container directly (contained, not cropped).
      if (_videoReady && _videoController != null) {
        final size = _videoController!.value.size;
        if (size.width > 0 && size.height > 0) {
          content = FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(_videoController!),
            ),
          );
        } else {
          // Dimensions unavailable — fill the 4:3 container as-is.
          content = VideoPlayer(_videoController!);
        }
      } else {
        content = const Center(child: CircularProgressIndicator());
      }
    } else {
      // image / gif — BoxFit.cover crops to fill the 4:3 box.
      content = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildMediaError(context),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
            ),
          );
        },
      );
    }

    // ── 4:3 cover container with expand-button overlay ───────────────────
    // Tapping anywhere on non-Chewie media opens the full-screen viewer;
    // Chewie handles its own touch so only the expand button is wired there.
    final Widget mediaBox = AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: mediaType == 'video' ? content : GestureDetector(onTap: widget.onMediaTap, child: content),
      ),
    );

    return Stack(
      children: [
        mediaBox,
        if (widget.onMediaTap != null)
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'View full screen',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: widget.onMediaTap,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaError(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 40, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 6),
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

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
///
/// Video controller ownership lives entirely in [_ChallengeStepViewerState].
/// Only one [VideoPlayerController] / [ChewieController] is active at a time,
/// preventing simultaneous hardware MediaCodec allocations that caused OOM
/// crashes on low-memory Android devices.
class ChallengeStepViewer extends StatefulWidget {
  final List<ChallengeStep> steps;

  const ChallengeStepViewer({super.key, required this.steps});

  @override
  State<ChallengeStepViewer> createState() => _ChallengeStepViewerState();
}

class _ChallengeStepViewerState extends State<ChallengeStepViewer> {
  late final PageController _pageController;
  int _currentPage = 0;

  // ── Single active video controller ───────────────────────────────────────────────────
  // These fields represent the video/webm for whichever page is currently
  // visible. They are disposed before a new page's video is initialised, so
  // at most one hardware video decoder is running at any given time.
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoReady = false;
  int? _videoPageIndex; // page that currently owns the active controller

  /// Monotonically-increasing counter used to detect stale async inits that
  /// should be discarded when the user swipes before initialisation finishes.
  int _initGeneration = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initVideoForPage(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _teardownVideo();
    super.dispose();
  }

  // ── Video lifecycle ───────────────────────────────────────────────────────────────────────

  void _teardownVideo() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
    _videoPageIndex = null;
    _videoReady = false;
  }

  Future<void> _initVideoForPage(int index) async {
    final generation = ++_initGeneration;
    if (index >= widget.steps.length) return;
    final step = widget.steps[index];

    // Always tear down whatever was running before.
    _teardownVideo();
    if (mounted) setState(() {});

    // No video content on this page — nothing to do.
    if ((step.mediaType != 'video' && step.mediaType != 'webm') || step.mediaUrl.isEmpty) {
      return;
    }

    // Wait briefly for the native ExoPlayer to release its graphic buffer
    // pool (~92 MB each) before we allocate a new decoder. Without this delay
    // rapid page swipes pile up decoders that haven't freed native memory yet,
    // exhausting the 512 MB largeHeap limit.
    await Future.delayed(const Duration(milliseconds: 300));
    if (generation != _initGeneration || !mounted) return;

    try {
      final vc = VideoPlayerController.networkUrl(
        Uri.parse(step.mediaUrl),
        // Prevent ExoPlayer from requesting audio focus so it cannot
        // interrupt the challenge audio player with AUDIOFOCUS_LOSS.
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await vc.initialize();

      // Stale init: the user already swiped to another page.
      if (generation != _initGeneration || !mounted) {
        vc.dispose();
        return;
      }

      if (step.mediaType == 'webm') {
        await vc.setLooping(true);
        await vc.setVolume(0);
        await vc.play();
        _videoController = vc;
      } else {
        // 'video' — wrap with Chewie for full controls.
        final cc = ChewieController(
          videoPlayerController: vc,
          autoPlay: false,
          looping: false,
          allowFullScreen: false,
          errorBuilder: (ctx, _) => _buildMediaError(ctx),
        );
        _videoController = vc;
        _chewieController = cc;
      }

      _videoPageIndex = index;
      if (mounted) setState(() => _videoReady = true);
    } catch (_) {
      // Leave _videoReady = false so the step shows an error widget.
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────────────────

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
            final double mediaHeight = (constraints.maxWidth - 24) * (4 / 3);
            return SizedBox(
              height: mediaHeight + 160,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.steps.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                  _initVideoForPage(idx);
                },
                itemBuilder: (context, index) {
                  // Only pass the active controllers to the visible page.
                  final isActive = _videoPageIndex == index;
                  return _StepPage(
                    step: widget.steps[index],
                    videoController: isActive ? _videoController : null,
                    chewieController: isActive ? _chewieController : null,
                    videoReady: isActive && _videoReady,
                    onMediaTap: () async {
                      // Teardown the inline controller before the full-screen
                      // viewer opens so only one VP9 decoder is alive at a time.
                      final savedPage = _currentPage;
                      _teardownVideo();
                      if (mounted) setState(() {});
                      await ChallengeStepsFullScreenViewer.show(
                        context,
                        steps: widget.steps,
                        initialIndex: index,
                      );
                      // Re-init for the page the user left on.
                      if (mounted) _initVideoForPage(savedPage);
                    },
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
            Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
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

// ── Single step page (stateless) ───────────────────────────────────────────────────────────────────

/// Displays a single [ChallengeStep]. Video controllers are owned by the
/// parent [_ChallengeStepViewerState] and passed in to keep only one decoder
/// alive at a time.
class _StepPage extends StatelessWidget {
  final ChallengeStep step;
  final VideoPlayerController? videoController;
  final ChewieController? chewieController;
  final bool videoReady;
  final VoidCallback? onMediaTap;

  const _StepPage({
    required this.step,
    this.videoController,
    this.chewieController,
    this.videoReady = false,
    this.onMediaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Step number chip ────────────────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Step ${step.stepNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'NovecentoSans',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Title ───────────────────────────────────────────────────────────────────────────────────────
          Text(
            step.title,
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // ── Media ───────────────────────────────────────────────────────────────────────────────────────
          _buildMedia(context),

          const SizedBox(height: 10),

          // ── Summary ──────────────────────────────────────────────────────────────────────────────────────
          Text(
            step.summary,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
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
    final mediaType = step.mediaType;
    final url = step.mediaUrl;

    Widget content;
    if (url.isEmpty) {
      content = _buildMediaError(context);
    } else if (mediaType == 'video') {
      content = (videoReady && chewieController != null) ? Chewie(controller: chewieController!) : _buildLoadingPlaceholder(context);
    } else if (mediaType == 'webm') {
      if (videoReady && videoController != null) {
        final size = videoController!.value.size;
        if (size.width > 0 && size.height > 0) {
          content = FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(videoController!),
            ),
          );
        } else {
          content = VideoPlayer(videoController!);
        }
      } else {
        content = _buildLoadingPlaceholder(context);
      }
    } else {
      // image / gif
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

    // ── 4:3 cover container with expand-button overlay ──────────────────────────────────
    final Widget mediaBox = AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: mediaType == 'video' ? content : GestureDetector(onTap: onMediaTap, child: content),
      ),
    );

    return Stack(
      children: [
        mediaBox,
        if (onMediaTap != null)
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'View full screen',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onMediaTap,
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
            Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
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

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeStep.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'ChallengeStepsFullScreenViewer.dart';

/// Horizontal PageView showing each [ChallengeStep] with its media, title,
/// and summary text.
///
/// WebM steps autoplay muted and looping inline. Regular video steps show a
/// play-icon placeholder — tapping them opens the full-screen viewer.
/// Only the currently visible page keeps a live [VideoPlayerController];
/// the controller is torn down and replaced when the user swipes to a new step.
class ChallengeStepViewer extends StatefulWidget {
  final List<ChallengeStep> steps;

  const ChallengeStepViewer({super.key, required this.steps});

  @override
  State<ChallengeStepViewer> createState() => _ChallengeStepViewerState();
}

class _ChallengeStepViewerState extends State<ChallengeStepViewer> {
  late final PageController _pageController;
  int _currentPage = 0;

  // ── Single active video controller ───────────────────────────────────────
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  int? _videoPageIndex;
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

  // ── Video lifecycle ───────────────────────────────────────────────────────

  Future<void> _initVideoForPage(int index) async {
    final generation = ++_initGeneration;
    if (index >= widget.steps.length) return;
    final step = widget.steps[index];

    _teardownVideo();
    if (mounted) setState(() {});

    // Only webm steps autoplay inline; regular video steps show a placeholder.
    if (step.mediaType != 'webm' || step.mediaUrl.isEmpty) {
      return;
    }

    try {
      final vc = VideoPlayerController.networkUrl(
        Uri.parse(resolveVideoUrl(step.mediaUrl)),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await vc.initialize();

      if (generation != _initGeneration || !mounted) {
        vc.dispose();
        return;
      }

      await vc.setLooping(true);
      await vc.setVolume(0);
      await vc.play();
      _videoController = vc;
      _videoPageIndex = index;
      if (mounted) setState(() => _videoReady = true);
    } catch (_) {
      // Leave _videoReady = false; the page shows a loading placeholder.
    }
  }

  void _teardownVideo() {
    _videoController?.dispose();
    _videoController = null;
    _videoPageIndex = null;
    _videoReady = false;
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
                  final isActive = _videoPageIndex == index;
                  return _StepPage(
                    step: widget.steps[index],
                    videoController: isActive ? _videoController : null,
                    videoReady: isActive && _videoReady,
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

// ── Single step page (stateless) ───────────────────────────────────────────────────────────────────

/// Displays a single [ChallengeStep]. Video controllers are owned by the
/// parent [_ChallengeStepViewerState] and passed in to keep only one decoder
/// alive at a time.
class _StepPage extends StatelessWidget {
  final ChallengeStep step;
  final VoidCallback? onMediaTap;
  final VideoPlayerController? videoController;
  final bool videoReady;

  const _StepPage({
    required this.step,
    this.onMediaTap,
    this.videoController,
    this.videoReady = false,
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
    } else if (mediaType == 'webm') {
      if (videoReady && videoController != null) {
        final size = videoController!.value.size;
        content = size.width > 0 && size.height > 0
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(videoController!),
                ),
              )
            : VideoPlayer(videoController!);
      } else {
        content = _buildVideoLoading(context);
      }
    } else if (mediaType == 'video') {
      // Regular video: show first-frame thumbnail with play overlay.
      // Tapping opens the full-screen viewer with Chewie controls.
      content = _VideoThumbWidget(url: url);
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
        child: GestureDetector(onTap: onMediaTap, child: content),
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

  Widget _buildVideoLoading(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
    );
  }
}

// ── First-frame thumbnail for video steps ────────────────────────────────────

/// Loads the first frame of an MP4 video via [VideoThumbnail] and renders it
/// with a semi-transparent play-circle overlay. Falls back to a play-icon
/// placeholder while loading or on error.
class _VideoThumbWidget extends StatefulWidget {
  final String url;

  const _VideoThumbWidget({required this.url});

  @override
  State<_VideoThumbWidget> createState() => _VideoThumbWidgetState();
}

class _VideoThumbWidgetState extends State<_VideoThumbWidget> {
  Uint8List? _thumb;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: widget.url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 70,
        timeMs: 0,
      );
      if (!mounted) return;
      if (data == null || data.isEmpty) {
        setState(() => _error = true);
        return;
      }
      setState(() => _thumb = data);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error || _thumb == null) {
      // Loading or error state: play-icon placeholder
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            Icons.play_circle_outline_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: _error ? 0.35 : 0.15),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(_thumb!, fit: BoxFit.cover),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
          ),
        ),
      ],
    );
  }
}

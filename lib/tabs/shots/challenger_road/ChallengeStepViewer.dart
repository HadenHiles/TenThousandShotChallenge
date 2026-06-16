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
        Stack(
          children: [
            SizedBox(
              height: 340,
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
            ),
            // Expand icon – overlaid in the top-right corner of the step area.
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'View full screen',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => ChallengeStepsFullScreenViewer.show(
                      context,
                      steps: widget.steps,
                      initialIndex: _currentPage,
                    ),
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

  /// Called when the user taps the image/gif media. Not fired for videos
  /// (Chewie handles its own tap interactions).
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
          Expanded(child: _buildMedia(context)),

          const SizedBox(height: 10),

          // ── Summary ───────────────────────────────────────────────────
          Text(
            widget.step.summary,
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
    final mediaType = widget.step.mediaType;
    final url = widget.step.mediaUrl;

    if (url.isEmpty) return const SizedBox.shrink();

    if (mediaType == 'video') {
      if (_videoReady && _chewieController != null) {
        return Chewie(controller: _chewieController!);
      }
      return const Center(child: CircularProgressIndicator());
    }

    // image / gif – tappable to open full-screen viewer.
    return GestureDetector(
      onTap: widget.onMediaTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
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
        ),
      ),
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

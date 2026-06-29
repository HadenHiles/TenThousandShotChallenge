import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeStep.dart';
import 'ChallengeStepsFullScreenViewer.dart';

/// Horizontal PageView showing each [ChallengeStep] with its media, title,
/// and summary text.
///
/// Video/webm steps show a static play-icon placeholder here. The actual
/// hardware VP9 decoder is only allocated inside [ChallengeStepsFullScreenViewer],
/// keeping at most one decoder alive at a time and preventing the OOM crashes
/// that occur when multiple decoders accumulate graphic-buffer pools (~92 MB
/// each) faster than Android's C2 evictor can reclaim them.
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

// ── Single step page (stateless) ───────────────────────────────────────────────────────────────────

/// Displays a single [ChallengeStep]. Video controllers are owned by the
/// parent [_ChallengeStepViewerState] and passed in to keep only one decoder
/// alive at a time.
class _StepPage extends StatelessWidget {
  final ChallengeStep step;
  final VoidCallback? onMediaTap;

  const _StepPage({
    required this.step,
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
    } else if (mediaType == 'video' || mediaType == 'webm') {
      // Hardware VP9 decoder is only allocated in ChallengeStepsFullScreenViewer.
      // Show a static placeholder here to avoid accumulating buffer pools.
      content = _buildVideoPlaceholder(context);
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

  Widget _buildVideoPlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 56,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

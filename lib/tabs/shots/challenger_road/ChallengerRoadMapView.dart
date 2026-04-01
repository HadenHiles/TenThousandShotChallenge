import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeProgressEntry.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'ChallengeDetailSheet.dart';
import 'ChallengeMapNode.dart';
import 'ChallengerRoadHeader.dart';
import 'LevelBannerWidget.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const double _nodeSpacing = 108.0; // vertical distance between node centres
const double _nodeDiameter = 62.0;
const double _bannerHeight = 44.0;
const double _levelTopPad = 16.0; // space above a level section's first node
const double _levelBottomPad = 20.0;
const double _levelSectionExtraTop = 8.0; // gap above the banner itself
// Column x-fractions for the 3-column zigzag
const List<double> _xFractions = [0.18, 0.50, 0.82];

// ── Data bundle loaded once per build ────────────────────────────────────────

class _CRMapData {
  final List<int> levels; // sorted ascending
  final Map<int, List<ChallengerRoadChallenge>> challengesByLevel;
  final ChallengerRoadAttempt? activeAttempt;
  final Map<String, ChallengeProgressEntry> progress; // challengeId → entry

  const _CRMapData({
    required this.levels,
    required this.challengesByLevel,
    required this.activeAttempt,
    required this.progress,
  });
}

// ── CustomPainter for within-level path ──────────────────────────────────────

class _LevelPathPainter extends CustomPainter {
  final List<Offset> centres; // node centres in local Stack coordinates
  final Color color;

  const _LevelPathPainter({required this.centres, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (centres.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(centres[0].dx, centres[0].dy);

    for (int i = 1; i < centres.length; i++) {
      final from = centres[i - 1];
      final to = centres[i];
      // Cubic bezier: control points bend the path smoothly between columns.
      final midY = (from.dy + to.dy) / 2.0;
      path.cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LevelPathPainter old) => old.centres != centres || old.color != color;
}

// ── Column index for snake zigzag pattern ────────────────────────────────────

/// Returns the x-fraction column index for a node at position [i] (0-based).
/// Pattern: 0 (left), 1 (centre), 2 (right), 1 (centre), 0, 1, 2, …
int _colForIndex(int i) {
  final mod = i % 4;
  return mod == 3 ? 1 : mod;
}

/// Compute local Stack [Offset] for each node in a level section.
/// [count]      — number of challenges
/// [stackWidth] — pixel width of the containing Stack
/// Nodes are laid out top-to-bottom (seq 0 at top).
List<Offset> _computeNodeCentres(int count, double stackWidth) {
  return List.generate(count, (i) {
    final x = stackWidth * _xFractions[_colForIndex(i)];
    final y = _levelTopPad + _bannerHeight + 16.0 + (_nodeDiameter / 2) + i * _nodeSpacing;
    return Offset(x, y);
  });
}

/// Total pixel height of one level section (banner + nodes + padding).
double _levelSectionHeight(int nodeCount) => _levelSectionExtraTop + _levelTopPad + _bannerHeight + 16.0 + math.max(nodeCount, 1) * _nodeSpacing + _levelBottomPad;

// ── Main widget ───────────────────────────────────────────────────────────────

/// Full-screen Challenger Road snake map shown in the Start tab for pro users.
///
/// Renders all levels (Level 1 at the bottom, highest level at the top).
/// Level 1 is scrolled into view on first load.
///
/// Pass [onChallengeTap] to handle when the user taps an available / completed
/// challenge node (Phase 6 detail sheet hook).
class ChallengerRoadMapView extends StatefulWidget {
  final String userId;
  final ValueChanged<bool>? onMainHeaderVisibilityChanged;
  final bool isPreviewMode;
  final int previewMaxLevel;
  final ChallengerRoadAttempt? previewHeaderAttempt;
  final VoidCallback? onPreviewLevelUnlockAttempted;
  final double mapBottomInset;

  /// Called when a tappable node is pressed.
  final void Function(
    ChallengerRoadChallenge challenge,
    ChallengerRoadLevel levelDoc,
    ChallengerRoadAttempt attempt,
  )? onChallengeTap;

  const ChallengerRoadMapView({
    super.key,
    required this.userId,
    this.onChallengeTap,
    this.onMainHeaderVisibilityChanged,
    this.isPreviewMode = false,
    this.previewMaxLevel = 1,
    this.previewHeaderAttempt,
    this.onPreviewLevelUnlockAttempted,
    this.mapBottomInset = 32,
  });

  @override
  State<ChallengerRoadMapView> createState() => _ChallengerRoadMapViewState();
}

class _ChallengerRoadMapViewState extends State<ChallengerRoadMapView> {
  ChallengerRoadService? _service;
  Future<_CRMapData>? _dataFuture;
  final ScrollController _scrollController = ScrollController();
  bool _didScrollToCurrentLevel = false;
  bool _mainHeaderVisible = true;

  // Track the height of each level section so we can scroll to the right level.
  // Key: level number, Value: cumulative top offset from the very top of scroll content.
  final Map<int, double> _levelTopOffsets = {};

  /// When a level is newly unlocked after a session, we store it here so the
  /// corresponding banner can play its slide-in animation on the first rebuild.
  int? _justUnlockedLevel;

  /// The last known current level before a data refresh, used to detect
  /// whether a level-unlock animation should fire.
  int? _previousCurrentLevel;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onMapScrolled);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service == null) {
      final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
      _service = ChallengerRoadService(firestore: firestore);
      _dataFuture = _loadMapData().then((data) {
        _previousCurrentLevel = data.activeAttempt?.currentLevel;
        return data;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onMapScrolled);
    _scrollController.dispose();
    super.dispose();
  }

  void _emitMainHeaderVisibility(bool visible) {
    if (_mainHeaderVisible == visible) return;
    if (mounted) {
      setState(() {
        _mainHeaderVisible = visible;
      });
    } else {
      _mainHeaderVisible = visible;
    }
    widget.onMainHeaderVisibilityChanged?.call(visible);
  }

  void _onMapScrolled() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    if (offset <= 8) {
      _emitMainHeaderVisibility(true);
      return;
    }

    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse) {
      // Reversed behavior per UX tweak: scrolling up shows header.
      _emitMainHeaderVisibility(true);
    } else if (direction == ScrollDirection.forward) {
      // Reversed behavior per UX tweak: scrolling down hides header.
      _emitMainHeaderVisibility(false);
    }
  }

  Future<_CRMapData> _loadMapData() async {
    final levels = await _service!.getAllActiveLevels();
    ChallengerRoadAttempt? attempt = await _service!.getActiveAttempt(widget.userId);

    if (widget.isPreviewMode && attempt == null) {
      // Ensure free preview users can actually try level 1 challenges.
      attempt = await _service!.createAttempt(widget.userId, 1);
    }

    final challengesByLevel = <int, List<ChallengerRoadChallenge>>{};
    for (final lvl in levels) {
      challengesByLevel[lvl] = await _service!.getChallengesForLevel(lvl);
    }

    final progress = <String, ChallengeProgressEntry>{};
    if (attempt != null) {
      final allIds = challengesByLevel.values.expand((list) => list).map((c) => c.id).whereType<String>().toSet();
      for (final cid in allIds) {
        final p = await _service!.getChallengeProgress(widget.userId, attempt.id!, cid);
        if (p != null) progress[cid] = p;
      }
    }

    return _CRMapData(
      levels: levels,
      challengesByLevel: challengesByLevel,
      activeAttempt: attempt,
      progress: progress,
    );
  }

  void _refreshData() {
    setState(() {
      _didScrollToCurrentLevel = false;
      _levelTopOffsets.clear();
      _dataFuture = _loadMapData().then((data) {
        final newLevel = data.activeAttempt?.currentLevel;
        if (newLevel != null && _previousCurrentLevel != null && newLevel > _previousCurrentLevel!) {
          // A level advance happened — flag the new level for its unlock animation.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _justUnlockedLevel = newLevel);
          });
        }
        _previousCurrentLevel = newLevel;
        return data;
      });
    });
  }

  // ── State helpers ─────────────────────────────────────────────────────────

  ChallengeNodeState _nodeState(
    String challengeId,
    int level,
    _CRMapData data,
    bool isFirstIncomplete,
  ) {
    final attempt = data.activeAttempt;
    if (attempt == null) return ChallengeNodeState.locked;

    final currentLevel = widget.isPreviewMode ? math.min(attempt.currentLevel, widget.previewMaxLevel) : attempt.currentLevel;
    if (level < currentLevel) return ChallengeNodeState.completed;
    if (level > currentLevel) return ChallengeNodeState.locked;

    // level == currentLevel
    final bestLevel = data.progress[challengeId]?.bestLevel ?? 0;
    if (bestLevel >= level) return ChallengeNodeState.completed;
    return isFirstIncomplete ? ChallengeNodeState.current : ChallengeNodeState.available;
  }

  // Scroll so that the player's current level is visible in the viewport.
  void _scrollToCurrentLevel(_CRMapData data) {
    if (_didScrollToCurrentLevel) return;
    _didScrollToCurrentLevel = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final currentLevel = widget.isPreviewMode ? math.min(data.activeAttempt?.currentLevel ?? 1, widget.previewMaxLevel) : (data.activeAttempt?.currentLevel ?? 1);

      // Levels are rendered highest-first (top), Level 1 last (bottom).
      // We want to scroll so the current level is near the top of the viewport.
      final targetOffset = _levelTopOffsets[currentLevel];
      if (targetOffset != null) {
        final scrollTo = (targetOffset - 16.0).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          scrollTo,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      } else {
        // Fallback: scroll to the bottom where Level 1 lives.
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Confirm restart dialog ────────────────────────────────────────────────

  void _confirmRestart(BuildContext context, ChallengerRoadAttempt attempt) {
    final isDoOver = attempt.resetCount == 0;
    final title = isDoOver ? 'Start Over?' : 'Restart Challenger Road?';
    final body = isDoOver
        ? 'Your shot count and challenge progress for this attempt will be cleared. '
            'Your attempt number stays the same — this is a do-over, not a new attempt.'
        : 'Your current attempt will end. Your next attempt will start one level below your current best.';

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'NovecentoSans')),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _service!.restartChallengerRoad(widget.userId);
              _refreshData();
            },
            child: Text(
              'Restart',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── No-attempt splash ─────────────────────────────────────────────────────

  Widget _buildNoAttemptSplash(BuildContext context, _CRMapData data) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Show the map blurred / dimmed as a preview
        Positioned.fill(
          child: Opacity(
            opacity: 0.3,
            child: _buildMapContent(context, data, interactive: false),
          ),
        ),
        // Overlay CTA
        Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Challenger Road',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 28,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete challenges level by level and push your game to the limit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        await _service!.createAttempt(widget.userId, 1);
                        _refreshData();
                      },
                      child: const Text(
                        'BEGIN YOUR JOURNEY',
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Map content (scrollable) ──────────────────────────────────────────────

  Widget _buildMapContent(
    BuildContext context,
    _CRMapData data, {
    bool interactive = true,
  }) {
    // Render levels with the HIGHEST level first (top of scroll), Level 1 last.
    final levels = data.levels.reversed.toList();
    // Compute cumulative offsets for scroll-to-level.
    double cumulativeOffset = 0;
    for (final lvl in levels) {
      _levelTopOffsets[lvl] = cumulativeOffset;
      final count = data.challengesByLevel[lvl]?.length ?? 0;
      cumulativeOffset += _levelSectionHeight(count);
    }

    return SingleChildScrollView(
      controller: interactive ? _scrollController : null,
      child: Column(
        children: [
          for (final lvl in levels) _buildLevelSection(context, lvl, data, interactive: interactive),
          SizedBox(height: widget.mapBottomInset),
        ],
      ),
    );
  }

  Widget _buildLevelSection(
    BuildContext context,
    int level,
    _CRMapData data, {
    bool interactive = true,
  }) {
    final challenges = data.challengesByLevel[level] ?? [];
    final attempt = data.activeAttempt;
    final currentLevel = widget.isPreviewMode ? math.min(attempt?.currentLevel ?? 1, widget.previewMaxLevel) : (attempt?.currentLevel ?? 1);
    final isCurrentLevel = level == currentLevel;
    final isLocked = level > currentLevel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centres = _computeNodeCentres(challenges.length, width);
        final sectionHeight = _levelSectionHeight(challenges.length);

        // Determine the next incomplete challenge index for the "current" state.
        // We advance from the bottom-most node upward within a level.
        int firstIncompleteIdx = -1;
        if (isCurrentLevel) {
          for (int i = challenges.length - 1; i >= 0; i--) {
            final cid = challenges[i].id ?? '';
            final best = data.progress[cid]?.bestLevel ?? 0;
            if (best < level) {
              firstIncompleteIdx = i;
              break;
            }
          }
        }

        // Path color
        final pathColor = isLocked
            ? Colors.grey.shade700.withValues(alpha: 0.4)
            : isCurrentLevel
                ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
                : Colors.green.shade600.withValues(alpha: 0.5);

        return SizedBox(
          height: sectionHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Path ────────────────────────────────────────────────────
              if (challenges.length > 1)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LevelPathPainter(centres: centres, color: pathColor),
                  ),
                ),

              // ── Level banner ────────────────────────────────────────────
              Positioned(
                top: _levelSectionExtraTop,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildLevelBanner(context, level, isCurrentLevel, isLocked),
                ),
              ),

              // ── Challenge nodes ─────────────────────────────────────────
              for (int i = 0; i < challenges.length; i++)
                Positioned(
                  // Centre the node widget horizontally around the computed x.
                  left: centres[i].dx - 41, // 41 = (82 node widget width) / 2
                  // Centre the circle (top portion of node widget) around y.
                  top: centres[i].dy - (_nodeDiameter / 2),
                  child: ChallengeMapNode(
                    challengeName: challenges[i].name,
                    state: _nodeState(
                      challenges[i].id ?? '',
                      level,
                      data,
                      i == firstIncompleteIdx,
                    ),
                    onTap: interactive && attempt != null ? () => _handleNodeTap(challenges[i], level, attempt, data) : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Level banner (with optional unlock animation) ─────────────────────────

  Widget _buildLevelBanner(
    BuildContext context,
    int level,
    bool isCurrentLevel,
    bool isLocked,
  ) {
    final banner = LevelBannerWidget(
      level: level,
      isCurrentLevel: isCurrentLevel,
      isLocked: isLocked,
    );

    if (_justUnlockedLevel == level) {
      // Clear the flag after the first frame so the animation only plays once.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _justUnlockedLevel == level) {
          setState(() => _justUnlockedLevel = null);
        }
      });

      return _LevelUnlockAnimatedBanner(child: banner);
    }

    return banner;
  }

  Future<void> _handleNodeTap(
    ChallengerRoadChallenge challenge,
    int level,
    ChallengerRoadAttempt attempt,
    _CRMapData data,
  ) async {
    final levelDoc = await _service!.getLevelDoc(challenge.id!, level);
    if (levelDoc == null || !mounted) return;

    if (widget.onChallengeTap != null) {
      widget.onChallengeTap!(challenge, levelDoc, attempt);
      return;
    }

    // Default: show the challenge detail sheet.
    await ChallengeDetailSheet.show(
      context,
      challenge: challenge,
      levelDoc: levelDoc,
      attempt: attempt,
      userId: widget.userId,
      progress: data.progress[challenge.id],
      onSessionComplete: _refreshData,
      isPreviewMode: widget.isPreviewMode,
      previewMaxLevel: widget.previewMaxLevel,
      onPreviewLevelUnlockAttempted: widget.onPreviewLevelUnlockAttempted,
    );
  }

  // ── Root build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CRMapData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        // ── Loading ──────────────────────────────────────────────────────
        if (!snapshot.hasData && !snapshot.hasError) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor,
            ),
          );
        }

        // ── Error ─────────────────────────────────────────────────────────
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 40, color: Theme.of(context).primaryColor),
                const SizedBox(height: 12),
                Text(
                  'Could not load Challenger Road',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: _refreshData, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        final attempt = data.activeAttempt;

        // Scroll to the current level once data is loaded.
        if (attempt != null) _scrollToCurrentLevel(data);

        // ── No data (no challenges seeded yet) ────────────────────────────
        if (data.levels.isEmpty) {
          return Center(
            child: Text(
              'Challenges coming soon!',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 20,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          );
        }

        return Column(
          children: [
            // ── Header (pinned below app header) ───────────────────────
            ChallengerRoadHeader(
              attempt: widget.isPreviewMode ? (widget.previewHeaderAttempt ?? attempt) : attempt,
              topPadding: _mainHeaderVisible ? 0 : MediaQuery.of(context).padding.top,
              onRestartTap: (!widget.isPreviewMode && attempt != null) ? () => _confirmRestart(context, attempt) : null,
            ),

            // ── Map (scrollable) or first-time splash ─────────────────
            Expanded(
              child: attempt != null ? _buildMapContent(context, data) : _buildNoAttemptSplash(context, data),
            ),
          ],
        );
      },
    );
  }
}

// ── Level unlock slide-in animation ──────────────────────────────────────────

/// Wraps a level banner widget and plays a one-shot slide-from-right + fade-in
/// animation to celebrate a newly-unlocked level.
class _LevelUnlockAnimatedBanner extends StatefulWidget {
  const _LevelUnlockAnimatedBanner({required this.child});
  final Widget child;

  @override
  State<_LevelUnlockAnimatedBanner> createState() => _LevelUnlockAnimatedBannerState();
}

class _LevelUnlockAnimatedBannerState extends State<_LevelUnlockAnimatedBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slide = Tween<Offset>(begin: const Offset(0.35, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}

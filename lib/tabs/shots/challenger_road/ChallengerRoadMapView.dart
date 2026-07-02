import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeProgressEntry.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
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
const double _focusedSectionExtraHeight = 96.0;
const double _focusExpandPerStep = 16.0;
const double _focusMaxNodeShift = 48.0;
const double _roadBoundaryLineHeight = 82.0;
const double _previewBannerHeight = 58.0; // approx height of the free-mode Card banner
const double _edgeFocusBufferMin = 100.0;
const double _edgeFocusBufferMax = 200.0;
const double _edgeFocusBufferFactor = 0.22;
// Height of a collapsed (non-active) level section – shows only the banner pill.
// Extra headroom accounts for the "LEVEL X" indicator text above the banner pill
// and the challenge-count row below it.
const double _collapsedSectionHeight = _levelSectionExtraTop + _bannerHeight + _levelBottomPad + 56.0;
// Fixed content-height from the top of the top buffer to the centre of the
// first (highest) challenge node.  Used to ensure the top buffer is always
// tall enough that the highest challenge can be scrolled into the focus zone
// on any screen size.
const double _firstNodeBelowTopBuffer = _roadBoundaryLineHeight + _levelSectionExtraTop + _levelTopPad + _nodeDiameter / 2;
const double _victoryBannerHeight = 290.0;
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

class _ChallengeFocusTarget {
  final ChallengerRoadChallenge challenge;
  final int level;
  final double centerYInContent;

  const _ChallengeFocusTarget({
    required this.challenge,
    required this.level,
    required this.centerYInContent,
  });
}

class _ChallengePreviewMedia {
  final String? url;
  final String mediaType;
  final String sourceLabel;

  const _ChallengePreviewMedia({
    required this.url,
    required this.mediaType,
    required this.sourceLabel,
  });

  bool get hasMedia => url != null && url!.isNotEmpty;
}

class _NextIncompleteTarget {
  final int level;
  final int challengeIndex;

  const _NextIncompleteTarget({required this.level, required this.challengeIndex});
}

// ── CustomPainter for within-level path ──────────────────────────────────────

class _LevelPathPainter extends CustomPainter {
  final List<Offset> centres; // node centres in local Stack coordinates
  final Color color;

  const _LevelPathPainter({required this.centres, required this.color});

  /// Walks a cubic bezier at [t] ∈ [0,1].
  static Offset _cubicPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1 - t;
    return p0 * (mt * mt * mt) + p1 * (3 * mt * mt * t) + p2 * (3 * mt * t * t) + p3 * (t * t * t);
  }

  /// Samples [segments] points along the cubic bezier and draws them as
  /// individual dash strokes of [dashLen] with gap [gapLen].
  void _drawDashedCubic(
    Canvas canvas,
    Paint paint,
    Offset from,
    Offset cp1,
    Offset cp2,
    Offset to, {
    int segments = 80,
    double dashLen = 6.0,
    double gapLen = 9.0,
  }) {
    // Estimate the path length via sampled points so dashes scale naturally.
    double totalLength = 0;
    final pts = List.generate(segments + 1, (i) => _cubicPoint(from, cp1, cp2, to, i / segments));
    for (int i = 1; i <= segments; i++) {
      totalLength += (pts[i] - pts[i - 1]).distance;
    }

    final cycleLen = dashLen + gapLen;
    double drawn = 0;
    double distAccum = 0;
    int ptIdx = 1;

    while (ptIdx <= segments) {
      final segStart = pts[ptIdx - 1];
      final segEnd = pts[ptIdx];
      final segLen = (segEnd - segStart).distance;
      double segConsumed = 0;

      while (segConsumed < segLen) {
        final posInCycle = drawn % cycleLen;
        final remaining = segLen - segConsumed;

        if (posInCycle < dashLen) {
          // Inside a dash - draw up to the end of this dash or end of segment.
          final dashRemaining = dashLen - posInCycle;
          final stepDist = math.min(dashRemaining, remaining);
          final t0 = (distAccum + segConsumed) / totalLength;
          final t1 = (distAccum + segConsumed + stepDist) / totalLength;
          final a = _cubicPoint(from, cp1, cp2, to, t0.clamp(0.0, 1.0));
          final b = _cubicPoint(from, cp1, cp2, to, t1.clamp(0.0, 1.0));
          canvas.drawLine(a, b, paint);
          segConsumed += stepDist;
          drawn += stepDist;
        } else {
          // Inside a gap - skip.
          final gapRemaining = cycleLen - posInCycle;
          final stepDist = math.min(gapRemaining, remaining);
          segConsumed += stepDist;
          drawn += stepDist;
        }
      }

      distAccum += segLen;
      ptIdx++;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (centres.length < 2) return;

    // Road surface - wide semi-transparent band follows the bezier.
    final roadPaint = Paint()
      ..color = color.withValues(alpha: 0.13)
      ..strokeWidth = 18.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Centre dashed line - red, subtle.
    final dashPaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 1; i < centres.length; i++) {
      final from = centres[i - 1];
      final to = centres[i];
      final midY = (from.dy + to.dy) / 2.0;
      final cp1 = Offset(from.dx, midY);
      final cp2 = Offset(to.dx, midY);

      // Draw road surface first, then dashes on top.
      final roadPath = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);
      canvas.drawPath(roadPath, roadPaint);

      _drawDashedCubic(canvas, dashPaint, from, cp1, cp2, to, dashLen: 7.0, gapLen: 10.0);
    }
  }

  @override
  bool shouldRepaint(_LevelPathPainter old) => old.centres != centres || old.color != color;
}

class _CheckeredFinishLinePainter extends CustomPainter {
  final int rows;

  const _CheckeredFinishLinePainter({this.rows = 3});

  @override
  void paint(Canvas canvas, Size size) {
    if (rows <= 0 || size.width <= 0 || size.height <= 0) return;

    final cell = size.height / rows;
    final cols = (size.width / cell).ceil();
    final darkPaint = Paint()..color = Colors.black87;
    final lightPaint = Paint()..color = Colors.white;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final x = col * cell;
        final y = row * cell;
        final rect = Rect.fromLTWH(x, y, cell, cell);
        final isDark = (row + col).isEven;
        canvas.drawRect(rect, isDark ? darkPaint : lightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckeredFinishLinePainter oldDelegate) => oldDelegate.rows != rows;
}

// ── Column index for snake zigzag pattern ────────────────────────────────────

/// Returns the x-fraction column index for a node at position [i] (0-based).
/// Pattern: 0 (left), 1 (centre), 2 (right), 1 (centre), 0, 1, 2, …
int _colForIndex(int i) {
  final mod = i % 4;
  return mod == 3 ? 1 : mod;
}

/// Compute local Stack [Offset] for each node in a level section.
/// [count]      - number of challenges
/// [stackWidth] - pixel width of the containing Stack
/// Nodes are laid out top-to-bottom (seq 0 at top).
/// The level banner now sits at the *bottom* of the section, so nodes start
/// from the top with only the top padding offset.
List<Offset> _computeNodeCentres(int count, double stackWidth) {
  return List.generate(count, (i) {
    final x = stackWidth * _xFractions[_colForIndex(i)];
    final y = _levelSectionExtraTop + _levelTopPad + (_nodeDiameter / 2) + i * _nodeSpacing;
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
  final VoidCallback? onCloseTap;
  final bool isPreviewMode;
  final int previewMaxLevel;
  final ChallengerRoadAttempt? previewHeaderAttempt;
  final VoidCallback? onPreviewLevelUnlockAttempted;
  final double mapBottomInset;

  /// Bottom offset (from the screen/stack bottom edge) at which the free-mode
  /// "Go Pro" preview banner should be anchored. Should NOT include vp.top.
  /// Defaults to [kBottomNavigationBarHeight] + 8 when not provided.
  final double bannerBottomInset;

  /// Whether a shooting session panel is currently collapsed at the bottom.
  /// Used to add extra clearance to the badges pill in preview mode.
  final bool hasActiveSession;

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
    this.onCloseTap,
    this.isPreviewMode = false,
    this.previewMaxLevel = 1,
    this.previewHeaderAttempt,
    this.onPreviewLevelUnlockAttempted,
    this.mapBottomInset = 16,
    this.bannerBottomInset = kBottomNavigationBarHeight + 8,
    this.hasActiveSession = false,
  });

  @override
  State<ChallengerRoadMapView> createState() => _ChallengerRoadMapViewState();
}

class _ChallengerRoadMapViewState extends State<ChallengerRoadMapView> {
  static const double _focusAcquireDistance = 58;
  static const double _focusRetainDistance = 88;
  static const double _focusHideDistance = 132;

  ChallengerRoadService? _service;
  Future<_CRMapData>? _dataFuture;
  final ScrollController _scrollController = ScrollController();
  bool _didScrollToCurrentLevel = false;
  final List<_ChallengeFocusTarget> _focusTargets = [];
  _ChallengeFocusTarget? _focusedTarget;

  // ── Preview / walkthrough state ───────────────────────────────────────────
  static const String _walkthroughSeenKey = 'challenger_road_preview_walkthrough_seen';
  static const List<({String title, String body, IconData icon})> _walkthroughSlides = [
    (title: 'How Challenger Road Works', body: 'Tap a challenge to open it. Then press Start to try the challenge.', icon: Icons.route_rounded),
    (title: 'Level 1 Is Free', body: 'You can try Level 1 challenges for free.', icon: Icons.sports_hockey),
    (title: 'Level 2 Requires Pro', body: 'When you finish Level 1, you can upgrade to unlock more levels.', icon: Icons.lock_open_rounded),
  ];
  bool _showWalkthrough = false;
  final PageController _walkthroughPageController = PageController();
  int _walkthroughPage = 0;

  // Track the height of each level section so we can scroll to the right level.
  // Key: level number, Value: cumulative top offset from the very top of scroll content.
  final Map<int, double> _levelTopOffsets = {};

  /// When a level is newly unlocked after a session, we store it here so the
  /// corresponding banner can play its slide-in animation on the first rebuild.
  int? _justUnlockedLevel;

  /// The last known current level before a data refresh, used to detect
  /// whether a level-unlock animation should fire.
  int? _previousCurrentLevel;

  /// Levels the user has manually expanded beyond the always-expanded current
  /// active level. Completed and locked levels start collapsed by default.
  final Set<int> _expandedLevels = {};

  // Confetti fired when the user scrolls past the finish line after completing
  // all available levels. Stores the last resolved data for scroll-listener access.
  late final ConfettiController _confettiController;
  bool _confettiFired = false;
  bool _runItBackLoading = false;
  _CRMapData? _lastData;
  // Approximate scroll offset (from content top) of the finish line;
  // updated during layout so the scroll listener knows when to fire.
  double _finishLineContentY = 100.0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _scrollController.addListener(_handleScrollForFocusUpdate);
    if (widget.isPreviewMode) _loadWalkthroughPreference();
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
    _scrollController.removeListener(_handleScrollForFocusUpdate);
    _scrollController.dispose();
    _confettiController.dispose();
    _walkthroughPageController.dispose();
    super.dispose();
  }

  // ── Preview walkthrough helpers ───────────────────────────────────────────

  Future<void> _loadWalkthroughPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_walkthroughSeenKey) ?? false;
    if (!mounted) return;
    setState(() => _showWalkthrough = !seen);
  }

  Future<void> _dismissWalkthrough() async {
    setState(() => _showWalkthrough = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walkthroughSeenKey, true);
  }

  Future<void> _nextWalkthroughPage() async {
    if (_walkthroughPage >= _walkthroughSlides.length - 1) {
      await _dismissWalkthrough();
      return;
    }
    await _walkthroughPageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _promptGoPro() async {
    await presentPaywallIfNeeded(context);
  }

  Future<_CRMapData> _loadMapData() async {
    // Start levels and attempt fetch concurrently – they are independent.
    final levelsFuture = _service!.getAllActiveLevels();
    final attemptFuture = widget.isPreviewMode ? _service!.getActiveAttempt(widget.userId) : _service!.syncActiveAttemptProgress(widget.userId);

    final levels = await levelsFuture;
    ChallengerRoadAttempt? attempt = await attemptFuture;

    if (widget.isPreviewMode && attempt == null) {
      // Ensure free preview users can actually try level 1 challenges.
      attempt = await _service!.createAttempt(widget.userId, 1);
    }

    // Fetch all levels' challenges in parallel (was sequential – big win for 12 levels).
    final challengeLists = await Future.wait(
      levels.map((lvl) => _service!.getChallengesForLevel(lvl)),
    );
    final challengesByLevel = <int, List<ChallengerRoadChallenge>>{};
    for (int i = 0; i < levels.length; i++) {
      // Reverse so sequence 1 appears at the bottom of the level section and
      // the highest sequence appears at the top (bottom-up progression).
      challengesByLevel[levels[i]] = challengeLists[i].reversed.toList();
    }

    // Fetch progress only for the CURRENT level's challenges in parallel.
    // Completed levels show all nodes as completed and locked levels show all
    // nodes as locked in _nodeState() regardless of individual progress entries,
    // so fetching 12×14 = 168 documents eagerly was wasted work.
    final progress = <String, ChallengeProgressEntry>{};
    if (attempt != null) {
      final effectiveCurrentLevel = widget.isPreviewMode ? math.min(attempt.currentLevel, widget.previewMaxLevel) : attempt.currentLevel;
      final currentChallenges = challengesByLevel[effectiveCurrentLevel] ?? const <ChallengerRoadChallenge>[];
      final currentIds = currentChallenges.map((c) => c.id).whereType<String>().toList();

      if (currentIds.isNotEmpty) {
        final entries = await Future.wait(
          currentIds.map((cid) => _service!.getChallengeProgress(widget.userId, attempt!.id!, cid)),
        );
        for (int i = 0; i < currentIds.length; i++) {
          final p = entries[i];
          if (p != null) progress[currentIds[i]] = p;
        }
      }
    }

    final result = _CRMapData(
      levels: levels,
      challengesByLevel: challengesByLevel,
      activeAttempt: attempt,
      progress: progress,
    );

    _lastData = result;

    // Silently catch up any badges the user earned before they were defined.
    // Runs in the background - does not block map rendering.
    if (!widget.isPreviewMode) {
      _service!.awardMissingTrophies(widget.userId).catchError((Object e, StackTrace st) {
        debugPrint('[ChallengerRoad] awardMissingTrophies failed: $e\n$st');
        return <String>[];
      });
    }

    return result;
  }

  bool _isRoadComplete(_CRMapData data) {
    // Road-complete is a data state: the attempt's currentLevel has been
    // advanced past the last active level by advanceLevel(). This is true
    // regardless of subscription/preview state - a non-pro user can never
    // reach currentLevel > levels.last because they cannot play level-2+
    // challenges to trigger advanceLevel().
    if (data.activeAttempt == null || data.levels.isEmpty) return false;
    return data.activeAttempt!.currentLevel > data.levels.last;
  }

  void _refreshData({bool scrollToBottom = false}) {
    setState(() {
      _didScrollToCurrentLevel = false;
      _confettiFired = false;
      _lastData = null;
      _levelTopOffsets.clear();
      _expandedLevels.clear();
      _focusTargets.clear();
      _focusedTarget = null;
      _dataFuture = _loadMapData().then((data) {
        final newLevel = data.activeAttempt?.currentLevel;
        if (newLevel != null && _previousCurrentLevel != null && newLevel > _previousCurrentLevel!) {
          // A level advance happened - flag the new level for its unlock animation.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _justUnlockedLevel = newLevel);
          });
        }
        _previousCurrentLevel = newLevel;
        if (scrollToBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
              );
            }
          });
        }
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

    // When the road is complete, lock all nodes until the user runs it back.
    if (_isRoadComplete(data)) return ChallengeNodeState.locked;

    final currentLevel = widget.isPreviewMode ? math.min(attempt.currentLevel, widget.previewMaxLevel) : attempt.currentLevel;
    if (level < currentLevel) return ChallengeNodeState.completed;
    if (level > currentLevel) return ChallengeNodeState.locked;

    // level == currentLevel
    final bestLevel = data.progress[challengeId]?.bestLevel ?? 0;
    if (bestLevel >= level) return ChallengeNodeState.completed;
    return isFirstIncomplete ? ChallengeNodeState.current : ChallengeNodeState.available;
  }

  _NextIncompleteTarget? _findNextIncompleteTarget(_CRMapData data) {
    final attempt = data.activeAttempt;
    if (attempt == null) return null;

    final currentLevel = widget.isPreviewMode ? math.min(attempt.currentLevel, widget.previewMaxLevel) : attempt.currentLevel;
    final currentLevelChallenges = data.challengesByLevel[currentLevel] ?? const <ChallengerRoadChallenge>[];

    // Match map behavior: scan bottom-most node upward for the next incomplete.
    for (int i = currentLevelChallenges.length - 1; i >= 0; i--) {
      final challengeId = currentLevelChallenges[i].id ?? '';
      final bestLevel = data.progress[challengeId]?.bestLevel ?? 0;
      if (bestLevel < currentLevel) {
        return _NextIncompleteTarget(level: currentLevel, challengeIndex: i);
      }
    }

    // Fallback when current level appears fully complete but attempt has not advanced yet.
    if (currentLevelChallenges.isNotEmpty) {
      return _NextIncompleteTarget(level: currentLevel, challengeIndex: currentLevelChallenges.length - 1);
    }

    return null;
  }

  // Scroll so the next incomplete challenge is centered/focused on first load.
  void _scrollToNextIncomplete(_CRMapData data) {
    if (_didScrollToCurrentLevel) return;
    _didScrollToCurrentLevel = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // Road complete - glide to the victory banner at the top.
      if (_isRoadComplete(data)) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeInOutCubic,
        );
        return;
      }

      final nextIncomplete = _findNextIncompleteTarget(data);

      if (nextIncomplete != null) {
        final levelTop = _levelTopOffsets[nextIncomplete.level];
        final levelChallenges = data.challengesByLevel[nextIncomplete.level] ?? const <ChallengerRoadChallenge>[];
        if (levelTop != null && nextIncomplete.challengeIndex >= 0 && nextIncomplete.challengeIndex < levelChallenges.length) {
          final nodeCentres = _computeNodeCentres(levelChallenges.length, 1);
          // When the node becomes focused, the level expands and shifts centres
          // down by half of the extra section height. Include that now so the
          // intended "next incomplete" node remains centered after focus locks.
          final nodeCenterYInContent = levelTop + nodeCentres[nextIncomplete.challengeIndex].dy + (_focusedSectionExtraHeight / 2);
          final desiredOffset = nodeCenterYInContent - (_scrollController.position.viewportDimension / 2);
          final scrollTo = desiredOffset.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.animateTo(
            scrollTo,
            duration: const Duration(milliseconds: 920),
            curve: Curves.easeInOutCubic,
          );
          return;
        }
      }

      final currentLevel = widget.isPreviewMode ? math.min(data.activeAttempt?.currentLevel ?? 1, widget.previewMaxLevel) : (data.activeAttempt?.currentLevel ?? 1);
      final currentLevelTop = _levelTopOffsets[currentLevel];
      if (currentLevelTop != null) {
        final scrollTo = (currentLevelTop - 16.0).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          scrollTo,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      } else {
        // Final fallback: scroll to the bottom where Level 1 lives.
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _handleScrollForFocusUpdate() {
    _updateFocusedTarget();
    _checkConfettiTrigger();
  }

  void _checkConfettiTrigger() {
    if (_confettiFired) return;
    final data = _lastData;
    if (data == null || !_isRoadComplete(data)) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset <= _finishLineContentY) {
      _confettiFired = true;
      _confettiController.play();
    }
  }

  void _scheduleFocusTargets(List<_ChallengeFocusTarget> targets) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusTargets
        ..clear()
        ..addAll(targets);
      _updateFocusedTarget();
    });
  }

  void _updateFocusedTarget() {
    if (!_scrollController.hasClients || _focusTargets.isEmpty) return;

    final viewportCenterY = _scrollController.offset + (_scrollController.position.viewportDimension / 2);

    _ChallengeFocusTarget? nearest;
    double nearestDistance = double.infinity;
    for (final target in _focusTargets) {
      final distance = (target.centerYInContent - viewportCenterY).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = target;
      }
    }

    if (nearest == null) return;

    final current = _focusedTarget;
    _ChallengeFocusTarget? next = current;

    if (current == null) {
      if (nearestDistance <= _focusAcquireDistance) {
        next = nearest;
      }
    } else {
      _ChallengeFocusTarget? currentLive;
      for (final target in _focusTargets) {
        if (target.challenge.id == current.challenge.id && target.level == current.level) {
          currentLive = target;
          break;
        }
      }

      final currentDistance = currentLive == null ? double.infinity : (currentLive.centerYInContent - viewportCenterY).abs();
      final isNearestCurrent = nearest.challenge.id == current.challenge.id && nearest.level == current.level;

      if (isNearestCurrent) {
        if (nearestDistance > _focusHideDistance) {
          next = null;
        } else {
          next = nearest;
        }
      } else {
        if (currentDistance <= _focusRetainDistance) {
          next = currentLive ?? current;
        } else if (nearestDistance <= _focusAcquireDistance) {
          next = nearest;
        } else if (currentDistance > _focusHideDistance) {
          next = null;
        }
      }
    }

    final isSame = _focusedTarget?.challenge.id == next?.challenge.id && _focusedTarget?.level == next?.level;
    if (isSame) return;

    setState(() {
      _focusedTarget = next;
    });
  }

  bool _isChallengeFocused(String challengeId, int level) {
    final focused = _focusedTarget;
    if (focused == null) return false;
    return focused.challenge.id == challengeId && focused.level == level;
  }

  int _focusedIndexForLevel(List<ChallengerRoadChallenge> challenges, int level) {
    final focused = _focusedTarget;
    if (focused == null || focused.level != level) return -1;
    return challenges.indexWhere((c) => c.id == focused.challenge.id);
  }

  /// Returns true when [level] should be fully expanded (nodes visible).
  /// The current active level is always expanded; others expand only when the
  /// user taps their collapsed banner.
  bool _isLevelExpanded(int level, int currentLevel) => level == currentLevel || _expandedLevels.contains(level);

  /// Expands [level] and scrolls so the section is visible near the upper
  /// portion of the viewport. The scroll runs concurrently with the expand
  /// animation so both complete at around the same time.
  void _expandLevel(int level) {
    setState(() => _expandedLevels.add(level));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final levelTop = _levelTopOffsets[level];
      if (levelTop == null) return;
      final viewport = _scrollController.position.viewportDimension;
      final target = (levelTop - viewport * 0.2).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  double _effectiveLevelSectionHeight(
    List<ChallengerRoadChallenge> challenges,
    int level, {
    required bool interactive,
    required int currentLevel,
  }) {
    if (interactive && !_isLevelExpanded(level, currentLevel)) {
      return _collapsedSectionHeight;
    }
    final focusedIndex = interactive ? _focusedIndexForLevel(challenges, level) : -1;
    return _levelSectionHeight(challenges.length) + (focusedIndex >= 0 ? _focusedSectionExtraHeight : 0);
  }

  List<Offset> _expandedNodeCentres(
    List<Offset> baseCentres,
    int focusedIndex,
  ) {
    if (focusedIndex < 0) return baseCentres;

    return List.generate(baseCentres.length, (i) {
      double shiftY = 0;
      if (i < focusedIndex) {
        shiftY = -math.min(_focusMaxNodeShift, (focusedIndex - i) * _focusExpandPerStep);
      } else if (i > focusedIndex) {
        shiftY = math.min(_focusMaxNodeShift, (i - focusedIndex) * _focusExpandPerStep);
      }

      // Keep the expanded cluster centered in the taller section.
      return Offset(
        baseCentres[i].dx,
        baseCentres[i].dy + (_focusedSectionExtraHeight / 2) + shiftY,
      );
    });
  }

  _ChallengePreviewMedia _resolvePreviewMedia(ChallengerRoadChallenge challenge) {
    final thumbnail = (challenge.previewThumbnailUrl ?? '').trim();
    if (thumbnail.isNotEmpty) {
      return _ChallengePreviewMedia(
        url: thumbnail,
        mediaType: (challenge.previewThumbnailMediaType ?? 'image').toLowerCase(),
        sourceLabel: 'Thumbnail',
      );
    }

    final sortedSteps = [...challenge.steps]..sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
    for (final step in sortedSteps) {
      final url = step.mediaUrl.trim();
      if (url.isNotEmpty) {
        return _ChallengePreviewMedia(
          url: url,
          mediaType: step.mediaType.toLowerCase(),
          sourceLabel: 'Step ${step.stepNumber}',
        );
      }
    }

    return const _ChallengePreviewMedia(
      url: null,
      mediaType: 'none',
      sourceLabel: 'No media',
    );
  }

  Widget _buildPreviewMedia(BuildContext context, _ChallengePreviewMedia media) {
    // Map view always shows static frames – no video cycling or live players.
    if (!media.hasMedia) {
      return _buildPreviewMediaPlaceholder(context, icon: Icons.photo_library_outlined, label: 'Preview coming soon');
    }

    if (media.mediaType == 'video' || media.mediaType == 'webm') {
      // Extract a single static thumbnail; never cycle frames or use VideoPlayerController.
      return _VideoFrameScrubber(
        url: media.url!,
        focused: false,
        placeholderBuilder: (ctx) => _buildPreviewMediaPlaceholder(ctx, icon: Icons.play_circle_fill_rounded, label: 'Video preview'),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        media.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPreviewMediaPlaceholder(context, icon: Icons.broken_image_outlined, label: 'Media unavailable'),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewMediaPlaceholder(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.2),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirm restart dialog ────────────────────────────────────────────────

  /// Shown when the user taps "RUN IT BACK" on the victory banner.
  /// Completes the current attempt and starts a brand-new one.
  /// If the player has inherited unlocks, they can choose to skip ahead or
  /// go for the full grind from Level 1.
  void _confirmRunItBack(BuildContext context) {
    final highestReached = _lastData?.activeAttempt?.highestLevelReachedThisAttempt ?? 1;
    final nextInherited = (highestReached - 1).clamp(0, 999);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.80),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: _RunItBackDialogContent(
          nextInherited: nextInherited,
          onFullGrind: () async {
            Navigator.of(dialogContext).pop();
            setState(() => _runItBackLoading = true);
            await _service!.runItBack(widget.userId, chosenStartingLevel: 1);
            if (mounted) setState(() => _runItBackLoading = false);
            _refreshData(scrollToBottom: true);
          },
          onJumpIn: () async {
            Navigator.of(dialogContext).pop();
            setState(() => _runItBackLoading = true);
            await _service!.runItBack(widget.userId, chosenStartingLevel: nextInherited + 1);
            if (mounted) setState(() => _runItBackLoading = false);
            _refreshData(scrollToBottom: true);
          },
          onCancel: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  void _confirmRestart(BuildContext context, ChallengerRoadAttempt attempt) {
    final isDoOver = attempt.resetCount == 0;
    final title = isDoOver ? 'Start Over?' : 'Restart Challenger Road?';

    // Compute inherited unlocks for the post-10k restart path.
    final nextInherited = isDoOver ? 0 : (attempt.highestLevelReachedThisAttempt - 1).clamp(0, 999);

    final body = isDoOver
        ? 'Your shot count and challenge progress for this attempt will be cleared. '
            'Your attempt number stays the same.\n\nThis is a do-over, not a new attempt.'
        : nextInherited >= 1
            ? 'Your current attempt will end. Your last run unlocks levels 1–$nextInherited - pick where you start next.'
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
          if (!isDoOver && nextInherited >= 1)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _service!.restartChallengerRoad(widget.userId, chosenStartingLevel: nextInherited + 1);
                _refreshData();
              },
              child: Text(
                'Jump to Level ${nextInherited + 1}',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _service!.restartChallengerRoad(
                widget.userId,
                chosenStartingLevel: isDoOver ? null : 1,
              );
              _refreshData();
            },
            child: Text(
              isDoOver
                  ? 'Restart'
                  : nextInherited >= 1
                      ? 'Full Grind - Start from Level 1'
                      : 'Restart',
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

  Widget _buildRoadBoundaryLine(
    BuildContext context, {
    required String label,
    required bool isFinish,
  }) {
    final accent = isFinish ? Colors.green.shade400 : Theme.of(context).primaryColor;
    return SizedBox(
      height: _roadBoundaryLineHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.1),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 12,
                letterSpacing: 0.8,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (isFinish)
            SizedBox(
              height: 18,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: CustomPaint(
                  painter: const _CheckeredFinishLinePainter(rows: 3),
                  size: const Size(double.infinity, 18),
                ),
              ),
            )
          else
            Divider(
              height: 1,
              thickness: 2,
              color: accent.withValues(alpha: 0.75),
            ),
        ],
      ),
    );
  }

  // ── Map content (scrollable) ──────────────────────────────────────────────

  Widget _buildMapContent(
    BuildContext context,
    _CRMapData data, {
    bool interactive = true,
  }) {
    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        final levels = data.levels.reversed.toList();
        final edgeFocusBuffer = (viewportConstraints.maxHeight * _edgeFocusBufferFactor).clamp(
          _edgeFocusBufferMin,
          _edgeFocusBufferMax,
        );
        // Ensure the top buffer is always large enough that the highest
        // challenge node can be scrolled into the focus acquisition zone
        // on every screen size (including small devices like the S20 Ultra).
        // Formula: at minScrollExtent the node must be within _focusAcquireDistance
        // of the viewport centre → topBuffer ≥ viewportH/2 - _firstNodeBelowTopBuffer + _focusAcquireDistance.
        final topEdgeFocusBuffer = math.max(
          edgeFocusBuffer,
          viewportConstraints.maxHeight / 2 - _firstNodeBelowTopBuffer + _focusAcquireDistance,
        );
        final roadComplete = _isRoadComplete(data);
        final topStaticHeight = topEdgeFocusBuffer + (roadComplete ? _victoryBannerHeight : 0) + _roadBoundaryLineHeight;

        // Compute currentLevel once for the whole layout pass so collapsed/expanded
        // decisions are consistent across offset calculation and rendering.
        final currentLevel = widget.isPreviewMode ? math.min(data.activeAttempt?.currentLevel ?? 1, widget.previewMaxLevel) : (data.activeAttempt?.currentLevel ?? 1);

        // Compute cumulative offsets for scroll-to-level after top buffer + finish line.
        double cumulativeOffset = topStaticHeight;
        for (final lvl in levels) {
          _levelTopOffsets[lvl] = cumulativeOffset;
          final challenges = data.challengesByLevel[lvl] ?? const <ChallengerRoadChallenge>[];
          cumulativeOffset += _effectiveLevelSectionHeight(
            challenges,
            lvl,
            interactive: interactive,
            currentLevel: currentLevel,
          );
        }

        final focusTargets = <_ChallengeFocusTarget>[];
        double sectionTopOffset = topStaticHeight;

        // Store the finish line scroll position so the confetti listener knows
        // when the user has crossed it. Victory banner sits above the line.
        final finishLineY = topEdgeFocusBuffer + (roadComplete ? _victoryBannerHeight : 0);
        _finishLineContentY = finishLineY;

        if (interactive) {
          _scheduleFocusTargets(focusTargets);
        }

        return SingleChildScrollView(
          controller: interactive ? _scrollController : null,
          child: Column(
            children: [
              SizedBox(height: topEdgeFocusBuffer),
              if (roadComplete) _buildVictoryBanner(context, data),
              _buildRoadBoundaryLine(
                context,
                label: 'FINISH LINE',
                isFinish: true,
              ),
              for (int lvlIdx = 0; lvlIdx < levels.length; lvlIdx++)
                (() {
                  final lvl = levels[lvlIdx];
                  final sectionTop = sectionTopOffset;
                  final challenges = data.challengesByLevel[lvl] ?? const <ChallengerRoadChallenge>[];
                  sectionTopOffset += _effectiveLevelSectionHeight(
                    challenges,
                    lvl,
                    interactive: interactive,
                    currentLevel: currentLevel,
                  );
                  // Pass info about the section immediately below so this
                  // section can draw an accurate cross-level connector into it.
                  // Rendering downward means the lower section (painted later)
                  // naturally covers the connector with its own nodes. ✓
                  // Skip connectors when the adjacent section is collapsed.
                  List<ChallengerRoadChallenge>? belowChallenges;
                  if (lvlIdx < levels.length - 1) {
                    final belowLevel = levels[lvlIdx + 1];
                    if (!interactive || _isLevelExpanded(belowLevel, currentLevel)) {
                      belowChallenges = data.challengesByLevel[belowLevel] ?? const <ChallengerRoadChallenge>[];
                    }
                  }
                  final int? belowLevelChallengeCount = belowChallenges?.length;
                  // The focused index of the below-level is needed so the
                  // connector endpoint tracks the exit node's expanded position.
                  final int? belowFocusedIndex = (belowChallenges != null && interactive) ? _focusedIndexForLevel(belowChallenges, levels[lvlIdx + 1]) : null;
                  return _buildLevelSection(
                    context,
                    lvl,
                    data,
                    sectionTopOffset: sectionTop,
                    focusTargets: focusTargets,
                    interactive: interactive,
                    currentLevel: currentLevel,
                    belowLevelChallengeCount: belowLevelChallengeCount,
                    belowFocusedIndex: belowFocusedIndex,
                  );
                })(),
              _buildRoadBoundaryLine(
                context,
                label: 'START LINE',
                isFinish: false,
              ),
              SizedBox(height: (edgeFocusBuffer * 0.30) + widget.mapBottomInset + (widget.isPreviewMode ? _previewBannerHeight + 8 : 0)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLevelSection(
    BuildContext context,
    int level,
    _CRMapData data, {
    required double sectionTopOffset,
    required List<_ChallengeFocusTarget> focusTargets,
    bool interactive = true,
    required int currentLevel,
    int? belowLevelChallengeCount,
    int? belowFocusedIndex,
  }) {
    final challenges = data.challengesByLevel[level] ?? [];
    final attempt = data.activeAttempt;
    final isCurrentLevel = level == currentLevel;
    final isLocked = level > currentLevel;
    final isExpanded = !interactive || _isLevelExpanded(level, currentLevel);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final focusedIndex = interactive ? _focusedIndexForLevel(challenges, level) : -1;
        final baseCentres = _computeNodeCentres(challenges.length, width);
        final centres = _expandedNodeCentres(baseCentres, focusedIndex);
        final fullSectionHeight = _levelSectionHeight(challenges.length) + (focusedIndex >= 0 ? _focusedSectionExtraHeight : 0);

        // ── Collapsed (lazy – no challenge nodes are built) ───────────────────
        if (!isExpanded) {
          final statusColor = isLocked ? Colors.grey.shade500.withValues(alpha: 0.75) : Colors.green.shade400.withValues(alpha: 0.75);
          return ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _expandLevel(level),
                child: SizedBox(
                  height: _collapsedSectionHeight,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLevelBanner(
                          context,
                          level,
                          challenges.isNotEmpty ? challenges.first.levelName : 'Level $level',
                          isCurrentLevel,
                          isLocked,
                          levelNumber: level,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLocked ? Icons.lock_outline : Icons.check_circle_outline,
                              size: 11,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${challenges.length} challenge${challenges.length == 1 ? '' : 's'}  ·  tap to expand',
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 11,
                                letterSpacing: 0.4,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // ── Expanded ──────────────────────────────────────────────────────────
        // Determine next incomplete challenge for "current" state.
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

        final isCompletedLevel = !isLocked && !isCurrentLevel;
        final pathColor = isLocked
            ? const Color(0xFFB0B0B0).withValues(alpha: 0.35)
            : isCompletedLevel
                ? const Color(0xFF2E7D32).withValues(alpha: 0.70)
                : const Color(0xFFCC2200).withValues(alpha: 0.75);
        final connectorColor = isLocked ? const Color(0xFFB0B0B0).withValues(alpha: 0.35) : const Color(0xFF2E7D32).withValues(alpha: 0.70);

        Widget? connectorPaint;
        if (belowLevelChallengeCount != null && belowLevelChallengeCount > 0 && centres.isNotEmpty) {
          final belowExitX = width * _xFractions[_colForIndex(0)];
          double belowExitLocalY = _levelSectionExtraTop + _levelTopPad + (_nodeDiameter / 2);
          final int bfi = belowFocusedIndex ?? -1;
          if (bfi >= 0) {
            final shiftForTopNode = bfi == 0 ? 0.0 : -math.min(_focusMaxNodeShift, bfi * _focusExpandPerStep);
            belowExitLocalY += _focusedSectionExtraHeight / 2 + shiftForTopNode;
          }
          final connStartY = centres.last.dy + (_nodeDiameter / 2);
          final connEndY = fullSectionHeight + belowExitLocalY;
          final connHeight = connEndY - connStartY;
          if (connHeight > 0) {
            connectorPaint = Positioned(
              top: connStartY,
              left: 0,
              right: 0,
              height: connHeight,
              child: CustomPaint(
                painter: _LevelPathPainter(
                  centres: [Offset(centres.last.dx, 0), Offset(belowExitX, connHeight)],
                  color: connectorColor,
                ),
              ),
            );
          }
        }

        return ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: fullSectionHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Cross-level connector ─────────────────────────────────
                  if (connectorPaint != null) connectorPaint,

                  // ── Path ─────────────────────────────────────────────────
                  if (challenges.length > 1)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LevelPathPainter(centres: centres, color: pathColor),
                      ),
                    ),

                  // ── Level banner (tap to collapse for non-current) ────────
                  Positioned(
                    bottom: _levelBottomPad,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (interactive && !isCurrentLevel) ...[
                            GestureDetector(
                              onTap: () => setState(() => _expandedLevels.remove(level)),
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          GestureDetector(
                            onTap: (interactive && !isCurrentLevel) ? () => setState(() => _expandedLevels.remove(level)) : null,
                            child: _buildLevelBanner(
                              context,
                              level,
                              challenges.isNotEmpty ? challenges.first.levelName : 'Level $level',
                              isCurrentLevel,
                              isLocked,
                              levelNumber: level,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Challenge nodes ───────────────────────────────────────
                  for (int i = 0; i < challenges.length; i++)
                    ...(() {
                      final challenge = challenges[i];
                      final challengeId = challenge.id ?? '';
                      final nodeCenter = centres[i];
                      final nodeState = _nodeState(challengeId, level, data, i == firstIncompleteIdx);

                      focusTargets.add(
                        _ChallengeFocusTarget(
                          challenge: challenge,
                          level: level,
                          centerYInContent: sectionTopOffset + nodeCenter.dy,
                        ),
                      );

                      final isFocused = interactive && _isChallengeFocused(challengeId, level);
                      final isSubscriptionLocked = widget.isPreviewMode && nodeState == ChallengeNodeState.locked;
                      final challengeTap = interactive && attempt != null && (nodeState != ChallengeNodeState.locked || isSubscriptionLocked) ? () => _handleNodeTap(challenge, level, attempt, data, isSubscriptionLocked: isSubscriptionLocked) : null;
                      final previewMedia = _resolvePreviewMedia(challenge);
                      const thumbWidth = 156.0;
                      const thumbHeight = 156.0;
                      const sideGap = 40.0;
                      const verticalUpOffset = -14.0;
                      const minLeft = 8.0;
                      const minTop = 6.0;
                      final maxLeft = width - thumbWidth - 8.0;
                      final maxTop = fullSectionHeight - thumbHeight - 6.0;
                      final leftSpace = nodeCenter.dx;
                      final rightSpace = width - nodeCenter.dx;

                      final prev = i > 0 ? centres[i - 1] : null;
                      final next = i + 1 < centres.length ? centres[i + 1] : null;

                      double directionDx;
                      if (prev != null && next != null) {
                        directionDx = next.dx - prev.dx;
                      } else if (next != null) {
                        directionDx = next.dx - nodeCenter.dx;
                      } else if (prev != null) {
                        directionDx = nodeCenter.dx - prev.dx;
                      } else {
                        directionDx = 0;
                      }

                      bool revealOnRight;
                      if (directionDx.abs() < 2.0) {
                        revealOnRight = rightSpace >= leftSpace;
                      } else {
                        revealOnRight = directionDx > 0;
                      }

                      final offsetUp = prev != null && next != null;
                      final xPct = width <= 0 ? 0.5 : (nodeCenter.dx / width);
                      final isEdgeColumn = xPct <= 0.34 || xPct >= 0.66;
                      final nonEdgeExtraUpOffset = isEdgeColumn ? 0.0 : -(_nodeDiameter / 2);

                      final rawTop = (nodeCenter.dy - (thumbHeight / 2)) + (offsetUp ? verticalUpOffset : 0.0) + nonEdgeExtraUpOffset;
                      final thumbTop = rawTop.clamp(minTop, maxTop);

                      double clampedLeftForSide(bool sideRight) {
                        final rawLeft = sideRight ? (nodeCenter.dx + sideGap) : (nodeCenter.dx - thumbWidth - sideGap);
                        return rawLeft.clamp(minLeft, maxLeft);
                      }

                      double horizontalOverlap(double thumbLeft) {
                        final thumbRight = thumbLeft + thumbWidth;
                        final nodeLeft = nodeCenter.dx - (_nodeDiameter / 2);
                        final nodeRight = nodeCenter.dx + (_nodeDiameter / 2);
                        final overlap = math.min(thumbRight, nodeRight) - math.max(thumbLeft, nodeLeft);
                        return math.max(0, overlap);
                      }

                      final preferredLeft = clampedLeftForSide(revealOnRight);
                      final oppositeLeft = clampedLeftForSide(!revealOnRight);
                      final preferredOverlap = horizontalOverlap(preferredLeft);
                      final oppositeOverlap = horizontalOverlap(oppositeLeft);

                      if (preferredOverlap > 8 && oppositeOverlap + 2 < preferredOverlap) {
                        revealOnRight = !revealOnRight;
                      }

                      final thumbLeft = clampedLeftForSide(revealOnRight);

                      return [
                        Positioned(
                          left: thumbLeft,
                          top: thumbTop,
                          width: thumbWidth,
                          height: thumbHeight,
                          child: IgnorePointer(
                            ignoring: !isFocused || challengeTap == null,
                            child: GestureDetector(
                              onTap: challengeTap,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                opacity: isFocused ? 1 : 0,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  scale: isFocused ? 1 : 0.96,
                                  child: AnimatedSlide(
                                    duration: const Duration(milliseconds: 190),
                                    curve: Curves.easeOutCubic,
                                    offset: isFocused ? Offset.zero : (revealOnRight ? const Offset(-0.18, 0) : const Offset(0.18, 0)),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context).primaryColor.withValues(alpha: 0.45),
                                          width: 1.1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.24),
                                            blurRadius: 14,
                                            offset: const Offset(0, 7),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: thumbWidth,
                                          height: thumbHeight,
                                          child: _buildPreviewMedia(context, previewMedia),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: nodeCenter.dx - 41,
                          top: nodeCenter.dy - (_nodeDiameter / 2),
                          child: ChallengeMapNode(
                            challengeName: challenge.name,
                            state: nodeState,
                            onTap: challengeTap,
                          ),
                        ),
                      ];
                    })(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Victory banner (shown above FINISH LINE when all levels complete) ──────

  Widget _buildVictoryBanner(BuildContext context, _CRMapData data) {
    final accent = Theme.of(context).primaryColor;
    return SizedBox(
      height: _victoryBannerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Trophy icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 28,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              'YOU\'VE CONQUERED\nCHALLENGER ROAD!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 26,
                color: accent,
                height: 1.2,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Every challenge. Every level. Think you can do it with less shots?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _confirmRunItBack(context),
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: const Text(
                'RUN IT BACK',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Level banner (with optional unlock animation) ─────────────────────────

  Widget _buildLevelBanner(
    BuildContext context,
    int level,
    String levelName,
    bool isCurrentLevel,
    bool isLocked, {
    int? levelNumber,
  }) {
    final banner = LevelBannerWidget(
      levelName: levelName,
      isCurrentLevel: isCurrentLevel,
      isLocked: isLocked,
      level: levelNumber,
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
    _CRMapData data, {
    bool isSubscriptionLocked = false,
  }) async {
    final levelDoc = challenge.toLevelDoc();
    if (!mounted) return;

    // If the road is already complete, don't let the user play challenges -
    // prompt them to Run It Back instead.
    if (_isRoadComplete(data) && !isSubscriptionLocked) {
      _confirmRunItBack(context);
      return;
    }

    if (widget.onChallengeTap != null) {
      widget.onChallengeTap!(challenge, levelDoc, attempt);
      return;
    }

    // Default: show the challenge detail sheet.
    // For subscription-locked challenges (preview mode, level > 1) we show
    // a history-only view – no steps, no start CTA – so users can still review
    // their past tries even if their subscription has lapsed.
    await ChallengeDetailSheet.show(
      context,
      challenge: challenge,
      levelDoc: levelDoc,
      attempt: attempt,
      userId: widget.userId,
      progress: data.progress[challenge.id],
      onSessionComplete: isSubscriptionLocked ? null : _refreshData,
      isPreviewMode: widget.isPreviewMode,
      previewMaxLevel: widget.previewMaxLevel,
      onPreviewLevelUnlockAttempted: widget.onPreviewLevelUnlockAttempted,
      isSubscriptionLocked: isSubscriptionLocked,
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

        // Scroll to and focus the next incomplete challenge once data is loaded.
        if (attempt != null) _scrollToNextIncomplete(data);

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

        // Resolve the display label for the current level in the header.
        String levelLabel;
        if (_isRoadComplete(data)) {
          levelLabel = 'COMPLETE';
        } else {
          final currentLevel = widget.isPreviewMode ? math.min(attempt?.currentLevel ?? 1, widget.previewMaxLevel) : (attempt?.currentLevel ?? 1);
          final currentChallenges = data.challengesByLevel[currentLevel];
          levelLabel = (currentChallenges != null && currentChallenges.isNotEmpty) ? currentChallenges.first.levelName.toUpperCase() : 'LVL $currentLevel';
        }

        return Column(
          children: [
            // ── Header (pinned below app header) ───────────────────────
            ChallengerRoadHeader(
              attempt: widget.isPreviewMode ? (widget.previewHeaderAttempt ?? attempt) : attempt,
              levelLabel: levelLabel,
              levelNumber: _isRoadComplete(data) ? null : (widget.isPreviewMode ? math.min(attempt?.currentLevel ?? 1, widget.previewMaxLevel) : attempt?.currentLevel),
              topPadding: MediaQuery.of(context).padding.top,
              onRestartTap: attempt != null ? () => _confirmRestart(context, attempt) : null,
              onCloseTap: widget.onCloseTap,
            ),

            // ── Map (scrollable) or first-time splash ─────────────────
            Expanded(
              child: Stack(
                children: [
                  attempt != null ? _buildMapContent(context, data) : _buildNoAttemptSplash(context, data),
                  // Confetti burst when the user crosses the finish line
                  if (_isRoadComplete(data))
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        maxBlastForce: 55,
                        minBlastForce: 18,
                        emissionFrequency: 0.04,
                        numberOfParticles: 28,
                        gravity: 0.35,
                        shouldLoop: false,
                        colors: const [
                          Color(0xFFFFD700),
                          Color(0xFF4CAF50),
                          Colors.white,
                          Color(0xFF2196F3),
                          Color(0xFFFF5722),
                        ],
                      ),
                    ),
                  // Loading overlay shown while "Run It Back" processes.
                  if (_runItBackLoading)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  // ── Free mode banner (preview only) ───────────────────
                  if (widget.isPreviewMode) _buildPreviewBanner(context),
                  // ── First-time walkthrough overlay (preview only) ─────
                  if (widget.isPreviewMode && _showWalkthrough) _buildWalkthroughCard(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Preview mode UI helpers ───────────────────────────────────────────────

  Widget _buildPreviewBanner(BuildContext context) {
    return Positioned(
      left: 14,
      right: 14,
      bottom: widget.bannerBottomInset,
      child: Card(
        color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.95),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.55)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Free mode: play all Level 1 challenges. Pro unlocks Level 2 and beyond.',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _promptGoPro,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'GO PRO',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalkthroughCard(BuildContext context) {
    final isLast = _walkthroughPage == _walkthroughSlides.length - 1;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 270,
                  child: PageView.builder(
                    controller: _walkthroughPageController,
                    itemCount: _walkthroughSlides.length,
                    onPageChanged: (index) => setState(() => _walkthroughPage = index),
                    itemBuilder: (context, index) {
                      final slide = _walkthroughSlides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(slide.icon, size: 44, color: Theme.of(context).primaryColor),
                            const SizedBox(height: 14),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 22,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              slide.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 16,
                                height: 1.35,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_walkthroughSlides.length, (i) {
                    final selected = i == _walkthroughPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: selected ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selected ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: _dismissWalkthrough,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        textStyle: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 17,
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _nextWalkthroughPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      ),
                      child: Text(isLast ? 'Get Started' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

// ── Video frame scrubber (map thumbnail) ─────────────────────────────────────

/// Loads a video silently and cycles through still frames sampled every 10 s,
/// producing a GIF-like preview without playing the full video at normal speed.
/// Frame loading is split into two phases:
///   1. First frame is extracted eagerly in the background for all video previews.
///   2. Remaining frames are extracted and cycling starts only when [focused] is true.
class _VideoFrameScrubber extends StatefulWidget {
  final String url;
  final bool focused;
  final Widget Function(BuildContext) placeholderBuilder;

  const _VideoFrameScrubber({
    required this.url,
    required this.focused,
    required this.placeholderBuilder,
  });

  @override
  State<_VideoFrameScrubber> createState() => _VideoFrameScrubberState();
}

class _VideoFrameScrubberState extends State<_VideoFrameScrubber> {
  List<Uint8List> _frames = [];
  int _frameIndex = 0;
  bool _ready = false;
  bool _allLoaded = false;
  bool _error = false;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadFirstFrame();
  }

  @override
  void didUpdateWidget(_VideoFrameScrubber old) {
    super.didUpdateWidget(old);
    if (!old.focused && widget.focused) {
      if (_frames.length > 1 && _timer == null) {
        _startTimer(); // frames already ready - resume cycling
      } else if (!_allLoaded) {
        _scheduleRemainingLoad(); // first time in focus - load frames
      }
    } else if (old.focused && !widget.focused) {
      _timer?.cancel();
      _timer = null;
      // Do NOT reset _frameIndex - resume from the same position on re-focus
      // so the animation doesn't visibly jump back to the start.
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _frameIndex = (_frameIndex + 1) % _frames.length);
    });
  }

  // ── Phase 1: load frame 0 eagerly in background ───────────────────────────

  Future<void> _loadFirstFrame() async {
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
      setState(() {
        _frames = [data];
        _ready = true;
      });
      if (widget.focused) _scheduleRemainingLoad();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  // ── Phase 2: detect duration then load remaining frames on focus ──────────

  void _scheduleRemainingLoad() {
    if (!_ready || _allLoaded || _loading) return;
    _loading = true;
    _loadRemainingFrames();
  }

  Future<void> _loadRemainingFrames() async {
    try {
      const totalFrames = 6;

      // ── Duration detection ───────────────────────────────────────────────
      // On Android, MediaMetadataRetriever does NOT return null for timestamps
      // past the video end - it clamps and returns the last frame. So we cannot
      // use null as a past-end sentinel. Instead:
      //   1. Fetch a guaranteed-past-end sentinel (24 h) at tiny quality.
      //   2. Run all probe candidates in parallel at the same tiny quality.
      //   3. The last frame for every out-of-bounds timestamp equals the sentinel
      //      byte-for-byte; the first probe that DIFFERS from the sentinel is
      //      within the video - that gives us the approximate duration.
      const sentinelMs = 24 * 60 * 60 * 1000; // 24 h - always past any video
      const probeCandidatesMs = [300000, 120000, 60000, 30000, 10000, 5000, 3000, 1000];

      if (!mounted) return;

      // One parallel round-trip for sentinel + all probes.
      final allResults = await Future.wait([
        VideoThumbnail.thumbnailData(
          video: widget.url,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 32,
          quality: 1,
          timeMs: sentinelMs,
        ),
        ...probeCandidatesMs.map(
          (t) => VideoThumbnail.thumbnailData(
            video: widget.url,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 32,
            quality: 1,
            timeMs: t,
          ),
        ),
      ]);

      if (!mounted) return;

      final sentinel = allResults[0];

      // Walk candidates descending; first one whose bytes differ from the
      // sentinel is inside the video.
      int detectedDurationMs = 0;
      for (int i = 0; i < probeCandidatesMs.length; i++) {
        final probe = allResults[i + 1];
        if (probe != null && probe.isNotEmpty) {
          final pastEnd = sentinel != null && _bytesEqual(probe, sentinel);
          if (!pastEnd) {
            detectedDurationMs = probeCandidatesMs[i];
            break;
          }
        }
      }

      final int stepMs = detectedDurationMs > 0 ? (detectedDurationMs / (totalFrames - 1)).round() : 1000; // fallback: 1 s steps

      // ── Frame extraction ─────────────────────────────────────────────────
      // Sequential fetching is more reliable than parallel for network videos:
      // concurrent MediaMetadataRetriever requests on Android frequently fail
      // or return empty, which was causing only 1-2 frames to load.
      // Add frames progressively so cycling starts as soon as 2 are ready.
      for (int i = 1; i < totalFrames; i++) {
        if (!mounted) return;
        final data = await VideoThumbnail.thumbnailData(
          video: widget.url,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 480,
          quality: 70,
          timeMs: i * stepMs,
        );
        if (data == null || data.isEmpty) continue;
        if (!mounted) return;
        setState(() => _frames = [..._frames, data]);
        // Start cycling as soon as we have 2 frames and are in focus.
        if (_frames.length == 2 && widget.focused && _timer == null) {
          _startTimer();
        }
      }

      if (!mounted) return;
      _allLoaded = true;
      _loading = false;

      // Ensure timer is running if it wasn't started mid-load.
      if (widget.focused && _frames.length > 1 && _timer == null) {
        _startTimer();
      }
    } catch (_) {
      _loading = false;
    }
  }

  /// Byte-exact equality check for two JPEG buffers.
  /// JPEGs from the same MediaMetadataRetriever render are bit-for-bit identical,
  /// so this reliably detects clamped "past-end" frames.
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error || !_ready) return widget.placeholderBuilder(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.expand(
        child: Image.memory(
          _frames[_frameIndex],
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
// ── Webm gif-like preview ──────────────────────────────────────────────────

/// Silent, auto-looping [VideoPlayer] used for webm challenge previews on
/// the Challenger Road map. Fills its parent with [BoxFit.cover] so the
/// 1:1 preview card always looks fully populated regardless of the video's
/// native aspect ratio.
class _WebmGifPreview extends StatefulWidget {
  final String url;

  const _WebmGifPreview({required this.url});

  @override
  State<_WebmGifPreview> createState() => _WebmGifPreviewState();
}

class _WebmGifPreviewState extends State<_WebmGifPreview> {
  // Limit simultaneous VP9/WebM software decoders app-wide. All nodes on the
  // map are built at once (non-recycling scroll), so without a cap every
  // visible challenge card starts its own decoder, exhausting the CPU and
  // causing thermal throttling on iOS.
  static int _activeDecoders = 0;
  static const int _maxConcurrentDecoders = 2;

  VideoPlayerController? _controller;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Wait for a decoder slot to free up.
    while (_activeDecoders >= _maxConcurrentDecoders) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }
    _activeDecoders++;
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(resolveVideoUrl(widget.url)),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _controller!.initialize();
      if (!mounted) return;
      await _controller!.setVolume(0);
      await _controller!.setLooping(true);
      await _controller!.play();
      if (mounted) setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('_WebmGifPreview: failed to load ${widget.url}\n$e\n$st');
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    if (_ready) _activeDecoders--; // only decrement if we successfully acquired a slot
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          child: Center(
            child: Icon(
              Icons.play_circle_outline_rounded,
              size: 36,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }
    if (!_ready || _controller == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );
    }

    final size = _controller!.value.size;
    Widget videoWidget;
    if (size.width > 0 && size.height > 0) {
      videoWidget = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(_controller!),
        ),
      );
    } else {
      videoWidget = VideoPlayer(_controller!);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.expand(child: videoWidget),
    );
  }
}
// ── Run It Back dialog content ─────────────────────────────────────────────

class _RunItBackDialogContent extends StatelessWidget {
  const _RunItBackDialogContent({
    required this.nextInherited,
    required this.onFullGrind,
    required this.onJumpIn,
    required this.onCancel,
  });

  final int nextInherited;
  final VoidCallback onFullGrind;
  final VoidCallback onJumpIn;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = Theme.of(context).primaryColor;
    final surfaceBg = scheme.surface;
    // Slightly elevated card bg: blend surface toward onSurface
    final cardBg = Color.lerp(scheme.surface, scheme.onSurface, scheme.brightness == Brightness.dark ? 0.07 : 0.04)!;

    return Container(
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: scheme.brightness == Brightness.dark ? 0.5 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor.withValues(alpha: 0.18),
                  primaryColor.withValues(alpha: 0.0),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.15),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.55), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.28),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.emoji_events_rounded, color: primaryColor, size: 34),
                ),
                const SizedBox(height: 14),
                Text(
                  'RUN IT BACK?',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 28,
                    color: scheme.onSurface,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nextInherited >= 1 ? 'You conquered the full road.\nChoose your path for the next run.' : 'You conquered the full road.\nReady to do it all over again?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // ── Path choice cards ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (nextInherited >= 1) ...[
                  _PathChoiceCard(
                    icon: Icons.bolt_rounded,
                    iconColor: primaryColor,
                    borderColor: primaryColor,
                    badge: 'HEAD START',
                    label: 'JUMP IN',
                    sublabel: 'Start at Level ${nextInherited + 1}',
                    description: 'Your last run earned it. Skip ahead and keep the momentum going.',
                    cardBg: cardBg,
                    onSurface: scheme.onSurface,
                    onTap: onJumpIn,
                  ),
                  const SizedBox(height: 10),
                ],
                _PathChoiceCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF7A30),
                  borderColor: const Color(0xFFFF7A30),
                  badge: 'COMPLETIONIST',
                  label: 'FULL GRIND',
                  sublabel: 'Start at Level 1',
                  description: 'Back to the bottom. Earn every single level from scratch-the hard way.',
                  cardBg: cardBg,
                  onSurface: scheme.onSurface,
                  onTap: onFullGrind,
                ),
              ],
            ),
          ),

          // ── Cancel ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: TextButton(
              onPressed: onCancel,
              child: Text(
                'NOT YET',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 13,
                  letterSpacing: 1.2,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable path-choice card ──────────────────────────────────────────────

class _PathChoiceCard extends StatelessWidget {
  const _PathChoiceCard({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.badge,
    required this.label,
    required this.sublabel,
    required this.description,
    required this.cardBg,
    required this.onSurface,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final String badge;
  final String label;
  final String sublabel;
  final String description;
  final Color cardBg;
  final Color onSurface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: borderColor.withValues(alpha: 0.15),
        highlightColor: borderColor.withValues(alpha: 0.08),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Icon circle ───────────────────────────────────────────
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.12),
                  border: Border.all(color: iconColor.withValues(alpha: 0.40), width: 1),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 14),

              // ── Text block ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 18,
                            color: onSurface,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: iconColor.withValues(alpha: 0.50), width: 0.8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 9,
                              color: iconColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 13,
                        color: iconColor.withValues(alpha: 0.9),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.50),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ── Chevron ───────────────────────────────────────────────
              Icon(
                Icons.chevron_right_rounded,
                color: onSurface.withValues(alpha: 0.30),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

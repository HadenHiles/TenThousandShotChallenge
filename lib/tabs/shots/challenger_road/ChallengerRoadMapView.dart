import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
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
const double _focusedSectionExtraHeight = 96.0;
const double _focusExpandPerStep = 16.0;
const double _focusMaxNodeShift = 48.0;
const double _roadBoundaryLineHeight = 82.0;
const double _edgeFocusBufferMin = 100.0;
const double _edgeFocusBufferMax = 200.0;
const double _edgeFocusBufferFactor = 0.22;
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
    return p0 * (mt * mt * mt) +
        p1 * (3 * mt * mt * t) +
        p2 * (3 * mt * t * t) +
        p3 * (t * t * t);
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
          // Inside a dash — draw up to the end of this dash or end of segment.
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
          // Inside a gap — skip.
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

    // Road surface — wide semi-transparent band follows the bezier.
    final roadPaint = Paint()
      ..color = color.withValues(alpha: 0.13)
      ..strokeWidth = 18.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Centre dashed line — red, subtle.
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
/// [count]      — number of challenges
/// [stackWidth] — pixel width of the containing Stack
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

  // Track the height of each level section so we can scroll to the right level.
  // Key: level number, Value: cumulative top offset from the very top of scroll content.
  final Map<int, double> _levelTopOffsets = {};

  /// When a level is newly unlocked after a session, we store it here so the
  /// corresponding banner can play its slide-in animation on the first rebuild.
  int? _justUnlockedLevel;

  /// The last known current level before a data refresh, used to detect
  /// whether a level-unlock animation should fire.
  int? _previousCurrentLevel;

  // Confetti fired when the user scrolls past the finish line after completing
  // all available levels. Stores the last resolved data for scroll-listener access.
  late final ConfettiController _confettiController;
  bool _confettiFired = false;
  _CRMapData? _lastData;
  // Approximate scroll offset (from content top) of the finish line;
  // updated during layout so the scroll listener knows when to fire.
  double _finishLineContentY = 100.0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _scrollController.addListener(_handleScrollForFocusUpdate);
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
    super.dispose();
  }

  Future<_CRMapData> _loadMapData() async {
    final levels = await _service!.getAllActiveLevels();
    ChallengerRoadAttempt? attempt;

    if (widget.isPreviewMode) {
      attempt = await _service!.getActiveAttempt(widget.userId);
    } else {
      attempt = await _service!.syncActiveAttemptProgress(widget.userId);
    }

    if (widget.isPreviewMode && attempt == null) {
      // Ensure free preview users can actually try level 1 challenges.
      attempt = await _service!.createAttempt(widget.userId, 1);
    }

    final challengesByLevel = <int, List<ChallengerRoadChallenge>>{};
    for (final lvl in levels) {
      // Reverse so sequence 1 appears at the bottom of the level section and
      // the highest sequence appears at the top (bottom-up progression).
      challengesByLevel[lvl] = (await _service!.getChallengesForLevel(lvl)).reversed.toList();
    }

    final progress = <String, ChallengeProgressEntry>{};
    if (attempt != null) {
      final allIds = challengesByLevel.values.expand((list) => list).map((c) => c.id).whereType<String>().toSet();
      for (final cid in allIds) {
        final p = await _service!.getChallengeProgress(widget.userId, attempt.id!, cid);
        if (p != null) progress[cid] = p;
      }
    }

    final result = _CRMapData(
      levels: levels,
      challengesByLevel: challengesByLevel,
      activeAttempt: attempt,
      progress: progress,
    );
    _lastData = result;
    return result;
  }

  bool _isRoadComplete(_CRMapData data) {
    if (widget.isPreviewMode) return false;
    if (data.activeAttempt == null || data.levels.isEmpty) return false;
    return data.activeAttempt!.currentLevel > data.levels.last;
  }

  void _refreshData() {
    setState(() {
      _didScrollToCurrentLevel = false;
      _confettiFired = false;
      _lastData = null;
      _levelTopOffsets.clear();
      _focusTargets.clear();
      _focusedTarget = null;
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

      // Road complete — glide to the victory banner at the top.
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

  double _effectiveLevelSectionHeight(
    List<ChallengerRoadChallenge> challenges,
    int level, {
    required bool interactive,
  }) {
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
    if (!media.hasMedia) {
      return _buildPreviewMediaPlaceholder(context, icon: Icons.photo_library_outlined, label: 'Preview coming soon');
    }

    if (media.mediaType == 'video') {
      return _buildPreviewMediaPlaceholder(context, icon: Icons.play_circle_fill_rounded, label: 'Video preview');
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

  void _confirmRestart(BuildContext context, ChallengerRoadAttempt attempt) {
    final isDoOver = attempt.resetCount == 0;
    final title = isDoOver ? 'Start Over?' : 'Restart Challenger Road?';
    final body = isDoOver
        ? 'Your shot count and challenge progress for this attempt will be cleared. '
            'Your attempt number stays the same.\n\nThis is a do-over, not a new attempt.'
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
        final topStaticHeight = edgeFocusBuffer + _roadBoundaryLineHeight;

        // Compute cumulative offsets for scroll-to-level after top buffer + finish line.
        double cumulativeOffset = topStaticHeight;
        for (final lvl in levels) {
          _levelTopOffsets[lvl] = cumulativeOffset;
          final challenges = data.challengesByLevel[lvl] ?? const <ChallengerRoadChallenge>[];
          cumulativeOffset += _effectiveLevelSectionHeight(
            challenges,
            lvl,
            interactive: interactive,
          );
        }

        final focusTargets = <_ChallengeFocusTarget>[];
        double sectionTopOffset = topStaticHeight;

        // Store the finish line scroll position so the confetti listener knows
        // when the user has crossed it. Victory banner sits above the line.
        final roadComplete = _isRoadComplete(data);
        final finishLineY = edgeFocusBuffer + (roadComplete ? _victoryBannerHeight : 0);
        _finishLineContentY = finishLineY;

        if (interactive) {
          _scheduleFocusTargets(focusTargets);
        }

        return SingleChildScrollView(
          controller: interactive ? _scrollController : null,
          child: Column(
            children: [
              SizedBox(height: edgeFocusBuffer),
              if (roadComplete) _buildVictoryBanner(context, data),
              _buildRoadBoundaryLine(
                context,
                label: 'FINISH LINE',
                isFinish: true,
              ),
              for (final lvl in levels)
                (() {
                  final sectionTop = sectionTopOffset;
                  final challenges = data.challengesByLevel[lvl] ?? const <ChallengerRoadChallenge>[];
                  sectionTopOffset += _effectiveLevelSectionHeight(
                    challenges,
                    lvl,
                    interactive: interactive,
                  );
                  return _buildLevelSection(
                    context,
                    lvl,
                    data,
                    sectionTopOffset: sectionTop,
                    focusTargets: focusTargets,
                    interactive: interactive,
                  );
                })(),
              _buildRoadBoundaryLine(
                context,
                label: 'START LINE',
                isFinish: false,
              ),
              SizedBox(height: (edgeFocusBuffer * 0.30) + widget.mapBottomInset),
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
  }) {
    final challenges = data.challengesByLevel[level] ?? [];
    final attempt = data.activeAttempt;
    final currentLevel = widget.isPreviewMode ? math.min(attempt?.currentLevel ?? 1, widget.previewMaxLevel) : (attempt?.currentLevel ?? 1);
    final isCurrentLevel = level == currentLevel;
    final isLocked = level > currentLevel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final focusedIndex = interactive ? _focusedIndexForLevel(challenges, level) : -1;
        final baseCentres = _computeNodeCentres(challenges.length, width);
        final centres = _expandedNodeCentres(baseCentres, focusedIndex);
        final sectionHeight = _effectiveLevelSectionHeight(
          challenges,
          level,
          interactive: interactive,
        );

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

        // Road colour: red-toned for active/completed; desaturated for locked.
        final pathColor = isLocked
            ? const Color(0xFFB0B0B0).withValues(alpha: 0.35)
            : const Color(0xFFCC2200).withValues(alpha: isCurrentLevel ? 0.75 : 0.50);

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

              // ── Level banner (at bottom — acts as threshold into this level
              // when scrolling upward through the map) ──────────────────────
              Positioned(
                bottom: _levelBottomPad,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildLevelBanner(context, level, challenges.isNotEmpty ? challenges.first.levelName : 'Level $level', isCurrentLevel, isLocked),
                ),
              ),

              // ── Challenge nodes ─────────────────────────────────────────
              for (int i = 0; i < challenges.length; i++)
                ...(() {
                  final challenge = challenges[i];
                  final challengeId = challenge.id ?? '';
                  final nodeCenter = centres[i];
                  final nodeState = _nodeState(
                    challengeId,
                    level,
                    data,
                    i == firstIncompleteIdx,
                  );

                  focusTargets.add(
                    _ChallengeFocusTarget(
                      challenge: challenge,
                      level: level,
                      centerYInContent: sectionTopOffset + nodeCenter.dy,
                    ),
                  );

                  final isFocused = interactive && _isChallengeFocused(challengeId, level);
                  final challengeTap = interactive && attempt != null && nodeState != ChallengeNodeState.locked ? () => _handleNodeTap(challenge, level, attempt, data) : null;
                  final previewMedia = _resolvePreviewMedia(challenge);
                  const thumbWidth = 156.0;
                  const thumbHeight = 96.0;
                  const sideGap = 40.0;
                  const verticalUpOffset = -14.0;
                  const minLeft = 8.0;
                  const minTop = 6.0;
                  final maxLeft = width - thumbWidth - 8.0;
                  final maxTop = sectionHeight - thumbHeight - 6.0;
                  final leftSpace = nodeCenter.dx;
                  final rightSpace = width - nodeCenter.dx;

                  // Place preview on the opposite side of path direction.
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

                  // If the preferred side tucks under the node, flip sides.
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
                      // Centre the node widget horizontally around the computed x.
                      left: nodeCenter.dx - 41, // 41 = (82 node widget width) / 2
                      // Centre the circle (top portion of node widget) around y.
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
        );
      },
    );
  }

  // ── Victory banner (shown above FINISH LINE when all levels complete) ──────

  Widget _buildVictoryBanner(BuildContext context, _CRMapData data) {
    final attempt = data.activeAttempt!;
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
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFF4A400)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                    blurRadius: 28,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 14),
            const Text(
              'YOU\'VE CONQUERED\nCHALLENGER ROAD!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 26,
                color: Color(0xFFFFD700),
                height: 1.2,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Every challenge. Every level. Think you can do it again?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _confirmRestart(context, attempt),
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
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black87,
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
    bool isLocked,
  ) {
    final banner = LevelBannerWidget(
      levelName: levelName,
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
    final levelDoc = challenge.toLevelDoc();
    if (!mounted) return;

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

        return Column(
          children: [
            // ── Header (pinned below app header) ───────────────────────
            ChallengerRoadHeader(
              attempt: widget.isPreviewMode ? (widget.previewHeaderAttempt ?? attempt) : attempt,
              topPadding: MediaQuery.of(context).padding.top,
              onRestartTap: (!widget.isPreviewMode && attempt != null) ? () => _confirmRestart(context, attempt) : null,
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
                ],
              ),
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

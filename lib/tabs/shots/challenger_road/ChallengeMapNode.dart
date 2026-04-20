import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

/// The four visual states a challenge node can appear in on the snake map.
enum ChallengeNodeState {
  /// Level not yet reached - greyed out, lock icon, non-tappable.
  locked,

  /// Level is current but this challenge has not been started yet.
  available,

  /// The first incomplete challenge in the current level - gets extra glow emphasis.
  current,

  /// Challenge has been passed at this level (or level is already beaten).
  completed,
}

/// A single challenge bubble on the Challenger Road snake map.
///
/// Renders in one of four visual states and plays a pulsing glow animation
/// for [ChallengeNodeState.available] and [ChallengeNodeState.current] nodes.
class ChallengeMapNode extends StatefulWidget {
  final String challengeName;
  final ChallengeNodeState state;
  final VoidCallback? onTap;

  const ChallengeMapNode({
    super.key,
    required this.challengeName,
    required this.state,
    this.onTap,
  });

  @override
  State<ChallengeMapNode> createState() => _ChallengeMapNodeState();
}

class _ChallengeMapNodeState extends State<ChallengeMapNode> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  static const double _diameter = 62.0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _glowAnim = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _maybeStartGlow();
  }

  @override
  void didUpdateWidget(ChallengeMapNode old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _maybeStartGlow();
  }

  void _maybeStartGlow() {
    final shouldGlow = widget.state == ChallengeNodeState.available || widget.state == ChallengeNodeState.current;
    if (shouldGlow) {
      if (!_glowController.isAnimating) _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  // ── Visual properties per state ────────────────────────────────────────────

  Color _circleColor(BuildContext context) {
    switch (widget.state) {
      case ChallengeNodeState.completed:
        return Colors.green.shade600;
      case ChallengeNodeState.current:
        return Theme.of(context).primaryColor;
      case ChallengeNodeState.available:
        return const Color(0xff1565C0);
      case ChallengeNodeState.locked:
        return Colors.grey.shade700;
    }
  }

  Color _borderColor(BuildContext context) {
    switch (widget.state) {
      case ChallengeNodeState.completed:
        return Colors.green.shade300;
      case ChallengeNodeState.current:
        return Colors.white.withValues(alpha: 0.6);
      case ChallengeNodeState.available:
        return Colors.white.withValues(alpha: 0.35);
      case ChallengeNodeState.locked:
        return Colors.grey.shade600;
    }
  }

  Widget _nodeIcon(BuildContext context) {
    switch (widget.state) {
      case ChallengeNodeState.completed:
        return const Icon(Icons.check_rounded, color: Colors.white, size: 28);
      case ChallengeNodeState.locked:
        return Icon(Icons.lock, color: Colors.white.withValues(alpha: 0.65), size: 22);
      case ChallengeNodeState.current:
        return const Icon(Icons.sports_hockey, color: Colors.white, size: 26);
      case ChallengeNodeState.available:
        return const Icon(Icons.sports_hockey, color: Colors.white70, size: 24);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool tappable = widget.state != ChallengeNodeState.locked && widget.onTap != null;

    Widget circle = Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _circleColor(context),
        border: Border.all(color: _borderColor(context), width: 2.5),
      ),
      child: Center(child: _nodeIcon(context)),
    );

    // Pulsing glow wrapper for interactive nodes
    if (widget.state == ChallengeNodeState.available || widget.state == ChallengeNodeState.current) {
      final glowColor = _circleColor(context);
      final isCurrentNode = widget.state == ChallengeNodeState.current;
      circle = AnimatedBuilder(
        animation: _glowAnim,
        builder: (_, child) => Container(
          width: _diameter,
          height: _diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: _glowAnim.value * (isCurrentNode ? 0.75 : 0.5)),
                blurRadius: (isCurrentNode ? 22 : 14) * _glowAnim.value,
                spreadRadius: (isCurrentNode ? 6 : 3) * _glowAnim.value,
              ),
            ],
          ),
          child: child,
        ),
        child: circle,
      );
    }

    return GestureDetector(
      onTap: tappable ? widget.onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          const SizedBox(height: 5),
          Container(
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AutoSizeText(
              widget.challengeName.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              minFontSize: 10,
              stepGranularity: 0.5,
              style: TextStyle(
                color: widget.state == ChallengeNodeState.locked ? Colors.grey.shade500 : Theme.of(context).colorScheme.onSurface,
                fontFamily: 'NovecentoSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

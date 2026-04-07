import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengeDetailSheet.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadMilestoneScreen.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengeQuotaIndicator.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengeResultScreen.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/ShotButton.dart';

import 'package:tenthousandshotchallenge/Navigation.dart' show sessionPanelController, activeChallengeSession, ChallengeSessionConfig;

/// Challenge shooting session shown inside the sliding panel in Navigation.
///
/// Set [activeChallengeSession] in Navigation.dart and open
/// [sessionPanelController] instead of pushing this widget directly.
class StartChallengeScreen extends StatefulWidget {
  const StartChallengeScreen({
    super.key,
    required this.challenge,
    required this.levelDoc,
    required this.attempt,
    required this.userId,
    this.onDismiss,
  });

  final ChallengerRoadChallenge challenge;
  final ChallengerRoadLevel levelDoc;
  final ChallengerRoadAttempt attempt;
  final String userId;

  /// Called when the session ends (pass/fail saved) or is cancelled so the
  /// caller can clear [activeChallengeSession] and refresh the road.
  final VoidCallback? onDismiss;

  @override
  State<StartChallengeScreen> createState() => _StartChallengeScreenState();
}

class _StartChallengeScreenState extends State<StartChallengeScreen> {
  late String _selectedShotType;
  late int _currentShotCount;
  final List<Shots> _shots = [];
  int? _lastTargetsHit;
  bool _saving = false;
  late DateTime _startTime;

  // ── Computed values ───────────────────────────────────────────────────────

  int get _sessionShotsMade => _shots.fold(0, (sum, s) => sum + (s.targetsHit ?? 0));
  int get _sessionTotalShots => _shots.fold(0, (sum, s) => sum + (s.count ?? 0));

  // Indicator values are per-try so the denominator stays meaningful when a
  // user logs multiple tries in the same challenge session.
  Shots? get _latestTry => _shots.isEmpty ? null : _shots.first;
  int get _currentTryShotsMade => _latestTry?.targetsHit ?? 0;
  int get _currentTryTotalShots => _latestTry?.count ?? 0;

  // Lightweight anti-spam guardrail:
  // - ~0.5s per shot is the lower-bound execution speed.
  // - add a conservative 15s reset/load time between logged tries.
  int _minimumRealisticSeconds({
    required int totalShots,
    required int tryCount,
  }) {
    final shotTimeSeconds = (totalShots * 0.5).ceil();
    final resetSeconds = (tryCount <= 1) ? 0 : (tryCount - 1) * 15;
    return shotTimeSeconds + resetSeconds;
  }

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Pre-select the shot type required by the challenge; fall back to 'wrist'.
    _selectedShotType = widget.challenge.shotType ?? 'wrist';
    // Default puck count to the challenge's required shots so each attempt is
    // a full "round" of the challenge out of the box.
    _currentShotCount = widget.levelDoc.shotsRequired;
  }

  // ── Accuracy dialog ───────────────────────────────────────────────────────

  Future<int?> _showAccuracyDialog(int shotCount) async {
    int value = (_lastTargetsHit ?? (shotCount * 0.5).round()).clamp(0, shotCount);

    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('How many targets did you hit?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      ' / $shotCount',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: value.clamp(0, shotCount).toDouble(),
                  min: 0,
                  max: shotCount.toDouble(),
                  divisions: shotCount > 0 ? shotCount : 1,
                  activeColor: Theme.of(ctx).primaryColor,
                  onChanged: (v) => setLocal(() => value = v.round().clamp(0, shotCount)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Save', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => Navigator.of(ctx).pop(value.clamp(0, shotCount)),
              ),
            ],
          );
        });
      },
    );
  }

  // ── Finish logic ──────────────────────────────────────────────────────────

  Future<void> _finishSession() async {
    if (_shots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log at least one shot before finishing.')),
      );
      return;
    }

    final duration = DateTime.now().difference(_startTime);
    final minSeconds = _minimumRealisticSeconds(
      totalShots: _sessionTotalShots,
      tryCount: _shots.length,
    );
    if (duration.inSeconds < minSeconds) {
      final waitSeconds = minSeconds - duration.inSeconds;
      final waitMins = waitSeconds ~/ 60;
      final waitRemainder = waitSeconds % 60;
      final waitLabel = waitMins > 0 ? '${waitMins}m ${waitRemainder}s' : '${waitRemainder}s';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session finished too quickly to be realistic. Keep shooting for about $waitLabel longer.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final service = ChallengerRoadService(firestore: firestore);

    // A session is passed when any single try met or exceeded the goal.
    final passed = _shots.any((s) => (s.targetsHit ?? 0) >= widget.levelDoc.shotsToPass);

    final session = ChallengeSession(
      challengeId: widget.challenge.id!,
      level: widget.levelDoc.level,
      date: DateTime.now(),
      duration: duration,
      shotsRequired: widget.levelDoc.shotsRequired,
      shotsToPass: widget.levelDoc.shotsToPass,
      shotsMade: _sessionShotsMade,
      totalShots: _sessionTotalShots,
      passed: passed,
      shots: List.unmodifiable(_shots),
    );

    try {
      // Save to ChallengerRoad sub-collection — this is the critical write.
      await service.saveChallengeSession(widget.userId, widget.attempt.id!, session);

      // Save to the global shooting session so the main iteration counter
      // updates.  This is best-effort: a missing index or network hiccup
      // should NOT block the user from seeing their challenge result.
      try {
        await saveShootingSession(_shots, auth, firestore);
      } catch (globalSaveError) {
        debugPrint('Global session save failed (non-fatal): $globalSaveError');
      }

      // Increment CR shot count + milestone check.
      final milestone = await service.incrementChallengerRoadShots(
        widget.userId,
        widget.attempt.id!,
        _sessionTotalShots,
      );

      if (milestone.didHitMilestone && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChallengerRoadMilestoneScreen(result: milestone),
            fullscreenDialog: true,
          ),
        );
        if (!mounted) return;
      }

      // Level advancement check.
      ChallengerRoadAttempt updatedAttempt = widget.attempt;
      bool levelAdvanced = false;
      if (passed) {
        final levelComplete = await service.isLevelComplete(
          widget.userId,
          widget.attempt.id!,
          widget.levelDoc.level,
        );
        if (levelComplete) {
          final current = activeChallengeSession.value;
          final isPreviewMode = current?.isPreviewMode == true;
          final previewMaxLevel = current?.previewMaxLevel ?? 1;

          if (isPreviewMode && widget.levelDoc.level >= previewMaxLevel) {
            // Free preview gate: users can play level 1 but cannot unlock level 2.
            await presentPaywallIfNeeded(context);
            if (!mounted) return;

            // If user upgraded in the paywall, continue progression immediately.
            final updatedSubscriptionLevel = await subscriptionLevel(context);
            if (!mounted) return;

            if (updatedSubscriptionLevel == 'pro') {
              updatedAttempt = await service.advanceLevel(widget.userId, widget.attempt.id!);
              levelAdvanced = true;
            } else {
              final unlockLevel = widget.levelDoc.level + 1;
              Fluttertoast.showToast(
                msg: 'Level $unlockLevel is a Pro feature. Upgrade to continue your run.',
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.CENTER,
              );
            }
          } else {
            updatedAttempt = await service.advanceLevel(widget.userId, widget.attempt.id!);
            levelAdvanced = true;
          }
        }
      }

      if (!mounted) return;

      // Edge case: the new level has no challenges yet (admin hasn't published them).
      if (levelAdvanced) {
        final nextLevelChallenges = await service.getChallengesForLevel(
          updatedAttempt.currentLevel,
        );
        if (!mounted) return;
        if (nextLevelChallenges.isEmpty) {
          // All currently available challenges conquered — return to the map
          // which will auto-scroll to the victory banner and fire confetti.
          sessionPanelController.close();
          widget.onDismiss?.call();
          return;
        }
      }

      // Close the panel, push the result screen above navigation, then clear
      // the active challenge once the user dismisses the result screen.
      sessionPanelController.close();
      final retryRequested = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChallengeResultScreen(
            session: session,
            challenge: widget.challenge,
            levelDoc: widget.levelDoc,
            updatedAttempt: updatedAttempt,
            milestoneResult: milestone,
            levelAdvanced: levelAdvanced,
          ),
        ),
      );
      if (!mounted) return;

      if (retryRequested == true) {
        // Start a fresh challenge session for the same challenge/attempt.
        final current = activeChallengeSession.value;
        if (current != null) {
          activeChallengeSession.value = ChallengeSessionConfig(
            challenge: current.challenge,
            levelDoc: current.levelDoc,
            attempt: current.attempt,
            userId: current.userId,
            startedAt: DateTime.now(),
            onSessionComplete: current.onSessionComplete,
            isPreviewMode: current.isPreviewMode,
            previewMaxLevel: current.previewMaxLevel,
            onPreviewLevelUnlockAttempted: current.onPreviewLevelUnlockAttempted,
          );
        }

        setState(() {
          _shots.clear();
          _lastTargetsHit = null;
          _saving = false;
          _startTime = DateTime.now();
          _selectedShotType = widget.challenge.shotType ?? 'wrist';
          _currentShotCount = widget.levelDoc.shotsRequired;
        });

        sessionPanelController.open();
        return;
      }

      widget.onDismiss?.call();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        final msg = _friendlyError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  /// Returns a human-readable error message, hiding raw Firebase details.
  String _friendlyError(Object e) {
    // FirebaseException carries a code that's safe to branch on.
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Permission denied. Please sign in and try again.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Couldn\'t reach the server. Check your connection and try again.';
        default:
          return 'Something went wrong saving your session. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Rendered inside the SlidingUpPanel — no Scaffold, no AppBar.
    return Column(
      children: [
        _buildChallengeDetailsLauncher(),

        // Quota indicator – live updates as shots are logged.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ChallengeQuotaIndicator(
            shotsMade: _currentTryShotsMade,
            shotsToPass: widget.levelDoc.shotsToPass,
            shotsRequired: widget.levelDoc.shotsRequired,
            totalShots: _currentTryTotalShots,
            tryCount: _shots.length,
          ),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // ── Shot type selector ─────────────────────────────────
                _buildShotSelector(),
                const SizedBox(height: 16),

                // ── Puck count ─────────────────────────────────────────
                Text(
                  '# OF SHOTS',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                IgnorePointer(
                  ignoring: true,
                  child: NumberPicker(
                    value: _currentShotCount,
                    minValue: 1,
                    maxValue: 500,
                    step: 1,
                    itemHeight: 60,
                    textStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20),
                    axis: Axis.horizontal,
                    haptics: false,
                    infiniteLoop: true,
                    onChanged: (_) {},
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                    ),
                  ),
                ),
                Text(
                  'Locked to required shots for this challenge',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Check (log shots) button ───────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logShots,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.sports_hockey, color: Colors.white, size: 22),
                    label: const Text(
                      'LOG A TRY',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 20,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Records one try at the challenge',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 16),

                // ── Shot list ──────────────────────────────────────────
                if (_shots.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'TRIES',
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 13,
                          letterSpacing: 0.8,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_shots.length} tr${_shots.length == 1 ? 'y' : 'ies'}',
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _buildShotsList(),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Finish button — sticky at the bottom of the panel.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _finishSession,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'FINISH SESSION',
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _buildChallengeDetailsLauncher() {
    final detailsColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: detailsColor.withValues(alpha: 0.12),
          ),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          onTap: () {
            ChallengeDetailSheet.show(
              context,
              challenge: widget.challenge,
              levelDoc: widget.levelDoc,
              attempt: widget.attempt,
              userId: widget.userId,
              showStartCta: false,
            );
          },
          title: Text(
            'CHALLENGE DETAILS',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 14,
              letterSpacing: 0.8,
              color: detailsColor.withValues(alpha: 0.8),
            ),
          ),
          subtitle: Text(
            'Tap to open how-to and steps',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 10,
              color: detailsColor.withValues(alpha: 0.55),
            ),
          ),
          trailing: Icon(
            Icons.expand_circle_down_rounded,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  Widget _buildShotSelector() {
    final locked = widget.challenge.shotType != null;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['wrist', 'snap', 'slap', 'backhand'].map((type) {
              final isChallengType = type == widget.challenge.shotType;
              return Opacity(
                opacity: locked && !isChallengType ? 0.25 : 1.0,
                child: IgnorePointer(
                  ignoring: locked && !isChallengType,
                  child: ShotTypeButton(
                    type: type,
                    active: _selectedShotType == type,
                    onPressed: () {
                      Feedback.forLongPress(context);
                      setState(() => _selectedShotType = type);
                    },
                    borderRadius: BorderRadius.circular(_selectedShotType == type ? 12 : 6),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (locked) ...[
          const SizedBox(height: 4),
          Text(
            '${widget.challenge.shotType!.toUpperCase()} SHOTS REQUIRED FOR THIS CHALLENGE',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 10,
              letterSpacing: 0.5,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _logShots() async {
    Feedback.forLongPress(context);

    // Enforce challenge integrity by locking each try to the level requirement.
    final shotCount = widget.levelDoc.shotsRequired;
    final targetsHit = await _showAccuracyDialog(shotCount);
    if (targetsHit == null) return;

    setState(() {
      _currentShotCount = shotCount;
      _lastTargetsHit = targetsHit;
      _shots.insert(
        0,
        Shots(DateTime.now(), _selectedShotType, shotCount, targetsHit),
      );
    });

    // Auto-complete if this try passed the challenge.
    if (targetsHit >= widget.levelDoc.shotsToPass && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Text('🏒  Challenge passed! Finishing session…'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(milliseconds: 1400),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) _finishSession();
    }
  }

  List<Widget> _buildShotsList() {
    final shotsToPass = widget.levelDoc.shotsToPass;
    return _shots.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      // Most recent is index 0 — try number counts from oldest.
      final tryNumber = _shots.length - i;
      final count = s.count ?? 1;
      final hit = s.targetsHit ?? 0;
      final passed = hit >= shotsToPass;
      final closeEnough = !passed && hit >= (shotsToPass * 0.7).floor();
      final pct = ((hit / count) * 100).round();

      final Color tileColor;
      final Color labelColor;
      if (passed) {
        tileColor = Colors.green.shade700.withValues(alpha: 0.15);
        labelColor = Colors.green.shade600;
      } else if (closeEnough) {
        tileColor = Colors.orange.shade700.withValues(alpha: 0.12);
        labelColor = Colors.orange.shade700;
      } else {
        tileColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
        labelColor = Colors.red.shade400;
      }

      return Dismissible(
        key: UniqueKey(),
        onDismissed: (_) {
          Fluttertoast.showToast(
            msg: 'Try #$tryNumber deleted',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Theme.of(context).cardTheme.color,
            textColor: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          );
          setState(() => _shots.remove(s));
        },
        background: Container(
          color: Theme.of(context).primaryColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(margin: const EdgeInsets.only(left: 15), child: const Text('DELETE', style: TextStyle(color: Colors.white, fontFamily: 'NovecentoSans', fontSize: 16))),
              Container(margin: const EdgeInsets.only(right: 15), child: const Icon(Icons.delete, color: Colors.white, size: 16)),
            ],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: labelColor.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            child: Row(
              children: [
                // Attempt number badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: labelColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#$tryNumber',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Score and type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$hit / $count',
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 26,
                              color: labelColor,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s.type!.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: count > 0 ? (hit / count).clamp(0.0, 1.0) : 0.0,
                          minHeight: 5,
                          backgroundColor: labelColor.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(labelColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Result badge
                Column(
                  children: [
                    Icon(
                      passed ? Icons.check_circle_rounded : (closeEnough ? Icons.radio_button_checked_rounded : Icons.cancel_rounded),
                      color: labelColor,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pct%',
                      style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 12, color: labelColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

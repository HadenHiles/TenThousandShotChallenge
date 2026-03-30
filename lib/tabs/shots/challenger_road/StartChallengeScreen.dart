import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengeQuotaIndicator.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadAllClearScreen.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengeResultScreen.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/ShotButton.dart';

/// Full-screen challenge shooting session.
///
/// Pushed via [Navigator.push] from [ChallengeDetailSheet]. Returns [true]
/// when the user completes a session so the caller can trigger a data reload.
class StartChallengeScreen extends StatefulWidget {
  const StartChallengeScreen({
    super.key,
    required this.challenge,
    required this.levelDoc,
    required this.attempt,
    required this.userId,
  });

  final ChallengerRoadChallenge challenge;
  final ChallengerRoadLevel levelDoc;
  final ChallengerRoadAttempt attempt;
  final String userId;

  @override
  State<StartChallengeScreen> createState() => _StartChallengeScreenState();
}

class _StartChallengeScreenState extends State<StartChallengeScreen> {
  String _selectedShotType = 'wrist';
  int _currentShotCount = 5;
  final List<Shots> _shots = [];
  int? _lastTargetsHit;
  bool _saving = false;
  late DateTime _startTime;

  // ── Computed values ───────────────────────────────────────────────────────

  int get _shotsMade => _shots.fold(0, (sum, s) => sum + (s.targetsHit ?? 0));
  int get _totalShots => _shots.fold(0, (sum, s) => sum + (s.count ?? 0));

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _currentShotCount = preferences?.puckCount ?? 5;
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

    setState(() => _saving = true);

    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final service = ChallengerRoadService(firestore: firestore);

    final duration = DateTime.now().difference(_startTime);
    final passed = _shotsMade >= widget.levelDoc.shotsToPass;

    final session = ChallengeSession(
      challengeId: widget.challenge.id!,
      level: widget.levelDoc.level,
      date: DateTime.now(),
      duration: duration,
      shotsRequired: widget.levelDoc.shotsRequired,
      shotsToPass: widget.levelDoc.shotsToPass,
      shotsMade: _shotsMade,
      totalShots: _totalShots,
      passed: passed,
      shots: List.unmodifiable(_shots),
    );

    try {
      // Save to ChallengerRoad sub-collection.
      await service.saveChallengeSession(widget.userId, widget.attempt.id!, session);

      // Save to global shooting session so the main iteration counter updates.
      await saveShootingSession(_shots, auth, firestore);

      // Increment CR shot count + milestone check.
      final milestone = await service.incrementChallengerRoadShots(
        widget.userId,
        widget.attempt.id!,
        _totalShots,
      );

      if (milestone.didHitMilestone && mounted) {
        Fluttertoast.showToast(
          msg: '🏒 You\'ve hit ${milestone.resetCount * 10000} Challenger Road shots!',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Theme.of(context).primaryColor,
          textColor: Colors.white,
          fontSize: 16,
        );
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
          updatedAttempt = await service.advanceLevel(widget.userId, widget.attempt.id!);
          levelAdvanced = true;
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
          // All currently available challenges conquered — show the all-clear screen.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChallengerRoadAllClearScreen(
                completedLevel: widget.levelDoc.level,
              ),
            ),
          );
          return;
        }
      }

      // Replace this screen with the result screen.
      Navigator.of(context).pushReplacement(
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
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save session: $e')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.challenge.name.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 20,
              ),
            ),
            Text(
              'LEVEL ${widget.levelDoc.level}',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Quota indicator – live updates as shots are logged.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ChallengeQuotaIndicator(
              shotsMade: _shotsMade,
              shotsToPass: widget.levelDoc.shotsToPass,
              shotsRequired: widget.levelDoc.shotsRequired,
              totalShots: _totalShots,
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
                  GestureDetector(
                    onLongPress: _openShotCountNumpad,
                    child: NumberPicker(
                      value: _currentShotCount,
                      minValue: 1,
                      maxValue: 500,
                      step: 1,
                      itemHeight: 60,
                      textStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20),
                      axis: Axis.horizontal,
                      haptics: true,
                      infiniteLoop: true,
                      onChanged: (v) => setState(() {
                        _currentShotCount = v;
                        _lastTargetsHit = (v * 0.5).round();
                      }),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                      ),
                    ),
                  ),
                  Text(
                    'Long press for numpad',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Check (log shots) button ───────────────────────────
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 200,
                    child: TextButton(
                      onPressed: _logShots,
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 10, horizontal: 5)),
                        backgroundColor: WidgetStateProperty.all(Colors.green.shade600),
                      ),
                      child: const Icon(Icons.check, size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tap ',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      Icon(Icons.check, color: Colors.green.shade600, size: 14),
                      Text(
                        ' to save below',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Shot list ──────────────────────────────────────────
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _buildShotsList(),
                  ),
                  const SizedBox(height: 80), // padding for FAB
                ],
              ),
            ),
          ),
        ],
      ),

      // Finish button
      bottomNavigationBar: SafeArea(
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
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _buildShotSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ['wrist', 'snap', 'slap', 'backhand'].map((type) {
          return ShotTypeButton(
            type: type,
            active: _selectedShotType == type,
            onPressed: () {
              Feedback.forLongPress(context);
              setState(() => _selectedShotType = type);
            },
            borderRadius: BorderRadius.circular(_selectedShotType == type ? 12 : 6),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _logShots() async {
    Feedback.forLongPress(context);

    final targetsHit = await _showAccuracyDialog(_currentShotCount);
    if (targetsHit == null) return;

    setState(() {
      _lastTargetsHit = targetsHit;
      _shots.insert(
        0,
        Shots(DateTime.now(), _selectedShotType, _currentShotCount, targetsHit),
      );
    });
  }

  Future<void> _openShotCountNumpad() async {
    Feedback.forLongPress(context);
    final controller = TextEditingController(text: _currentShotCount.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter # of shots'),
        content: Center(
          child: Container(
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '1 - 500',
                hintStyle: TextStyle(color: Colors.black38),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final entered = int.tryParse(controller.text);
              if (entered != null && entered > 0 && entered <= 500) Navigator.of(ctx).pop(entered);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (value != null) setState(() => _currentShotCount = value);
  }

  List<Widget> _buildShotsList() {
    return _shots.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      return Dismissible(
        key: UniqueKey(),
        onDismissed: (_) {
          Fluttertoast.showToast(
            msg: '${s.count} ${s.type} shots deleted',
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: ListTile(
            tileColor: (i % 2 == 0) ? Theme.of(context).cardTheme.color : Theme.of(context).colorScheme.primary,
            leading: Text(
              s.count.toString(),
              style: const TextStyle(fontSize: 24, fontFamily: 'NovecentoSans'),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.type!.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontFamily: 'NovecentoSans')),
                Text(printTime(s.date!), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontFamily: 'NovecentoSans')),
              ],
            ),
            subtitle: s.targetsHit != null
                ? Text(
                    'Accuracy: ${((s.targetsHit! / (s.count ?? 1)) * 100).round()}%',
                    style: TextStyle(color: Colors.green.shade700, fontSize: 14, fontFamily: 'NovecentoSans'),
                  )
                : null,
          ),
        ),
      );
    }).toList();
  }
}

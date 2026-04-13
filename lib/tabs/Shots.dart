import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/ShotCount.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/ShotBreakdownDonut.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tenthousandshotchallenge/widgets/WeeklyAchievementsWidget.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadMapView.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadTeaserView.dart';
import '../main.dart';

class Shots extends StatefulWidget {
  const Shots({
    super.key,
    required this.sessionPanelController,
    required this.resetSignal,
    this.onChallengerRoadAvailabilityChanged,
  });

  final PanelController sessionPanelController;
  final int resetSignal;
  final ValueChanged<bool>? onChallengerRoadAvailabilityChanged;

  @override
  State<Shots> createState() => _ShotsState();
}

class _ShotsState extends State<Shots> {
  // Static variables
  DateTime? _targetDate;
  final TextEditingController _targetDateController = TextEditingController();
  Iteration? currentIteration;
  String _subscriptionLevel = 'free';
  CustomerInfoNotifier? _customerInfoNotifier;
  bool _showChallengerRoad = false;

  // Real-time stream of the active (incomplete) iteration for live updates
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _activeIterationStream;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) {
      _activeIterationStream = const Stream.empty();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutePaths.login);
      });
    } else {
      _activeIterationStream = firestore.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).snapshots();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _customerInfoNotifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
      _customerInfoNotifier?.addListener(_onSubscriptionChanged);
      _loadSubscriptionLevel();
    });
  }

  void _onSubscriptionChanged() {
    subscriptionLevel(context).then((level) {
      if (!mounted) return;
      setState(() => _subscriptionLevel = level);
    });
  }

  void _loadSubscriptionLevel() {
    subscriptionLevel(context).then((level) {
      if (!mounted) return;
      setState(() => _subscriptionLevel = level);
    });
  }

  @override
  void dispose() {
    _customerInfoNotifier?.removeListener(_onSubscriptionChanged);
    _targetDateController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Shots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) {
      // Reset can happen while parent is rebuilding; defer to next frame to
      // avoid triggering parent setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _closeChallengerRoad();
      });
    }
  }

  void _editTargetDate() {
    DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1),
      maxTime: DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day),
      onChanged: (date) {},
      onConfirm: (date) async {
        if (!mounted) return;
        setState(() {
          _targetDate = date;
        });
        _targetDateController.text = DateFormat('MMMM d, y').format(date);
        final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
        if (user == null) return;
        await Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).get().then((iSnap) async {
          if (iSnap.docs.isNotEmpty) {
            DocumentReference ref = iSnap.docs[0].reference;
            Iteration i = Iteration.fromSnapshot(iSnap.docs[0]);
            if (!mounted) return;
            setState(() {
              currentIteration = i;
            });
            Iteration updated = Iteration(i.startDate, date, i.endDate, i.totalDuration, i.total, i.totalWrist, i.totalSnap, i.totalSlap, i.totalBackhand, i.complete, DateTime.now());
            await ref.update(updated.toMap());
            // Update the text field and state immediately so UI reflects the new date
            setState(() {
              _targetDate = date;
              _targetDateController.text = DateFormat('MMMM d, y').format(date);
            });
            // Force rebuild to update shots/day and week calculation
            setState(() {});
          }
        });
      },
      currentTime: _targetDate,
      locale: LocaleType.en,
    );
  }

  bool _achievementsCollapsed = true;

  Future<void> _openChallengerRoad() async {
    if (_showChallengerRoad) return;
    final latestLevel = await subscriptionLevel(context);
    if (!mounted) return;
    setState(() {
      _subscriptionLevel = latestLevel;
      _showChallengerRoad = true;
    });
    widget.onChallengerRoadAvailabilityChanged?.call(true);
  }

  void _closeChallengerRoad() {
    if (!_showChallengerRoad) return;
    setState(() => _showChallengerRoad = false);
    widget.onChallengerRoadAvailabilityChanged?.call(false);
  }

  void _syncTargetDate(Iteration iteration) {
    if (_targetDate != null) return;
    _targetDate = iteration.targetDate;
    final fallbackDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day + 100,
    );
    _targetDateController.text = DateFormat('MMMM d, y').format(
      iteration.targetDate ?? fallbackDate,
    );
  }

  _TrainProgressMetrics _metricsForIteration(Iteration? iteration) {
    final total = ((iteration?.total ?? 0) >= 10000) ? 10000 : (iteration?.total ?? 0);
    final shotsRemaining = 10000 - total;
    final targetDate = _targetDate ?? iteration?.targetDate;
    int daysRemaining = targetDate != null ? targetDate.difference(DateTime.now()).inDays : 0;
    final weeksRemaining = daysRemaining > 0 ? (daysRemaining / 7) : 0;

    int shotsPerDay;
    if (shotsRemaining < 1) {
      shotsPerDay = 0;
    } else if (daysRemaining <= 1) {
      shotsPerDay = shotsRemaining;
    } else {
      shotsPerDay = shotsRemaining <= daysRemaining ? 1 : (shotsRemaining / daysRemaining).round();
    }

    int shotsPerWeek;
    if (shotsRemaining < 1) {
      shotsPerWeek = 0;
    } else if (weeksRemaining <= 1) {
      shotsPerWeek = shotsRemaining;
    } else {
      shotsPerWeek = shotsRemaining <= weeksRemaining ? 1 : (shotsRemaining / weeksRemaining).round();
    }

    final isPastGoal = targetDate != null && targetDate.compareTo(DateTime.now()) < 0;
    if (isPastGoal) {
      daysRemaining = DateTime.now().difference(targetDate).inDays * -1;
    }

    final dailyText = shotsRemaining < 1
        ? 'Done'
        : isPastGoal
            ? '${daysRemaining.abs()} days past goal'
            : '${numberFormat.format(shotsPerDay)} / day';
    final weeklyText = shotsRemaining < 1
        ? 'Done'
        : isPastGoal
            ? '${numberFormat.format(shotsRemaining)} remaining'
            : '${numberFormat.format(shotsPerWeek)} / week';

    final goalDateLabel = targetDate != null ? DateFormat('MMM d, y').format(targetDate) : 'Set a goal date';
    final statusLabel = shotsRemaining < 1
        ? 'Challenge complete'
        : isPastGoal
            ? 'Past due'
            : '${numberFormat.format(shotsRemaining)} shots remaining';

    return _TrainProgressMetrics(
      total: total,
      shotsRemaining: shotsRemaining,
      shotsPerDay: shotsPerDay,
      shotsPerWeek: shotsPerWeek,
      isPastGoal: isPastGoal,
      dailyText: dailyText,
      weeklyText: weeklyText,
      goalDateLabel: goalDateLabel,
      statusLabel: statusLabel,
      progress: total / 10000,
    );
  }

  Widget _buildSeasonOverviewCard(BuildContext context, Iteration? iteration) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.primaryContainer;
    final metrics = _metricsForIteration(iteration);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.94),
            cardColor.withValues(alpha: 0.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '10,000 Shot Challenge',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 20,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    '${(metrics.progress * 100).round()}%',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AutoSizeText(
                  numberFormat.format(metrics.total),
                  maxLines: 1,
                  maxFontSize: 32,
                  minFontSize: 20,
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 32,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 3),
                  child: Text(
                    '/ 10,000',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 16,
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWrist = iteration?.totalWrist ?? 0;
                final totalSnap = iteration?.totalSnap ?? 0;
                final totalBackhand = iteration?.totalBackhand ?? 0;
                final totalSlap = iteration?.totalSlap ?? 0;
                final progressWidth = constraints.maxWidth * metrics.progress;
                final segmentTotal = metrics.total == 0 ? 1 : metrics.total;

                Widget buildSegment(int count, Color color) {
                  return Container(
                    height: 8,
                    width: count > 0 ? (count / segmentTotal) * progressWidth : 0,
                    color: color,
                  );
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        width: constraints.maxWidth,
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.12),
                      ),
                      Row(
                        children: [
                          buildSegment(totalWrist, wristShotColor),
                          buildSegment(totalSnap, snapShotColor),
                          buildSegment(totalBackhand, backhandShotColor),
                          buildSegment(totalSlap, slapShotColor),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    metrics.statusLabel,
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 15,
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: iteration == null ? null : _editTargetDate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.64),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        metrics.goalDateLabel,
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 15,
                          color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.52),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengerRoadEntryCard(BuildContext context, User? user) {
    final theme = Theme.of(context);
    final isPro = _subscriptionLevel == 'pro';
    final accent = theme.primaryColor;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: user == null ? null : _openChallengerRoad,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.24),
              theme.cardTheme.color?.withValues(alpha: 0.98) ?? theme.colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.5),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Challenger Road',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 24,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPro ? 'Can you make it to the end of the road?' : 'Think you can complete every challenge?',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 13,
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent,
                ),
                child: Text(
                  isPro ? 'CONTINUE' : 'START',
                  style: const TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyAchievementsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                _achievementsCollapsed = !_achievementsCollapsed;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amberAccent.withValues(alpha: 0.16),
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Achievements',
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 22,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete these achievements to start a hot streak.',
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _achievementsCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                    color: theme.colorScheme.onSurface,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _achievementsCollapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: WeeklyAchievementsWidget(
                showResetCountdown: true,
                showOnlyResetCountdown: true,
              ),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              child: WeeklyAchievementsWidget(showResetCountdown: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShotMixCard(BuildContext context, Iteration? iteration) {
    final theme = Theme.of(context);
    if (iteration == null) {
      return Card(
        color: theme.cardTheme.color,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shot Mix',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log a session to see how your shots break down.',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final shotCounts = [
      ShotCount('Wrist'.toUpperCase(), iteration.totalWrist ?? 0, Colors.cyan),
      ShotCount('Snap'.toUpperCase(), iteration.totalSnap ?? 0, Colors.blue),
      ShotCount('Backhand'.toUpperCase(), iteration.totalBackhand ?? 0, Colors.indigo),
      ShotCount('Slap'.toUpperCase(), iteration.totalSlap ?? 0, Colors.teal),
    ];

    Widget countTile(String label, int total, Color color) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontFamily: 'NovecentoSans',
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 34,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            AutoSizeText(
              numberFormat.format(total),
              maxFontSize: 18,
              maxLines: 1,
              minFontSize: 12,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontFamily: 'NovecentoSans',
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      color: theme.cardTheme.color,
      margin: EdgeInsets.zero,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shot Mix',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 22,
                fontFamily: 'NovecentoSans',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              iteration.total == null || iteration.total == 0 ? 'Log your first session to see your breakdown.' : 'See how your shots break down this challenge.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                fontSize: 13,
                fontFamily: 'NovecentoSans',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                countTile('Wrist', iteration.totalWrist ?? 0, wristShotColor),
                countTile('Snap', iteration.totalSnap ?? 0, snapShotColor),
                countTile('Backhand', iteration.totalBackhand ?? 0, backhandShotColor),
                countTile('Slap', iteration.totalSlap ?? 0, slapShotColor),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: iteration.total == null || iteration.total == 0
                  ? Center(
                      child: Text(
                        'Hit the ice. Your breakdown will fill in here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        Positioned(
                          top: 96,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  FontAwesomeIcons.hockeyPuck,
                                  size: 26,
                                  color: theme.colorScheme.onSurface,
                                ),
                                Positioned(
                                  left: -11,
                                  top: -11,
                                  child: Icon(
                                    FontAwesomeIcons.hockeyPuck,
                                    size: 14,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Positioned(
                                  right: -11,
                                  bottom: -11,
                                  child: Icon(
                                    FontAwesomeIcons.hockeyPuck,
                                    size: 14,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ShotBreakdownDonut(context, shotCounts),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainDashboard(User? user) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activeIterationStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor,
            ),
          );
        }

        final iteration = snapshot.data!.docs.isNotEmpty ? Iteration.fromSnapshot(snapshot.data!.docs[0]) : null;
        if (iteration != null) {
          _syncTargetDate(iteration);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSeasonOverviewCard(context, iteration),
              const SizedBox(height: 16),
              _buildChallengerRoadEntryCard(context, user),
              const SizedBox(height: 16),
              _buildWeeklyAchievementsCard(context),
              const SizedBox(height: 16),
              _buildShotMixCard(context, iteration),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInlineChallengerRoad(User user) {
    if (_subscriptionLevel == 'pro') {
      return ChallengerRoadMapView(
        userId: user.uid,
        onCloseTap: _closeChallengerRoad,
      );
    }

    return ChallengerRoadTeaserView(
      embedded: true,
      onCloseTap: _closeChallengerRoad,
    );
  }

  Widget _buildSessionControls() {
    return SessionServiceProvider(
      service: sessionService,
      child: AnimatedBuilder(
        animation: sessionService,
        builder: (context, child) {
          return SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.only(
                bottom: !sessionService.isRunning ? AppBar().preferredSize.height : AppBar().preferredSize.height + 65,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _activeIterationStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        Iteration iteration = Iteration.fromSnapshot(snapshot.data!.docs[0]);
                        return iteration.total! < 10000
                            ? Container()
                            : SizedBox(
                                width: MediaQuery.of(context).size.width - 30,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.all(10),
                                    backgroundColor: Theme.of(context).cardTheme.color,
                                  ),
                                  onPressed: () {
                                    dialog(
                                      context,
                                      ConfirmDialog(
                                        'Start a new challenge?',
                                        Text(
                                          'Your current challenge data will remain in your profile.\n\nWould you like to continue?',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        'Cancel',
                                        () {
                                          Navigator.of(context).pop();
                                        },
                                        'Continue',
                                        () {
                                          startNewIteration(
                                            Provider.of<FirebaseAuth>(context, listen: false),
                                            Provider.of<FirebaseFirestore>(context, listen: false),
                                          ).then((success) {
                                            if (success!) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: Theme.of(context).cardTheme.color,
                                                  duration: const Duration(milliseconds: 1200),
                                                  content: Text(
                                                    'Challenge restarted!',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: Theme.of(context).cardTheme.color,
                                                  duration: const Duration(milliseconds: 1200),
                                                  content: Text(
                                                    'There was an error restarting the challenge :(',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          });
                                          context.pop();
                                        },
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Start New Challenge'.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              );
                      }
                      return Container();
                    },
                  ),
                  sessionService.isRunning
                      ? Container()
                      : Container(
                          padding: isThreeButtonAndroidNavigation(context) ? EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight) : const EdgeInsets.only(bottom: 15),
                          width: MediaQuery.of(context).size.width - 30,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(10),
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                            onPressed: () {
                              if (!sessionService.isRunning) {
                                Feedback.forTap(context);
                                sessionService.start();
                                widget.sessionPanelController.show();
                                widget.sessionPanelController.open();
                              } else {
                                dialog(
                                  context,
                                  ConfirmDialog(
                                    'Override current session?',
                                    Text(
                                      'Starting a new session will override your existing one.\n\nWould you like to continue?',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    'Cancel',
                                    () {
                                      Navigator.of(context).pop();
                                    },
                                    'Continue',
                                    () {
                                      Feedback.forTap(context);
                                      sessionService.reset();
                                      Navigator.of(context).pop();
                                      sessionService.start();
                                      widget.sessionPanelController.show();
                                      widget.sessionPanelController.open();
                                    },
                                  ),
                                );
                              }
                            },
                            child: Text(
                              'Start Shooting'.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
        final showingRoad = _showChallengerRoad && user != null;

        return Stack(
          key: const Key('shots_tab_body'),
          children: [
            Positioned.fill(
              child: showingRoad ? _buildInlineChallengerRoad(user) : _buildTrainDashboard(user),
            ),
            if (!showingRoad)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildSessionControls(),
              ),
          ],
        );
      },
    );
  }
}

class _TrainProgressMetrics {
  const _TrainProgressMetrics({
    required this.total,
    required this.shotsRemaining,
    required this.shotsPerDay,
    required this.shotsPerWeek,
    required this.isPastGoal,
    required this.dailyText,
    required this.weeklyText,
    required this.goalDateLabel,
    required this.statusLabel,
    required this.progress,
  });

  final int total;
  final int shotsRemaining;
  final int shotsPerDay;
  final int shotsPerWeek;
  final bool isPastGoal;
  final String dailyText;
  final String weeklyText;
  final String goalDateLabel;
  final String statusLabel;
  final double progress;
}

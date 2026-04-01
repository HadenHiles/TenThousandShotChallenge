import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/profile/QR.dart';
import 'package:tenthousandshotchallenge/widgets/AchievementStatsRow.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';

class Profile extends StatefulWidget {
  const Profile({super.key, this.sessionPanelController, this.updateSessionShotsCB});

  final PanelController? sessionPanelController;
  final Function? updateSessionShotsCB;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  User? get user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;

  final GlobalKey _avatarMenuKey = GlobalKey();
  String _subscriptionLevel = 'free';

  String? _selectedIterationId;
  DateTime? firstSessionDate;
  DateTime? latestSessionDate;
  bool _loadingSessionDates = false;

  CustomerInfoNotifier? _customerInfoNotifier;

  // Progress card state
  DateTime? _progressTargetDate;
  final TextEditingController _progressTargetDateController = TextEditingController();
  bool _progressShowShotsPerDay = true;

  final NumberFormat numberFormat = NumberFormat('#,###');

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setInitialIterationId());
    _loadSubscriptionLevel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _customerInfoNotifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
      _customerInfoNotifier?.addListener(_onEntitlementsChanged);
    });
  }

  void _onEntitlementsChanged() {
    subscriptionLevel(context).then((level) {
      if (mounted) setState(() => _subscriptionLevel = level);
    });
  }

  void _loadSubscriptionLevel() {
    subscriptionLevel(context).then((level) {
      if (!mounted) return;
      setState(() => _subscriptionLevel = level);
    }).catchError((_) {});
  }

  Future<void> _setInitialIterationId() async {
    final u = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (u == null) return;
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final snap = await firestore.collection('iterations').doc(u.uid).collection('iterations').orderBy('start_date', descending: false).get();
    if (snap.docs.isNotEmpty && mounted) {
      setState(() => _selectedIterationId = snap.docs.last.id);
      _loadFirstLastSession(snap.docs.last.id);
    }
  }

  Future<void> _loadFirstLastSession(String? iterationId) async {
    if (iterationId == null || user == null) return;
    if (_loadingSessionDates) return;
    setState(() => _loadingSessionDates = true);
    try {
      final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
      final col = firestore.collection('iterations').doc(user!.uid).collection('iterations').doc(iterationId).collection('sessions');
      final results = await Future.wait([
        col.orderBy('date', descending: false).limit(1).get(),
        col.orderBy('date', descending: true).limit(1).get(),
      ]);
      if (results[0].docs.isNotEmpty && results[1].docs.isNotEmpty) {
        final first = ShootingSession.fromSnapshot(results[0].docs.first);
        final last = ShootingSession.fromSnapshot(results[1].docs.first);
        if (mounted) {
          setState(() {
            firstSessionDate = first.date;
            latestSessionDate = last.date;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            firstSessionDate = null;
            latestSessionDate = null;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSessionDates = false);
    }
  }

  void _editProgressTargetDate(String iterationId) {
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final authUser = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (authUser == null) return;
    DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1),
      maxTime: DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day),
      onChanged: (_) {},
      onConfirm: (date) async {
        if (!mounted) return;
        setState(() {
          _progressTargetDate = date;
          _progressTargetDateController.text = DateFormat('MMMM d, y').format(date);
        });
        final docRef = firestore.collection('iterations').doc(authUser.uid).collection('iterations').doc(iterationId);
        final snap = await docRef.get();
        if (!snap.exists || !mounted) return;
        final i = Iteration.fromSnapshot(snap);
        final updated = Iteration(i.startDate, date, i.endDate, i.totalDuration, i.total, i.totalWrist, i.totalSnap, i.totalSlap, i.totalBackhand, i.complete, DateTime.now());
        await docRef.update(updated.toMap());
        if (!mounted) return;
        setState(() {
          _progressTargetDate = date;
          _progressTargetDateController.text = DateFormat('MMMM d, y').format(date);
        });
      },
      currentTime: _progressTargetDate,
      locale: LocaleType.en,
    );
  }

  @override
  void dispose() {
    try {
      _customerInfoNotifier?.removeListener(_onEntitlementsChanged);
    } catch (_) {}
    _progressTargetDateController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUser = user;
    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return Container(
      key: const Key('profile_tab_body'),
      padding: isThreeButtonAndroidNavigation(context)
          ? EdgeInsets.only(bottom: sessionService.isRunning ? MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight + 65 : MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight)
          : sessionService.isRunning
              ? const EdgeInsets.only(top: 15, bottom: 65)
              : const EdgeInsets.only(top: 15),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, currentUser),
            const SizedBox(height: 16),
            _buildProgressCard(context, currentUser),
            const SizedBox(height: 12),
            _buildSessionsCard(context, currentUser),
            const SizedBox(height: 12),
            _buildAccuracyCard(context, currentUser),
            const SizedBox(height: 12),
            _buildAchievementsCard(context, currentUser),
            const SizedBox(height: 12),
            _buildChallengerRoadCard(context, currentUser),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, User currentUser) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: Stack(
                children: [
                  PopupMenuButton(
                    key: _avatarMenuKey,
                    color: Theme.of(context).colorScheme.primary,
                    iconSize: 40,
                    icon: Container(),
                    itemBuilder: (_) => <PopupMenuItem<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Change Avatar'.toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).colorScheme.onPrimary)),
                            Icon(Icons.edit, color: Theme.of(context).colorScheme.onPrimary),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'qr_code',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Show QR Code'.toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).colorScheme.onPrimary)),
                            Icon(Icons.qr_code_2_rounded, color: Theme.of(context).colorScheme.onPrimary),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        context.push(AppRoutePaths.editProfile);
                      } else if (value == 'qr_code') {
                        showQRCode(context, currentUser);
                      }
                    },
                  ),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onLongPress: () {
                        Feedback.forLongPress(context);
                        context.push(AppRoutePaths.editProfile);
                      },
                      onTap: () {
                        Feedback.forTap(context);
                        dynamic state = _avatarMenuKey.currentState;
                        state.showButtonMenu();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(currentUser.uid).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return UserAvatar(user: UserProfile.fromSnapshot(snapshot.data!), backgroundColor: Colors.transparent);
                            }
                            return UserAvatar(
                              user: UserProfile(currentUser.displayName, currentUser.email, currentUser.photoURL, true, true, null, ''),
                              backgroundColor: Colors.transparent,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 120) * 0.55,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(currentUser.uid).snapshots(),
                    builder: (context, snapshot) {
                      String name = currentUser.displayName ?? 'Player';
                      if (snapshot.hasData) {
                        final profile = UserProfile.fromSnapshot(snapshot.data!);
                        if (profile.displayName?.isNotEmpty == true) {
                          name = profile.displayName!;
                        }
                      }
                      return AutoSizeText(
                        name,
                        maxLines: 1,
                        maxFontSize: 22,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color),
                      );
                    },
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(currentUser.uid).collection('iterations').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(width: 120, height: 2, child: LinearProgressIndicator());
                    }
                    int total = 0;
                    for (final doc in snapshot.data!.docs) {
                      total += Iteration.fromSnapshot(doc).total!;
                    }
                    final label = total > 999 ? '${numberFormat.format(total)} lifetime shots' : '$total lifetime shots';
                    return Text(label, style: TextStyle(fontSize: 16, fontFamily: 'NovecentoSans', color: Theme.of(context).colorScheme.onPrimary));
                  },
                ),
              ],
            ),
          ],
        ),
        // Iteration dropdown (only when multiple challenges exist)
        StreamBuilder<QuerySnapshot>(
          stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(currentUser.uid).collection('iterations').orderBy('start_date', descending: false).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final docs = snapshot.data!.docs;
            if (docs.length <= 1) return const SizedBox.shrink();

            final items = <DropdownMenuItem<String>>[];
            for (int i = 0; i < docs.length; i++) {
              items.add(DropdownMenuItem<String>(
                value: docs[i].reference.id,
                child: Text('challenge ${i + 1}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 18, fontFamily: 'NovecentoSans')),
              ));
            }

            if (_selectedIterationId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedIterationId = docs.last.reference.id);
              });
            }

            return DropdownButton<String>(
              value: _selectedIterationId,
              items: items,
              dropdownColor: Theme.of(context).colorScheme.primary,
              onChanged: (value) {
                setState(() {
                  _selectedIterationId = value;
                  firstSessionDate = null;
                  latestSessionDate = null;
                  _progressTargetDate = null;
                });
                _loadFirstLastSession(value);
              },
            );
          },
        ),
      ],
    );
  }

  // ── Progress card ─────────────────────────────────────────────────────────

  Widget _buildProgressCard(BuildContext context, User currentUser) {
    final theme = Theme.of(context);
    if (_selectedIterationId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(currentUser.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
      builder: (context, iterSnap) {
        if (!iterSnap.hasData || !iterSnap.data!.exists) {
          return Container(
            height: 120,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: theme.cardTheme.color),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final iteration = Iteration.fromSnapshot(iterSnap.data!);
        final bool isComplete = iteration.complete ?? false;

        if (_progressTargetDate == null) {
          _progressTargetDate = iteration.targetDate;
          _progressTargetDateController.text = DateFormat('MMMM d, y').format(
            iteration.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
          );
        }

        final int iterTotal = (iteration.total ?? 0).clamp(0, 10000);
        final int shotsRemaining = 10000 - iterTotal;
        final double progress = iterTotal / 10000.0;

        final DateTime? targetDate = _progressTargetDate ?? iteration.targetDate;
        final bool isPastGoal = targetDate != null && targetDate.isBefore(DateTime.now());
        int daysRemaining = targetDate != null ? targetDate.difference(DateTime.now()).inDays : 0;

        int shotsPerDay = 0;
        int shotsPerWeek = 0;
        if (!isPastGoal && daysRemaining > 0 && shotsRemaining > 0) {
          shotsPerDay = daysRemaining <= 1 ? shotsRemaining : (shotsRemaining / daysRemaining).ceil();
          final weeks = daysRemaining / 7.0;
          shotsPerWeek = weeks <= 1 ? shotsRemaining : (shotsRemaining / weeks).ceil();
        }

        String paceText;
        if (shotsRemaining <= 0) {
          paceText = 'Done!';
        } else if (isPastGoal) {
          final overdue = DateTime.now().difference(targetDate).inDays;
          paceText = '$overdue day${overdue == 1 ? '' : 's'} past goal';
        } else if (_progressShowShotsPerDay) {
          paceText = shotsPerDay > 999 ? '${numberFormat.format(shotsPerDay)} / day' : '$shotsPerDay / day';
        } else {
          paceText = shotsPerWeek > 999 ? '${numberFormat.format(shotsPerWeek)} / week' : '$shotsPerWeek / week';
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: 0.94),
                theme.colorScheme.primary.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shot total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        iterTotal > 999 ? numberFormat.format(iterTotal) : iterTotal.toString(),
                        style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 36, color: theme.colorScheme.onPrimary, height: 1.0),
                      ),
                      Text(
                        '/ 10,000 shots',
                        style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                  // Pace + goal date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _progressShowShotsPerDay = !_progressShowShotsPerDay),
                        child: Row(
                          children: [
                            Text(paceText, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: theme.colorScheme.onPrimary)),
                            const SizedBox(width: 4),
                            Icon(Icons.swap_vert, size: 16, color: theme.colorScheme.onPrimary.withValues(alpha: 0.6)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!isComplete)
                        GestureDetector(
                          onTap: () => _editProgressTargetDate(_selectedIterationId!),
                          child: Row(
                            children: [
                              Text(
                                targetDate != null ? DateFormat('MMM d, y').format(targetDate) : 'Set goal date',
                                style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7)),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit, size: 12, color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Challenge complete!',
                          style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildProgressBar(context, iteration, progress),
              const SizedBox(height: 10),
              _buildShotTypeRow(context, iteration),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, Iteration iteration, double progress) {
    final theme = Theme.of(context);
    final total = iteration.total ?? 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);
        final seg = total == 0 ? 1.0 : total.toDouble();

        Widget segment(int count, Color color) => Container(
              height: 8,
              width: count > 0 ? (count / seg) * barWidth : 0,
              color: color,
            );

        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(height: 8, width: constraints.maxWidth, color: theme.colorScheme.onPrimary.withValues(alpha: 0.12)),
              Row(children: [
                segment(iteration.totalWrist ?? 0, wristShotColor),
                segment(iteration.totalSnap ?? 0, snapShotColor),
                segment(iteration.totalBackhand ?? 0, backhandShotColor),
                segment(iteration.totalSlap ?? 0, slapShotColor),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShotTypeRow(BuildContext context, Iteration iteration) {
    final types = [
      ('Wrist', iteration.totalWrist ?? 0, wristShotColor),
      ('Snap', iteration.totalSnap ?? 0, snapShotColor),
      ('Backhand', iteration.totalBackhand ?? 0, backhandShotColor),
      ('Slap', iteration.totalSlap ?? 0, slapShotColor),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: types.map((t) {
        final (label, count, color) = t;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 14, fontFamily: 'NovecentoSans')),
            const SizedBox(height: 2),
            Container(width: 28, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 2),
            AutoSizeText(
              count > 999 ? numberFormat.format(count) : count.toString(),
              maxFontSize: 16,
              maxLines: 1,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontFamily: 'NovecentoSans'),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── Sessions card ─────────────────────────────────────────────────────────

  Widget _buildSessionsCard(BuildContext context, User currentUser) {
    final theme = Theme.of(context);
    return _DashboardCard(
      onTap: () => context.push(AppRoutePaths.history, extra: _selectedIterationId),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.history_rounded, color: theme.colorScheme.onPrimary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sessions'.toUpperCase(), style: theme.textTheme.headlineSmall),
                  if (_selectedIterationId != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(currentUser.uid).collection('iterations').doc(_selectedIterationId).collection('sessions').orderBy('date', descending: true).limit(1).snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData || snap.data!.docs.isEmpty) {
                          return Text('No sessions yet', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.6)));
                        }
                        final last = ShootingSession.fromSnapshot(snap.data!.docs.first);
                        return Text(
                          'Last: ${printDate(last.date!)}  \u00b7  ${last.total} shots',
                          style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7)),
                        );
                      },
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onPrimary.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  // ── Accuracy card ─────────────────────────────────────────────────────────

  Widget _buildAccuracyCard(BuildContext context, User currentUser) {
    final theme = Theme.of(context);
    final isPro = _subscriptionLevel == 'pro';
    return _DashboardCard(
      onTap: isPro ? () => context.push(AppRoutePaths.profileAccuracy, extra: _selectedIterationId) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.track_changes_rounded, color: theme.colorScheme.onPrimary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Shot Accuracy'.toUpperCase(), style: theme.textTheme.headlineSmall),
                    if (!isPro) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_rounded, size: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.4)),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  _buildAccuracyGlanceChips(context, currentUser, isPro),
                  if (!isPro)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Pro feature', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 12, color: theme.colorScheme.onPrimary.withValues(alpha: 0.5))),
                    ),
                ],
              ),
            ),
            if (isPro) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onPrimary.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyGlanceChips(BuildContext context, User currentUser, bool isPro) {
    const shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
    const shotTypeColors = {
      'wrist': wristShotColor,
      'snap': snapShotColor,
      'slap': slapShotColor,
      'backhand': backhandShotColor,
    };
    const shotTypeLabels = {'wrist': 'W', 'snap': 'SN', 'slap': 'SL', 'backhand': 'B'};

    if (!isPro || _selectedIterationId == null) {
      const dummyAccuracy = {'wrist': 72.0, 'snap': 68.0, 'slap': 80.0, 'backhand': 65.0};
      return Row(
        children: shotTypes.map((type) => _accuracyChip(context, shotTypeLabels[type]!, dummyAccuracy[type]!, shotTypeColors[type]!)).toList(),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(currentUser.uid).collection('iterations').doc(_selectedIterationId).collection('sessions').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Row(children: shotTypes.map((t) => _accuracyChip(context, shotTypeLabels[t]!, 0, shotTypeColors[t]!, loading: true)).toList());
        }
        return FutureBuilder<Map<String, double>>(
          future: _computeAvgAccuracy(snap.data!.docs, shotTypes),
          builder: (context, asyncSnap) {
            final acc = asyncSnap.data ?? {for (var t in shotTypes) t: 0.0};
            return Row(
              children: shotTypes.map((type) => _accuracyChip(context, shotTypeLabels[type]!, acc[type] ?? 0, shotTypeColors[type]!)).toList(),
            );
          },
        );
      },
    );
  }

  Widget _accuracyChip(BuildContext context, String label, double pct, Color color, {bool loading = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'NovecentoSans', fontWeight: FontWeight.bold, fontSize: 12)),
        Stack(alignment: Alignment.center, children: [
          Container(width: 32, height: 26, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) else Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontFamily: 'NovecentoSans', fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ]),
    );
  }

  Future<Map<String, double>> _computeAvgAccuracy(List<QueryDocumentSnapshot> sessionDocs, List<String> shotTypes) async {
    Map<String, int> totalHits = {for (var t in shotTypes) t: 0};
    Map<String, int> totalShots = {for (var t in shotTypes) t: 0};
    for (final doc in sessionDocs) {
      try {
        final shotsSnap = await doc.reference.collection('shots').get();
        for (final shotDoc in shotsSnap.docs) {
          final shot = Shots.fromSnapshot(shotDoc);
          if (shot.type != null && shotTypes.contains(shot.type) && shot.targetsHit != null && shot.count != null && shot.count! > 0) {
            totalHits[shot.type!] = (totalHits[shot.type!] ?? 0) + (shot.targetsHit as num).toInt();
            totalShots[shot.type!] = (totalShots[shot.type!] ?? 0) + (shot.count as num).toInt();
          }
        }
      } catch (_) {}
    }
    return {for (var t in shotTypes) t: totalShots[t]! > 0 ? (totalHits[t]! / totalShots[t]!) * 100.0 : 0.0};
  }

  // ── Achievements card ─────────────────────────────────────────────────────

  Widget _buildAchievementsCard(BuildContext context, User currentUser) {
    final theme = Theme.of(context);
    return _DashboardCard(
      onTap: () => context.push(AppRoutePaths.profileAchievements),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Achievements'.toUpperCase(), style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  AchievementStatsRow(userId: currentUser.uid, padding: EdgeInsets.zero, inline: true),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onPrimary.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  // ── Challenger Road card ──────────────────────────────────────────────────

  Widget _buildChallengerRoadCard(BuildContext context, User currentUser) {
    final theme = Theme.of(context);
    final isPro = _subscriptionLevel == 'pro';
    return _DashboardCard(
      onTap: () => context.push(AppRoutePaths.profileChallengerRoad),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.route_rounded, color: theme.colorScheme.onPrimary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Challenger Road'.toUpperCase(), style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  if (isPro)
                    StreamBuilder<ChallengerRoadUserSummary>(
                      stream: ChallengerRoadService().watchUserSummary(currentUser.uid),
                      builder: (context, snap) {
                        final summary = snap.data ?? ChallengerRoadUserSummary.empty();
                        return Text(
                          'Best: Level ${summary.allTimeBestLevel}  \u00b7  ${summary.totalAttempts} attempt${summary.totalAttempts == 1 ? '' : 's'}',
                          style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7)),
                        );
                      },
                    )
                  else
                    Text(
                      'Pro feature \u2014 unlock to track progress',
                      style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onPrimary.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ── Reusable dashboard card shell ─────────────────────────────────────────────

class _DashboardCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _DashboardCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.primaryContainer;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        child: child,
      ),
    );
  }
}

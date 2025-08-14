import 'dart:ui';
import 'dart:math' as math;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/profile/QR.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tenthousandshotchallenge/tabs/shots/TargetAccuracyVisualizer.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/widgets/AchievementStatsRow.dart';
import 'package:tenthousandshotchallenge/widgets/WeeklyAchievementsWidget.dart';

class Profile extends StatefulWidget {
  const Profile({super.key, this.sessionPanelController, this.updateSessionShotsCB});

  final PanelController? sessionPanelController;
  final Function? updateSessionShotsCB;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // Remove direct singleton usage, use Provider in build/init
  User? get user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;

  final GlobalKey _avatarMenuKey = GlobalKey();
  String _subscriptionLevel = "free";

  String? _selectedIterationId;
  // First and latest session dates for the currently selected iteration.
  // Initialized as null until loaded from Firestore to avoid using DateTime.now() placeholder values.
  DateTime? firstSessionDate;
  DateTime? latestSessionDate;
  bool _loadingSessionDates = false;

  Future<void> _loadFirstLastSession(String? iterationId) async {
    if (iterationId == null || user == null) return;
    if (_loadingSessionDates) return; // prevent overlapping calls
    setState(() => _loadingSessionDates = true);
    try {
      final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
      final sessionsCollection = firestore.collection('iterations').doc(user!.uid).collection('iterations').doc(iterationId).collection('sessions');

      // Fetch first and last session dates with two lightweight queries in parallel.
      final futures = await Future.wait([
        sessionsCollection.orderBy('date', descending: false).limit(1).get(),
        sessionsCollection.orderBy('date', descending: true).limit(1).get(),
      ]);

      final firstSnap = futures[0];
      final lastSnap = futures[1];

      if (firstSnap.docs.isNotEmpty && lastSnap.docs.isNotEmpty) {
        final first = ShootingSession.fromSnapshot(firstSnap.docs.first);
        final last = ShootingSession.fromSnapshot(lastSnap.docs.first);
        setState(() {
          firstSessionDate = first.date;
          latestSessionDate = last.date;
        });
      } else {
        // No sessions yet: clear dates so UI can handle gracefully.
        setState(() {
          firstSessionDate = null;
          latestSessionDate = null;
        });
      }
    } catch (_) {
      // Swallow silently; optional: add debug print.
    } finally {
      if (mounted) {
        setState(() => _loadingSessionDates = false);
      }
    }
  }

  // State for selected shot type in accuracy section
  String _selectedAccuracyShotType = 'wrist';

  // Helper to get shot type colors (reuse from session charts)
  final Map<String, Color> shotTypeColors = {
    'wrist': Colors.cyan,
    'snap': Colors.blue,
    'backhand': Colors.indigo,
    'slap': Colors.teal,
  };

  // Add state for collapsible sections
  bool _showSessions = true;
  bool _showAccuracy = false;
  bool _showAchievements = false;

  // Dummy data for non-pro users
  final Map<String, double> _dummyAvgAccuracy = {
    'wrist': 72.0,
    'backhand': 65.0,
    'slap': 80.0,
    'snap': 68.0,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setInitialIterationId());
    _loadSubscriptionLevel();
    // Keep subscription level in sync with RevenueCat updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
      notifier?.addListener(_onEntitlementsChanged);
    });
  }

  void _onEntitlementsChanged() {
    subscriptionLevel(context).then((level) {
      if (mounted) {
        setState(() => _subscriptionLevel = level);
      }
    });
  }

  _loadSubscriptionLevel() async {
    subscriptionLevel(context).then((level) {
      setState(() {
        _subscriptionLevel = level;
      });
    }).catchError((error) {
      print("Error loading subscription level: $error");
    });
  }

  Future<void> _setInitialIterationId() async {
    User? user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (user == null) return;
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final snapshot = await firestore.collection('iterations').doc(user.uid).collection('iterations').orderBy('start_date', descending: false).get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _selectedIterationId = snapshot.docs.last.id;
      });
    }
  }

  @override
  void dispose() {
    try {
      final notifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
      notifier?.removeListener(_onEntitlementsChanged);
    } catch (_) {}
    super.dispose();
  }

  // Helper to get if the selected iteration is completed
  bool _isCurrentIterationCompleted(AsyncSnapshot<DocumentSnapshot> iterationSnapshot) {
    if (iterationSnapshot.hasData && iterationSnapshot.data!.exists) {
      final iteration = Iteration.fromSnapshot(iterationSnapshot.data!);
      return iteration.complete ?? false;
    }
    return false;
  }

  // 1. Radial area chart for overall average accuracy per shot type
  Widget _buildRadialAccuracyChart(BuildContext context, String? iterationId) {
    // Guard against null user during auth transitions
    final authUser = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (authUser == null && _subscriptionLevel == 'pro') {
      return const SizedBox.shrink();
    }
    if (_subscriptionLevel != 'pro') {
      final shotTypes = ['wrist', 'backhand', 'slap', 'snap'];
      Map<String, double> avgAccuracy = Map<String, double>.from(_dummyAvgAccuracy);
      String challengeLabel = 'challenge 1';
      Widget dateRangeWidget = Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              challengeLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'NovecentoSans',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Text(
              "Accuracy data".toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'NovecentoSans',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Jan 1, 2025 - Jun 1, 2025",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w100,
                fontFamily: 'NovecentoSans',
              ),
            ),
          ),
        ],
      );
      Widget radarWithLabels = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 220,
            width: 220,
            child: RadarChart(
              RadarChartData(
                radarBackgroundColor: Colors.transparent,
                tickCount: 5,
                ticksTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0),
                  fontFamily: 'NovecentoSans',
                  fontSize: 12,
                ),
                getTitle: (index, angle) => RadarChartTitle(
                  positionPercentageOffset: (shotTypes[index] == "backhand" || shotTypes[index] == "snap") ? 0.3 : 0.1,
                  text: shotTypes[index][0].toUpperCase() + shotTypes[index].substring(1),
                ),
                dataSets: [
                  RadarDataSet(
                    fillColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    entryRadius: 0,
                    borderWidth: 0,
                    dataEntries: shotTypes.map((type) => const RadarEntry(value: 30)).toList(),
                  ),
                  RadarDataSet(
                    fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                    borderColor: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                    entryRadius: 6,
                    borderWidth: 2,
                    dataEntries: shotTypes.map((type) => RadarEntry(value: avgAccuracy[type]!)).toList(),
                  ),
                  RadarDataSet(
                    fillColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    entryRadius: 0,
                    borderWidth: 0,
                    dataEntries: shotTypes.map((type) => const RadarEntry(value: 100)).toList(),
                  ),
                ],
                radarShape: RadarShape.circle,
                gridBorderData: BorderSide(color: Colors.black.withValues(alpha: 0.2), width: 2),
                radarBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.25), width: 1.5),
                tickBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 0.8),
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                final radius = constraints.maxWidth / 2 * 0.85;
                List<Widget> labels = [];
                for (int i = 0; i < shotTypes.length; i++) {
                  final angle = (i / shotTypes.length) * 2 * math.pi - math.pi / 2;
                  final value = avgAccuracy[shotTypes[i]]!;
                  final pointRadius = radius * (value / 100.0);
                  double dx = center.dx + pointRadius * math.cos(angle);
                  double dy = center.dy + pointRadius * math.sin(angle) - 18;
                  if (shotTypes[i] == "backhand") {
                    dx = center.dx + pointRadius * math.cos(angle) + 18;
                    dy = center.dy + pointRadius * math.sin(angle) - 22;
                  } else if (shotTypes[i] == "slap") {
                    dx = center.dx + pointRadius * math.cos(angle) - 6;
                    dy = center.dy + pointRadius * math.sin(angle) - 22;
                  }
                  labels.add(Positioned(
                    left: dx - 22,
                    top: dy,
                    child: Text(
                      "${value.round()}%",
                      style: TextStyle(
                        color: shotTypeColors[shotTypes[i]],
                        fontWeight: FontWeight.bold,
                        fontFamily: 'NovecentoSans',
                        fontSize: 16,
                        shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                      ),
                    ),
                  ));
                }
                return Stack(children: labels);
              },
            ),
          ),
        ],
      );
      return Column(
        children: [
          dateRangeWidget,
          radarWithLabels,
        ],
      );
    }

    if (iterationId == null) return Container();
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final currentUser = authUser; // already guarded above
    // Swap 'snap' and 'backhand' in shotTypes for the radar chart
    final shotTypes = ['wrist', 'backhand', 'slap', 'snap'];
    Map<String, double> avgAccuracy = {for (var t in shotTypes) t: 0};
    List<DateTime> accuracyDates = [];

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('iterations').doc(currentUser!.uid).collection('iterations').orderBy('start_date', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
        }
        final docs = snapshot.data!.docs;
        int challengeIndex = docs.indexWhere((doc) => doc.reference.id == iterationId);
        String challengeLabel = challengeIndex != -1 ? 'challenge ${(challengeIndex + 1)}' : '';

        // The rest of the original chart logic
        return StreamBuilder<QuerySnapshot>(
          stream: firestore.collection('iterations').doc(currentUser.uid).collection('iterations').doc(iterationId).collection('sessions').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
            }
            final sessionDocs = snapshot.data!.docs;
            Future<List<ShootingSession>> loadSessionsWithShots() async {
              List<ShootingSession> sessions = [];
              for (final doc in sessionDocs) {
                try {
                  final session = ShootingSession.fromSnapshot(doc);
                  final shotsSnap = await doc.reference.collection('shots').get();
                  final shots = shotsSnap.docs.map((shotDoc) => Shots.fromSnapshot(shotDoc)).toList();
                  session.shots = shots;
                  sessions.add(session);
                } catch (_) {}
              }
              return sessions.where((s) => s.shots != null && s.shots!.any((shot) => shot.type != null && shot.targetsHit != null && shot.count != null && shot.count! > 0)).toList();
            }

            return FutureBuilder<List<ShootingSession>>(
              future: loadSessionsWithShots(),
              builder: (context, asyncSnapshot) {
                if (!asyncSnapshot.hasData) {
                  return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
                }
                final sessions = asyncSnapshot.data!;
                if (sessions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "no accuracy data tracked for this challenge",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                        fontSize: 15,
                        fontFamily: 'NovecentoSans',
                      ),
                    ),
                  );
                }

                Map<String, int> totalHits = {for (var t in shotTypes) t: 0};
                Map<String, int> totalShots = {for (var t in shotTypes) t: 0};

                for (final session in sessions) {
                  for (final shot in session.shots!) {
                    if (shot.type != null && shotTypes.contains(shot.type) && shot.targetsHit != null && shot.count != null && shot.count! > 0) {
                      totalHits[shot.type!] = (totalHits[shot.type!] ?? 0) + (shot.targetsHit as num).toInt();
                      totalShots[shot.type!] = (totalShots[shot.type!] ?? 0) + (shot.count as num).toInt();
                      if (session.date != null) {
                        accuracyDates.add(session.date!);
                      }
                    }
                  }
                }
                for (final type in shotTypes) {
                  avgAccuracy[type] = (totalShots[type]! > 0) ? (totalHits[type]! / totalShots[type]!) * 100 : 0;
                }

                // Show date range for available accuracy data
                Widget dateRangeWidget = Column(
                  children: [
                    if (challengeLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          challengeLabel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NovecentoSans',
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 0),
                      child: Text(
                        "Accuracy data".toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NovecentoSans',
                        ),
                      ),
                    ),
                    if (accuracyDates.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "${DateFormat('MMM d, yyyy').format(accuracyDates.first)} - ${DateFormat('MMM d, yyyy').format(accuracyDates.last)}",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                            fontSize: 18,
                            fontWeight: FontWeight.w100,
                            fontFamily: 'NovecentoSans',
                          ),
                        ),
                      ),
                  ],
                );

                // --- Radial Chart: always 100% outer ring, circular, faded lines ---
                Widget radarWithLabels = Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 220,
                      width: 220,
                      child: RadarChart(
                        RadarChartData(
                          radarBackgroundColor: Colors.transparent,
                          tickCount: 5,
                          ticksTextStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0),
                            fontFamily: 'NovecentoSans',
                            fontSize: 12,
                          ),
                          getTitle: (index, angle) => RadarChartTitle(
                            positionPercentageOffset: (shotTypes[index] == "backhand" || shotTypes[index] == "snap") ? 0.3 : 0.1,
                            text: shotTypes[index][0].toUpperCase() + shotTypes[index].substring(1),
                          ),
                          dataSets: [
                            RadarDataSet(
                              fillColor: Colors.transparent,
                              borderColor: Colors.transparent,
                              entryRadius: 0,
                              borderWidth: 0,
                              dataEntries: shotTypes.map((type) => const RadarEntry(value: 30)).toList(),
                            ),
                            RadarDataSet(
                              fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                              borderColor: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                              entryRadius: 6,
                              borderWidth: 2,
                              dataEntries: shotTypes.map((type) => RadarEntry(value: avgAccuracy[type]!)).toList(),
                            ),
                            RadarDataSet(
                              fillColor: Colors.transparent,
                              borderColor: Colors.transparent,
                              entryRadius: 0,
                              borderWidth: 0,
                              dataEntries: shotTypes.map((type) => const RadarEntry(value: 100)).toList(),
                            ),
                          ],
                          radarShape: RadarShape.circle,
                          gridBorderData: BorderSide(color: Colors.black.withValues(alpha: 0.2), width: 2),
                          radarBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.25), width: 1.5),
                          tickBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 0.8),
                        ),
                      ),
                    ),
                    // Overlay % labels above each plot point
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                          final radius = constraints.maxWidth / 2 * 0.85;
                          List<Widget> labels = [];
                          for (int i = 0; i < shotTypes.length; i++) {
                            final angle = (i / shotTypes.length) * 2 * math.pi - math.pi / 2;
                            final value = avgAccuracy[shotTypes[i]]!;
                            final pointRadius = radius * (value / 100.0);
                            double dx = center.dx + pointRadius * math.cos(angle);
                            double dy = center.dy + pointRadius * math.sin(angle) - 18;

                            if (shotTypes[i] == "backhand") {
                              dx = center.dx + pointRadius * math.cos(angle) + 18;
                              dy = center.dy + pointRadius * math.sin(angle) - 22;
                            } else if (shotTypes[i] == "slap") {
                              dx = center.dx + pointRadius * math.cos(angle) - 6;
                              dy = center.dy + pointRadius * math.sin(angle) - 22;
                            }

                            labels.add(Positioned(
                              left: dx - 22,
                              top: dy,
                              child: Text(
                                "${value.round()}%",
                                style: TextStyle(
                                  color: shotTypeColors[shotTypes[i]],
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 16,
                                  shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                                ),
                              ),
                            ));
                          }
                          return Stack(children: labels);
                        },
                      ),
                    ),
                  ],
                );

                return Column(
                  children: [
                    dateRangeWidget,
                    radarWithLabels,
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // 2. TargetAccuracyVisualizers for each shot type, tappable
  Widget _buildShotTypeAccuracyVisualizers(BuildContext context, String? iterationId) {
    final authUser = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (authUser == null && _subscriptionLevel == 'pro') {
      return const SizedBox.shrink();
    }
    if (_subscriptionLevel != 'pro') {
      // Always show dummy data for non-pro users
      final shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
      Map<String, double> avgAccuracy = Map<String, double>.from(_dummyAvgAccuracy);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: shotTypes.map((type) {
          return Column(
            children: [
              Text(
                type.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 16,
                  fontFamily: 'NovecentoSans',
                ),
              ),
              SizedBox(height: 4),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: shotTypeColors[type],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${avgAccuracy[type]!.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'NovecentoSans',
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      );
    }

    User? user = authUser;
    if (iterationId == null || user == null) return Container();

    final shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
    return StreamBuilder<QuerySnapshot>(
      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user.uid).collection('iterations').doc(iterationId).collection('sessions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
        }
        final sessionDocs = snapshot.data!.docs;
        Future<List<ShootingSession>> loadSessionsWithShots() async {
          List<ShootingSession> sessions = [];
          for (final doc in sessionDocs) {
            try {
              final session = ShootingSession.fromSnapshot(doc);
              final shotsSnap = await doc.reference.collection('shots').get();
              final shots = shotsSnap.docs.map((shotDoc) => Shots.fromSnapshot(shotDoc)).toList();
              session.shots = shots;
              sessions.add(session);
            } catch (_) {}
          }
          return sessions.where((s) => s.shots != null && s.shots!.any((shot) => shot.type != null && shot.targetsHit != null && shot.count != null && shot.count! > 0)).toList();
        }

        return FutureBuilder<List<ShootingSession>>(
          future: loadSessionsWithShots(),
          builder: (context, asyncSnapshot) {
            if (!asyncSnapshot.hasData) {
              return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
            }
            final sessions = asyncSnapshot.data!;

            if (sessions.isEmpty) {
              return const SizedBox();
            }

            Map<String, int> totalHits = {for (var t in shotTypes) t: 0};
            Map<String, int> totalShots = {for (var t in shotTypes) t: 0};

            for (final session in sessions) {
              for (final shot in session.shots!) {
                if (shot.type != null && shotTypes.contains(shot.type) && shot.targetsHit != null && shot.count != null && shot.count! > 0) {
                  totalHits[shot.type!] = (totalHits[shot.type!] ?? 0) + (shot.targetsHit as num).toInt();
                  totalShots[shot.type!] = (totalShots[shot.type!] ?? 0) + (shot.count as num).toInt();
                }
              }
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: shotTypes.map((type) {
                final color = shotTypeColors[type]!;
                final isActive = _selectedAccuracyShotType == type;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAccuracyShotType = type;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        TargetAccuracyVisualizer(
                          hits: totalHits[type]!,
                          total: totalShots[type]!,
                          shotColor: color,
                          size: isActive ? 80 : 60,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            color: isActive ? color : Theme.of(context).colorScheme.onPrimary.withAlpha(153),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NovecentoSans',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  // 3. Scatter chart for accuracy over time for selected shot type
  Widget _buildAccuracyScatterChart(BuildContext context, String? iterationId) {
    final authUser = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (authUser == null && _subscriptionLevel == 'pro') {
      return const SizedBox.shrink();
    }
    if (_subscriptionLevel != 'pro') {
      // Always show dummy data for non-pro users
      final shotType = _selectedAccuracyShotType;
      final dummyData = {
        'wrist': [72.0, 74.0, 70.0, 73.0, 72.0],
        'backhand': [65.0, 67.0, 64.0, 66.0, 65.0],
        'slap': [80.0, 81.0, 79.0, 80.0, 80.0],
        'snap': [68.0, 69.0, 67.0, 68.0, 68.0],
      };
      final dummyDates = List.generate(5, (i) => DateTime.now().subtract(Duration(days: 4 - i)));
      return SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: dummyData[shotType]!.length,
          itemBuilder: (context, i) {
            return Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: dummyData[shotType]![i],
                    width: 30,
                    color: shotTypeColors[shotType],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${dummyData[shotType]![i].toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 14,
                      fontFamily: 'NovecentoSans',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${dummyDates[i].month}/${dummyDates[i].day}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                      fontSize: 12,
                      fontFamily: 'NovecentoSans',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    User? user = authUser;
    if (iterationId == null || user == null) return Container();

    final shotType = _selectedAccuracyShotType;
    return StreamBuilder<QuerySnapshot>(
      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user.uid).collection('iterations').doc(iterationId).collection('sessions').orderBy('date', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
        }
        final sessionDocs = snapshot.data!.docs;
        Future<List<ShootingSession>> loadSessionsWithShots() async {
          List<ShootingSession> sessions = [];
          for (final doc in sessionDocs) {
            try {
              final session = ShootingSession.fromSnapshot(doc);
              final shotsSnap = await doc.reference.collection('shots').get();
              final shots = shotsSnap.docs.map((shotDoc) => Shots.fromSnapshot(shotDoc)).toList();
              session.shots = shots;
              sessions.add(session);
            } catch (_) {}
          }
          // Only sessions with at least one valid shot of this type
          return sessions.where((s) => s.shots != null && s.shots!.any((shot) => shot.type == shotType && shot.targetsHit != null && shot.count != null && shot.count! > 0)).toList();
        }

        return FutureBuilder<List<ShootingSession>>(
          future: loadSessionsWithShots(),
          builder: (context, asyncSnapshot) {
            if (!asyncSnapshot.hasData) {
              return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
            }
            final sessions = asyncSnapshot.data!;

            if (sessions.isEmpty) {
              return const SizedBox();
            }

            // --- Combine all shots of this type in each session into one dot ---
            List<FlSpot> spots = [];
            List<double> allAccuracies = [];
            List<DateTime> accuracyDates = [];
            int sessionIndex = 0;
            for (final session in sessions) {
              // Combine all shots of this type in this session
              final relevantShots = session.shots!.where((shot) => shot.type == shotType && shot.targetsHit != null && shot.count != null && shot.count! > 0).toList();
              if (relevantShots.isNotEmpty) {
                int totalHits = relevantShots.fold(0, (sum, s) => sum + (s.targetsHit ?? 0));
                int totalShots = relevantShots.fold(0, (sum, s) => sum + (s.count ?? 0));
                if (totalShots > 0) {
                  double accuracy = (totalHits / totalShots) * 100.0;
                  spots.add(FlSpot(sessionIndex.toDouble(), accuracy));
                  allAccuracies.add(accuracy);
                  accuracyDates.add(session.date!);
                  sessionIndex++;
                }
              }
            }

            // Calculate trend line (simple linear regression)
            List<FlSpot> trendLine = [];
            if (spots.length > 1) {
              double n = spots.length.toDouble();
              double sumX = spots.fold(0, (sum, s) => sum + s.x);
              double sumY = spots.fold(0, (sum, s) => sum + s.y);
              double sumXY = spots.fold(0, (sum, s) => sum + s.x * s.y);
              double sumX2 = spots.fold(0, (sum, s) => sum + s.x * s.x);
              double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX + 0.0001);
              double intercept = (sumY - slope * sumX) / n;
              trendLine = [
                FlSpot(spots.first.x, slope * spots.first.x + intercept),
                FlSpot(spots.last.x, slope * spots.last.x + intercept),
              ];
            }

            // --- Chart layout tweaks ---
            double dotSpacing = 18;
            double rightPadding = 36;
            double minChartWidth = 320;
            double chartWidth = minChartWidth;
            if (spots.isNotEmpty) {
              chartWidth = (spots.length - 1) * dotSpacing + rightPadding;
              if (chartWidth < minChartWidth) chartWidth = minChartWidth;
            }
            double chartHeight = chartWidth;
            double maxChartHeight = 400;
            if (chartHeight > maxChartHeight) chartHeight = maxChartHeight;

            Map<double, String> xLabels = {};
            if (accuracyDates.isNotEmpty && spots.isNotEmpty) {
              xLabels[spots.first.x] = DateFormat('MMM d').format(accuracyDates.first);
              xLabels[spots.last.x] = DateFormat('MMM d').format(accuracyDates.last);
            }

            return Column(
              children: [
                Text(
                  '${shotType[0].toUpperCase()}${shotType.substring(1)} Shot Accuracy',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    height: chartHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 24, top: 8, bottom: 0),
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: 100,
                          minX: 0,
                          maxX: spots.isNotEmpty ? spots.last.x : 1,
                          gridData: FlGridData(show: true, horizontalInterval: 20, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withValues(alpha: 0.1), strokeWidth: 1)),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 32, interval: 20, getTitlesWidget: (v, meta) => Text('${v.toInt()}%', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12))),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (value, meta) {
                                  if (xLabels.containsKey(value)) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(xLabels[value]!, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12)),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2))),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: false,
                              color: shotTypeColors[shotType] ?? Colors.cyan,
                              barWidth: 0,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  return FlDotCirclePainter(
                                    radius: 5,
                                    color: shotTypeColors[shotType] ?? Colors.cyan,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(show: false),
                            ),
                            if (trendLine.isNotEmpty)
                              LineChartBarData(
                                spots: trendLine,
                                isCurved: false,
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                barWidth: 2,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(show: false),
                              ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (LineBarSpot spot) => Colors.white,
                              fitInsideHorizontally: false,
                              fitInsideVertically: false,
                              tooltipMargin: 8,
                              tooltipBorderRadius: BorderRadius.circular(8),
                              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((touchedSpot) {
                                  // Find the correct index for this spot
                                  int idx = spots.indexWhere((s) => s.x == touchedSpot.x && s.y == touchedSpot.y);
                                  final date = (idx >= 0 && idx < accuracyDates.length) ? DateFormat('MMM d, yyyy').format(accuracyDates[idx]) : '';
                                  return LineTooltipItem(
                                    (idx >= 0 && idx < allAccuracies.length) ? '${allAccuracies[idx].toStringAsFixed(1)}%' : '',
                                    TextStyle(color: shotTypeColors[shotType], fontWeight: FontWeight.bold, fontSize: 18),
                                    children: [
                                      if (idx >= 0 && idx < allAccuracies.length)
                                        TextSpan(
                                          text: '\n$date',
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                    ],
                                  );
                                }).toList();
                              },
                            ),
                            handleBuiltInTouches: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user; // getter
    if (currentUser == null) {
      // While auth state is changing (e.g., user just signed out) we avoid building with null assertions
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      key: const Key('profile_tab_body'),
      padding: isThreeButtonAndroidNavigation(context)
          ? EdgeInsets.only(bottom: sessionService.isRunning ? MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight + 65 : MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight)
          : sessionService.isRunning
              ? EdgeInsets.only(top: 15, bottom: 65)
              : EdgeInsets.only(top: 15),
      child: SingleChildScrollView(
        // <-- Make the whole profile screen scrollable
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 15),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
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
                                        Text(
                                          "Change Avatar".toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'NovecentoSans',
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                        Icon(
                                          Icons.edit,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'qr_code',
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Show QR Code".toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'NovecentoSans',
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                        Icon(
                                          Icons.qr_code_2_rounded,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    context.push('/editProfile');
                                  } else if (value == 'qr_code') {
                                    showQRCode(context, currentUser);
                                  }
                                },
                              ),
                              Container(
                                width: 60,
                                height: 60,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(60),
                                ),
                                child: GestureDetector(
                                  onLongPress: () {
                                    Feedback.forLongPress(context);
                                    context.push('/editProfile');
                                  },
                                  onTap: () {
                                    Feedback.forTap(context);
                                    dynamic state = _avatarMenuKey.currentState;
                                    state.showButtonMenu();
                                  },
                                  child: SizedBox(
                                    height: 60,
                                    width: 60,
                                    child: StreamBuilder<DocumentSnapshot>(
                                      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(currentUser.uid).snapshots(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          UserProfile userProfile = UserProfile.fromSnapshot(snapshot.data!);
                                          return UserAvatar(
                                            user: userProfile,
                                            backgroundColor: Colors.transparent,
                                          );
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
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 100) * 0.6,
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(currentUser.uid).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Center(
                                      child: SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              UserProfile userProfile = UserProfile.fromSnapshot(snapshot.data as DocumentSnapshot);

                              return SizedBox(
                                width: (MediaQuery.of(context).size.width - 100) * 0.5,
                                child: AutoSizeText(
                                  userProfile.displayName != null && userProfile.displayName!.isNotEmpty ? userProfile.displayName! : (currentUser.displayName ?? 'Player'),
                                  maxLines: 1,
                                  maxFontSize: 22,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        StreamBuilder(
                            stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(currentUser.uid).collection('iterations').snapshots(),
                            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                  child: SizedBox(
                                    width: (MediaQuery.of(context).size.width - 100) * 0.5,
                                    height: 2,
                                    child: const LinearProgressIndicator(),
                                  ),
                                );
                              } else {
                                int total = 0;
                                for (var doc in snapshot.data!.docs) {
                                  total += Iteration.fromSnapshot(doc).total!;
                                }

                                return SizedBox(
                                  width: (MediaQuery.of(context).size.width - 100) * 0.5,
                                  child: AutoSizeText(
                                    total > 999 ? numberFormat.format(total) + " Lifetime Shots".toLowerCase() : total.toString() + " Lifetime Shots".toLowerCase(),
                                    maxFontSize: 20,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'NovecentoSans',
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                );
                              }
                            }),
                        StreamBuilder(
                            stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(currentUser.uid).collection('iterations').snapshots(),
                            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                  child: SizedBox(
                                    width: (MediaQuery.of(context).size.width - 100) * 0.5,
                                    height: 2,
                                    child: const LinearProgressIndicator(),
                                  ),
                                );
                              } else {
                                Duration totalDuration = const Duration();
                                for (var doc in snapshot.data!.docs) {
                                  totalDuration += Iteration.fromSnapshot(doc).totalDuration!;
                                }

                                return totalDuration > const Duration()
                                    ? Text(
                                        "IN ${printDuration(totalDuration, true)}",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontFamily: 'NovecentoSans',
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      )
                                    : Container();
                              }
                            }),
                      ],
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(right: 15),
                  child: Row(
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user!.uid).collection('iterations').orderBy('start_date', descending: false).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }
                          List<DropdownMenuItem<String>> iterations = [];
                          String? latestIterationId;
                          snapshot.data!.docs.asMap().forEach((i, iDoc) {
                            iterations.add(DropdownMenuItem<String>(
                              value: iDoc.reference.id,
                              child: Text(
                                "challenge ${(i + 1).toString().toLowerCase()}",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 20,
                                  fontFamily: 'NovecentoSans',
                                ),
                              ),
                            ));
                            // Always update latestIterationId to the last one
                            latestIterationId = iDoc.reference.id;
                          });

                          // Set default selected iteration if not set
                          if (_selectedIterationId == null && iterations.isNotEmpty) {
                            _selectedIterationId = latestIterationId;
                            // Load session date bounds for initial iteration selection.
                            WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirstLastSession(_selectedIterationId));
                          }

                          // Only show the dropdown if there is more than one challenge
                          if (iterations.length <= 1) {
                            return Container();
                          }

                          return DropdownButton<String>(
                            value: _selectedIterationId,
                            items: iterations,
                            onChanged: (value) {
                              setState(() {
                                _selectedIterationId = value;
                                // Reset dates before loading to avoid stale display.
                                firstSessionDate = null;
                                latestSessionDate = null;
                              });
                              _loadFirstLastSession(value);
                            },
                            dropdownColor: Theme.of(context).colorScheme.primary,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: _selectedIterationId == null ? null : Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  Iteration i = Iteration.fromSnapshot(snapshot.data as DocumentSnapshot);

                  // Decide which day-span calculation to use:
                  // Completed iteration: inclusive span between first session date (or iteration startDate if available) and endDate.
                  // Active iteration: inclusive span between first and latest session dates (or fallback to first->now if latest missing).
                  if (i.endDate != null) {
                    final DateTime? startRef = firstSessionDate ?? i.startDate; // fallback to stored startDate if model contains it
                    int daysTaken = (startRef != null) ? i.endDate!.difference(startRef).inDays + 1 : 0;
                    // Never show 0 days if iteration has any shots; clamp to minimum 1 for display
                    if (daysTaken < 1 && (i.total ?? 0) > 0) daysTaken = 1;
                    String endDate = DateFormat('MMMM d, y').format(i.endDate!);
                    String iterationDescription;
                    String goalDescription = "";
                    String fTotal = i.total! > 999 ? numberFormat.format(i.total) : i.total.toString();
                    iterationDescription = daysTaken == 1 ? "$fTotal shots in $daysTaken day" : "$fTotal shots in $daysTaken days";

                    if (i.targetDate != null) {
                      String targetDate = DateFormat('MMMM d, y').format(i.targetDate!);
                      int daysBeforeAfterTarget = i.targetDate!.difference(i.endDate!).inDays;

                      if (daysBeforeAfterTarget > 0) {
                        if (daysBeforeAfterTarget.abs() <= 1) {
                          goalDescription += " ${daysBeforeAfterTarget.abs()} day before goal";
                        } else {
                          goalDescription += " ${daysBeforeAfterTarget.abs()} days before goal";
                        }
                      } else if (daysBeforeAfterTarget < 0) {
                        if (daysBeforeAfterTarget.abs() <= 1) {
                          goalDescription += " ${daysBeforeAfterTarget.abs()} day after goal";
                        } else {
                          goalDescription += " ${daysBeforeAfterTarget.abs()} days after goal";
                        }
                      }

                      goalDescription += " ($targetDate)";
                    } else {
                      goalDescription += "completed on $endDate";
                    }

                    return SizedBox(
                      width: MediaQuery.of(context).size.width - 20,
                      height: 60,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 8,
                              ),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    FontAwesomeIcons.hockeyPuck,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  Positioned(
                                    left: -6,
                                    top: -6,
                                    child: Icon(
                                      FontAwesomeIcons.hockeyPuck,
                                      size: 8,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                  Positioned(
                                    left: -5,
                                    bottom: -5,
                                    child: Icon(
                                      FontAwesomeIcons.hockeyPuck,
                                      size: 6,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                  Positioned(
                                    right: -4,
                                    top: -6,
                                    child: Icon(
                                      FontAwesomeIcons.hockeyPuck,
                                      size: 6,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                  Positioned(
                                    right: -4,
                                    bottom: -8,
                                    child: Icon(
                                      FontAwesomeIcons.hockeyPuck,
                                      size: 8,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              AutoSizeText(
                                iterationDescription.toLowerCase(),
                                maxFontSize: 18,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontFamily: "NovecentoSans",
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                FontAwesomeIcons.calendarCheck,
                                size: 20,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              AutoSizeText(
                                goalDescription.toLowerCase(),
                                maxFontSize: 18,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontFamily: "NovecentoSans",
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Active iteration: derive inclusive day span only when we have at least one session date.
                    final DateTime? first = firstSessionDate;
                    final DateTime? latest = latestSessionDate;
                    int daysSoFar = 0;
                    if (first != null) {
                      final DateTime latestRef = latest ?? DateTime.now();
                      daysSoFar = latestRef.difference(first).inDays + 1;
                    }
                    // Clamp: Never show 0 days once any shots have been logged in the iteration.
                    if (daysSoFar < 1 && (i.total ?? 0) > 0) daysSoFar = 1;
                    String? iterationDescription;
                    String goalDescription = "";
                    int remainingShots = 10000 - i.total!;
                    String fRemainingShots = remainingShots > 999 ? numberFormat.format(remainingShots) : remainingShots.toString();
                    String fTotal = i.total! > 999 ? numberFormat.format(i.total) : i.total.toString();
                    iterationDescription = daysSoFar == 1 ? "$fTotal shots in $daysSoFar day" : "$fTotal shots in $daysSoFar days";

                    if (i.targetDate != null && remainingShots > 0) {
                      String? targetDate = DateFormat("MM/dd/yyyy").format(i.targetDate!);
                      int daysBeforeAfterTarget = i.targetDate!.difference(DateTime.now()).inDays;
                      if (i.targetDate!.compareTo(DateTime.now()) < 0) {
                        daysBeforeAfterTarget = DateTime.now().difference(i.targetDate!).inDays * -1;
                      }

                      if (daysBeforeAfterTarget > 0) {
                        if (daysBeforeAfterTarget <= 1 && daysBeforeAfterTarget != 0) {
                          goalDescription += "${daysBeforeAfterTarget.abs()} day left to take $fRemainingShots shots";
                        } else {
                          goalDescription += "${daysBeforeAfterTarget.abs()} days left to take $fRemainingShots shots";
                        }
                      } else if (daysBeforeAfterTarget < 0) {
                        if (daysBeforeAfterTarget == -1) {
                          goalDescription += "${daysBeforeAfterTarget.abs()} day past goal ($targetDate)";
                        } else {
                          goalDescription += "${daysBeforeAfterTarget.abs()} days past goal ($targetDate)";
                        }
                      } else {
                        goalDescription += "1 day left to take $fRemainingShots shots";
                      }
                    }

                    return SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: 60,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: (remainingShots >= 10000 || remainingShots <= 0) ? MainAxisAlignment.center : MainAxisAlignment.spaceEvenly,
                        children: [
                          remainingShots >= 10000
                              ? Container()
                              : Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Icon(
                                          FontAwesomeIcons.hockeyPuck,
                                          size: 14,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                        Positioned(
                                          left: -6,
                                          top: -6,
                                          child: Icon(
                                            FontAwesomeIcons.hockeyPuck,
                                            size: 8,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                        Positioned(
                                          left: -5,
                                          bottom: -5,
                                          child: Icon(
                                            FontAwesomeIcons.hockeyPuck,
                                            size: 6,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                        Positioned(
                                          right: -4,
                                          top: -6,
                                          child: Icon(
                                            FontAwesomeIcons.hockeyPuck,
                                            size: 6,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                        Positioned(
                                          right: -4,
                                          bottom: -8,
                                          child: Icon(
                                            FontAwesomeIcons.hockeyPuck,
                                            size: 8,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * .3,
                                      child: AutoSizeText(
                                        iterationDescription.toLowerCase(),
                                        maxFontSize: 18,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontFamily: "NovecentoSans",
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          remainingShots <= 0
                              ? Container()
                              : Row(
                                  children: [
                                    const Icon(
                                      FontAwesomeIcons.calendarCheck,
                                      size: 20,
                                    ),
                                    const SizedBox(
                                      width: 2,
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * .4,
                                      child: AutoSizeText(
                                        goalDescription != "" ? goalDescription.toLowerCase() : "N/A".toLowerCase(),
                                        maxFontSize: 18,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontFamily: "NovecentoSans",
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    );
                  }
                }

                return Container();
              },
            ),
            // Achievements section: collapsible like others
            GestureDetector(
              onTap: () {
                Future.microtask(() {
                  setState(() {
                    if (_showAchievements) {
                      _showAchievements = false;
                    } else {
                      _showAchievements = true;
                      _showAccuracy = false;
                      _showSessions = false;
                    }
                  });
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: lighten(Theme.of(context).colorScheme.primary, 0.1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                margin: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Achievements'.toUpperCase(),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(width: 10),
                          if (user != null)
                            Flexible(
                              child: AchievementStatsRow(
                                userId: user!.uid,
                                padding: EdgeInsets.zero,
                                inline: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      _showAchievements ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 6.0, bottom: 8),
                child: Opacity(
                  opacity: _showAchievements ? 1.0 : 0.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
                        child: const WeeklyAchievementsWidget(),
                      ),
                    ],
                  ),
                ),
              ),
              crossFadeState: _showAchievements ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 350),
              sizeCurve: Curves.easeInOut,
            ),
            GestureDetector(
              onTap: () {
                Future.microtask(() {
                  setState(() {
                    // Toggle: If already open, close. If closed, open and close the other.
                    if (_showAccuracy) {
                      _showAccuracy = false;
                    } else {
                      _showAccuracy = true;
                      _showSessions = false;
                      _showAchievements = false;
                    }
                  });
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: lighten(Theme.of(context).colorScheme.primary, 0.1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Shot Accuracy".toUpperCase(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    // Shot type stats row
                    (_subscriptionLevel != 'pro' || _selectedIterationId == null)
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Builder(
                                builder: (context) {
                                  final shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
                                  final shotTypeLabels = {'wrist': 'W', 'snap': 'S', 'slap': 'SL', 'backhand': 'B'};
                                  final shotTypeColorsLocal = {
                                    'wrist': wristShotColor,
                                    'snap': snapShotColor,
                                    'slap': slapShotColor,
                                    'backhand': backhandShotColor,
                                  };
                                  Map<String, double> accuracyMap = _dummyAvgAccuracy;
                                  return Row(
                                    children: shotTypes.map((type) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              shotTypeLabels[type]!,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onPrimary,
                                                fontFamily: 'NovecentoSans',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Container(
                                                  width: 30,
                                                  height: 25,
                                                  decoration: BoxDecoration(
                                                    color: shotTypeColorsLocal[type],
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                                Text(
                                                  "${accuracyMap[type]?.toStringAsFixed(0) ?? '--'}%",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: 'NovecentoSans',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                                    child: Container(
                                      color: Colors.white.withOpacity(0.35),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : StreamBuilder<QuerySnapshot>(
                            stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).collection('sessions').snapshots(),
                            builder: (context, snapshot) {
                              final shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
                              final shotTypeLabels = {'wrist': 'W', 'snap': 'S', 'slap': 'SL', 'backhand': 'B'};
                              final shotTypeColorsLocal = {
                                'wrist': wristShotColor,
                                'snap': snapShotColor,
                                'slap': slapShotColor,
                                'backhand': backhandShotColor,
                              };
                              if (!snapshot.hasData) {
                                return Row(
                                  children: shotTypes
                                      .map((type) => Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(shotTypeLabels[type]!, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'NovecentoSans', fontWeight: FontWeight.bold, fontSize: 14)),
                                                Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Container(
                                                      width: 30,
                                                      height: 25,
                                                      decoration: BoxDecoration(
                                                        color: shotTypeColorsLocal[type],
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 24,
                                                      height: 16,
                                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                );
                              }
                              final sessionDocs = snapshot.data!.docs;
                              return FutureBuilder<List<ShootingSession>>(
                                future: (() async {
                                  List<ShootingSession> sessions = [];
                                  for (final doc in sessionDocs) {
                                    try {
                                      final session = ShootingSession.fromSnapshot(doc);
                                      final shotsSnap = await doc.reference.collection('shots').get();
                                      final shots = shotsSnap.docs.map((shotDoc) => Shots.fromSnapshot(shotDoc)).toList();
                                      session.shots = shots;
                                      sessions.add(session);
                                    } catch (_) {}
                                  }
                                  return sessions.where((s) => s.shots != null && s.shots!.any((shot) => shot.type != null && shot.targetsHit != null && shot.count != null && shot.count! > 0)).toList();
                                })(),
                                builder: (context, asyncSnapshot) {
                                  Map<String, double> accuracyMap = {for (var t in shotTypes) t: 0};
                                  if (asyncSnapshot.hasData && asyncSnapshot.data!.isNotEmpty) {
                                    Map<String, int> totalHits = {for (var t in shotTypes) t: 0};
                                    Map<String, int> totalShots = {for (var t in shotTypes) t: 0};
                                    for (final session in asyncSnapshot.data!) {
                                      for (final shot in session.shots!) {
                                        if (shot.type != null && shotTypes.contains(shot.type) && shot.targetsHit != null && shot.count != null && shot.count! > 0) {
                                          totalHits[shot.type!] = (totalHits[shot.type!] ?? 0) + (shot.targetsHit as num).toInt();
                                          totalShots[shot.type!] = (totalShots[shot.type!] ?? 0) + (shot.count as num).toInt();
                                        }
                                      }
                                    }
                                    for (final type in shotTypes) {
                                      accuracyMap[type] = (totalShots[type]! > 0) ? (totalHits[type]! / totalShots[type]!) * 100 : 0;
                                    }
                                  }
                                  return Row(
                                    children: shotTypes.map((type) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              shotTypeLabels[type]!,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onPrimary,
                                                fontFamily: 'NovecentoSans',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Container(
                                                  width: 30,
                                                  height: 25,
                                                  decoration: BoxDecoration(
                                                    color: shotTypeColorsLocal[type],
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                                Text(
                                                  "${accuracyMap[type]?.toStringAsFixed(0) ?? '--'}%",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: 'NovecentoSans',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              );
                            },
                          ),
                    Icon(
                      _showAccuracy ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _subscriptionLevel != 'pro'
                  ? Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, bottom: 50),
                          child: Opacity(
                            opacity: _showAccuracy ? 1.0 : 0.0,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildShotTypeAccuracyVisualizers(context, _selectedIterationId),
                                  const SizedBox(height: 15),
                                  _buildAccuracyScatterChart(context, _selectedIterationId),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.4),
                                alignment: Alignment.center,
                                child: const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock, color: Colors.white, size: 48),
                                      SizedBox(height: 12),
                                      Text(
                                        'Start a Pro subscription to\nunlock accuracy tracking!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'NovecentoSans',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 50),
                      child: Opacity(
                        opacity: _showAccuracy ? 1.0 : 0.0,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildRadialAccuracyChart(context, _selectedIterationId),
                              const SizedBox(height: 15),
                              _buildShotTypeAccuracyVisualizers(context, _selectedIterationId),
                              const SizedBox(height: 15),
                              _buildAccuracyScatterChart(context, _selectedIterationId),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
              crossFadeState: _showAccuracy ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 350),
              sizeCurve: Curves.easeInOut,
            ),

            // Collapsible Recent Sessions section header (now below My Accuracy)
            GestureDetector(
              onTap: () {
                // Use Future.microtask to avoid scrollable assertion errors
                Future.microtask(() {
                  setState(() {
                    // Toggle: If already open, close. If closed, open and close the other.
                    if (_showSessions) {
                      _showSessions = false;
                    } else {
                      _showSessions = true;
                      _showAccuracy = false;
                      _showAchievements = false;
                    }
                  });
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: lighten(Theme.of(context).colorScheme.primary, 0.1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Recent Sessions".toUpperCase(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Icon(
                      _showSessions ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  // Only show session shot type legend if expanded
                  Container(
                    decoration: BoxDecoration(color: lighten(Theme.of(context).colorScheme.primary, 0.1)),
                    padding: const EdgeInsets.only(top: 5, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          "Wrist".toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontFamily: 'NovecentoSans',
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 25,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(color: wristShotColor),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Opacity(
                                opacity: 0.75,
                                child: Text(
                                  "W",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'NovecentoSans',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "Snap".toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontFamily: 'NovecentoSans',
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 25,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(color: snapShotColor),
                          child: const Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Opacity(
                                opacity: 0.75,
                                child: Text(
                                  "SN",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'NovecentoSans',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          "Backhand".toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontFamily: 'NovecentoSans',
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 25,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(color: backhandShotColor),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Opacity(
                                opacity: 0.75,
                                child: Text(
                                  "B",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'NovecentoSans',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "Slap".toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontFamily: 'NovecentoSans',
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 25,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(color: slapShotColor),
                          child: const Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Opacity(
                                opacity: 0.75,
                                child: Text(
                                  "SL",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'NovecentoSans',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Recent Sessions StreamBuilder (only show if sessions expanded)
                  if (_selectedIterationId != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
                      builder: (context, snapshot) {
                        final iterationCompleted = _isCurrentIterationCompleted(snapshot);
                        return StreamBuilder<QuerySnapshot>(
                          stream: Provider.of<FirebaseFirestore>(context, listen: false)
                              .collection('iterations')
                              .doc(user!.uid)
                              .collection('iterations')
                              .doc(_selectedIterationId)
                              .collection('sessions')
                              .orderBy('date', descending: true)
                              .limit(3)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return SizedBox(
                                height: 25,
                                width: 25,
                                child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                              );
                            }
                            List<DocumentSnapshot> sessions = snapshot.data!.docs;
                            if (sessions.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 20.0, bottom: 10),
                                child: Text(
                                  "You don't have any sessions yet".toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'NovecentoSans',
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: List.generate(
                                sessions.length,
                                (i) => _buildSessionItem(
                                  ShootingSession.fromSnapshot(sessions[i]),
                                  i,
                                  iterationCompleted, // Pass completed status
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  // Add History button below the Recent Sessions section (only show if sessions expanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: ElevatedButton.icon(
                      key: const Key('viewHistoryButton'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.history),
                      label: Text(
                        "View History".toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 18,
                        ),
                      ),
                      onPressed: () {
                        context.push('/history');
                      },
                    ),
                  ),
                ],
              ),
              crossFadeState: _showSessions ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 350),
              sizeCurve: Curves.easeInOut,
            ),
            // Add bottom space to prevent content from being cut off
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(ShootingSession s, int i, bool iterationCompleted) {
    return AbsorbPointer(
      absorbing: iterationCompleted,
      child: Dismissible(
        key: UniqueKey(),
        onDismissed: (direction) async {
          Fluttertoast.showToast(
            msg: '${s.total} shots deleted',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Theme.of(context).cardTheme.color,
            textColor: Theme.of(context).colorScheme.onPrimary,
            fontSize: 16.0,
          );

          await deleteSession(
            s,
            Provider.of<FirebaseAuth>(context, listen: false),
            Provider.of<FirebaseFirestore>(context, listen: false),
          ).then((deleted) {
            if (!deleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Theme.of(context).cardTheme.color,
                  content: Text(
                    "Sorry this session can't be deleted",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  duration: const Duration(milliseconds: 1500),
                ),
              );
            }
          });
        },
        confirmDismiss: (DismissDirection direction) async {
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  "Delete Session?".toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 24,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Are you sure you want to delete this shooting session forever?",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    Container(
                      height: 120,
                      margin: const EdgeInsets.only(top: 15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You will lose:",
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            s.total.toString() + " Shots".toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            "Taken on:",
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            printDate(s.date!),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      "Cancel".toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      "Delete".toUpperCase(),
                      style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              );
            },
          );
        },
        background: Container(
          color: Theme.of(context).primaryColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                margin: const EdgeInsets.only(left: 15),
                child: Text(
                  "Delete".toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 15),
                child: const Icon(
                  Icons.delete,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.only(top: 5, bottom: 15),
          decoration: BoxDecoration(
            color: i % 2 == 0 ? Colors.transparent : Theme.of(context).cardTheme.color,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      printDate(s.date!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 18,
                        fontFamily: 'NovecentoSans',
                      ),
                    ),
                    Text(
                      printDuration(s.duration!, true),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 18,
                        fontFamily: 'NovecentoSans',
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          s.total.toString() + " Shots".toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontFamily: 'NovecentoSans',
                          ),
                        ),
                        // Resume session code removed
                        // Only show delete menu
                        if (!iterationCompleted)
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: PopupMenuButton(
                              key: UniqueKey(),
                              color: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 24,
                              ),
                              itemBuilder: (_) => <PopupMenuItem<String>>[
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Delete".toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                      Icon(
                                        Icons.delete,
                                        color: Colors.red.shade600,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  return await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text(
                                          "Delete Session?".toUpperCase(),
                                          style: const TextStyle(
                                            fontFamily: 'NovecentoSans',
                                            fontSize: 24,
                                          ),
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Are you sure you want to delete this shooting session forever?",
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onPrimary,
                                              ),
                                            ),
                                            Container(
                                              height: 120,
                                              margin: const EdgeInsets.only(top: 15),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "You will lose:",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Text(
                                                    s.total.toString() + " Shots".toUpperCase(),
                                                    style: TextStyle(
                                                      fontFamily: 'NovecentoSans',
                                                      fontSize: 20,
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Text(
                                                    "Taken on:",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Text(
                                                    printDate(s.date!),
                                                    style: TextStyle(
                                                      fontFamily: 'NovecentoSans',
                                                      fontSize: 20,
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: Text(
                                              "Cancel".toUpperCase(),
                                              style: TextStyle(
                                                fontFamily: 'NovecentoSans',
                                                color: Theme.of(context).colorScheme.onPrimary,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              Fluttertoast.showToast(
                                                msg: '${s.total} shots deleted',
                                                toastLength: Toast.LENGTH_SHORT,
                                                gravity: ToastGravity.BOTTOM,
                                                timeInSecForIosWeb: 1,
                                                backgroundColor: Theme.of(context).cardTheme.color,
                                                textColor: Theme.of(context).colorScheme.onPrimary,
                                                fontSize: 16.0,
                                              );

                                              await deleteSession(
                                                s,
                                                Provider.of<FirebaseAuth>(context, listen: false),
                                                Provider.of<FirebaseFirestore>(context, listen: false),
                                              ).then((deleted) {
                                                if (!deleted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      backgroundColor: Theme.of(context).cardTheme.color,
                                                      content: Text(
                                                        "Sorry this session can't be deleted",
                                                        style: TextStyle(
                                                          color: Theme.of(context).colorScheme.onPrimary,
                                                        ),
                                                      ),
                                                      duration: const Duration(milliseconds: 1500),
                                                    ),
                                                  );
                                                }
                                              });
                                            },
                                            child: Text(
                                              "Delete".toUpperCase(),
                                              style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).primaryColor),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width - 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: calculateSessionShotWidth(s, s.totalWrist!),
                          height: 30,
                          decoration: const BoxDecoration(
                            color: wristShotColor,
                          ),
                          child: s.totalWrist! < 1
                              ? Container()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: calculateSessionShotWidth(s, s.totalWrist!),
                                      child: AutoSizeText(
                                        s.totalWrist.toString(),
                                        maxFontSize: 14,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        Container(
                          width: calculateSessionShotWidth(s, s.totalSnap!),
                          height: 30,
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            color: snapShotColor,
                          ),
                          child: s.totalSnap! < 1
                              ? Container()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: calculateSessionShotWidth(s, s.totalSnap!),
                                      child: AutoSizeText(
                                        s.totalSnap.toString(),
                                        maxFontSize: 14,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        Container(
                          width: calculateSessionShotWidth(s, s.totalBackhand!),
                          height: 30,
                          decoration: const BoxDecoration(
                            color: backhandShotColor,
                          ),
                          child: s.totalBackhand! < 1
                              ? Container()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: calculateSessionShotWidth(s, s.totalBackhand!),
                                      child: AutoSizeText(
                                        s.totalBackhand.toString(),
                                        maxFontSize: 14,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        Container(
                          width: calculateSessionShotWidth(s, s.totalSlap!),
                          height: 30,
                          decoration: const BoxDecoration(
                            color: slapShotColor,
                          ),
                          child: s.totalSlap! < 1
                              ? Container()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: calculateSessionShotWidth(s, s.totalSlap!),
                                      child: AutoSizeText(
                                        s.totalSlap.toString(),
                                        maxFontSize: 14,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width - 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SizedBox(
                          width: calculateSessionShotWidth(s, s.totalWrist!),
                          child: s.totalWrist! < 1
                              ? Container()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Opacity(
                                      opacity: 0.5,
                                      child: Text(
                                        "W",
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 16,
                                          fontFamily: 'NovecentoSans',
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        SizedBox(
                          width: calculateSessionShotWidth(s, s.totalSnap!),
                          child: s.totalSnap! < 1
                              ? Container()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Opacity(
                                      opacity: 0.5,
                                      child: Text(
                                        "SN",
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 16,
                                          fontFamily: 'NovecentoSans',
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        SizedBox(
                          width: calculateSessionShotWidth(s, s.totalBackhand!),
                          child: s.totalBackhand! < 1
                              ? Container()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Opacity(
                                      opacity: 0.5,
                                      child: Text(
                                        "B",
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 16,
                                          fontFamily: 'NovecentoSans',
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        SizedBox(
                          width: calculateSessionShotWidth(s, s.totalSlap!),
                          child: s.totalSlap! < 1
                              ? Container()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Opacity(
                                      opacity: 0.5,
                                      child: Text(
                                        "SL",
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 16,
                                          fontFamily: 'NovecentoSans',
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double calculateSessionShotWidth(ShootingSession session, int shotCount) {
    double percentage = (shotCount / session.total!);
    return (MediaQuery.of(context).size.width - 30) * percentage;
  }
}

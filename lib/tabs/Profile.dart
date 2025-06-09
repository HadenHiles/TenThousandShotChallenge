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
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/profile/History.dart';
import 'package:tenthousandshotchallenge/tabs/profile/QR.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditProfile.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tenthousandshotchallenge/tabs/shots/TargetAccuracyVisualizer.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';

class Profile extends StatefulWidget {
  const Profile({super.key, this.sessionPanelController, this.updateSessionShotsCB});

  final PanelController? sessionPanelController;
  final Function? updateSessionShotsCB;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final user = FirebaseAuth.instance.currentUser;
  final GlobalKey _avatarMenuKey = GlobalKey();

  String? _selectedIterationId;
  DateTime? firstSessionDate = DateTime.now();
  DateTime? latestSessionDate = DateTime.now();

  // State for selected shot type in accuracy section
  String _selectedAccuracyShotType = 'wrist';

  // Helper to get shot type colors (reuse from session charts)
  final Map<String, Color> shotTypeColors = {
    'wrist': Colors.cyan,
    'snap': Colors.blue,
    'backhand': Colors.indigo,
    'slap': Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    _setInitialIterationId();
  }

  Future<void> _setInitialIterationId() async {
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').orderBy('start_date', descending: false).get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _selectedIterationId = snapshot.docs.last.id;
      });
    }
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
    if (iterationId == null) return Container();

    final shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
    Map<String, double> avgAccuracy = {for (var t in shotTypes) t: 0};
    List<DateTime> accuracyDates = [];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(iterationId).collection('sessions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
        }
        final sessions = snapshot.data!.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                List<Shots> shots = [];
                if (data['shots'] != null && data['shots'] is List) {
                  shots = (data['shots'] as List).where((s) => s != null).map((s) => Shots.fromMap(Map<String, dynamic>.from(s))).toList();
                }
                final session = ShootingSession.fromSnapshot(doc);
                session.shots = shots;
                return session;
              } catch (_) {
                return null;
              }
            })
            .where((s) => s != null && s.shots != null && s.shots!.any((shot) => shot.type != null && shot.targetsHit != null && shot.count != null && shot.count! > 0))
            .toList();

        if (sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "No accuracy data tracked for this challenge.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                fontSize: 13,
                fontFamily: 'NovecentoSans',
              ),
            ),
          );
        }

        Map<String, int> totalHits = {for (var t in shotTypes) t: 0};
        Map<String, int> totalShots = {for (var t in shotTypes) t: 0};

        for (final session in sessions) {
          for (final shot in session!.shots!) {
            if (shot.type != null && shotTypes.contains(shot.type) && shot.targetsHit != null && shot.count != null && shot.count! > 0) {
              totalHits[shot.type!] = (totalHits[shot.type!] ?? 0) + (shot.targetsHit as num).toInt();
              totalShots[shot.type!] = (totalShots[shot.type!] ?? 0) + (shot.count as num).toInt();
              if (session.date != null) accuracyDates.add(session.date!);
            }
          }
        }
        for (final type in shotTypes) {
          avgAccuracy[type] = (totalShots[type]! > 0) ? (totalHits[type]! / totalShots[type]!) * 100 : 0;
        }

        // Show date range for available accuracy data
        Widget dateRangeWidget = Container();
        if (accuracyDates.isNotEmpty) {
          accuracyDates.sort();
          final first = accuracyDates.first;
          final last = accuracyDates.last;
          final dateFormat = DateFormat('MMM d, yyyy');
          dateRangeWidget = Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Accuracy data: ${dateFormat.format(first)} - ${dateFormat.format(last)}",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                fontSize: 13,
                fontFamily: 'NovecentoSans',
              ),
            ),
          );
        }

        // Custom painter overlay for % labels above each plot point
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
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
                    fontFamily: 'NovecentoSans',
                    fontSize: 12,
                  ),
                  getTitle: (index, angle) => RadarChartTitle(
                    text: shotTypes[index][0].toUpperCase() + shotTypes[index].substring(1),
                  ),
                  dataSets: [
                    RadarDataSet(
                      fillColor: Theme.of(context).primaryColor.withOpacity(0.18),
                      borderColor: Theme.of(context).primaryColor,
                      entryRadius: 6,
                      borderWidth: 3,
                      dataEntries: shotTypes.map((type) => RadarEntry(value: avgAccuracy[type]!)).toList(),
                    ),
                  ],
                  radarShape: RadarShape.polygon,
                  radarBorderData: const BorderSide(color: Colors.grey, width: 1),
                  tickBorderData: const BorderSide(color: Colors.grey, width: 0.5),
                  // Outer ring always 100%
                  // No maxEntryValue param, so values are relative to 100
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
                    final dx = center.dx + pointRadius * math.cos(angle);
                    final dy = center.dy + pointRadius * math.sin(angle) - 18;
                    labels.add(Positioned(
                      left: dx - 18,
                      top: dy,
                      child: Text(
                        "${value.round()}%",
                        style: TextStyle(
                          color: shotTypeColors[shotTypes[i]],
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NovecentoSans',
                          fontSize: 15,
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
  }

  // 2. TargetAccuracyVisualizers for each shot type, tappable
  Widget _buildShotTypeAccuracyVisualizers(BuildContext context, String? iterationId) {
    if (iterationId == null) return Container();

    final shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(iterationId).collection('sessions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
        }
        final sessions = snapshot.data!.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                List<Shots> shots = [];
                if (data['shots'] != null && data['shots'] is List) {
                  shots = (data['shots'] as List).where((s) => s != null).map((s) => Shots.fromMap(Map<String, dynamic>.from(s))).toList();
                }
                final session = ShootingSession.fromSnapshot(doc);
                session.shots = shots;
                return session;
              } catch (_) {
                return null;
              }
            })
            .where((s) => s != null && s.shots != null && s.shots!.any((shot) => shot.type != null && shot.targetsHit != null && shot.count != null && shot.count! > 0))
            .toList();

        if (sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "No accuracy data tracked for this challenge.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                fontSize: 13,
                fontFamily: 'NovecentoSans',
              ),
            ),
          );
        }

        Map<String, int> totalHits = {for (var t in shotTypes) t: 0};
        Map<String, int> totalShots = {for (var t in shotTypes) t: 0};

        for (final session in sessions) {
          for (final shot in session!.shots!) {
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
                        color: isActive ? color : Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
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
  }

  // 3. Line chart for accuracy over time for selected shot type
  Widget _buildAccuracyLineChart(BuildContext context, String? iterationId) {
    if (iterationId == null) return Container();

    final shotType = _selectedAccuracyShotType;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(iterationId).collection('sessions').orderBy('date', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
        }
        final sessions = snapshot.data!.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                List<Shots> shots = [];
                if (data['shots'] != null && data['shots'] is List) {
                  shots = (data['shots'] as List).where((s) => s != null).map((s) => Shots.fromMap(Map<String, dynamic>.from(s))).toList();
                }
                final session = ShootingSession.fromSnapshot(doc);
                session.shots = shots;
                return session;
              } catch (_) {
                return null;
              }
            })
            .where((s) => s != null && s.shots != null && s.shots!.any((shot) => shot.type == shotType && shot.targetsHit != null && shot.count != null && shot.count! > 0))
            .toList();

        if (sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "No accuracy data tracked for this shot type.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                fontSize: 13,
                fontFamily: 'NovecentoSans',
              ),
            ),
          );
        }

        List<FlSpot> spots = [];
        List<double> allAccuracies = [];
        int cumulativeShots = 0;
        List<DateTime> accuracyDates = [];
        for (final session in sessions) {
          for (final shot in session!.shots!) {
            if (shot.type == shotType && shot.targetsHit != null && shot.count != null && shot.count! > 0) {
              cumulativeShots += (shot.count as num).toInt();
              double accuracy = (shot.targetsHit as num).toDouble() / (shot.count as num).toDouble();
              spots.add(FlSpot(cumulativeShots.toDouble(), (accuracy * 100).roundToDouble()));
              allAccuracies.add(accuracy * 100);
              if (session.date != null) accuracyDates.add(session.date!);
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

        // Show date range for available accuracy data
        Widget dateRangeWidget = Container();
        if (accuracyDates.isNotEmpty) {
          accuracyDates.sort();
          final first = accuracyDates.first;
          final last = accuracyDates.last;
          final dateFormat = DateFormat('MMM d, yyyy');
          dateRangeWidget = Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              "Accuracy data: ${dateFormat.format(first)} - ${dateFormat.format(last)}",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                fontSize: 13,
                fontFamily: 'NovecentoSans',
              ),
            ),
          );
        }

        // Make the chart horizontally scrollable
        double chartWidth = 400;
        if (spots.isNotEmpty && spots.last.x > 10) {
          chartWidth = spots.last.x * 18;
        }

        return Column(
          children: [
            dateRangeWidget,
            SizedBox(
              height: 220,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      minX: spots.isNotEmpty ? spots.first.x : 0,
                      maxX: spots.isNotEmpty ? spots.last.x : 1,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 20,
                        verticalInterval: spots.isNotEmpty && spots.last.x > spots.first.x ? ((spots.last.x - spots.first.x) / 5).clamp(1, double.infinity) : 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          axisNameWidget: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Accuracy (%)',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'NovecentoSans',
                              ),
                            ),
                          ),
                          axisNameSize: 28,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                value.toString(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 12,
                                  fontFamily: 'NovecentoSans',
                                ),
                              ),
                            ),
                            interval: 20,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          axisNameWidget: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Shooting Sessions',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'NovecentoSans',
                              ),
                            ),
                          ),
                          axisNameSize: 28,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              bool show = spots.any((spot) => spot.x == value);
                              if (show) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 12,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            interval: spots.isNotEmpty && spots.last.x > spots.first.x ? ((spots.last.x - spots.first.x) / 5).clamp(1, double.infinity) : 1,
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                        ),
                      ),
                      lineBarsData: [
                        if (spots.isNotEmpty)
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 4,
                            color: shotTypeColors[shotType],
                            dotData: const FlDotData(show: true),
                          ),
                        if (trendLine.isNotEmpty)
                          LineChartBarData(
                            spots: trendLine,
                            isCurved: false,
                            barWidth: 3,
                            color: Colors.grey.shade400,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.grey.shade400.withOpacity(0.18),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${shotType[0].toUpperCase()}${shotType.substring(1)} Accuracy Over Time",
              style: TextStyle(
                color: shotTypeColors[shotType],
                fontFamily: 'NovecentoSans',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 15),
      child: SingleChildScrollView(
        // <-- Make the whole profile screen scrollable
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                                    navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
                                      return const EditProfile();
                                    }));
                                  } else if (value == 'qr_code') {
                                    showQRCode(user);
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

                                    navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
                                      return const EditProfile();
                                    }));
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
                                      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          UserProfile userProfile = UserProfile.fromSnapshot(snapshot.data!);
                                          return UserAvatar(
                                            user: userProfile,
                                            backgroundColor: Colors.transparent,
                                          );
                                        }

                                        return UserAvatar(
                                          user: UserProfile(user!.displayName, user!.email, user!.photoURL, true, true, null, ''),
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
                            stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
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
                                  userProfile.displayName != null && userProfile.displayName!.isNotEmpty ? userProfile.displayName! : user!.displayName!,
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
                            stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').snapshots(),
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
                            stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').snapshots(),
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
                  margin: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return SizedBox(
                              width: (MediaQuery.of(context).size.width - 100) * 0.3,
                              child: AutoSizeText(
                                "challenge ".toLowerCase() + (snapshot.data!.docs.length).toString().toLowerCase(),
                                maxFontSize: 34,
                                maxLines: 1,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 34,
                                  fontFamily: 'NovecentoSans',
                                ),
                              ),
                            );
                          }

                          return Container();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: _selectedIterationId == null ? null : FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  Iteration i = Iteration.fromSnapshot(snapshot.data as DocumentSnapshot);

                  if (i.endDate != null) {
                    int daysTaken = i.endDate!.difference(firstSessionDate!).inDays + 1;
                    daysTaken = daysTaken < 1 ? 1 : daysTaken;
                    String endDate = DateFormat('MMMM d, y').format(i.endDate!);
                    String iterationDescription;
                    String goalDescription = "";
                    String fTotal = i.total! > 999 ? numberFormat.format(i.total) : i.total.toString();

                    if (daysTaken <= 1) {
                      iterationDescription = "$fTotal shots in $daysTaken day";
                    } else {
                      iterationDescription = "$fTotal shots in $daysTaken days";
                    }

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
                      width: MediaQuery.of(context).size.width,
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
                                  fontSize: 18,
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
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  } else {
                    int daysSoFar = latestSessionDate!.difference(firstSessionDate!).inDays + 1;
                    daysSoFar = daysSoFar < 1 ? 1 : daysSoFar;
                    String? iterationDescription;
                    String goalDescription = "";
                    int remainingShots = 10000 - i.total!;
                    String fRemainingShots = remainingShots > 999 ? numberFormat.format(remainingShots) : remainingShots.toString();
                    String fTotal = i.total! > 999 ? numberFormat.format(i.total) : i.total.toString();

                    if (daysSoFar <= 1 && daysSoFar != 0) {
                      iterationDescription = "$fTotal shots in $daysSoFar day";
                    } else {
                      iterationDescription = "$fTotal shots in $daysSoFar days";
                    }

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
            Container(
              decoration: BoxDecoration(color: lighten(Theme.of(context).colorScheme.primary, 0.1)),
              padding: const EdgeInsets.only(top: 5, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    "Recent Sessions".toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Column(
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
                    ],
                  ),
                  Column(
                    children: [
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
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Opacity(
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
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
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
                    ],
                  ),
                  Column(
                    children: [
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
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Opacity(
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Replace attempts dropdown with a StreamBuilder
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').orderBy('start_date', descending: false).snapshots(),
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
                        fontSize: 26,
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
                    });
                  },
                  dropdownColor: Theme.of(context).colorScheme.primary,
                );
              },
            ),

            // Recent Sessions StreamBuilder
            if (_selectedIterationId != null)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
                builder: (context, iterationSnapshot) {
                  final iterationCompleted = _isCurrentIterationCompleted(iterationSnapshot);
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).collection('sessions').orderBy('date', descending: true).limit(3).snapshots(),
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
                        return Text(
                          "You don't have any sessions yet".toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16,
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

            // Add History button below the Recent Sessions section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: ElevatedButton.icon(
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
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const History()),
                  );
                },
              ),
            ),
            // --- My Accuracy Section ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "My Accuracy".toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Radial area graph for overall average accuracy per shot type
                    _buildRadialAccuracyChart(context, _selectedIterationId),

                    const SizedBox(height: 24),

                    // 2. TargetAccuracyVisualizers for each shot type, tappable
                    _buildShotTypeAccuracyVisualizers(context, _selectedIterationId),

                    const SizedBox(height: 24),

                    // 3. Line chart for accuracy over time for selected shot type
                    _buildAccuracyLineChart(context, _selectedIterationId),
                  ],
                ),
              ),
            ),
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

          await deleteSession(s).then((deleted) {
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

                                              await deleteSession(s).then((deleted) {
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

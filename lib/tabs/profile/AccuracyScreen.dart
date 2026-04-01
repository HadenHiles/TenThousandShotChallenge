import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/tabs/shots/TargetAccuracyVisualizer.dart';
import 'package:tenthousandshotchallenge/main.dart';

/// Full-screen accuracy detail view, extracted from Profile.dart.
class AccuracyScreen extends StatefulWidget {
  final String? initialIterationId;

  const AccuracyScreen({super.key, this.initialIterationId});

  @override
  State<AccuracyScreen> createState() => _AccuracyScreenState();
}

class _AccuracyScreenState extends State<AccuracyScreen> {
  User? get _user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;

  String? _selectedIterationId;
  String _selectedShotType = 'wrist';
  bool _showLoadingPulse = false;
  Timer? _loadingPulseTimer;

  final Map<String, Color> _shotTypeColors = {
    'wrist': wristShotColor,
    'snap': snapShotColor,
    'backhand': backhandShotColor,
    'slap': slapShotColor,
  };

  @override
  void initState() {
    super.initState();
    _selectedIterationId = widget.initialIterationId;
    if (_selectedIterationId == null) {
      _loadLatestIteration();
    }
  }

  Future<void> _loadLatestIteration() async {
    final user = _user;
    if (user == null) return;
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final snap = await firestore.collection('iterations').doc(user.uid).collection('iterations').orderBy('start_date', descending: false).get();
    if (snap.docs.isNotEmpty && mounted) {
      setState(() => _selectedIterationId = snap.docs.last.id);
    }
  }

  void _triggerLoadingPulse([Duration duration = const Duration(milliseconds: 450)]) {
    _loadingPulseTimer?.cancel();
    if (mounted) {
      setState(() => _showLoadingPulse = true);
      _loadingPulseTimer = Timer(duration, () {
        if (mounted) setState(() => _showLoadingPulse = false);
      });
    }
  }

  @override
  void dispose() {
    _loadingPulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            collapsedHeight: 65,
            expandedHeight: 85,
            backgroundColor: Theme.of(context).colorScheme.primary,
            floating: true,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.only(top: 10),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                onPressed: () => context.pop(),
              ),
            ),
            actions: const [],
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
              child: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                centerTitle: true,
                title: Text(
                  'Shot Accuracy'.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                background: Container(color: Theme.of(context).colorScheme.primaryContainer),
              ),
            ),
          ),
        ],
        body: user == null ? const Center(child: CircularProgressIndicator()) : _buildBody(context, user),
      ),
    );
  }

  Widget _buildBody(BuildContext context, User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user.uid).collection('iterations').orderBy('start_date', descending: false).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              children: [
                _buildLoadingPlaceholder(context, height: 220),
                const SizedBox(height: 20),
                _buildLoadingPlaceholder(context, height: 100),
                const SizedBox(height: 20),
                _buildLoadingPlaceholder(context, height: 260),
              ],
            ),
          );
        }
        final docs = snap.data?.docs ?? [];

        // Build iteration selector items
        final items = <DropdownMenuItem<String>>[];
        String? latestId;
        for (int i = 0; i < docs.length; i++) {
          final doc = docs[i];
          items.add(DropdownMenuItem<String>(
            value: doc.reference.id,
            child: Text(
              'challenge ${i + 1}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 20,
                fontFamily: 'NovecentoSans',
              ),
            ),
          ));
          latestId = doc.reference.id;
        }

        if (_selectedIterationId == null && latestId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedIterationId = latestId);
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Iteration selector (only if multiple challenges)
              if (items.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButton<String>(
                    value: _selectedIterationId,
                    items: items,
                    dropdownColor: Theme.of(context).colorScheme.primary,
                    onChanged: (value) {
                      _triggerLoadingPulse();
                      setState(() => _selectedIterationId = value);
                    },
                  ),
                ),

              _buildRadialAccuracyChart(context, user, _selectedIterationId),
              const SizedBox(height: 20),
              _buildShotTypeAccuracyVisualizers(context, user, _selectedIterationId),
              const SizedBox(height: 20),
              _buildAccuracyScatterChart(context, user, _selectedIterationId),
            ],
          ),
        );
      },
    );
  }

  // ── Radial/radar chart ────────────────────────────────────────────────────

  Widget _buildRadialAccuracyChart(BuildContext context, User user, String? iterationId) {
    final shotTypes = ['wrist', 'backhand', 'slap', 'snap'];

    if (iterationId == null) {
      return _buildLoadingPlaceholder(context, height: 180);
    }

    if (_showLoadingPulse) {
      return _buildLoadingPlaceholder(context, height: 220);
    }

    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('iterations').doc(user.uid).collection('iterations').orderBy('start_date', descending: false).snapshots(),
      builder: (context, allIterSnap) {
        final allDocs = allIterSnap.data?.docs ?? [];
        int challengeIndex = allDocs.indexWhere((d) => d.reference.id == iterationId);
        String challengeLabel = challengeIndex != -1 ? 'challenge ${challengeIndex + 1}' : '';

        return StreamBuilder<QuerySnapshot>(
          stream: firestore.collection('iterations').doc(user.uid).collection('iterations').doc(iterationId).collection('sessions').snapshots(),
          builder: (context, sessSnap) {
            if (sessSnap.connectionState == ConnectionState.waiting) {
              return _buildLoadingPlaceholder(context, height: 180);
            }
            final sessionDocs = sessSnap.data!.docs;
            return FutureBuilder<List<ShootingSession>>(
              future: _loadSessionsWithShots(sessionDocs),
              builder: (context, asyncSnap) {
                if (asyncSnap.connectionState == ConnectionState.waiting) {
                  return _buildLoadingPlaceholder(context, height: 180);
                }
                final sessions = asyncSnap.data!;

                Map<String, double> avgAccuracy = {for (var t in shotTypes) t: 0};
                List<DateTime> accuracyDates = [];

                if (sessions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'no accuracy data tracked for this challenge',
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
                      if (session.date != null) accuracyDates.add(session.date!);
                    }
                  }
                }
                for (final type in shotTypes) {
                  avgAccuracy[type] = totalShots[type]! > 0 ? (totalHits[type]! / totalShots[type]!) * 100 : 0;
                }

                return Column(
                  children: [
                    if (challengeLabel.isNotEmpty)
                      Text(
                        challengeLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                          fontSize: 20,
                          fontFamily: 'NovecentoSans',
                        ),
                      ),
                    Text(
                      'Accuracy Data'.toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                        fontSize: 28,
                        fontFamily: 'NovecentoSans',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (accuracyDates.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${DateFormat('MMM d, yyyy').format(accuracyDates.first)} - ${DateFormat('MMM d, yyyy').format(accuracyDates.last)}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                            fontSize: 18,
                            fontFamily: 'NovecentoSans',
                          ),
                        ),
                      ),
                    _buildRadar(context, shotTypes, avgAccuracy),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRadar(BuildContext context, List<String> shotTypes, Map<String, double> avgAccuracy) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 220,
          width: 220,
          child: RadarChart(
            RadarChartData(
              radarBackgroundColor: Colors.transparent,
              tickCount: 5,
              ticksTextStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0), fontFamily: 'NovecentoSans', fontSize: 12),
              getTitle: (index, angle) => RadarChartTitle(
                positionPercentageOffset: (shotTypes[index] == 'backhand' || shotTypes[index] == 'snap') ? 0.3 : 0.1,
                text: shotTypes[index][0].toUpperCase() + shotTypes[index].substring(1),
              ),
              dataSets: [
                RadarDataSet(fillColor: Colors.transparent, borderColor: Colors.transparent, entryRadius: 0, borderWidth: 0, dataEntries: shotTypes.map((_) => const RadarEntry(value: 30)).toList()),
                RadarDataSet(
                  fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                  borderColor: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                  entryRadius: 6,
                  borderWidth: 2,
                  dataEntries: shotTypes.map((type) => RadarEntry(value: avgAccuracy[type]!)).toList(),
                ),
                RadarDataSet(fillColor: Colors.transparent, borderColor: Colors.transparent, entryRadius: 0, borderWidth: 0, dataEntries: shotTypes.map((_) => const RadarEntry(value: 100)).toList()),
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
              final labels = <Widget>[];
              for (int i = 0; i < shotTypes.length; i++) {
                final angle = (i / shotTypes.length) * 2 * math.pi - math.pi / 2;
                final value = avgAccuracy[shotTypes[i]]!;
                final pointRadius = radius * (value / 100.0);
                double dx = center.dx + pointRadius * math.cos(angle);
                double dy = center.dy + pointRadius * math.sin(angle) - 18;
                if (shotTypes[i] == 'backhand') {
                  dx = center.dx + pointRadius * math.cos(angle) + 18;
                  dy = center.dy + pointRadius * math.sin(angle) - 22;
                } else if (shotTypes[i] == 'slap') {
                  dx = center.dx + pointRadius * math.cos(angle) - 6;
                  dy = center.dy + pointRadius * math.sin(angle) - 22;
                }
                labels.add(Positioned(
                  left: dx - 22,
                  top: dy,
                  child: Text(
                    '${value.round()}%',
                    style: TextStyle(
                      color: _shotTypeColors[shotTypes[i]],
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
  }

  // ── Target visualizers ────────────────────────────────────────────────────

  Widget _buildShotTypeAccuracyVisualizers(BuildContext context, User user, String? iterationId) {
    final shotTypes = ['wrist', 'snap', 'slap', 'backhand'];

    if (iterationId == null) return _buildLoadingPlaceholder(context, height: 80);
    if (_showLoadingPulse) return _buildLoadingPlaceholder(context, height: 80);

    return StreamBuilder<QuerySnapshot>(
      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user.uid).collection('iterations').doc(iterationId).collection('sessions').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingPlaceholder(context, height: 80);
        }
        return FutureBuilder<List<ShootingSession>>(
          future: _loadSessionsWithShots(snap.data!.docs),
          builder: (context, asyncSnap) {
            if (asyncSnap.connectionState == ConnectionState.waiting) {
              return _buildLoadingPlaceholder(context, height: 80);
            }
            final sessions = asyncSnap.data!;
            if (sessions.isEmpty) return const SizedBox.shrink();

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
                final color = _shotTypeColors[type]!;
                final isActive = _selectedShotType == type;
                return GestureDetector(
                  onTap: () {
                    if (_selectedShotType == type) return;
                    _triggerLoadingPulse(const Duration(milliseconds: 300));
                    setState(() => _selectedShotType = type);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        TargetAccuracyVisualizer(hits: totalHits[type]!, total: totalShots[type]!, shotColor: color, size: isActive ? 80 : 60),
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

  // ── Scatter / trend chart ─────────────────────────────────────────────────

  Widget _buildAccuracyScatterChart(BuildContext context, User user, String? iterationId) {
    final shotType = _selectedShotType;
    if (iterationId == null) return _buildLoadingPlaceholder(context, height: 220);
    if (_showLoadingPulse) return _buildLoadingPlaceholder(context, height: 220);

    return StreamBuilder<QuerySnapshot>(
      stream: Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user.uid).collection('iterations').doc(iterationId).collection('sessions').orderBy('date', descending: false).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingPlaceholder(context, height: 220);
        }
        return FutureBuilder<List<ShootingSession>>(
          key: ValueKey('$iterationId:$shotType'),
          future: _loadSessionsWithShotsForType(snap.data!.docs, shotType),
          builder: (context, asyncSnap) {
            if (asyncSnap.connectionState == ConnectionState.waiting) {
              return _buildLoadingPlaceholder(context, height: 220);
            }
            final sessions = asyncSnap.data!;
            if (sessions.isEmpty) return const SizedBox.shrink();

            List<FlSpot> spots = [];
            List<double> allAccuracies = [];
            List<DateTime> accuracyDates = [];
            int idx = 0;
            for (final session in sessions) {
              final relevant = session.shots!.where((s) => s.type == shotType && s.targetsHit != null && s.count != null && s.count! > 0).toList();
              if (relevant.isNotEmpty) {
                int hits = relevant.fold(0, (sum, s) => sum + (s.targetsHit ?? 0));
                int total = relevant.fold(0, (sum, s) => sum + (s.count ?? 0));
                if (total > 0) {
                  double acc = (hits / total) * 100.0;
                  spots.add(FlSpot(idx.toDouble(), acc));
                  allAccuracies.add(acc);
                  accuracyDates.add(session.date!);
                  idx++;
                }
              }
            }

            List<FlSpot> trendLine = [];
            if (spots.length > 1) {
              double n = spots.length.toDouble();
              double sumX = spots.fold(0.0, (s, p) => s + p.x);
              double sumY = spots.fold(0.0, (s, p) => s + p.y);
              double sumXY = spots.fold(0.0, (s, p) => s + p.x * p.y);
              double sumX2 = spots.fold(0.0, (s, p) => s + p.x * p.x);
              double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX + 0.0001);
              double intercept = (sumY - slope * sumX) / n;
              trendLine = [FlSpot(spots.first.x, slope * spots.first.x + intercept), FlSpot(spots.last.x, slope * spots.last.x + intercept)];
            }

            double dotSpacing = 18;
            double chartWidth = ((spots.length - 1) * dotSpacing + 36).clamp(320.0, double.infinity);
            double chartHeight = chartWidth.clamp(0.0, 400.0);

            Map<double, String> xLabels = {};
            if (accuracyDates.isNotEmpty && spots.isNotEmpty) {
              xLabels[spots.first.x] = DateFormat('MMM d').format(accuracyDates.first);
              xLabels[spots.last.x] = DateFormat('MMM d').format(accuracyDates.last);
            }

            final color = _shotTypeColors[shotType] ?? Colors.cyan;
            return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey('scatter-$iterationId-$shotType'),
                  children: [
                    Text(
                      '${shotType[0].toUpperCase()}${shotType.substring(1)} Shot Accuracy Over Time',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth,
                        height: chartHeight,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 24, top: 8),
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 100,
                              minX: 0,
                              maxX: spots.isNotEmpty ? spots.last.x : 1,
                              gridData: FlGridData(show: true, horizontalInterval: 20, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withValues(alpha: 0.1), strokeWidth: 1)),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 20, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12)))),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 24,
                                    getTitlesWidget: (value, _) {
                                      if (xLabels.containsKey(value)) {
                                        return Padding(padding: const EdgeInsets.only(top: 2), child: Text(xLabels[value]!, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12)));
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
                                  color: color,
                                  barWidth: 0,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 5, color: color, strokeWidth: 2, strokeColor: Colors.white),
                                  ),
                                  belowBarData: BarAreaData(show: false),
                                ),
                                if (trendLine.isNotEmpty)
                                  LineChartBarData(
                                    spots: trendLine,
                                    isCurved: false,
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                    barWidth: 2,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                              ],
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (_) => Colors.white,
                                  fitInsideHorizontally: false,
                                  fitInsideVertically: false,
                                  tooltipBorderRadius: BorderRadius.circular(8),
                                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  getTooltipItems: (touchedSpots) => touchedSpots.map((ts) {
                                    int i = spots.indexWhere((s) => s.x == ts.x && s.y == ts.y);
                                    final date = (i >= 0 && i < accuracyDates.length) ? DateFormat('MMM d, yyyy').format(accuracyDates[i]) : '';
                                    return LineTooltipItem(
                                      i >= 0 && i < allAccuracies.length ? '${allAccuracies[i].toStringAsFixed(1)}%' : '',
                                      TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                                      children: [if (i >= 0 && i < allAccuracies.length) TextSpan(text: '\n$date', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14))],
                                    );
                                  }).toList(),
                                ),
                                handleBuiltInTouches: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ));
          },
        );
      },
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context, {required double height}) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final pulse = Theme.of(context).colorScheme.primary.withValues(alpha: 0.18);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.25, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted && _showLoadingPulse) {
          setState(() {});
        }
      },
      builder: (context, t, _) {
        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [base, Color.lerp(base, pulse, t)!, base],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: const Center(
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<ShootingSession>> _loadSessionsWithShots(List<QueryDocumentSnapshot> docs) async {
    final sessions = <ShootingSession>[];
    for (final doc in docs) {
      try {
        final session = ShootingSession.fromSnapshot(doc);
        final shotsSnap = await doc.reference.collection('shots').get();
        session.shots = shotsSnap.docs.map((d) => Shots.fromSnapshot(d)).toList();
        sessions.add(session);
      } catch (_) {}
    }
    return sessions.where((s) => s.shots != null && s.shots!.any((shot) => shot.type != null && shot.targetsHit != null && shot.count != null && shot.count! > 0)).toList();
  }

  Future<List<ShootingSession>> _loadSessionsWithShotsForType(List<QueryDocumentSnapshot> docs, String shotType) async {
    final sessions = <ShootingSession>[];
    for (final doc in docs) {
      try {
        final session = ShootingSession.fromSnapshot(doc);
        final shotsSnap = await doc.reference.collection('shots').get();
        session.shots = shotsSnap.docs.map((d) => Shots.fromSnapshot(d)).toList();
        sessions.add(session);
      } catch (_) {}
    }
    return sessions.where((s) => s.shots != null && s.shots!.any((shot) => shot.type == shotType && shot.targetsHit != null && shot.count != null && shot.count! > 0)).toList();
  }
}

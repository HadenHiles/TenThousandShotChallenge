import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/Settings.dart';
import 'package:tenthousandshotchallenge/tabs/shots/TargetAccuracyVisualizer.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/ShotButton.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:url_launcher/url_launcher_string.dart';

class StartShooting extends StatefulWidget {
  const StartShooting({super.key, required this.sessionPanelController, this.shots});

  final PanelController sessionPanelController;
  final List<Shots>? shots;

  @override
  State<StartShooting> createState() => _StartShootingState();
}

class _StartShootingState extends State<StartShooting> {
  final bool showAccuracyFeature = true;

  String _selectedShotType = 'wrist';
  int _currentShotCount = preferences!.puckCount!;
  bool _puckCountUpdating = false;
  List<Shots> _shots = [];
  bool _showAccuracyPrompt = true;
  int? _lastTargetsHit;
  bool _chartCollapsed = true;

  // State to track selected plot index
  int? _selectedPlotIndex;

  @override
  void initState() {
    _shots = widget.shots ?? [];
    _currentShotCount = preferences!.puckCount!;
    _chartCollapsed = true; // Default to collapsed when starting a new session
    super.initState();
  }

  @override
  void dispose() {
    _shots = [];
    _currentShotCount = preferences!.puckCount!;
    super.dispose();
  }

  void reset() {
    _shots = [];
    _currentShotCount = preferences!.puckCount!;
  }

  Future<int?> showAccuracyInputDialog(BuildContext context, int shotCount) async {
    int value = (_lastTargetsHit ?? (shotCount * 0.5).round()).clamp(0, shotCount);
    // Helper to round to nearest even number
    int roundEven(num n) => (n / 2).round() * 2;
    // Build presets, ensuring no duplicates; if duplicate, allow one as odd
    Set<int> seen = {};
    List<int> presets = [];
    for (final percent in [0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85]) {
      int even = roundEven(shotCount * percent);
      if (!seen.contains(even)) {
        presets.add(even);
        seen.add(even);
      } else {
        int odd = even.isEven ? even + 1 : even - 1;
        if (odd >= 0 && odd <= shotCount && !seen.contains(odd)) {
          presets.add(odd);
          seen.add(odd);
        }
      }
    }
    presets = presets.where((p) => p >= 0 && p <= shotCount).toList();

    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('How many targets did you hit?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Centered selected value above the slider, compact, with box and tap-to-edit
                  Padding(
                    padding: const EdgeInsets.only(bottom: 0, top: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            "$value",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        Text(
                          " / $shotCount",
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Slider(
                    value: value.clamp(0, shotCount).toDouble(),
                    min: 0,
                    max: shotCount.toDouble(),
                    divisions: shotCount > 0 ? shotCount : 1,
                    activeColor: Theme.of(context).primaryColor,
                    thumbColor: Theme.of(context).primaryColor,
                    onChanged: (v) => setState(() => value = v.round().clamp(0, shotCount)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets
                        .map((preset) => ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: value == preset ? Colors.grey.shade300 : Colors.grey.shade100,
                                foregroundColor: Colors.black87,
                                minimumSize: const Size(48, 32),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                elevation: value == preset ? 2 : 0,
                              ),
                              onPressed: () => setState(() => value = preset.clamp(0, shotCount)),
                              child: Text("$preset"),
                            ))
                        .toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Save', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(value.clamp(0, shotCount)),
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
    // --- Gather accuracy data for all shot types ---
    final shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
    final shotTypeColors = {
      'wrist': Colors.cyan,
      'snap': Colors.blue,
      'backhand': Colors.indigo,
      'slap': Colors.teal,
    };

    Map<String, List<FlSpot>> accuracySpotsByType = {};
    Map<String, List<int>> shotCountsByType = {};
    Map<String, double> avgAccuracyByType = {};

    for (var type in shotTypes) {
      List<Shots> filtered = _shots.where((s) => s.type == type).toList();
      List<FlSpot> spots = [];
      List<int> shotCounts = [];
      int totalHits = 0;
      int totalShots = 0;
      int cumulativeShots = 0;
      for (int i = 0; i < filtered.length; i++) {
        final s = filtered[filtered.length - 1 - i]; // oldest first
        if (s.targetsHit != null && s.count != null && s.count! > 0) {
          double accuracy = s.targetsHit! / s.count!;
          cumulativeShots += s.count!;
          spots.add(FlSpot(cumulativeShots.toDouble(), (accuracy * 100).roundToDouble()));
          shotCounts.add(cumulativeShots);
          totalHits += s.targetsHit!;
          totalShots += s.count!;
        }
      }
      accuracySpotsByType[type] = spots;
      shotCountsByType[type] = shotCounts;
      avgAccuracyByType[type] = totalShots > 0 ? (totalHits / totalShots) * 100 : 0;
    }

    double? minX, maxX;
    for (var spots in accuracySpotsByType.values) {
      if (spots.isNotEmpty) {
        minX = minX == null ? spots.first.x : min(minX, spots.first.x);
        maxX = maxX == null ? spots.last.x : max(maxX, spots.last.x);
      }
    }

    return Expanded(
      child: Stack(
        children: [
          // Main content (puck count, shot list, etc.) always at the bottom of the stack
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: [
                  // Always show the prompt and expand/collapse button at the top
                  if (_showAccuracyPrompt && showAccuracyFeature)
                    Card(
                      color: Colors.green.shade50,
                      margin: const EdgeInsets.all(12),
                      child: ListTile(
                        leading: const Icon(Icons.track_changes, color: Colors.green),
                        title: Text(
                          "Want to track your shot accuracy?",
                          style: TextStyle(
                            color: Colors.green.shade900,
                            fontFamily: 'NovecentoSans',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() => _showAccuracyPrompt = false);
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const ProfileSettings(),
                          ));
                        },
                      ),
                    ),
                  // Expand/collapse chart button
                  if (showAccuracyFeature)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _chartCollapsed ? "Show Accuracy Chart" : "Shot Accuracy",
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _chartCollapsed ? Icons.expand_more : Icons.expand_less,
                              color: Theme.of(context).primaryColor,
                            ),
                            tooltip: _chartCollapsed ? "Expand Chart" : "Collapse Chart",
                            onPressed: () {
                              setState(() {
                                _chartCollapsed = !_chartCollapsed;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  // Only show the shot selector here if chart is collapsed
                  if (_chartCollapsed)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: _buildShotSelector(context),
                    ),
                  // Main content (puck count, shot list, etc.)
                  _buildMainContent(context),
                ],
              ),
            ),
          ),
          // Chart overlay and pinned selector when expanded
          if (showAccuracyFeature && !_chartCollapsed)
            Positioned.fill(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.98),
                child: Column(
                  children: [
                    // Chart card and visualizers
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 8,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Shot Accuracy",
                                    style: TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.expand_less,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    tooltip: "Collapse Chart",
                                    onPressed: () {
                                      setState(() {
                                        _chartCollapsed = true;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: shotTypes.map((type) {
                                  final color = shotTypeColors[type]!;
                                  final isActive = _selectedShotType == type;
                                  final shotsOfType = _shots.where((s) => s.type == type && s.targetsHit != null && s.count != null).toList();
                                  final totalHits = shotsOfType.fold<int>(0, (sum, s) => sum + (s.targetsHit ?? 0));
                                  final totalShots = shotsOfType.fold<int>(0, (sum, s) => sum + (s.count ?? 0));
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedShotType = type;
                                      });
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          type[0].toUpperCase() + type.substring(1),
                                          style: TextStyle(
                                            color: isActive ? color : Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'NovecentoSans',
                                            fontSize: 14,
                                          ),
                                        ),
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeOutCubic,
                                          width: isActive ? 90 : 70,
                                          height: isActive ? 110 : 85,
                                          child: Opacity(
                                            opacity: isActive ? 1.0 : 0.45,
                                            child: TargetAccuracyVisualizer(
                                              hits: totalHits,
                                              total: totalShots,
                                              shotColor: color,
                                              size: isActive ? 90 : 70,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardTheme.color,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: accuracySpotsByType[_selectedShotType]!.isEmpty
                                    ? Center(
                                        child: Text(
                                          "Add shots to see your accuracy chart.",
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      )
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          final chartWidth = constraints.maxWidth;
                                          final chartHeight = constraints.maxHeight;
                                          final spots = accuracySpotsByType[_selectedShotType]!;
                                          final filtered = _shots.where((s) => s.type == _selectedShotType).toList();

                                          // Find min/max for scaling
                                          final minX = spots.isNotEmpty ? spots.first.x : 0;
                                          final maxX = spots.isNotEmpty ? spots.last.x : 1;
                                          const minY = 0.0;
                                          const maxY = 100.0;

                                          List<Widget> labels = [];
                                          for (int i = 0; i < spots.length; i++) {
                                            final spot = spots[i];
                                            // Find targetsHit/count for this spot
                                            int cumulative = 0;
                                            int? targetsHit;
                                            int? count;
                                            for (int j = 0; j < filtered.length; j++) {
                                              final s = filtered[j];
                                              cumulative += s.count!;
                                              if (cumulative.toDouble() == spot.x) {
                                                targetsHit = s.targetsHit;
                                                count = s.count;
                                                break;
                                              }
                                            }

                                            // Calculate position
                                            final x = ((spot.x - minX) / (maxX - minX)) * chartWidth;
                                            final y = chartHeight - ((spot.y - minY) / (maxY - minY)) * chartHeight;

                                            labels.add(
                                              Positioned(
                                                left: x - 20,
                                                top: y - 20,
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: shotTypeColors[_selectedShotType]!.withOpacity(0.9),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        "${targetsHit ?? '-'}",
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontFamily: 'NovecentoSans',
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black38,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        "${count ?? '-'}",
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontFamily: 'NovecentoSans',
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }

                                          return Stack(
                                            children: [
                                              // Base line chart
                                              LineChart(
                                                LineChartData(
                                                  minY: 0,
                                                  maxY: 100,
                                                  minX: (accuracySpotsByType[_selectedShotType]!.isNotEmpty) ? accuracySpotsByType[_selectedShotType]!.first.x : 0,
                                                  maxX: (accuracySpotsByType[_selectedShotType]!.isNotEmpty) ? accuracySpotsByType[_selectedShotType]!.last.x : 1,
                                                  gridData: FlGridData(
                                                    show: true,
                                                    drawVerticalLine: true,
                                                    horizontalInterval: 20,
                                                    verticalInterval: (accuracySpotsByType[_selectedShotType]!.isNotEmpty && accuracySpotsByType[_selectedShotType]!.last.x > accuracySpotsByType[_selectedShotType]!.first.x) ? ((accuracySpotsByType[_selectedShotType]!.last.x - accuracySpotsByType[_selectedShotType]!.first.x) / 5).clamp(1, double.infinity) : 1,
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
                                                            value.toInt().toString(),
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
                                                          'Shots Taken',
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
                                                          bool show = accuracySpotsByType[_selectedShotType]!.any((spot) => spot.x == value);
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
                                                        interval: (accuracySpotsByType[_selectedShotType]!.isNotEmpty && accuracySpotsByType[_selectedShotType]!.last.x > accuracySpotsByType[_selectedShotType]!.first.x) ? ((accuracySpotsByType[_selectedShotType]!.last.x - accuracySpotsByType[_selectedShotType]!.first.x) / 5).clamp(1, double.infinity) : 1,
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
                                                    if (accuracySpotsByType[_selectedShotType]!.isNotEmpty)
                                                      LineChartBarData(
                                                        spots: accuracySpotsByType[_selectedShotType]!,
                                                        isCurved: true,
                                                        barWidth: 4,
                                                        color: shotTypeColors[_selectedShotType],
                                                        dotData: const FlDotData(show: true),
                                                      ),
                                                    // Optional: average line for selected type
                                                    if (accuracySpotsByType[_selectedShotType]!.isNotEmpty)
                                                      LineChartBarData(
                                                        spots: [
                                                          FlSpot(accuracySpotsByType[_selectedShotType]!.first.x, avgAccuracyByType[_selectedShotType]!.roundToDouble()),
                                                          FlSpot(accuracySpotsByType[_selectedShotType]!.last.x, avgAccuracyByType[_selectedShotType]!.roundToDouble()),
                                                        ],
                                                        isCurved: false,
                                                        barWidth: 1,
                                                        color: shotTypeColors[_selectedShotType]!.withOpacity(0.5),
                                                        dashArray: [4, 4],
                                                        dotData: const FlDotData(show: false),
                                                      ),
                                                  ],
                                                  lineTouchData: LineTouchData(
                                                    enabled: true,
                                                    handleBuiltInTouches: true,
                                                    touchSpotThreshold: 22, // <-- Increase touch area for all dots
                                                    touchTooltipData: LineTouchTooltipData(
                                                      getTooltipColor: (d) => Theme.of(context).colorScheme.surface.withOpacity(0.95),
                                                      tooltipRoundedRadius: 10,
                                                      fitInsideHorizontally: false, // Allow tooltip to overflow horizontally
                                                      fitInsideVertically: false,
                                                      tooltipMargin: 24, // Add more margin so tooltips aren't clipped
                                                      getTooltipItems: (touchedSpots) {
                                                        final color = shotTypeColors[_selectedShotType]!;
                                                        final spots = accuracySpotsByType[_selectedShotType]!;
                                                        return touchedSpots.map((touched) {
                                                          // Use a small epsilon for floating point comparison
                                                          final index = spots.indexWhere((spot) => (spot.x - touched.x).abs() < 0.01 && (spot.y - touched.y).abs() < 0.01);
                                                          if (index == -1) return null; // <-- Return null instead of continue

                                                          // Find the corresponding shot for this spot
                                                          final filtered = _shots.where((s) => s.type == _selectedShotType).toList();
                                                          int cumulative = 0;
                                                          int? targetsHit;
                                                          int? count;
                                                          for (int i = 0; i < filtered.length; i++) {
                                                            final s = filtered[filtered.length - 1 - i];
                                                            if (s.targetsHit != null && s.count != null && s.count! > 0) {
                                                              cumulative += s.count!;
                                                              if (cumulative.toDouble() == touched.x) {
                                                                targetsHit = s.targetsHit;
                                                                count = s.count;
                                                                break;
                                                              }
                                                            }
                                                          }

                                                          return LineTooltipItem(
                                                            "${_selectedShotType[0].toUpperCase()}${_selectedShotType.substring(1)}\n"
                                                            "Targets Hit: ${targetsHit ?? '-'}\n"
                                                            "Shots: ${count ?? '-'}\n"
                                                            "Accuracy: ${touched.y.toStringAsFixed(1)}%",
                                                            TextStyle(
                                                              color: color,
                                                              fontWeight: FontWeight.bold,
                                                              fontFamily: 'NovecentoSans',
                                                              fontSize: 14,
                                                            ),
                                                          );
                                                        }).toList();
                                                      },
                                                    ),
                                                    touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                                                      if (touchResponse != null && touchResponse.lineBarSpots != null && touchResponse.lineBarSpots!.isNotEmpty) {
                                                        final spot = touchResponse.lineBarSpots!.first;
                                                        final spots = accuracySpotsByType[_selectedShotType]!;
                                                        final index = spots.indexWhere((s) => (s.x - spot.x).abs() < 0.01 && (s.y - spot.y).abs() < 0.01);
                                                        if (index != -1) {
                                                          setState(() {
                                                            _selectedPlotIndex = index;
                                                          });
                                                        }
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),
                                              // Average accuracy label for active type
                                              if (accuracySpotsByType[_selectedShotType]!.isNotEmpty)
                                                Positioned(
                                                  left: 8,
                                                  top: 8,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: shotTypeColors[_selectedShotType]!.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      "Avg: ${avgAccuracyByType[_selectedShotType]!.round()}%",
                                                      style: TextStyle(
                                                        color: shotTypeColors[_selectedShotType],
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'NovecentoSans',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                              // Fill remaining space so close button is at the bottom
                            ),
                            Expanded(child: Container()),
                            // Close button at the bottom
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24, top: 8),
                              child: SizedBox(
                                width: 180,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.close),
                                  label: const Text("Close"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    textStyle: const TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _chartCollapsed = true;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShotSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          ShotTypeButton(
            type: 'wrist',
            active: _selectedShotType == 'wrist',
            onPressed: () {
              Feedback.forLongPress(context);
              setState(() {
                _selectedShotType = 'wrist';
              });
            },
            borderRadius: BorderRadius.circular(_selectedShotType == 'wrist' ? 12 : 6),
          ),
          ShotTypeButton(
            type: 'snap',
            active: _selectedShotType == 'snap',
            onPressed: () {
              Feedback.forLongPress(context);
              setState(() {
                _selectedShotType = 'snap';
              });
            },
            borderRadius: BorderRadius.circular(_selectedShotType == 'snap' ? 12 : 6),
          ),
          ShotTypeButton(
            type: 'slap',
            active: _selectedShotType == 'slap',
            onPressed: () {
              Feedback.forLongPress(context);
              setState(() {
                _selectedShotType = 'slap';
              });
            },
            borderRadius: BorderRadius.circular(_selectedShotType == 'slap' ? 12 : 6),
          ),
          ShotTypeButton(
            type: 'backhand',
            active: _selectedShotType == 'backhand',
            onPressed: () {
              Feedback.forLongPress(context);
              setState(() {
                _selectedShotType = 'backhand';
              });
            },
            borderRadius: BorderRadius.circular(_selectedShotType == 'backhand' ? 12 : 6),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        preferences!.puckCount != _currentShotCount ? const SizedBox(height: 10) : Container(),
        GestureDetector(
          onTap: () async {
            Feedback.forLongPress(context);

            setState(() {
              _puckCountUpdating = true;
            });

            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.setInt(
              'puck_count',
              _currentShotCount,
            );

            if (context.mounted) {
              Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(
                Preferences(
                  prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark,
                  _currentShotCount,
                  prefs.getBool('friend_notifications'),
                  DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
                  prefs.getString('fcm_token'),
                ),
              );
            }

            Future.delayed(const Duration(seconds: 1), () {
              setState(() {
                _puckCountUpdating = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Theme.of(context).cardTheme.color,
                  content: Text(
                    '# of pucks updated successfully!',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  duration: const Duration(milliseconds: 1200),
                ),
              );
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _puckCountUpdating
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : preferences!.puckCount != _currentShotCount
                      ? Text(
                          "Tap to update # of pucks you have from ${preferences!.puckCount} to $_currentShotCount",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Container(height: 14),
              preferences!.puckCount != _currentShotCount
                  ? Container(
                      margin: const EdgeInsets.only(left: 4),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 14,
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
        preferences!.puckCount != _currentShotCount ? const SizedBox(height: 5) : Container(),
        Text(
          "# of Shots".toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontFamily: 'NovecentoSans',
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 15),
        GestureDetector(
          onLongPress: () async {
            Feedback.forLongPress(context);

            int value = _currentShotCount;
            final controller = TextEditingController(text: value.toString());
            int? manualValue = await showDialog<int>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Enter # of shots'),
                  content: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "1 - 500",
                          hintStyle: TextStyle(color: Colors.black38),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black38,
                        backgroundColor: Colors.transparent,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        int? entered = int.tryParse(controller.text);
                        if (entered != null && entered > 0 && entered <= 500) {
                          Navigator.of(context).pop(entered);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
            if (manualValue != null && manualValue > 0 && manualValue <= 500) {
              setState(() {
                _currentShotCount = manualValue;
                _lastTargetsHit = (_currentShotCount * 0.5).round();
              });
            }
          },
          child: NumberPicker(
            value: _currentShotCount,
            minValue: 1,
            maxValue: 500,
            step: 1,
            itemHeight: 60,
            textStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 20),
            axis: Axis.horizontal,
            haptics: true,
            infiniteLoop: true,
            onChanged: (value) {
              setState(() {
                _currentShotCount = value;
                _lastTargetsHit = (_currentShotCount * 0.5).round();
              });
            },
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).primaryColor, width: 2),
            ),
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          "Long press for numpad",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 15,
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width - 200,
          child: TextButton(
            onPressed: () async {
              Feedback.forLongPress(context);

              int? targetsHit;
              if (showAccuracyFeature) {
                targetsHit = await showAccuracyInputDialog(context, _currentShotCount); // <-- Use session puck count
                if (targetsHit == null) return;
                setState(() {
                  _lastTargetsHit = targetsHit;
                });
              }

              Shots shots = Shots(
                DateTime.now(),
                _selectedShotType,
                _currentShotCount,
                showAccuracyFeature ? targetsHit : null,
              );
              setState(() {
                _shots.insert(0, shots);
              });
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 10, horizontal: 5)),
              backgroundColor: WidgetStateProperty.all(Colors.green.shade600),
            ),
            child: const Icon(
              Icons.check,
              size: 40,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Tap",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                Icons.check,
                color: Colors.green.shade600,
                size: 14,
              ),
            ),
            Text(
              "to save below",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 15,
        ),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: _buildShotsList(context, _shots),
        ),
        // Add this: Finish Session button at the bottom
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 60,
              width: MediaQuery.of(context).size.width - 20,
              child: StreamProvider<NetworkStatus>(
                create: (context) {
                  return NetworkStatusService().networkStatusController.stream;
                },
                initialData: NetworkStatus.Online,
                child: NetworkAwareWidget(
                  onlineChild: _shots.isEmpty
                      ? TextButton(
                          onPressed: () {
                            Feedback.forLongPress(context);
                            // Reset session and close panel
                            sessionService.reset();
                            widget.sessionPanelController.close();
                            reset();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.grey.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.delete_forever, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                "Cancel".toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : TextButton(
                          onPressed: () async {
                            Feedback.forLongPress(context);

                            int totalShots = 0;
                            for (var s in _shots) {
                              totalShots += s.count!;
                            }

                            await saveShootingSession(_shots).then((success) async {
                              sessionService.reset();
                              widget.sessionPanelController.close();
                              reset();

                              await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').where('complete', isEqualTo: false).get().then((snapshot) {
                                if (snapshot.docs.isNotEmpty) {
                                  Iteration i = Iteration.fromSnapshot(snapshot.docs[0]);

                                  if ((i.total! + totalShots) < 10000) {
                                    Fluttertoast.showToast(
                                      msg: 'Shooting session saved!',
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.BOTTOM,
                                      timeInSecForIosWeb: 1,
                                      backgroundColor: Theme.of(context).cardTheme.color,
                                      textColor: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16.0,
                                    );
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return Dialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                                          child: SingleChildScrollView(
                                            clipBehavior: Clip.none,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.topCenter,
                                              children: [
                                                SizedBox(
                                                  height: 550,
                                                  child: Padding(
                                                    padding: const EdgeInsets.fromLTRB(10, 70, 10, 10),
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          "Challenge Complete!".toUpperCase(),
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            color: Theme.of(context).primaryColor,
                                                            fontFamily: "NovecentoSans",
                                                            fontSize: 32,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 5),
                                                        Text(
                                                          "Nice job, ya beauty!\n10,000 shots isn't easy.",
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            color: Theme.of(context).colorScheme.onPrimary,
                                                            fontFamily: "NovecentoSans",
                                                            fontSize: 22,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 5),
                                                        Opacity(
                                                          opacity: 0.8,
                                                          child: Text(
                                                            "To celebrate, here's 40% off our limited edition Sniper Snapback only available to snipers like yourself!",
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onPrimary,
                                                              fontFamily: "NovecentoSans",
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 15),
                                                        GestureDetector(
                                                          onTap: () async {
                                                            String link = "https://howtohockey.com/link/sniper-snapback-coupon/";
                                                            await canLaunchUrlString(link).then((can) {
                                                              launchUrlString(link).catchError((err) {
                                                                print(err);
                                                                return false;
                                                              });
                                                            });
                                                          },
                                                          child: Card(
                                                            color: Theme.of(context).cardTheme.color,
                                                            elevation: 4,
                                                            child: SizedBox(
                                                              width: 125,
                                                              height: 180,
                                                              child: Column(
                                                                mainAxisAlignment: MainAxisAlignment.start,
                                                                children: [
                                                                  const Image(
                                                                    image: NetworkImage(
                                                                      "https://howtohockey.com/wp-content/uploads/2021/07/featured.jpg",
                                                                    ),
                                                                    width: 150,
                                                                  ),
                                                                  Expanded(
                                                                    child: Column(
                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                      children: [
                                                                        Container(
                                                                          padding: const EdgeInsets.all(5),
                                                                          child: Text(
                                                                            "Sniper Snapback".toUpperCase(),
                                                                            maxLines: 2,
                                                                            textAlign: TextAlign.center,
                                                                            style: TextStyle(
                                                                              fontFamily: "NovecentoSans",
                                                                              fontSize: 18,
                                                                              color: Theme.of(context).colorScheme.onPrimary,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 5),
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(context).colorScheme.primaryContainer,
                                                          ),
                                                          padding: const EdgeInsets.all(5),
                                                          child: SelectableText(
                                                            "TENKSNIPER",
                                                            style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onPrimary,
                                                              fontFamily: "NovecentoSans",
                                                              fontSize: 24,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 5),
                                                        TextButton(
                                                          onPressed: () async {
                                                            Navigator.of(context).pop();
                                                            String link = "https://howtohockey.com/link/sniper-snapback-coupon/";
                                                            await canLaunchUrlString(link).then((can) {
                                                              launchUrlString(link).catchError((err) {
                                                                print(err);
                                                                return false;
                                                              });
                                                            });
                                                          },
                                                          style: ButtonStyle(
                                                            backgroundColor: WidgetStateProperty.all(
                                                              Theme.of(context).primaryColor,
                                                            ),
                                                            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 4, horizontal: 15)),
                                                          ),
                                                          child: Text(
                                                            "Get yours".toUpperCase(),
                                                            style: const TextStyle(
                                                              fontFamily: "NovecentoSans",
                                                              fontSize: 30,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const Positioned(
                                                  top: -40,
                                                  child: SizedBox(
                                                    width: 100,
                                                    height: 100,
                                                    child: Image(
                                                      image: AssetImage("assets/images/GoalLight.gif"),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                }
                              });
                            }).onError((error, stackTrace) {
                              print(error);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Theme.of(context).cardTheme.color,
                                  content: Text(
                                    'There was an error saving your shooting session :(',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                  duration: const Duration(milliseconds: 1500),
                                ),
                              );
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_alt_rounded, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                "Finish".toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                  offlineChild: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "You need wifi to save, bud.".toLowerCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontFamily: "NovecentoSans",
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(top: 5),
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Dismissible> _buildShotsList(BuildContext context, List<Shots> shots) {
    List<Dismissible> list = [];

    shots.asMap().forEach((i, s) {
      Dismissible tile = Dismissible(
        key: UniqueKey(),
        onDismissed: (direction) {
          Fluttertoast.showToast(
            msg: '${s.count} ${s.type} shots deleted',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Theme.of(context).cardTheme.color,
            textColor: Theme.of(context).colorScheme.onPrimary,
            fontSize: 16.0,
          );
          setState(() {
            _shots.remove(s);
          });
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: ListTile(
            tileColor: (i % 2 == 0) ? Theme.of(context).cardTheme.color : Theme.of(context).colorScheme.primary,
            leading: Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: Text(
                s.count.toString(),
                style: const TextStyle(fontSize: 24, fontFamily: 'NovecentoSans'),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  s.type!.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 20,
                    fontFamily: 'NovecentoSans',
                  ),
                ),
                Text(
                  printTime(s.date!),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 20,
                    fontFamily: 'NovecentoSans',
                  ),
                ),
              ],
            ),
            subtitle: showAccuracyFeature && s.targetsHit != null
                ? Text(
                    "Accuracy: ${((s.targetsHit! / (s.count ?? 1)) * 100).round()}%",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 14,
                      fontFamily: 'NovecentoSans',
                    ),
                  )
                : null,
          ),
        ),
      );

      list.add(tile);
    });

    return list;
  }
}

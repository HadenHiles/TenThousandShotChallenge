import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/Settings.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/ShotButton.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:fl_chart/fl_chart.dart';

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
  bool _chartCollapsed = false;

  @override
  void initState() {
    _shots = widget.shots ?? [];
    _currentShotCount = preferences!.puckCount!;
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
    int value = _lastTargetsHit ?? (shotCount * 0.5).round();
    // Helper to round to nearest even number
    int roundEven(num n) => (n / 2).round() * 2;
    List<int> presets = [
      roundEven(shotCount * 0.15),
      roundEven(shotCount * 0.25),
      roundEven(shotCount * 0.35),
      roundEven(shotCount * 0.45),
      roundEven(shotCount * 0.55),
      roundEven(shotCount * 0.65),
      roundEven(shotCount * 0.75),
      roundEven(shotCount * 0.85),
    ];
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
                        GestureDetector(
                          onTap: () async {
                            final controller = TextEditingController(text: value.toString());
                            int? manualValue = await showDialog<int>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Enter targets hit'),
                                  content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: "0 - $shotCount",
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        int? entered = int.tryParse(controller.text);
                                        if (entered != null && entered >= 0 && entered <= shotCount) {
                                          Navigator.of(context).pop(entered);
                                        }
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (manualValue != null) {
                              setState(() => value = manualValue);
                            }
                          },
                          child: Container(
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
                    value: value.toDouble(),
                    min: 0,
                    max: shotCount.toDouble(),
                    divisions: shotCount,
                    label: "$value",
                    activeColor: Theme.of(context).primaryColor,
                    thumbColor: Theme.of(context).primaryColor,
                    onChanged: (v) => setState(() => value = v.round()),
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
                              onPressed: () => setState(() => value = preset),
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
                  onPressed: () => Navigator.of(context).pop(value),
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
      'wrist': Colors.red, // Use your donut chart colors here
      'snap': Colors.blue,
      'slap': Colors.orange,
      'backhand': Colors.purple,
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
      // After building spots for each type
      if (spots.isNotEmpty && spots.first.x != 0) {
        spots.insert(0, FlSpot(0, spots.first.y));
      }
      accuracySpotsByType[type] = spots;
      shotCountsByType[type] = shotCounts;
      avgAccuracyByType[type] = totalShots > 0 ? (totalHits / totalShots) * 100 : 0;
    }

    // Find global min/max for x axis
    double? minX, maxX;
    for (var spots in accuracySpotsByType.values) {
      if (spots.isNotEmpty) {
        minX = minX == null ? spots.first.x : min(minX, spots.first.x);
        maxX = maxX == null ? spots.last.x : max(maxX, spots.last.x);
      }
    }

    return Expanded(
      child: Column(
        children: [
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
          // Collapse/expand chart button
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
          if (showAccuracyFeature && !_chartCollapsed)
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: accuracySpotsByType.values.every((spots) => spots.isEmpty)
                    ? Center(
                        child: Text(
                          "Add shots to see your accuracy chart.",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 100,
                              minX: minX ?? 0,
                              maxX: maxX ?? 1,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: 20,
                                verticalInterval: (maxX != null && minX != null && maxX > minX) ? ((maxX - minX) / 5).clamp(1, double.infinity) : 1,
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
                                      // Show only for actual shot counts in the data for any type
                                      bool show = accuracySpotsByType.values.any((spots) => spots.any((spot) => spot.x == value));
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
                                    interval: (maxX != null && minX != null && maxX > minX) ? ((maxX - minX) / 5).clamp(1, double.infinity) : 1,
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
                              lineBarsData: shotTypes
                                      .map((type) {
                                        final spots = accuracySpotsByType[type]!;
                                        final color = shotTypeColors[type]!;
                                        final isActive = type == _selectedShotType;
                                        if (spots.isEmpty) return null;
                                        return LineChartBarData(
                                          spots: spots,
                                          isCurved: true,
                                          barWidth: isActive ? 4 : 2,
                                          color: color,
                                          dotData: FlDotData(show: isActive),
                                          dashArray: isActive ? null : [8, 4],
                                        );
                                      })
                                      .whereType<LineChartBarData>()
                                      .toList() +
                                  // Add average accuracy lines for each type (optional, can comment out if not wanted)
                                  shotTypes
                                      .map((type) {
                                        final spots = accuracySpotsByType[type]!;
                                        final color = shotTypeColors[type]!;
                                        final avg = avgAccuracyByType[type]!;
                                        if (spots.isEmpty) return null;
                                        return LineChartBarData(
                                          spots: [
                                            FlSpot(spots.first.x, avg.roundToDouble()),
                                            FlSpot(spots.last.x, avg.roundToDouble()),
                                          ],
                                          isCurved: false,
                                          barWidth: 1,
                                          color: color.withOpacity(0.5),
                                          dashArray: [4, 4],
                                          dotData: const FlDotData(show: false),
                                        );
                                      })
                                      .whereType<LineChartBarData>()
                                      .toList(),
                            ),
                          ),
                          // Chart legend
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: shotTypes.map((type) {
                                return Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: shotTypeColors[type],
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${type[0].toUpperCase()}${type.substring(1)}",
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 12,
                                        fontFamily: 'NovecentoSans',
                                        fontWeight: type == _selectedShotType ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
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
                      ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 15),
                  Text(
                    "Shot Type".toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontFamily: 'NovecentoSans',
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
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
                        ),
                      ],
                    ),
                  ),
                  preferences!.puckCount != _currentShotCount
                      ? const SizedBox(
                          height: 10,
                        )
                      : Container(),
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
                  preferences!.puckCount != _currentShotCount
                      ? const SizedBox(
                          height: 5,
                        )
                      : Container(),
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

                      await showDialog<int>(
                        context: context,
                        builder: (context) {
                          int value = _currentShotCount;
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return AlertDialog(
                                title: const Text('Shots'),
                                content: NumberPicker(
                                  value: value,
                                  minValue: 1,
                                  maxValue: 500,
                                  onChanged: (v) => setState(() => value = v),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(value);
                                    },
                                    child: const Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ).then((value) {
                        if (value != null && value > 0 && value <= 500) {
                          setState(() {
                            _currentShotCount = value;
                          });
                        }
                      });
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
                          targetsHit = await showAccuracyInputDialog(context, _currentShotCount);
                          if (targetsHit == null) return;
                          setState(() {
                            _lastTargetsHit = targetsHit;
                          });
                        }

                        Shots shots = Shots(
                          DateTime.now(),
                          _selectedShotType,
                          _currentShotCount,
                          targetsHit: showAccuracyFeature ? targetsHit : null,
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
                ],
              ),
            ),
          ),
        ],
      ),
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

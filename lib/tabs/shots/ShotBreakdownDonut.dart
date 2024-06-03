import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/ShotCount.dart';

class ShotBreakdownDonut extends StatelessWidget {
  final List<ShotCount> shotCounts;

  const ShotBreakdownDonut(this.shotCounts, {super.key});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        borderData: FlBorderData(
          show: false,
        ),
        sectionsSpace: 0,
        centerSpaceRadius: 50,
        sections: showingSections(),
      ),
    );
  }

  List<PieChartSectionData> showingSections() {
    const fontSize = 16.0;
    const radius = 50.0;
    const shadows = [Shadow(color: Colors.black, blurRadius: 2)];
    List<PieChartSectionData> sections = [];
    final totalShots = shotCounts.fold(0, (int sum, sc) => sum + sc.count);

    for (ShotCount sc in shotCounts) {
      sections.add(
        PieChartSectionData(
          color: sc.color,
          value: (sc.count / totalShots) * 100,
          title: sc.count.toString(),
          badgeWidget: Text(
            sc.type,
            style: const TextStyle(
              color: Colors.black38,
              fontFamily: 'Novecento',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          badgePositionPercentageOffset: 1.5,
          radius: radius,
          titleStyle: const TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: shadows,
          ),
        ),
      );
    }

    return sections;
  }
}

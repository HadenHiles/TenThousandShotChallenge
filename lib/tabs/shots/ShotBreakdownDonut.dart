/// Donut chart with labels example. This is a simple pie chart with a hole in
/// the middle.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/ShotCount.dart';

class ShotBreakdownDonut extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  ShotBreakdownDonut(this.seriesList, {this.animate});

  /// Creates a [PieChart] with sample data and no transition.
  factory ShotBreakdownDonut.withSampleData() {
    return new ShotBreakdownDonut(
      _createSampleData(),
      // Disable animations for image tests.
      animate: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new charts.PieChart(
      seriesList,
      animate: animate,
      // Configure the width of the pie slices to 60px. The remaining space in
      // the chart will be left as a hole in the center.
      //
      // [ArcLabelDecorator] will automatically position the label inside the
      // arc if the label will fit. If the label will not fit, it will draw
      // outside of the arc with a leader line. Labels can always display
      // inside or outside using [LabelPosition].
      //
      // Text style for inside / outside can be controlled independently by
      // setting [insideLabelStyleSpec] and [outsideLabelStyleSpec].
      //
      // Example configuring different styles for inside/outside:
      //       new charts.ArcLabelDecorator(
      //          insideLabelStyleSpec: new charts.TextStyleSpec(...),
      //          outsideLabelStyleSpec: new charts.TextStyleSpec(...)),
      defaultRenderer: new charts.ArcRendererConfig(
        arcWidth: 60,
        arcRendererDecorators: [new charts.ArcLabelDecorator()],
      ),
    );
  }

  /// Create one series with sample hard coded data.
  static List<charts.Series<ShotCount, int>> _createSampleData() {
    final data = [
      new ShotCount('Wrist', 100),
      new ShotCount('Snap', 75),
      new ShotCount('Slap', 25),
      new ShotCount('Backhand', 5),
    ];

    return [
      new charts.Series<ShotCount, dynamic>(
        id: 'Shots',
        domainFn: (ShotCount sales, _) => sales.type,
        measureFn: (ShotCount sales, _) => sales.count,
        data: data,
        // Set a label accessor to control the text of the arc label.
        labelAccessorFn: (ShotCount row, _) => '${row.type}: ${row.count}',
      )
    ];
  }
}

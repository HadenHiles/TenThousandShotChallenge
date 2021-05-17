import 'dart:math';

/// Donut chart with labels example. This is a simple pie chart with a hole in
/// the middle.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:charts_flutter/flutter.dart';
import 'package:flutter/material.dart';

class ShotBreakdownDonut extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  ShotBreakdownDonut(this.seriesList, {this.animate});

  @override
  Widget build(BuildContext context) {
    return new charts.PieChart(
      seriesList,
      animate: animate,
      animationDuration: Duration(milliseconds: 500),
      selectionModels: [],
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
        arcWidth: 30,
        startAngle: 4 / 5 * pi,
        arcLength: 7 / 5 * pi,
        arcRendererDecorators: [
          new charts.ArcLabelDecorator(
              outsideLabelStyleSpec: TextStyleSpec(
            fontFamily: 'NovecentoSans',
            fontSize: 16,
            color: charts.MaterialPalette.gray.shade300,
          ))
        ],
      ),
    );
  }
}

import 'dart:math';

/// Donut chart with labels example. This is a simple pie chart with a hole in
/// the middle.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:charts_flutter/flutter.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/main.dart';

class ShotBreakdownDonut extends StatelessWidget {
  final List<charts.Series<dynamic, String>> seriesList;
  final bool? animate;

  const ShotBreakdownDonut(this.seriesList, {Key? key, this.animate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return charts.PieChart<String>(
      seriesList,
      animate: animate!,
      animationDuration: const Duration(milliseconds: 500),
      selectionModels: const [],
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
      defaultRenderer: charts.ArcRendererConfig(
        startAngle: 5 / 5 * pi,
        arcLength: 10 / 5 * pi,
        arcRatio: 0.4,
        arcRendererDecorators: [
          charts.ArcLabelDecorator(
              outsideLabelStyleSpec: TextStyleSpec(
            fontFamily: 'NovecentoSans',
            fontSize: 18,
            color: preferences!.darkMode! ? charts.MaterialPalette.gray.shade300 : charts.MaterialPalette.gray.shade600,
          ))
        ],
      ),
      // behaviors: [
      //   new charts.DatumLegend(
      //     position: charts.BehaviorPosition.top,
      //     outsideJustification: charts.OutsideJustification.endDrawArea,
      //     horizontalFirst: true,
      //     cellPadding: EdgeInsets.only(right: 10.0, bottom: 5.0),
      //     showMeasures: false,
      //     desiredMaxColumns: 4,
      //     desiredMaxRows: 1,
      //     legendDefaultMeasure: charts.LegendDefaultMeasure.firstValue,
      //     insideJustification: charts.InsideJustification.topStart,
      //     measureFormatter: (num value) {
      //       return value == null ? '-' : "$value";
      //     },
      //     entryTextStyle: charts.TextStyleSpec(
      //       color: preferences.darkMode ? charts.MaterialPalette.gray.shade300 : charts.MaterialPalette.gray.shade600,
      //       fontFamily: 'NovecentoSans',
      //       fontSize: 18,
      //     ),
      //   ),
      // ],
    );
  }
}

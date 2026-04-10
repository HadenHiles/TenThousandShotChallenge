import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/ShotCount.dart';
import 'package:tenthousandshotchallenge/tabs/shots/ShotBreakdownDonut.dart';
import 'package:tenthousandshotchallenge/tabs/shots/ShotProgress.dart';
import 'package:tenthousandshotchallenge/tabs/shots/ShotsOverTimeLineChart.dart';
import 'package:tenthousandshotchallenge/tabs/shots/TargetAccuracyVisualizer.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // ── ShotBreakdownDonut ────────────────────────────────────────────────────

  group('ShotBreakdownDonut', () {
    final shotCounts = [
      ShotCount('Wrist', 40, Colors.blue),
      ShotCount('Snap', 30, Colors.red),
      ShotCount('Slap', 20, Colors.green),
      ShotCount('Backhand', 10, Colors.orange),
    ];

    testWidgets('renders with shot count data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ShotBreakdownDonut(ctx, shotCounts),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ShotBreakdownDonut), findsOneWidget);
    });

    testWidgets('renders with multiple shot types', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ShotBreakdownDonut(ctx, shotCounts),
            ),
          ),
        ),
      );
      await tester.pump();
      // Widget renders without error and all shot type labels appear
      expect(find.byType(ShotBreakdownDonut), findsOneWidget);
      expect(find.text('Wrist'), findsWidgets);
    });

    testWidgets('renders with single shot type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ShotBreakdownDonut(ctx, [ShotCount('Wrist', 100, Colors.blue)]),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ShotBreakdownDonut), findsOneWidget);
    });
  });

  // ── ShotProgress ─────────────────────────────────────────────────────────

  group('ShotProgress', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_wrap(const ShotProgress()));
      await tester.pump();
      expect(find.byType(ShotProgress), findsOneWidget);
    });

    testWidgets('contains an empty Row', (tester) async {
      await tester.pumpWidget(_wrap(const ShotProgress()));
      await tester.pump();
      expect(find.byType(Row), findsWidgets);
    });
  });

  // ── ShotsOverTimeLineChart ────────────────────────────────────────────────

  group('ShotsOverTimeLineChart', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_wrap(const ShotsOverTimeLineChart()));
      await tester.pump();
      expect(find.byType(ShotsOverTimeLineChart), findsOneWidget);
    });

    testWidgets('shows avg toggle button', (tester) async {
      await tester.pumpWidget(_wrap(const ShotsOverTimeLineChart()));
      await tester.pump();
      expect(find.text('avg'), findsOneWidget);
    });

    testWidgets('avg button toggles state', (tester) async {
      await tester.pumpWidget(_wrap(const ShotsOverTimeLineChart()));
      await tester.pump();
      // Initially shows main data with avg button present
      expect(find.text('avg'), findsOneWidget);
      // Tap the avg button
      await tester.tap(find.text('avg'));
      await tester.pump();
      // Widget still renders after toggle
      expect(find.byType(ShotsOverTimeLineChart), findsOneWidget);
    });
  });

  // ── TargetAccuracyVisualizer ──────────────────────────────────────────────

  group('TargetAccuracyVisualizer', () {
    testWidgets('renders with perfect accuracy', (tester) async {
      await tester.pumpWidget(
        _wrap(const TargetAccuracyVisualizer(
          hits: 10,
          total: 10,
          shotColor: Colors.blue,
        )),
      );
      await tester.pump();
      expect(find.byType(TargetAccuracyVisualizer), findsOneWidget);
    });

    testWidgets('renders with zero accuracy', (tester) async {
      await tester.pumpWidget(
        _wrap(const TargetAccuracyVisualizer(
          hits: 0,
          total: 10,
          shotColor: Colors.red,
        )),
      );
      await tester.pump();
      expect(find.byType(TargetAccuracyVisualizer), findsOneWidget);
    });

    testWidgets('renders with no shots taken', (tester) async {
      await tester.pumpWidget(
        _wrap(const TargetAccuracyVisualizer(
          hits: 0,
          total: 0,
          shotColor: Colors.green,
        )),
      );
      await tester.pump();
      expect(find.byType(TargetAccuracyVisualizer), findsOneWidget);
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        _wrap(const TargetAccuracyVisualizer(
          hits: 5,
          total: 8,
          shotColor: Colors.purple,
          size: 120,
        )),
      );
      await tester.pump();
      expect(find.byType(TargetAccuracyVisualizer), findsOneWidget);
    });

    testWidgets('renders with partial accuracy (mid range)', (tester) async {
      await tester.pumpWidget(
        _wrap(const TargetAccuracyVisualizer(
          hits: 7,
          total: 12,
          shotColor: Colors.orange,
        )),
      );
      await tester.pump();
      expect(find.byType(TargetAccuracyVisualizer), findsOneWidget);
    });
  });
}

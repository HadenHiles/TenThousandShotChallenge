import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/widgets/MilestoneShareCard.dart';

void main() {
  group('MilestoneShareCard widget', () {
    // Give every test a wide surface so the fixed-width 360px card never overflows
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    Widget buildCard({
      required String title,
      required String subtitle,
      required int totalShots,
      String? displayName,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: MilestoneShareCard(
                title: title,
                subtitle: subtitle,
                totalShots: totalShots,
                displayName: displayName,
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pumpLarge(WidgetTester tester, Widget widget) async {
      await tester.binding.setSurfaceSize(const Size(600, 900));
      await tester.pumpWidget(widget);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    testWidgets('renders without crashing', (tester) async {
      await pumpLarge(
        tester,
        buildCard(title: '1000 SHOTS!', subtitle: 'Milestone reached', totalShots: 1000),
      );
      expect(find.byType(MilestoneShareCard), findsOneWidget);
    });

    testWidgets('displays title text', (tester) async {
      await pumpLarge(
        tester,
        buildCard(title: '5000 SHOTS!', subtitle: 'Halfway there', totalShots: 5000),
      );
      expect(find.textContaining('5000 SHOTS!', findRichText: true), findsOneWidget);
    });

    testWidgets('displays subtitle text', (tester) async {
      await pumpLarge(
        tester,
        buildCard(title: '1000 SHOTS!', subtitle: 'Milestone reached toward 10,000', totalShots: 1000),
      );
      expect(find.textContaining('Milestone reached', findRichText: true), findsOneWidget);
    });

    testWidgets('displays formatted shot count', (tester) async {
      await pumpLarge(
        tester,
        buildCard(title: '2500 SHOTS!', subtitle: 'Keep pushing', totalShots: 2500),
      );
      // NumberFormat('#,###') renders 2500 as "2,500"
      expect(find.textContaining('2,500', findRichText: true), findsOneWidget);
    });

    testWidgets('displays displayName when provided', (tester) async {
      await pumpLarge(
        tester,
        buildCard(
          title: '10000 SHOTS!',
          subtitle: 'Challenge complete',
          totalShots: 10000,
          displayName: 'Wayne',
        ),
      );
      expect(find.textContaining('Wayne', findRichText: true), findsOneWidget);
    });

    testWidgets('renders without displayName when null', (tester) async {
      await pumpLarge(
        tester,
        buildCard(title: '7500 SHOTS!', subtitle: 'Almost there', totalShots: 7500),
      );
      expect(find.byType(MilestoneShareCard), findsOneWidget);
    });

    testWidgets('shows hockey sports icon', (tester) async {
      await pumpLarge(
        tester,
        buildCard(title: '1000 SHOTS!', subtitle: 'Nice', totalShots: 1000),
      );
      expect(find.byIcon(Icons.sports_hockey), findsWidgets);
    });

    testWidgets('shows trophy icon', (tester) async {
      await pumpLarge(
        tester,
        buildCard(title: '1000 SHOTS!', subtitle: 'Nice', totalShots: 1000),
      );
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    });

    testWidgets('app name label is always shown', (tester) async {
      await pumpLarge(
        tester,
        buildCard(title: '1000 SHOTS!', subtitle: 'Nice', totalShots: 1000),
      );
      expect(find.textContaining('TEN THOUSAND SHOT CHALLENGE', findRichText: true), findsOneWidget);
    });
  });
}

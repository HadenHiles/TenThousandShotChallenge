import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/HandsfreeCountdownMode.dart';

void main() {
  group('HandsfreeCountdownMode widget', () {
    Widget buildWidget({
      int shotCount = 25,
      String shotType = 'wrist',
      void Function(Shots)? onShotAdded,
      VoidCallback? onExit,
    }) {
      return MaterialApp(
        home: HandsfreeCountdownMode(
          shotCount: shotCount,
          shotType: shotType,
          onShotAdded: onShotAdded ?? (_) {},
          onExit: onExit ?? () {},
        ),
      );
    }

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(HandsfreeCountdownMode), findsOneWidget);
    });

    testWidgets('shows HANDS-FREE MODE title', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.textContaining('HANDS-FREE MODE', findRichText: true), findsOneWidget);
    });

    testWidgets('shows START button when not yet running', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('START'), findsOneWidget);
    });

    testWidgets('shows speed slider', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('shows shot type and puck count hint', (tester) async {
      await tester.pumpWidget(buildWidget(shotCount: 30, shotType: 'snap'));
      expect(find.textContaining('snap shot', findRichText: true), findsOneWidget);
      expect(find.textContaining('30 pucks', findRichText: true), findsOneWidget);
    });

    testWidgets('shows sets and shots stat chips', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('SETS'), findsOneWidget);
      expect(find.text('SHOTS'), findsOneWidget);
    });

    testWidgets('shows speed labels Slow and Fast', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.textContaining('Slow', findRichText: true), findsOneWidget);
      expect(find.textContaining('Fast', findRichText: true), findsOneWidget);
    });

    testWidgets('tapping START changes button to PAUSE', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('START'));
      await tester.pump();
      expect(find.text('PAUSE'), findsOneWidget);
    });

    testWidgets('tapping PAUSE while running reverts to START (no sets yet)', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.tap(find.text('PAUSE'));
      await tester.pump();
      // _setsLogged is still 0, so button shows START again
      expect(find.text('START'), findsOneWidget);
    });

    testWidgets('exit icon button calls onExit', (tester) async {
      bool exited = false;
      await tester.pumpWidget(buildWidget(onExit: () => exited = true));
      // The close icon is in the header row
      await tester.tap(find.byIcon(Icons.close));
      expect(exited, isTrue);
    });

    testWidgets('onShotAdded receives correct shot type', (tester) async {
      Shots? received;
      await tester.pumpWidget(
        buildWidget(
          shotCount: 20,
          shotType: 'slap',
          onShotAdded: (s) => received = s,
        ),
      );
      // advance timers to fire one shot (default 15 spm = 4 sec interval)
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(received?.type, 'slap');
      expect(received?.count, 20);
    });
  });
}

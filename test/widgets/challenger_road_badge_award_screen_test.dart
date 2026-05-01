import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadTrophyAwardScreen.dart';

void main() {
  testWidgets('pages through multiple unlocked badges and updates counter', (tester) async {
    const badges = [
      ChallengerRoadTrophyDefinition(
        id: 'cr_fresh_laces',
        name: 'Fresh Laces',
        description: 'Started the Challenger Road.',
        category: ChallengerRoadTrophyCategory.firstSteps,
        tier: ChallengerRoadTrophyTier.common,
      ),
      ChallengerRoadTrophyDefinition(
        id: 'cr_clean_read',
        name: 'Clean Read',
        description: 'Passed your first challenge.',
        category: ChallengerRoadTrophyCategory.firstSteps,
        tier: ChallengerRoadTrophyTier.common,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: ChallengerRoadTrophyAwardScreen(trophies: badges),
      ),
    );

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('NEXT BADGE'), findsOneWidget);
    expect(find.text('FRESH LACES'), findsOneWidget);

    await tester.tap(find.text('NEXT BADGE'));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text("LET'S KEEP GOING"), findsOneWidget);
    expect(find.text('CLEAN READ'), findsOneWidget);
  });

  testWidgets('single badge flow does not show counter and shows final CTA', (tester) async {
    const badges = [
      ChallengerRoadTrophyDefinition(
        id: 'cr_fresh_laces',
        name: 'Fresh Laces',
        description: 'Started the Challenger Road.',
        category: ChallengerRoadTrophyCategory.firstSteps,
        tier: ChallengerRoadTrophyTier.common,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: ChallengerRoadTrophyAwardScreen(trophies: badges),
      ),
    );

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('1 / 1'), findsNothing);
    expect(find.text("LET'S KEEP GOING"), findsOneWidget);
    expect(find.text('FRESH LACES'), findsOneWidget);
  });
}

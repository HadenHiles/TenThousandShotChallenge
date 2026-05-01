import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/widgets/CrAvatarTrophy.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatarCrPopover.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );

void main() {
  group('resolveCrProfileAccomplishment', () {
    test('prefers road completion over other earned badges', () {
      final summary = ChallengerRoadUserSummary(
        totalAttempts: 4,
        allTimeBestLevel: 12,
        allTimeBestLevelShots: 9876,
        allTimeTotalChallengerRoadShots: 22000,
        trophies: const ['cr_buzzer_beater', 'cr_the_general'],
      );

      final accomplishment = resolveCrProfileAccomplishment(summary);

      expect(accomplishment, isNotNull);
      expect(accomplishment!.headline, 'Road Complete (Sub-10k)');
      expect(accomplishment.subtitle, contains('9,876 shots'));
    });

    test('selects the highest-tier earned badge when road is not complete', () {
      final summary = ChallengerRoadUserSummary(
        totalAttempts: 2,
        allTimeBestLevel: 7,
        allTimeBestLevelShots: 11000,
        allTimeTotalChallengerRoadShots: 14000,
        trophies: const ['cr_ice_time_earned', 'cr_team_captain', 'cr_bar_down'],
      );

      final accomplishment = resolveCrProfileAccomplishment(summary);

      expect(accomplishment, isNotNull);
      expect(accomplishment!.headline, 'Team Captain');
      expect(accomplishment.subtitle, 'Level 10 cleared.');
    });

    test('falls back to generic best-level progress when no badges exist', () {
      final summary = ChallengerRoadUserSummary(
        totalAttempts: 1,
        allTimeBestLevel: 6,
        allTimeBestLevelShots: 4500,
        allTimeTotalChallengerRoadShots: 4500,
        trophies: const [],
      );

      final accomplishment = resolveCrProfileAccomplishment(summary);

      expect(accomplishment, isNotNull);
      expect(accomplishment!.headline, 'Best Level: 6');
      expect(accomplishment.label, '6');
    });

    test('falls back to pro subscriber when requested and no CR activity exists', () {
      final accomplishment = resolveCrProfileAccomplishment(
        ChallengerRoadUserSummary.empty(),
        showProFallback: true,
      );

      expect(accomplishment, isNotNull);
      expect(accomplishment!.headline, 'Pro Subscriber');
      expect(accomplishment.subtitle, 'No Challenger Road milestone yet');
    });
  });

  group('UserAvatarCrPopover', () {
    testWidgets('shows accomplishment row and provided actions in the popup menu', (tester) async {
      final controller = StreamController<ChallengerRoadUserSummary>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _wrap(
          UserAvatarCrPopover(
            userId: 'user-1',
            summaryStream: controller.stream,
            onViewProfile: () {},
            onEditAvatar: () {},
            onShowQrCode: () {},
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );

      controller.add(
        ChallengerRoadUserSummary(
          totalAttempts: 3,
          allTimeBestLevel: 10,
          allTimeBestLevelShots: 10000,
          allTimeTotalChallengerRoadShots: 15000,
          trophies: const ['cr_team_captain'],
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('TEAM CAPTAIN'), findsOneWidget);
      expect(find.text('VIEW PROFILE'), findsOneWidget);
      expect(find.text('CHANGE AVATAR'), findsOneWidget);
      expect(find.text('SHOW QR CODE'), findsOneWidget);
    });

    testWidgets('shows pro fallback copy when explicitly enabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UserAvatarCrPopover(
            userId: 'user-2',
            showProFallback: true,
            summaryStream: Stream.value(ChallengerRoadUserSummary.empty()),
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('PRO SUBSCRIBER'), findsOneWidget);
      expect(find.text('No Challenger Road milestone yet'), findsOneWidget);
    });
  });
}

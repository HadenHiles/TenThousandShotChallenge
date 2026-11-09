import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/TeamBadge.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamBadgeBoard.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamBadgeStrip.dart';

void main() {
  test('catalog has five badges and exactly one free badge', () {
    expect(teamBadges, hasLength(5));
    expect(teamBadges.where((b) => b.isFree).map((b) => b.id), ['hardest_worker']);
  });

  test('a badge stays with its latest holder and counts persist per player', () {
    final now = DateTime(2026, 11, 9, 12);
    final awards = TeamBadgeAwards.fromDocs([
      {'player_id': 'p1', 'badge_id': 'hardest_worker', 'day': '2026-11-06'},
      {'player_id': 'p1', 'badge_id': 'hardest_worker', 'day': '2026-11-07'},
      {'player_id': 'p2', 'badge_id': 'hardest_worker', 'day': '2026-11-08'},
      {'player_id': 'p1', 'badge_id': 'leadership', 'day': '2026-11-08'},
      {'player_id': 'p2', 'badge_id': 'not_a_badge', 'day': '2026-11-09'},
    ], now: now);

    expect(awards.heldBy('p1'), {'leadership': 1});
    expect(awards.heldBy('p2'), {'hardest_worker': 1});
    expect(awards.timesEarned('p1', 'hardest_worker'), 2);
  });

  test('today tracks who has each badge and whether giving it would move it', () {
    final now = DateTime(2026, 11, 9, 12);
    final awards = TeamBadgeAwards.fromDocs([
      {'player_id': 'p1', 'badge_id': 'hardest_worker', 'day': '2026-11-09'},
      {'player_id': 'p1', 'badge_id': 'hardest_worker', 'day': '2026-11-08'},
    ], now: now);

    expect(awards.awardedToday('p1', 'hardest_worker'), isTrue);
    expect(awards.awardedToday('p2', 'hardest_worker'), isFalse);
    expect(awards.awardedTodayToSomeoneElse('p2', 'hardest_worker'), isTrue);
    expect(awards.awardedTodayToSomeoneElse('p1', 'hardest_worker'), isFalse);
    expect(awards.awardedTodayToSomeoneElse('p2', 'leadership'), isFalse);
    expect(awards.heldBy('p1'), {'hardest_worker': 2});
  });

  testWidgets('strip shows a count only for badges earned more than once', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TeamBadgeStrip(counts: {'hardest_worker': 3, 'leadership': 1})),
    ));

    expect(find.byType(TeamBadgeIcon), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('board shows a slot per badge with the current holder avatar', (tester) async {
    final awards = TeamBadgeAwards.fromDocs([
      {'player_id': 'p1', 'badge_id': 'leadership', 'day': '2026-11-08'},
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeamBadgeBoard(
          teamId: 't1',
          players: const [TeamBadgePlayer(id: 'p1', name: 'Pat'), TeamBadgePlayer(id: 'p2', name: 'Sam')],
          awards: Stream.value(awards),
          isCoach: false,
          coachId: 'coach',
          accentColor: Colors.red,
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(Image), findsNWidgets(5));
    expect(find.text('P'), findsOneWidget);
    expect(find.text('S'), findsNothing);
  });
}

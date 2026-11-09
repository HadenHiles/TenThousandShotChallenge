import 'package:intl/intl.dart';

/// A character/effort badge a coach can award to players on their team.
class TeamBadge {
  const TeamBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.asset,
    this.isFree = false,
  });

  final String id;
  final String title;
  final String description;
  final String asset;

  /// Free badges can be awarded by any coach; the rest need a Pro subscription.
  final bool isFree;
}

// Keep ids and the free flag in sync with TEAM_BADGES in functions/src/index.ts.
const List<TeamBadge> teamBadges = [
  TeamBadge(
    id: 'hardest_worker',
    title: 'Hardest Worker',
    description: 'Gave top effort in drills and practice.',
    asset: 'assets/images/team_badges/hardest_worker.png',
    isFree: true,
  ),
  TeamBadge(
    id: 'great_teammate',
    title: 'Great Teammate',
    description: 'Lifted others up and made everyone feel included.',
    asset: 'assets/images/team_badges/great_teammate.png',
  ),
  TeamBadge(
    id: 'never_gave_up',
    title: 'Never Gave Up',
    description: 'Fought through a tough moment and kept going.',
    asset: 'assets/images/team_badges/never_gave_up.png',
  ),
  TeamBadge(
    id: 'leadership',
    title: 'Leadership',
    description: 'Set the example and helped teammates improve.',
    asset: 'assets/images/team_badges/leadership.png',
  ),
  TeamBadge(
    id: 'great_attitude',
    title: 'Great Attitude',
    description: 'Positive, coachable and a good sport.',
    asset: 'assets/images/team_badges/great_attitude.png',
  ),
];

TeamBadge? teamBadgeById(String id) {
  for (final badge in teamBadges) {
    if (badge.id == id) return badge;
  }
  return null;
}

/// Badge awards for one team. Each badge is a sticker the coach can give to
/// one player per day, and it stays on that player until it is given to someone else.
class TeamBadgeAwards {
  const TeamBadgeAwards({this.counts = const {}, this.holders = const {}, this.todayHolders = const {}});

  /// playerId -> badgeId -> number of days the player was awarded the badge.
  final Map<String, Map<String, int>> counts;

  /// badgeId -> player who currently holds it (the most recent award).
  final Map<String, String> holders;

  /// badgeId -> player it was awarded to today, if anyone.
  final Map<String, String> todayHolders;

  static const empty = TeamBadgeAwards();

  static String dayKey([DateTime? now]) => DateFormat('yyyy-MM-dd').format(now ?? DateTime.now());

  /// Each doc is one badge given to one player on one day.
  factory TeamBadgeAwards.fromDocs(Iterable<Map<String, dynamic>> docs, {DateTime? now}) {
    final today = dayKey(now);
    final counts = <String, Map<String, int>>{};
    final latestDay = <String, String>{};
    final holders = <String, String>{};
    final todayHolders = <String, String>{};
    for (final data in docs) {
      final playerId = data['player_id'];
      final badgeId = data['badge_id'];
      final day = data['day'];
      if (playerId is! String || badgeId is! String || day is! String || teamBadgeById(badgeId) == null) continue;
      final perPlayer = counts.putIfAbsent(playerId, () => {});
      perPlayer[badgeId] = (perPlayer[badgeId] ?? 0) + 1;
      final latest = latestDay[badgeId];
      if (latest == null || day.compareTo(latest) > 0) {
        latestDay[badgeId] = day;
        holders[badgeId] = playerId;
      }
      if (day == today) todayHolders[badgeId] = playerId;
    }
    return TeamBadgeAwards(counts: counts, holders: holders, todayHolders: todayHolders);
  }

  /// The badges a player currently holds, with how many times they have earned each.
  Map<String, int> heldBy(String playerId) => {
        for (final entry in holders.entries)
          if (entry.value == playerId) entry.key: counts[playerId]?[entry.key] ?? 1,
      };

  int timesEarned(String playerId, String badgeId) => counts[playerId]?[badgeId] ?? 0;

  bool awardedToday(String playerId, String badgeId) => todayHolders[badgeId] == playerId;

  /// Awarded today to a different player, so giving it here would move it.
  bool awardedTodayToSomeoneElse(String playerId, String badgeId) {
    final holder = todayHolders[badgeId];
    return holder != null && holder != playerId;
  }
}

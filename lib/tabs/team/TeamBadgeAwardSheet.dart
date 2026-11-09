import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/TeamBadge.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/services/TeamBadgeService.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamBadgeStrip.dart';

/// Coach-only sheet for awarding today's badges to one player.
Future<void> showTeamBadgeAwardSheet(
  BuildContext context, {
  required String teamId,
  required String playerId,
  required String playerName,
  required Stream<TeamBadgeAwards> awards,
  TeamBadgeService? service,
}) {
  final badgeService = service ?? TeamBadgeService();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.primary,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => _TeamBadgeAwardSheet(
      teamId: teamId,
      playerId: playerId,
      playerName: playerName,
      awards: awards,
      service: badgeService,
    ),
  );
}

class _TeamBadgeAwardSheet extends StatefulWidget {
  const _TeamBadgeAwardSheet({
    required this.teamId,
    required this.playerId,
    required this.playerName,
    required this.awards,
    required this.service,
  });

  final String teamId;
  final String playerId;
  final String playerName;
  final Stream<TeamBadgeAwards> awards;
  final TeamBadgeService service;

  @override
  State<_TeamBadgeAwardSheet> createState() => _TeamBadgeAwardSheetState();
}

class _TeamBadgeAwardSheetState extends State<_TeamBadgeAwardSheet> {
  String? _busyBadgeId;

  Future<void> _toggle(TeamBadge badge, bool awardedToday) async {
    final isPro = Provider.of<CustomerInfoNotifier?>(context, listen: false)?.isPro ?? false;
    if (!badge.isFree && !isPro && !awardedToday) {
      Navigator.of(context).pop();
      await presentPaywallIfNeeded(context);
      return;
    }

    setState(() => _busyBadgeId = badge.id);
    final error = await widget.service.setAward(
      teamId: widget.teamId,
      playerId: widget.playerId,
      badgeId: badge.id,
      remove: awardedToday,
    );
    if (!mounted) return;
    setState(() => _busyBadgeId = null);
    if (error != null) {
      Fluttertoast.showToast(msg: error);
    } else if (!awardedToday) {
      Fluttertoast.showToast(msg: '${badge.title} awarded to ${widget.playerName}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final isPro = Provider.of<CustomerInfoNotifier?>(context)?.isPro ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: StreamBuilder<TeamBadgeAwards>(
          stream: widget.awards,
          initialData: TeamBadgeAwards.empty,
          builder: (context, snapshot) {
            final awards = snapshot.data ?? TeamBadgeAwards.empty;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Award a badge to ${widget.playerName}'.toUpperCase(),
                  style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 24, color: onPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Each badge can go to one player per day and stays with them until you give it to someone else. Tap an awarded badge to take it back.',
                  style: TextStyle(color: onPrimary.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 8),
                for (final badge in teamBadges) _buildRow(context, badge, awards, isPro, onPrimary),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, TeamBadge badge, TeamBadgeAwards awards, bool isPro, Color onPrimary) {
    final awardedToday = awards.awardedToday(widget.playerId, badge.id);
    final total = awards.timesEarned(widget.playerId, badge.id);
    final movesFromOther = awards.awardedTodayToSomeoneElse(widget.playerId, badge.id);
    final locked = !badge.isFree && !isPro && !awardedToday;
    final busy = _busyBadgeId == badge.id;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: _busyBadgeId == null,
      onTap: () => _toggle(badge, awardedToday),
      leading: TeamBadgeIcon(badge: badge, count: total, size: 44),
      title: Text(badge.title.toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: onPrimary)),
      subtitle: Text(movesFromOther ? 'Already given to another player today. Tap to move it here.' : badge.description, style: TextStyle(color: onPrimary.withValues(alpha: 0.7))),
      trailing: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : awardedToday
              ? Icon(Icons.check_circle, color: onPrimary)
              : locked
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_outline, size: 18, color: onPrimary.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text('PRO', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: onPrimary.withValues(alpha: 0.7))),
                    ])
                  : Icon(Icons.add_circle_outline, color: onPrimary.withValues(alpha: 0.8)),
    );
  }
}

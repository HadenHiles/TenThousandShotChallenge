import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/TeamBadge.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/services/TeamBadgeService.dart';

/// The minimum a player needs to appear on the badge board.
class TeamBadgePlayer {
  const TeamBadgePlayer({required this.id, required this.name, this.photoUrl});

  final String id;
  final String name;
  final String? photoUrl;
}

/// One column per badge showing the player who currently holds it. The coach
/// can tap a column to give the badge to a player.
class TeamBadgeBoard extends StatelessWidget {
  const TeamBadgeBoard({
    super.key,
    required this.teamId,
    required this.players,
    required this.awards,
    required this.isCoach,
    required this.coachId,
    required this.accentColor,
    this.service,
  });

  final String teamId;
  final List<TeamBadgePlayer> players;
  final Stream<TeamBadgeAwards> awards;
  final bool isCoach;
  final String? coachId;
  final Color accentColor;
  final TeamBadgeService? service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TeamBadgeAwards>(
      stream: awards,
      initialData: TeamBadgeAwards.empty,
      builder: (context, snapshot) {
        final data = snapshot.data ?? TeamBadgeAwards.empty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final badge in teamBadges)
                Expanded(child: _slot(context, badge, data)),
            ],
          ),
        );
      },
    );
  }

  Widget _slot(BuildContext context, TeamBadge badge, TeamBadgeAwards data) {
    final holderId = data.holders[badge.id];
    TeamBadgePlayer? holder;
    for (final p in players) {
      if (p.id == holderId) holder = p;
    }
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(badge.asset, width: 38, height: 38, semanticLabel: badge.title),
        const SizedBox(height: 2),
        holder != null
            ? TeamBadgeAvatar(player: holder, radius: 16, accentColor: accentColor)
            : Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: onSurface.withValues(alpha: 0.25)),
                ),
                child: isCoach ? Icon(Icons.add, size: 16, color: onSurface.withValues(alpha: 0.4)) : null,
              ),
      ],
    );

    return Tooltip(
      message: holder == null ? badge.title : '${badge.title}: ${holder.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isCoach ? () => _openPicker(context, badge, data) : null,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: content),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, TeamBadge badge, TeamBadgeAwards data) async {
    final isPro = Provider.of<CustomerInfoNotifier?>(context, listen: false)?.isPro ?? false;
    if (!badge.isFree && !isPro) {
      await _showProPreview(context, badge);
      return;
    }
    if (!context.mounted) return;
    final candidates = [for (final p in players) if (p.id != coachId) p];
    final badgeService = service ?? TeamBadgeService();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _BadgePlayerPicker(
        teamId: teamId,
        badge: badge,
        players: candidates,
        awards: awards,
        accentColor: accentColor,
        service: badgeService,
      ),
    );
  }
}

/// Lets free coaches see what a Pro badge is before deciding to unlock it.
Future<void> _showProPreview(BuildContext context, TeamBadge badge) async {
  final unlock = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.primary,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      final onPrimary = Theme.of(sheetContext).colorScheme.onPrimary;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(badge.asset, width: 96, height: 96, semanticLabel: badge.title),
              const SizedBox(height: 8),
              Text(badge.title.toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 28, color: onPrimary)),
              const SizedBox(height: 4),
              Text(badge.description, textAlign: TextAlign.center, style: TextStyle(color: onPrimary.withValues(alpha: 0.8))),
              const SizedBox(height: 12),
              Text(
                'Awarding this badge is a Pro feature. Hardest Worker is free for every coach.',
                textAlign: TextAlign.center,
                style: TextStyle(color: onPrimary.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: onPrimary,
                    foregroundColor: Theme.of(sheetContext).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Unlock with Pro'.toUpperCase(), style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (unlock == true && context.mounted) await presentPaywallIfNeeded(context, focus: PaywallFocus.teamBadges);
}

class _BadgePlayerPicker extends StatefulWidget {
  const _BadgePlayerPicker({
    required this.teamId,
    required this.badge,
    required this.players,
    required this.awards,
    required this.accentColor,
    required this.service,
  });

  final String teamId;
  final TeamBadge badge;
  final List<TeamBadgePlayer> players;
  final Stream<TeamBadgeAwards> awards;
  final Color accentColor;
  final TeamBadgeService service;

  @override
  State<_BadgePlayerPicker> createState() => _BadgePlayerPickerState();
}

class _BadgePlayerPickerState extends State<_BadgePlayerPicker> {
  bool _busy = false;

  Future<void> _set(TeamBadgePlayer player, {required bool remove}) async {
    setState(() => _busy = true);
    final error = await widget.service.setAward(
      teamId: widget.teamId,
      playerId: player.id,
      badgeId: widget.badge.id,
      remove: remove,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _busy = false);
      Fluttertoast.showToast(msg: error);
      return;
    }
    Navigator.of(context).pop();
    if (!remove) Fluttertoast.showToast(msg: '${widget.badge.title} awarded to ${player.name}');
  }

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: StreamBuilder<TeamBadgeAwards>(
            stream: widget.awards,
            initialData: TeamBadgeAwards.empty,
            builder: (context, snapshot) {
              final data = snapshot.data ?? TeamBadgeAwards.empty;
              final todayHolderId = data.todayHolders[widget.badge.id];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Image.asset(widget.badge.asset, width: 44, height: 44),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.badge.title.toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 24, color: onPrimary)),
                    ),
                  ]),
                  Text(
                    'Give it to one player today. It stays with them until you give it to someone else.',
                    style: TextStyle(color: onPrimary.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: widget.players.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text('No players to award yet.', style: TextStyle(color: onPrimary.withValues(alpha: 0.7))),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              for (final player in widget.players)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  enabled: !_busy,
                                  leading: TeamBadgeAvatar(player: player, radius: 20, accentColor: widget.accentColor),
                                  title: Text(player.name, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: onPrimary)),
                                  trailing: todayHolderId == player.id
                                      ? Icon(Icons.check_circle, color: onPrimary)
                                      : data.holders[widget.badge.id] == player.id
                                          ? Text('CURRENT', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: onPrimary.withValues(alpha: 0.6)))
                                          : null,
                                  onTap: () => _set(player, remove: todayHolderId == player.id),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class TeamBadgeAvatar extends StatelessWidget {
  const TeamBadgeAvatar({super.key, required this.player, required this.radius, required this.accentColor});

  final TeamBadgePlayer player;
  final double radius;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    var photo = player.photoUrl ?? '';
    if (photo.startsWith('file:///')) photo = photo.substring('file:///'.length);
    if (photo.startsWith('/')) photo = photo.substring(1);

    ImageProvider? image;
    if (photo.startsWith('http')) {
      image = NetworkImage(photo);
    } else if (photo.isNotEmpty) {
      image = AssetImage(photo);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      backgroundImage: image,
      onBackgroundImageError: image == null ? null : (_, __) {},
      child: image == null
          ? Text(
              player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
              style: TextStyle(fontFamily: 'NovecentoSans', fontSize: radius, color: accentColor),
            )
          : null,
    );
  }
}

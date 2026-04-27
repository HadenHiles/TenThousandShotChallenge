import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';

// ── Data model ───────────────────────────────────────────────────────────────

enum _ActivityType { shooting, challengerRoad }

class _ActivityEntry {
  final _ActivityType type;
  final DateTime date;
  final String playerUid;
  final String playerName;
  final String? playerPhotoUrl;

  // Regular session fields
  final ShootingSession? session;

  // Challenger Road session fields
  final ChallengeSession? challengeSession;

  const _ActivityEntry.shooting({
    required this.date,
    required this.playerUid,
    required this.playerName,
    this.playerPhotoUrl,
    required this.session,
  })  : type = _ActivityType.shooting,
        challengeSession = null;

  const _ActivityEntry.challengerRoad({
    required this.date,
    required this.playerUid,
    required this.playerName,
    this.playerPhotoUrl,
    required this.challengeSession,
  })  : type = _ActivityType.challengerRoad,
        session = null;
}

// ── Screen ───────────────────────────────────────────────────────────────────

class TeamActivity extends StatefulWidget {
  final Team team;

  const TeamActivity({super.key, required this.team});

  @override
  State<TeamActivity> createState() => _TeamActivityState();
}

class _TeamActivityState extends State<TeamActivity> {
  final NumberFormat _nf = NumberFormat('###,###,###', 'en_US');

  bool _loading = true;
  String? _error;

  // All activity entries sorted newest-first
  List<_ActivityEntry> _entries = [];

  // Player name/photo cache keyed by uid
  final Map<String, UserProfile> _profileCache = {};

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
      final playerUids = widget.team.players ?? [];
      final teamStart = widget.team.startDate ?? DateTime(2000);
      final teamEnd = widget.team.targetDate ?? DateTime(2100);

      // Load all player profiles in parallel
      final profileFutures = playerUids.map((uid) async {
        final doc = await firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          return MapEntry(uid, UserProfile.fromSnapshot(doc));
        }
        return null;
      });
      final profileResults = await Future.wait(profileFutures);
      for (final entry in profileResults) {
        if (entry != null) _profileCache[entry.key] = entry.value;
      }

      final List<_ActivityEntry> all = [];

      // For each player, load their shooting sessions + CR sessions in parallel
      await Future.wait(playerUids.map((uid) async {
        final profile = _profileCache[uid];
        final name = profile?.displayName ?? 'Player';
        final photo = profile?.photoUrl;

        await Future.wait([
          _loadShootingSessions(firestore, uid, name, photo, teamStart, teamEnd, all),
          _loadChallengerRoadSessions(firestore, uid, name, photo, teamStart, teamEnd, all),
        ]);
      }));

      all.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _entries = all;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load activity.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadShootingSessions(
    FirebaseFirestore firestore,
    String uid,
    String name,
    String? photo,
    DateTime teamStart,
    DateTime teamEnd,
    List<_ActivityEntry> out,
  ) async {
    // Iterate through all iterations for this player
    final iterSnap = await firestore.collection('iterations').doc(uid).collection('iterations').get();

    for (final iterDoc in iterSnap.docs) {
      final sessSnap = await firestore.collection('iterations').doc(uid).collection('iterations').doc(iterDoc.id).collection('sessions').orderBy('date', descending: true).get();

      for (final sessDoc in sessSnap.docs) {
        try {
          final s = ShootingSession.fromSnapshot(sessDoc);
          if (s.date == null) continue;
          final d = s.date!;
          final day = DateTime(d.year, d.month, d.day);
          final startDay = DateTime(teamStart.year, teamStart.month, teamStart.day);
          final endDay = DateTime(teamEnd.year, teamEnd.month, teamEnd.day);
          if (day.isBefore(startDay) || day.isAfter(endDay)) continue;
          out.add(_ActivityEntry.shooting(
            date: d,
            playerUid: uid,
            playerName: name,
            playerPhotoUrl: photo,
            session: s,
          ));
        } catch (_) {
          // Skip malformed docs
        }
      }
    }
  }

  Future<void> _loadChallengerRoadSessions(
    FirebaseFirestore firestore,
    String uid,
    String name,
    String? photo,
    DateTime teamStart,
    DateTime teamEnd,
    List<_ActivityEntry> out,
  ) async {
    final attemptsSnap = await firestore.collection('users').doc(uid).collection('challenger_road_attempts').get();

    for (final attemptDoc in attemptsSnap.docs) {
      final sessSnap = await firestore.collection('users').doc(uid).collection('challenger_road_attempts').doc(attemptDoc.id).collection('challenge_sessions').orderBy('date', descending: true).get();

      for (final sessDoc in sessSnap.docs) {
        try {
          final s = ChallengeSession.fromSnapshot(sessDoc);
          final d = s.date;
          final day = DateTime(d.year, d.month, d.day);
          final startDay = DateTime(teamStart.year, teamStart.month, teamStart.day);
          final endDay = DateTime(teamEnd.year, teamEnd.month, teamEnd.day);
          if (day.isBefore(startDay) || day.isAfter(endDay)) continue;
          out.add(_ActivityEntry.challengerRoad(
            date: d,
            playerUid: uid,
            playerName: name,
            playerPhotoUrl: photo,
            challengeSession: s,
          ));
        } catch (_) {
          // Skip malformed docs
        }
      }
    }
  }

  // ── Grouping ─────────────────────────────────────────────────────────────

  /// Group entries by calendar day (local time). Returns a list of
  /// [day, List<_ActivityEntry>] pairs, newest-day first.
  List<MapEntry<DateTime, List<_ActivityEntry>>> _groupByDay() {
    final map = <String, List<_ActivityEntry>>{};
    for (final e in _entries) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      (map[key] ??= []).add(e);
    }

    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    // Ensure today is always present even if empty
    map.putIfAbsent(todayKey, () => []);

    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) {
      final parts = k.split('-');
      final day = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return MapEntry(day, map[k]!);
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final teamPrimaryColor = colorFromHex(widget.team.primaryColor);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            collapsedHeight: 65,
            expandedHeight: 65,
            backgroundColor: Theme.of(context).colorScheme.primary,
            floating: true,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.only(top: 10),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
              child: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                titlePadding: null,
                centerTitle: false,
                title: const BasicTitle(title: 'Team Activity'),
                background: Container(color: Theme.of(context).scaffoldBackgroundColor),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                child: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 26),
                  onPressed: _loadActivity,
                ),
              ),
            ],
          ),
        ],
        body: _loading
            ? Center(child: CircularProgressIndicator(color: teamPrimaryColor))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadActivity, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _buildFeed(context, teamPrimaryColor),
      ),
    );
  }

  Widget _buildFeed(BuildContext context, Color teamPrimaryColor) {
    final grouped = _groupByDay();
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    // Build a flat list: day header + entry cards, skipping empty non-today days
    final items = <Widget>[];
    for (final group in grouped) {
      final day = group.key;
      final dayEntries = group.value;
      final isToday = day == todayDay;

      if (dayEntries.isEmpty && !isToday) continue;

      items.add(_DayHeader(day: day, isToday: isToday, primaryColor: teamPrimaryColor));

      if (dayEntries.isEmpty) {
        items.add(_EmptyDayCard(context));
      } else {
        for (final entry in dayEntries) {
          items.add(_ActivityCard(
            entry: entry,
            teamPrimaryColor: teamPrimaryColor,
            nf: _nf,
            onTap: () => _showDetailSheet(context, entry, teamPrimaryColor),
          ));
        }
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No activity yet.'.toUpperCase(),
          style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
      children: items,
    );
  }

  void _showDetailSheet(BuildContext context, _ActivityEntry entry, Color teamPrimaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionDetailSheet(
        entry: entry,
        teamPrimaryColor: teamPrimaryColor,
        nf: _nf,
      ),
    );
  }
}

// ── Day header ────────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final Color primaryColor;

  const _DayHeader({required this.day, required this.isToday, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    String label;
    if (isToday) {
      label = 'Today';
    } else if (day == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEEE, MMMM d').format(day);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: primaryColor, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ── Empty day card ────────────────────────────────────────────────────────────

Widget _EmptyDayCard(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'No sessions yet today',
        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45)),
      ),
    ),
  );
}

// ── Activity card ─────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final _ActivityEntry entry;
  final Color teamPrimaryColor;
  final NumberFormat nf;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.entry,
    required this.teamPrimaryColor,
    required this.nf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCR = entry.type == _ActivityType.challengerRoad;
    final theme = Theme.of(context);

    // Avatar
    Widget avatar = CircleAvatar(
      radius: 20,
      backgroundColor: teamPrimaryColor.withValues(alpha: 0.15),
      backgroundImage: _resolveImage(entry.playerPhotoUrl),
      child: _resolveImage(entry.playerPhotoUrl) == null
          ? Text(
              entry.playerName.isNotEmpty ? entry.playerName[0].toUpperCase() : '?',
              style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: teamPrimaryColor),
            )
          : null,
    );

    // Primary stat
    String statLine;
    IconData statIcon;
    Color statColor;
    if (isCR) {
      final cs = entry.challengeSession!;
      statLine = '${cs.shotsMade} / ${cs.shotsRequired} shots  •  Lvl ${cs.level}';
      statIcon = cs.passed ? Icons.emoji_events_rounded : Icons.sports_hockey_rounded;
      statColor = cs.passed ? Colors.amber : teamPrimaryColor;
    } else {
      final s = entry.session!;
      statLine = '${nf.format(s.total ?? 0)} shots';
      statIcon = Icons.sports_hockey_rounded;
      statColor = teamPrimaryColor;
    }

    final timeStr = DateFormat('h:mm a').format(entry.date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.playerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 17, color: theme.colorScheme.onPrimary),
                            ),
                          ),
                          if (isCR)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: teamPrimaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: teamPrimaryColor.withValues(alpha: 0.3)),
                              ),
                              child: Text('Challenger Road', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 11, color: teamPrimaryColor)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(statIcon, size: 14, color: statColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              statLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 15, color: statColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(timeStr, style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimary.withValues(alpha: 0.5))),
                    const SizedBox(height: 4),
                    Icon(Icons.chevron_right, color: theme.colorScheme.onPrimary.withValues(alpha: 0.3), size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider? _resolveImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('assets/')) return AssetImage(url);
    return null;
  }
}

// ── Session detail bottom sheet ───────────────────────────────────────────────

class _SessionDetailSheet extends StatelessWidget {
  final _ActivityEntry entry;
  final Color teamPrimaryColor;
  final NumberFormat nf;

  const _SessionDetailSheet({
    required this.entry,
    required this.teamPrimaryColor,
    required this.nf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCR = entry.type == _ActivityType.challengerRoad;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Player row
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: teamPrimaryColor.withValues(alpha: 0.15),
                    backgroundImage: _resolveImage(entry.playerPhotoUrl),
                    child: _resolveImage(entry.playerPhotoUrl) == null ? Text(entry.playerName.isNotEmpty ? entry.playerName[0].toUpperCase() : '?', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: teamPrimaryColor)) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.playerName, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: theme.colorScheme.onPrimary)),
                        Text(
                          '${DateFormat('EEEE, MMMM d').format(entry.date)}  •  ${DateFormat('h:mm a').format(entry.date)}',
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onPrimary.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),
                  if (isCR)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: teamPrimaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: teamPrimaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Text('Challenger Road', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, color: teamPrimaryColor)),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              if (isCR) _buildCRDetail(context, entry.challengeSession!) else _buildShootingDetail(context, entry.session!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShootingDetail(BuildContext context, ShootingSession s) {
    final theme = Theme.of(context);
    final rows = <_StatRow>[
      _StatRow('Total Shots', nf.format(s.total ?? 0)),
      if ((s.totalWrist ?? 0) > 0) _StatRow('Wrist', nf.format(s.totalWrist ?? 0)),
      if ((s.totalSnap ?? 0) > 0) _StatRow('Snap', nf.format(s.totalSnap ?? 0)),
      if ((s.totalSlap ?? 0) > 0) _StatRow('Slap', nf.format(s.totalSlap ?? 0)),
      if ((s.totalBackhand ?? 0) > 0) _StatRow('Backhand', nf.format(s.totalBackhand ?? 0)),
      if (s.duration != null && s.duration!.inSeconds > 0) _StatRow('Duration', printDuration(s.duration!, true)),
    ];

    // Targets hit
    final wristHit = s.wristTargetsHit ?? 0;
    final snapHit = s.snapTargetsHit ?? 0;
    final slapHit = s.slapTargetsHit ?? 0;
    final backHit = s.backhandTargetsHit ?? 0;
    final totalHit = wristHit + snapHit + slapHit + backHit;
    if (totalHit > 0) {
      rows.add(_StatRow('Targets Hit', nf.format(totalHit)));
    }

    return _statsCard(context, theme, rows);
  }

  Widget _buildCRDetail(BuildContext context, ChallengeSession cs) {
    final theme = Theme.of(context);
    final passed = cs.passed;
    final passedColor = passed ? Colors.amber : theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pass/fail badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: passedColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: passedColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(passed ? Icons.emoji_events_rounded : Icons.close_rounded, color: passedColor, size: 18),
              const SizedBox(width: 6),
              Text(
                passed ? 'Level Passed!'.toUpperCase() : 'Not Passed'.toUpperCase(),
                style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: passedColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _statsCard(
          context,
          theme,
          [
            _StatRow('Challenge', cs.challengeName),
            _StatRow('Level', cs.level.toString()),
            _StatRow('Shots Made', nf.format(cs.shotsMade)),
            _StatRow('Total Shots', nf.format(cs.totalShots)),
            _StatRow('Required to Pass', nf.format(cs.shotsToPass)),
            _StatRow('Required Total', nf.format(cs.shotsRequired)),
            _StatRow('Duration', printDuration(cs.duration, true)),
          ],
        ),
      ],
    );
  }

  Widget _statsCard(BuildContext context, ThemeData theme, List<_StatRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.value.label, style: TextStyle(fontSize: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.6))),
                    Text(e.value.value, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: teamPrimaryColor)),
                  ],
                ),
              ),
              if (!isLast) Divider(height: 1, color: theme.colorScheme.onPrimary.withValues(alpha: 0.07)),
            ],
          );
        }).toList(),
      ),
    );
  }

  ImageProvider? _resolveImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('assets/')) return AssetImage(url);
    return null;
  }
}

class _StatRow {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatarCrPopover.dart';

/// Side-by-side stat comparison between the current user and a friend.
class CompareStats extends StatefulWidget {
  const CompareStats({super.key, required this.friendUid});

  final String friendUid;

  @override
  State<CompareStats> createState() => _CompareStatsState();
}

class _CompareStatsState extends State<CompareStats> {
  final _numberFmt = NumberFormat('#,###');

  _UserStats? _myStats;
  _UserStats? _friendStats;
  UserProfile? _myProfile;
  UserProfile? _friendProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final myUid = auth.currentUser?.uid;
    if (myUid == null) {
      setState(() => _loading = false);
      return;
    }

    final results = await Future.wait([
      _loadStats(firestore, myUid),
      _loadStats(firestore, widget.friendUid),
      firestore.collection('users').doc(myUid).get(),
      firestore.collection('users').doc(widget.friendUid).get(),
    ]);

    if (mounted) {
      setState(() {
        _myStats = results[0] as _UserStats;
        _friendStats = results[1] as _UserStats;
        final myDoc = results[2] as DocumentSnapshot;
        if (myDoc.exists) _myProfile = UserProfile.fromSnapshot(myDoc);
        final friendDoc = results[3] as DocumentSnapshot;
        if (friendDoc.exists) _friendProfile = UserProfile.fromSnapshot(friendDoc);
        _loading = false;
      });
    }
  }

  Future<_UserStats> _loadStats(FirebaseFirestore firestore, String uid) async {
    int totalShots = 0;
    int wrist = 0, snap = 0, slap = 0, backhand = 0;
    int wristHits = 0, snapHits = 0, slapHits = 0, backhandHits = 0;
    int sessionCount = 0;
    final Set<String> activeDays = {};

    final iters = await firestore.collection('iterations').doc(uid).collection('iterations').get();
    for (final iter in iters.docs) {
      final sessions = await iter.reference.collection('sessions').get();
      for (final sess in sessions.docs) {
        final d = sess.data();
        sessionCount++;
        final total = (d['total'] as int? ?? 0);
        totalShots += total;
        wrist += (d['total_wrist'] as int? ?? 0);
        snap += (d['total_snap'] as int? ?? 0);
        slap += (d['total_slap'] as int? ?? 0);
        backhand += (d['total_backhand'] as int? ?? 0);
        wristHits += (d['wrist_targets_hit'] as int? ?? 0);
        snapHits += (d['snap_targets_hit'] as int? ?? 0);
        slapHits += (d['slap_targets_hit'] as int? ?? 0);
        backhandHits += (d['backhand_targets_hit'] as int? ?? 0);

        final raw = d['date'];
        if (raw is Timestamp) {
          activeDays.add(raw.toDate().toIso8601String().substring(0, 10));
        }
      }
    }

    // Current streak
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final key = today.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
      if (activeDays.contains(key)) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    return _UserStats(
      totalShots: totalShots,
      sessionCount: sessionCount,
      currentStreak: streak,
      activeDays: activeDays.length,
      wrist: wrist,
      snap: snap,
      slap: slap,
      backhand: backhand,
      wristHits: wristHits,
      snapHits: snapHits,
      slapHits: slapHits,
      backhandHits: backhandHits,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<FirebaseAuth>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Compare Stats'.toUpperCase(),
          style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 20),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  // ── Player headers ───────────────────────────────────────
                  Row(
                    children: [
                      _PlayerHeader(
                        profile: _myProfile,
                        name: _myProfile?.displayName ?? auth.currentUser?.displayName ?? 'You',
                      ),
                      const Spacer(),
                      _PlayerHeader(
                        profile: _friendProfile,
                        name: _friendProfile?.displayName ?? 'Friend',
                        alignRight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Stat rows ────────────────────────────────────────────
                  _buildStatRow(context, 'Total Shots', _myStats?.totalShots, _friendStats?.totalShots),
                  _buildStatRow(context, 'Sessions', _myStats?.sessionCount, _friendStats?.sessionCount),
                  _buildStatRow(context, 'Active Days', _myStats?.activeDays, _friendStats?.activeDays),
                  _buildStatRow(context, 'Current Streak', _myStats?.currentStreak, _friendStats?.currentStreak, suffix: ' days'),
                  const SizedBox(height: 16),

                  // ── Accuracy section ─────────────────────────────────────
                  _SectionHeader(label: 'Accuracy'),
                  const SizedBox(height: 8),
                  _buildAccuracyRow(context, 'Wrist', _myStats?.wrist, _myStats?.wristHits, _friendStats?.wrist, _friendStats?.wristHits, Colors.cyan),
                  _buildAccuracyRow(context, 'Snap', _myStats?.snap, _myStats?.snapHits, _friendStats?.snap, _friendStats?.snapHits, Colors.blue),
                  _buildAccuracyRow(context, 'Slap', _myStats?.slap, _myStats?.slapHits, _friendStats?.slap, _friendStats?.slapHits, Colors.teal),
                  _buildAccuracyRow(context, 'Backhand', _myStats?.backhand, _myStats?.backhandHits, _friendStats?.backhand, _friendStats?.backhandHits, Colors.indigo),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, int? myVal, int? friendVal, {String suffix = ''}) {
    final my = myVal ?? 0;
    final fr = friendVal ?? 0;
    final myWins = my > fr;
    final frWins = fr > my;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              _StatValue(value: _numberFmt.format(my) + suffix, highlight: myWins),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              _StatValue(value: _numberFmt.format(fr) + suffix, highlight: frWins, alignRight: true),
            ],
          ),
          const SizedBox(height: 4),
          _CompareBar(myVal: my.toDouble(), friendVal: fr.toDouble()),
        ],
      ),
    );
  }

  Widget _buildAccuracyRow(BuildContext context, String label, int? myShots, int? myHits, int? frShots, int? frHits, Color color) {
    final myPct = (myShots ?? 0) > 0 ? ((myHits ?? 0) / (myShots ?? 1) * 100) : 0.0;
    final frPct = (frShots ?? 0) > 0 ? ((frHits ?? 0) / (frShots ?? 1) * 100) : 0.0;
    final myWins = myPct > frPct;
    final frWins = frPct > myPct;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              _StatValue(value: '${myPct.round()}%', highlight: myWins, color: color),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              _StatValue(value: '${frPct.round()}%', highlight: frWins, alignRight: true, color: color),
            ],
          ),
          const SizedBox(height: 4),
          _CompareBar(myVal: myPct, friendVal: frPct, color: color),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _UserStats {
  final int totalShots;
  final int sessionCount;
  final int currentStreak;
  final int activeDays;
  final int wrist, snap, slap, backhand;
  final int wristHits, snapHits, slapHits, backhandHits;

  const _UserStats({
    required this.totalShots,
    required this.sessionCount,
    required this.currentStreak,
    required this.activeDays,
    required this.wrist,
    required this.snap,
    required this.slap,
    required this.backhand,
    required this.wristHits,
    required this.snapHits,
    required this.slapHits,
    required this.backhandHits,
  });
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.profile, required this.name, this.alignRight = false});

  final UserProfile? profile;
  final String name;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        UserAvatarCrPopover(
          userId: profile?.reference?.id ?? '',
          menuColor: Theme.of(context).colorScheme.primary,
          child: CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: UserAvatar(user: profile, radius: 28),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 110,
          child: Text(
            name,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.value, this.highlight = false, this.alignRight = false, this.color});

  final String value;
  final bool highlight;
  final bool alignRight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Text(
        value,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: highlight ? (color ?? Theme.of(context).primaryColor) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _CompareBar extends StatelessWidget {
  const _CompareBar({required this.myVal, required this.friendVal, this.color});

  final double myVal;
  final double friendVal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final total = myVal + friendVal;
    final myFraction = total > 0 ? myVal / total : 0.5;
    final c = color ?? Theme.of(context).primaryColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Flexible(
              flex: (myFraction * 100).round(),
              child: Container(color: c),
            ),
            Flexible(
              flex: ((1 - myFraction) * 100).round(),
              child: Container(color: c.withValues(alpha: 0.25)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15))),
      ],
    );
  }
}

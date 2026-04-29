import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
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
  bool _statsLoading = false;
  _CompareScope _scope = _CompareScope.allTime;
  _TimeframePreset _timeframePreset = _TimeframePreset.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final effectiveSelectedRange = _rangeForTimeframePreset(_timeframePreset);

    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final myUid = auth.currentUser?.uid;
    if (myUid == null) {
      setState(() => _loading = false);
      return;
    }

    final results = await Future.wait([
      _loadStats(firestore, myUid, scope: _scope, selectedRange: effectiveSelectedRange),
      _loadStats(firestore, widget.friendUid, scope: _scope, selectedRange: effectiveSelectedRange),
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

  Future<void> _reloadStatsOnly() async {
    if (!mounted) return;
    setState(() => _statsLoading = true);
    final effectiveSelectedRange = _rangeForTimeframePreset(_timeframePreset);

    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final myUid = auth.currentUser?.uid;
    if (myUid == null) {
      if (mounted) {
        setState(() => _statsLoading = false);
      }
      return;
    }

    final results = await Future.wait<_UserStats>([
      _loadStats(firestore, myUid, scope: _scope, selectedRange: effectiveSelectedRange),
      _loadStats(firestore, widget.friendUid, scope: _scope, selectedRange: effectiveSelectedRange),
    ]);

    if (mounted) {
      setState(() {
        _myStats = results[0];
        _friendStats = results[1];
        _statsLoading = false;
      });
    }
  }

  Future<_UserStats> _loadStats(
    FirebaseFirestore firestore,
    String uid, {
    required _CompareScope scope,
    required DateTimeRange selectedRange,
  }) async {
    int totalShots = 0;
    int wrist = 0, snap = 0, slap = 0, backhand = 0;
    int wristHits = 0, snapHits = 0, slapHits = 0, backhandHits = 0;
    int sessionCount = 0;
    int totalDurationSeconds = 0;
    final Set<String> activeDays = {};
    final List<_ParsedSession> parsedSessions = [];

    final iters = await firestore.collection('iterations').doc(uid).collection('iterations').get();
    List<QueryDocumentSnapshot<Map<String, dynamic>>> scopedIterations = iters.docs;

    if (scope == _CompareScope.currentIteration) {
      final openIterations = iters.docs.where((doc) => doc.data()['complete'] == false).toList();
      if (openIterations.isNotEmpty) {
        openIterations.sort((a, b) {
          final aTs = a.data()['start_date'] as Timestamp?;
          final bTs = b.data()['start_date'] as Timestamp?;
          final aMs = aTs?.millisecondsSinceEpoch ?? 0;
          final bMs = bTs?.millisecondsSinceEpoch ?? 0;
          return bMs.compareTo(aMs);
        });
        scopedIterations = [openIterations.first];
      } else if (iters.docs.isNotEmpty) {
        final sorted = [...iters.docs]..sort((a, b) {
            final aTs = a.data()['start_date'] as Timestamp?;
            final bTs = b.data()['start_date'] as Timestamp?;
            final aMs = aTs?.millisecondsSinceEpoch ?? 0;
            final bMs = bTs?.millisecondsSinceEpoch ?? 0;
            return bMs.compareTo(aMs);
          });
        scopedIterations = [sorted.first];
      }
    }

    for (final iter in scopedIterations) {
      final iterStartDate = _parseSessionDate(iter.data()['start_date']);
      final iterUpdatedAt = _parseSessionDate(iter.data()['updated_at']);
      final sessions = await iter.reference.collection('sessions').get();
      for (final sess in sessions.docs) {
        final d = sess.data();
        final directSessionDate = _extractSessionDate(d);
        final iterationFallbackDate = iterUpdatedAt ?? iterStartDate;
        final sessionDate = _resolveSessionDate(
          directSessionDate: directSessionDate,
          iterationFallbackDate: iterationFallbackDate,
        );
        parsedSessions.add(_ParsedSession(data: d, date: sessionDate));
      }
    }

    DateTimeRange? appliedTimeframeRange;
    if (scope == _CompareScope.timeframe) {
      appliedTimeframeRange = selectedRange;
    }

    for (final entry in parsedSessions) {
      final sessionDate = entry.date;

      // Only exclude by timeframe when a reliable date exists.
      if (appliedTimeframeRange != null && sessionDate != null && !_isWithinRange(sessionDate, appliedTimeframeRange)) {
        continue;
      }

      sessionCount++;
      final d = entry.data;
      final total = (d['total'] as int? ?? 0);
      totalShots += total;
      totalDurationSeconds += (d['duration'] as int? ?? 0);
      wrist += (d['total_wrist'] as int? ?? 0);
      snap += (d['total_snap'] as int? ?? 0);
      slap += (d['total_slap'] as int? ?? 0);
      backhand += (d['total_backhand'] as int? ?? 0);
      wristHits += (d['wrist_targets_hit'] as int? ?? 0);
      snapHits += (d['snap_targets_hit'] as int? ?? 0);
      slapHits += (d['slap_targets_hit'] as int? ?? 0);
      backhandHits += (d['backhand_targets_hit'] as int? ?? 0);

      if (sessionDate != null) {
        activeDays.add(sessionDate.toIso8601String().substring(0, 10));
      }
    }

    // Best streak within the scoped active days
    int bestStreak = 0;
    if (activeDays.isNotEmpty) {
      final sortedDays = activeDays.toList()..sort();
      int current = 1;
      for (int i = 1; i < sortedDays.length; i++) {
        final prev = DateTime.parse(sortedDays[i - 1]);
        final curr = DateTime.parse(sortedDays[i]);
        if (curr.difference(prev).inDays == 1) {
          current++;
          if (current > bestStreak) bestStreak = current;
        } else {
          if (current > bestStreak) bestStreak = current;
          current = 1;
        }
      }
      if (current > bestStreak) bestStreak = current;
    }

    return _UserStats(
      totalShots: totalShots,
      sessionCount: sessionCount,
      bestStreak: bestStreak,
      activeDays: activeDays.length,
      totalDurationSeconds: totalDurationSeconds,
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

  bool _isWithinRange(DateTime? dt, DateTimeRange range) {
    if (dt == null) return false;
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final startOnly = DateTime(range.start.year, range.start.month, range.start.day);
    final endOnly = DateTime(range.end.year, range.end.month, range.end.day);
    return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly);
  }

  DateTime? _parseSessionDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;

    if (raw is Map) {
      final dynamic secValue = raw['seconds'] ?? raw['_seconds'];
      final dynamic nanoValue = raw['nanoseconds'] ?? raw['_nanoseconds'];
      final dynamic msValue = raw['milliseconds'] ?? raw['millisecondsSinceEpoch'];

      int? sec = _toInt(secValue);
      int? nanos = _toInt(nanoValue);
      int? ms = _toInt(msValue);

      if (ms != null) {
        final normalizedMs = _normalizeEpochToMilliseconds(ms);
        return DateTime.fromMillisecondsSinceEpoch(normalizedMs);
      }

      if (sec != null) {
        final int millisFromSec = _normalizeEpochToMilliseconds(sec);
        final int millisFromNanos = ((nanos ?? 0) / 1000000).round();
        return DateTime.fromMillisecondsSinceEpoch(millisFromSec + millisFromNanos);
      }
    }

    if (raw is int) {
      final ms = _normalizeEpochToMilliseconds(raw);
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }

    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;

      final asInt = int.tryParse(raw);
      if (asInt != null) {
        final ms = _normalizeEpochToMilliseconds(asInt);
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }

    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int _normalizeEpochToMilliseconds(int value) {
    final abs = value.abs();

    // >= 1e18 typically represents nanoseconds.
    if (abs >= 1000000000000000000) {
      return (value / 1000000).round();
    }

    // >= 1e15 typically represents microseconds.
    if (abs >= 1000000000000000) {
      return (value / 1000).round();
    }

    // >= 1e12 is already milliseconds.
    if (abs >= 1000000000000) {
      return value;
    }

    // Otherwise treat as seconds.
    return value * 1000;
  }

  DateTime? _extractSessionDate(Map<String, dynamic> data) {
    final keys = [
      'date',
      'session_date',
      'sessionDate',
      'created_at',
      'createdAt',
      'updated_at',
      'updatedAt',
    ];

    for (final key in keys) {
      final parsed = _parseSessionDate(data[key]);
      if (parsed != null) return parsed;
    }

    return null;
  }

  DateTime? _resolveSessionDate({DateTime? directSessionDate, DateTime? iterationFallbackDate}) {
    if (directSessionDate == null) return iterationFallbackDate;
    if (iterationFallbackDate == null) return directSessionDate;

    final directDay = DateTime(directSessionDate.year, directSessionDate.month, directSessionDate.day);
    final fallbackDay = DateTime(iterationFallbackDate.year, iterationFallbackDate.month, iterationFallbackDate.day);
    final nowDay = _todayStart();

    final ageGap = directDay.difference(fallbackDay).inDays.abs();
    final fallbackIsRecent = nowDay.difference(fallbackDay).inDays <= 120;
    final directLooksStale = nowDay.difference(directDay).inDays > 365;

    // If direct session dates are far older than a recent iteration signal,
    // prefer iteration recency for timeframe filtering.
    if (ageGap > 365 && fallbackIsRecent && directLooksStale) {
      return iterationFallbackDate;
    }

    return directSessionDate;
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _todayEnd() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  DateTimeRange _rangeForTimeframePreset(_TimeframePreset preset) {
    final end = _todayEnd();
    final start = _todayStart().subtract(Duration(days: preset.days - 1));
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _setTimeframePreset(_TimeframePreset preset) async {
    if (_timeframePreset == preset) return;
    setState(() => _timeframePreset = preset);
    await _reloadStatsOnly();
  }

  bool get _myHasAccuracyData {
    final s = _myStats;
    if (s == null) return false;
    return (s.wrist + s.snap + s.slap + s.backhand) > 0;
  }

  bool get _friendHasAccuracyData {
    final s = _friendStats;
    if (s == null) return false;
    return (s.wrist + s.snap + s.slap + s.backhand) > 0;
  }

  Future<void> _setScope(_CompareScope nextScope) async {
    if (_scope == nextScope) return;
    setState(() => _scope = nextScope);
    await _reloadStatsOnly();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final bool canCompareAccuracy = (_myProfile?.isPro == true) && (_friendProfile?.isPro == true);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    collapsedHeight: 65,
                    expandedHeight: 108,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    floating: true,
                    pinned: true,
                    leading: Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 28,
                        ),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    flexibleSpace: DecoratedBox(
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
                      child: FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        titlePadding: null,
                        centerTitle: false,
                        title: const BasicTitle(title: 'Compare Stats'),
                        background: Container(color: Theme.of(context).scaffoldBackgroundColor),
                      ),
                    ),
                  ),
                ];
              },
              body: SingleChildScrollView(
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

                    _buildScopeControls(context),
                    const SizedBox(height: 16),

                    Stack(
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: _statsLoading ? 0.45 : 1,
                          child: Column(
                            children: [
                              if ((_myStats?.sessionCount ?? 0) == 0 && (_friendStats?.sessionCount ?? 0) == 0)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _scope == _CompareScope.currentIteration
                                        ? 'No sessions available in current challenge for either player yet.'
                                        : _scope == _CompareScope.timeframe
                                            ? 'No sessions found in the selected timeframe.'
                                            : 'No sessions found yet for either player.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),

                              // ── Stat rows ────────────────────────────────────────────
                              _buildStatRow(context, 'Total Shots', _myStats?.totalShots, _friendStats?.totalShots),
                              _buildStatRow(context, 'Sessions', _myStats?.sessionCount, _friendStats?.sessionCount),
                              _buildStatRow(context, 'Active Days', _myStats?.activeDays, _friendStats?.activeDays),
                              _buildStatRow(context, 'Best Streak', _myStats?.bestStreak, _friendStats?.bestStreak, suffix: ' days'),
                              _buildDurationRow(context, 'Shooting Time', _myStats?.totalDurationSeconds, _friendStats?.totalDurationSeconds),
                              const SizedBox(height: 16),

                              // ── Accuracy section ─────────────────────────────────────
                              _SectionHeader(label: 'Accuracy'),
                              const SizedBox(height: 8),
                              if (canCompareAccuracy) ...[
                                Builder(builder: (context) {
                                  final myMissing = (_myStats?.sessionCount ?? 0) > 0 && !_myHasAccuracyData;
                                  final frMissing = (_friendStats?.sessionCount ?? 0) > 0 && !_friendHasAccuracyData;
                                  if (!myMissing && !frMissing) return const SizedBox.shrink();
                                  final names = [
                                    if (myMissing) (_myProfile?.displayName ?? 'You'),
                                    if (frMissing) (_friendProfile?.displayName ?? 'Friend'),
                                  ];
                                  final subject = names.join(' and ');
                                  final verb = names.length == 1 ? 'has' : 'have';
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                                    ),
                                    child: Text(
                                      '$subject $verb sessions without accuracy tracking in this scope - those shot types are shown as -.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  );
                                }),
                                _buildAccuracyRow(context, 'Wrist', _myStats?.wrist, _myStats?.wristHits, _friendStats?.wrist, _friendStats?.wristHits, Colors.cyan),
                                _buildAccuracyRow(context, 'Snap', _myStats?.snap, _myStats?.snapHits, _friendStats?.snap, _friendStats?.snapHits, Colors.blue),
                                _buildAccuracyRow(context, 'Slap', _myStats?.slap, _myStats?.slapHits, _friendStats?.slap, _friendStats?.slapHits, Colors.teal),
                                _buildAccuracyRow(context, 'Backhand', _myStats?.backhand, _myStats?.backhandHits, _friendStats?.backhand, _friendStats?.backhandHits, Colors.indigo),
                              ] else
                                Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Both users require pro access to compare accuracy stats.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildLockedAccuracyPreview(context),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (_statsLoading)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScopeControls(BuildContext context) {
    final selectedColor = Theme.of(context).primaryColor;
    final unselectedColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compare Scope'.toUpperCase(),
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('All Time'.toUpperCase()),
                selected: _scope == _CompareScope.allTime,
                onSelected: (_) => _setScope(_CompareScope.allTime),
                labelStyle: TextStyle(
                  fontFamily: 'NovecentoSans',
                  color: _scope == _CompareScope.allTime ? Colors.white : unselectedColor,
                ),
                selectedColor: selectedColor,
              ),
              ChoiceChip(
                label: Text('Current Challenge'.toUpperCase()),
                selected: _scope == _CompareScope.currentIteration,
                onSelected: (_) => _setScope(_CompareScope.currentIteration),
                labelStyle: TextStyle(
                  fontFamily: 'NovecentoSans',
                  color: _scope == _CompareScope.currentIteration ? Colors.white : unselectedColor,
                ),
                selectedColor: selectedColor,
              ),
              ChoiceChip(
                label: Text('Timeframe'.toUpperCase()),
                selected: _scope == _CompareScope.timeframe,
                onSelected: (_) => _setScope(_CompareScope.timeframe),
                labelStyle: TextStyle(
                  fontFamily: 'NovecentoSans',
                  color: _scope == _CompareScope.timeframe ? Colors.white : unselectedColor,
                ),
                selectedColor: selectedColor,
              ),
            ],
          ),
          if (_scope == _CompareScope.timeframe) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _timeframePreset.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                PopupMenuButton<_TimeframePreset>(
                  onSelected: _setTimeframePreset,
                  color: Theme.of(context).colorScheme.surface,
                  itemBuilder: (context) => _TimeframePreset.values
                      .map(
                        (preset) => PopupMenuItem<_TimeframePreset>(
                          value: preset,
                          child: Text(
                            preset.label,
                            style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  child: TextButton.icon(
                    onPressed: null,
                    icon: Icon(
                      Icons.tune_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    label: Text(
                      'Change'.toUpperCase(),
                      style: const TextStyle(fontFamily: 'NovecentoSans'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLockedAccuracyPreview(BuildContext context) {
    final preview = Column(
      children: [
        _buildAccuracyRow(context, 'Wrist', 100, 73, 100, 78, Colors.cyan),
        _buildAccuracyRow(context, 'Snap', 100, 69, 100, 75, Colors.blue),
        _buildAccuracyRow(context, 'Slap', 100, 65, 100, 70, Colors.teal),
        _buildAccuracyRow(context, 'Backhand', 100, 58, 100, 64, Colors.indigo),
      ],
    );

    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
              child: Opacity(
                opacity: 0.75,
                child: preview,
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.08),
              ),
            ),
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

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Widget _buildDurationRow(BuildContext context, String label, int? mySeconds, int? frSeconds) {
    final my = mySeconds ?? 0;
    final fr = frSeconds ?? 0;
    final myWins = my > fr;
    final frWins = fr > my;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              _StatValue(value: _formatDuration(my), highlight: myWins),
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
              _StatValue(value: _formatDuration(fr), highlight: frWins, alignRight: true),
            ],
          ),
          const SizedBox(height: 4),
          _CompareBar(myVal: my.toDouble(), friendVal: fr.toDouble()),
        ],
      ),
    );
  }

  Widget _buildAccuracyRow(BuildContext context, String label, int? myShots, int? myHits, int? frShots, int? frHits, Color color) {
    final double? myPct = (myShots ?? 0) > 0 ? ((myHits ?? 0) / (myShots ?? 1) * 100) : null;
    final double? frPct = (frShots ?? 0) > 0 ? ((frHits ?? 0) / (frShots ?? 1) * 100) : null;
    final myWins = myPct != null && frPct != null && myPct > frPct;
    final frWins = myPct != null && frPct != null && frPct > myPct;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              _StatValue(value: myPct != null ? '${myPct.round()}%' : '-', highlight: myWins, color: color),
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
              _StatValue(value: frPct != null ? '${frPct.round()}%' : '-', highlight: frWins, alignRight: true, color: color),
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
  final int bestStreak;
  final int activeDays;
  final int totalDurationSeconds;
  final int wrist, snap, slap, backhand;
  final int wristHits, snapHits, slapHits, backhandHits;

  const _UserStats({
    required this.totalShots,
    required this.sessionCount,
    required this.bestStreak,
    required this.activeDays,
    required this.totalDurationSeconds,
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

class _ParsedSession {
  const _ParsedSession({required this.data, required this.date});

  final Map<String, dynamic> data;
  final DateTime? date;
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.profile, required this.name, this.alignRight = false});

  final UserProfile? profile;
  final String name;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final bool isProForDisplay = profile?.isPro == true;
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        UserAvatarCrPopover(
          userId: profile?.reference?.id ?? '',
          menuColor: Theme.of(context).colorScheme.primary,
          showAccomplishment: isProForDisplay,
          showProFallback: isProForDisplay,
          onViewProfile: (profile?.reference?.id ?? '').isNotEmpty ? () => context.push(AppRoutePaths.playerPathFor(profile!.reference!.id)) : null,
          viewProfileActionLabel: 'View Profile',
          onViewCrProgress: (profile?.reference?.id ?? '').isNotEmpty ? () => context.push(AppRoutePaths.playerChallengerRoadPathFor(profile!.reference!.id)) : null,
          onUnlockChallengerRoad: () => context.push(AppRoutePaths.challengerRoad),
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

  final double? myVal;
  final double? friendVal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).primaryColor;
    // When either side has no data, show a neutral grey bar instead of a
    // misleading skewed result.
    if (myVal == null || friendVal == null) {
      final greyColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 6,
          child: Row(
            children: [
              Flexible(flex: 50, child: Container(color: myVal != null ? c : greyColor)),
              Flexible(flex: 50, child: Container(color: friendVal != null ? c.withValues(alpha: 0.25) : greyColor)),
            ],
          ),
        ),
      );
    }
    final total = myVal! + friendVal!;
    final myFraction = total > 0 ? myVal! / total : 0.5;

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

enum _CompareScope {
  allTime,
  timeframe,
  currentIteration,
}

enum _TimeframePreset {
  week,
  twoWeeks,
  month,
  threeMonths,
  sixMonths,
  year,
}

extension _TimeframePresetX on _TimeframePreset {
  int get days {
    switch (this) {
      case _TimeframePreset.week:
        return 7;
      case _TimeframePreset.twoWeeks:
        return 14;
      case _TimeframePreset.month:
        return 30;
      case _TimeframePreset.threeMonths:
        return 90;
      case _TimeframePreset.sixMonths:
        return 180;
      case _TimeframePreset.year:
        return 365;
    }
  }

  String get label {
    switch (this) {
      case _TimeframePreset.week:
        return 'Past Week';
      case _TimeframePreset.twoWeeks:
        return 'Past 2 Weeks';
      case _TimeframePreset.month:
        return 'Past Month';
      case _TimeframePreset.threeMonths:
        return 'Past 3 Months';
      case _TimeframePreset.sixMonths:
        return 'Past 6 Months';
      case _TimeframePreset.year:
        return 'Past Year';
    }
  }
}

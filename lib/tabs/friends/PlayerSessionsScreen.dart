import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';

/// Full-screen sessions list for another player's profile.
class PlayerSessionsScreen extends StatefulWidget {
  final String userId;
  final String playerName;
  final String? initialIterationId;

  const PlayerSessionsScreen({
    super.key,
    required this.userId,
    required this.playerName,
    this.initialIterationId,
  });

  @override
  State<PlayerSessionsScreen> createState() => _PlayerSessionsScreenState();
}

class _PlayerSessionsScreenState extends State<PlayerSessionsScreen> {
  String? _selectedIterationId;
  List<DropdownMenuItem<String>> _attemptDropdownItems = [];

  @override
  void initState() {
    super.initState();
    _selectedIterationId = widget.initialIterationId;
    _getAttempts();
  }

  Future<void> _getAttempts() async {
    final snapshot = await FirebaseFirestore.instance.collection('iterations').doc(widget.userId).collection('iterations').orderBy('start_date', descending: false).get();

    final items = <DropdownMenuItem<String>>[];
    snapshot.docs.asMap().forEach((i, doc) {
      items.add(DropdownMenuItem<String>(
        value: doc.reference.id,
        child: Text(
          'challenge ${i + 1}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontFamily: 'NovecentoSans',
          ),
        ),
      ));
    });

    if (mounted) {
      setState(() {
        if (_selectedIterationId == null && items.isNotEmpty) {
          _selectedIterationId = items.last.value;
        }
        _attemptDropdownItems = items;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            collapsedHeight: 65,
            expandedHeight: 85,
            backgroundColor: theme.colorScheme.primary,
            floating: true,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.only(top: 10),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: theme.colorScheme.onPrimary, size: 28),
                onPressed: () => context.pop(),
              ),
            ),
            actions: const [],
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
              child: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                centerTitle: true,
                title: Text(
                  "Sessions".toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 20,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                background: Container(color: theme.colorScheme.primaryContainer),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            if (_attemptDropdownItems.length > 1)
              Container(
                color: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DropdownButton<String>(
                      onChanged: (value) => setState(() => _selectedIterationId = value),
                      underline: const SizedBox.shrink(),
                      dropdownColor: theme.colorScheme.primary,
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        color: theme.colorScheme.onPrimary,
                      ),
                      value: _selectedIterationId,
                      items: _attemptDropdownItems,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _selectedIterationId == null ? null : FirebaseFirestore.instance.collection('iterations').doc(widget.userId).collection('iterations').doc(_selectedIterationId).collection('sessions').orderBy('date', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final sessions = snapshot.data!.docs;
                  if (sessions.isEmpty) {
                    return Center(
                      child: Text(
                        "${widget.playerName} doesn't have any sessions yet".toLowerCase(),
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          color: theme.colorScheme.onPrimary,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (_, int index) {
                      final s = ShootingSession.fromSnapshot(sessions[index]);
                      if (s.total == null || s.total! <= 0) return const SizedBox.shrink();
                      return _buildSessionItem(context, s, index % 2 == 0);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, ShootingSession s, bool showBackground) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 5, bottom: 15),
      decoration: BoxDecoration(
        color: showBackground ? theme.cardTheme.color : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(printDate(s.date!), style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 18, fontFamily: 'NovecentoSans')),
                Text(
                  s.duration == Duration.zero ? '0s' : printDuration(s.duration!, true),
                  style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 18, fontFamily: 'NovecentoSans'),
                ),
                Text('${s.total} shots', style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 18, fontFamily: 'NovecentoSans')),
              ],
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width - 30,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                _shotBar(context, s, s.totalWrist ?? 0, wristShotColor, s.total ?? 0),
                _shotBar(context, s, s.totalSnap ?? 0, snapShotColor, s.total ?? 0),
                _shotBar(context, s, s.totalBackhand ?? 0, backhandShotColor, s.total ?? 0),
                _shotBar(context, s, s.totalSlap ?? 0, slapShotColor, s.total ?? 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shotBar(BuildContext context, ShootingSession s, int count, Color color, int total) {
    if (count < 1 || total <= 0) return const SizedBox.shrink();
    final width = (MediaQuery.of(context).size.width - 30) * (count / total);
    return Container(
      width: width,
      height: 30,
      color: color,
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}

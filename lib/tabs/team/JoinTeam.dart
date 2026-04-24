import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/widgets/MobileScanner/barcode_scanner_simple.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamIdentityPicker.dart';

class JoinTeam extends StatefulWidget {
  const JoinTeam({super.key});

  @override
  State<JoinTeam> createState() => _JoinTeamState();
}

class _JoinTeamState extends State<JoinTeam> {
  User? get user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;

  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _teams = [];
  bool _isSearching = false;

  Future<void> _runSearch(String value) async {
    if (value.isEmpty) {
      setState(() {
        _teams = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    List<DocumentSnapshot> teams = [];
    await FirebaseFirestore.instance.collection('teams').orderBy('name_lowercase', descending: false).where('public', isEqualTo: true).startAt([value.toLowerCase()]).endAt(['${value.toLowerCase()}\uf8ff']).get().then((snap) {
          for (var doc in snap.docs) {
            if (doc.id != user?.uid) teams.add(doc);
          }
        });
    if (teams.isEmpty) {
      await FirebaseFirestore.instance.collection('teams').where('code', isEqualTo: value.toUpperCase()).get().then((snap) => teams.addAll(snap.docs));
    }
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      setState(() {
        _teams = teams;
        _isSearching = false;
      });
    }
  }

  Future<void> _joinTeam(BuildContext ctx, String teamId, String teamName) async {
    final success = await joinTeam(
      teamId,
      Provider.of<FirebaseAuth>(ctx, listen: false),
      Provider.of<FirebaseFirestore>(ctx, listen: false),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      backgroundColor: Theme.of(ctx).cardTheme.color,
      content: Text(
        success ? 'Joined team $teamName!' : 'Failed to join $teamName :(',
        style: TextStyle(color: Theme.of(ctx).colorScheme.onPrimary),
      ),
      duration: const Duration(seconds: 4),
    ));
    if (success) {
      setState(() {
        _teams = [];
      });
      _searchController.clear();
      goToAppSection(ctx, AppSection.community, communitySection: CommunitySection.team);
    }
  }

  Future<void> _scanQR(BuildContext ctx) async {
    final result = await Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => const BarcodeScannerSimple(title: 'Scan Team QR Code')),
    );
    if (result == null || !mounted) return;
    // Look up team by ID to show the preview instead of blindly joining
    try {
      final doc = await FirebaseFirestore.instance.collection('teams').doc(result.toString()).get();
      if (!mounted) return;
      if (doc.exists) {
        _openTeamPreview(ctx, doc);
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          backgroundColor: Theme.of(ctx).cardTheme.color,
          content: Text('Team not found.', style: TextStyle(color: Theme.of(ctx).colorScheme.onPrimary)),
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        backgroundColor: Theme.of(ctx).cardTheme.color,
        content: Text("There was an error scanning that QR code :(", style: TextStyle(color: Theme.of(ctx).colorScheme.onPrimary)),
      ));
    }
  }

  void _openTeamPreview(BuildContext ctx, DocumentSnapshot teamDoc) {
    FocusScope.of(ctx).unfocus();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeamPreviewSheet(
        teamDoc: teamDoc,
        currentUserId: user!.uid,
        onJoin: (teamId, teamName) => _joinTeam(ctx, teamId, teamName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      return StreamProvider<NetworkStatus>(
        create: (_) => NetworkStatusService().networkStatusController.stream,
        initialData: NetworkStatus.Online,
        child: NetworkAwareWidget(
          offlineChild: Scaffold(
            body: Container(
              color: Theme.of(context).primaryColor,
              margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Image(image: AssetImage('assets/images/logo.png')),
                  Text("Where's the wifi bud?".toUpperCase(), style: const TextStyle(color: Colors.white70, fontFamily: 'NovecentoSans', fontSize: 24)),
                  const SizedBox(height: 25),
                  const CircularProgressIndicator(color: Colors.white70),
                ],
              ),
            ),
          ),
          onlineChild: Scaffold(
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
                      onPressed: () => context.pop(),
                    ),
                  ),
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      titlePadding: null,
                      centerTitle: false,
                      title: const BasicTitle(title: 'Join Team'),
                      background: Container(color: Theme.of(context).scaffoldBackgroundColor),
                    ),
                  ),
                ),
              ],
              body: GestureDetector(
                onTap: () {
                  Feedback.forTap(context);
                  FocusScope.of(context).unfocus();
                },
                behavior: HitTestBehavior.translucent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // ── Search bar ────────────────────────────────────────
                    Card(
                      elevation: 0,
                      color: Theme.of(context).cardTheme.color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: TextField(
                                controller: _searchController,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.search,
                                cursorColor: Theme.of(context).colorScheme.onSurface,
                                style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Team name or code…',
                                  hintStyle: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.35)),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45)),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear_rounded, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45), size: 20),
                                          onPressed: () {
                                            _searchController.clear();
                                            _runSearch('');
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: _runSearch,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            child: Tooltip(
                              message: 'Scan QR Code',
                              child: IconButton(
                                icon: Icon(Icons.qr_code_scanner_rounded, color: Theme.of(context).primaryColor, size: 26),
                                onPressed: () => _scanQR(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Results / states ───────────────────────────────────
                    if (_isSearching)
                      Center(
                          child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                      ))
                    else if (_searchController.text.isNotEmpty && _teams.isEmpty)
                      _buildEmptyState(context)
                    else if (_searchController.text.isEmpty)
                      _buildIdleState(context)
                    else
                      ..._teams.map((doc) => _buildTeamCard(context, doc)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildIdleState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Icon(Icons.group_add_rounded, size: 56, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text(
            'Find your team',
            style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 6),
          Text(
            'Search by name or enter your team code above.\nOr scan a teammate\'s QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 32),
          const _OrDivider(),
          const SizedBox(height: 24),
          _buildCreateCard(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('No teams found', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: Theme.of(context).colorScheme.onPrimary)),
          const SizedBox(height: 6),
          Text(
            'Try a different name or code.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 32),
          const _OrDivider(),
          const SizedBox(height: 24),
          _buildCreateCard(context),
        ],
      ),
    );
  }

  Widget _buildCreateCard(BuildContext context) {
    return Card(
      elevation: 2,
      color: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(AppRoutePaths.createTeam),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create a Team'.toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Theme.of(context).colorScheme.onPrimary)),
                    const SizedBox(height: 2),
                    Text('Set a goal and invite players', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.55))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, DocumentSnapshot doc) {
    final team = Team.fromSnapshot(doc);
    final playerCount = team.players?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 1,
        color: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Feedback.forTap(context);
            _openTeamPreview(context, doc);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                buildTeamLogoWidget(
                  context: context,
                  logoAsset: team.logoAsset,
                  primaryColorHex: team.primaryColor,
                  size: 44,
                  iconSize: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (team.name != null)
                        Text(
                          team.name!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontFamily: 'NovecentoSans', fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      Text(
                        '$playerCount ${playerCount == 1 ? "player" : "players"}',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 15, color: Theme.of(context).primaryColor)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.35), size: 22),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared divider ─────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('OR', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.4), letterSpacing: 1)),
      ),
      const Expanded(child: Divider()),
    ]);
  }
}

// ─── Team preview bottom sheet ───────────────────────────────────────────────

class _TeamPreviewSheet extends StatefulWidget {
  final DocumentSnapshot teamDoc;
  final String currentUserId;
  final Future<void> Function(String teamId, String teamName) onJoin;

  const _TeamPreviewSheet({required this.teamDoc, required this.currentUserId, required this.onJoin});

  @override
  State<_TeamPreviewSheet> createState() => _TeamPreviewSheetState();
}

class _TeamPreviewSheetState extends State<_TeamPreviewSheet> {
  bool _joining = false;
  bool _showShotsPerDay = true;
  final NumberFormat _nf = NumberFormat('###,###,###', 'en_US');
  Future<List<_PlayerPreview>>? _playersFuture;

  @override
  void initState() {
    super.initState();
    final team = Team.fromSnapshot(widget.teamDoc);
    _playersFuture = _loadPlayers(team);
  }

  Future<List<_PlayerPreview>> _loadPlayers(Team team) async {
    if (team.players == null || team.players!.isEmpty) return [];
    final previews = <_PlayerPreview>[];
    await Future.wait(team.players!.map((uid) async {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        UserProfile? profile;
        if (userDoc.exists) profile = UserProfile.fromSnapshot(userDoc);

        int totalShots = 0;
        final itersSnap = await FirebaseFirestore.instance.collection('iterations').doc(uid).collection('iterations').get();
        for (final iDoc in itersSnap.docs) {
          final data = iDoc.data();
          totalShots += (data['total'] as int? ?? 0);
        }
        previews.add(_PlayerPreview(uid: uid, profile: profile, totalShots: totalShots));
      } catch (_) {
        previews.add(_PlayerPreview(uid: uid, profile: null, totalShots: 0));
      }
    }));
    previews.sort((a, b) => b.totalShots.compareTo(a.totalShots));
    return previews;
  }

  Map<String, String> _calcShotTexts(int teamTotalShots, Team team) {
    final int goalTotal = team.goalTotal ?? 0;
    final DateTime targetDate = team.targetDate ?? DateTime.now().add(const Duration(days: 100));
    final int numPlayers = (team.players?.isNotEmpty ?? false) ? team.players!.length : 1;

    int shotsRemaining = goalTotal - teamTotalShots;
    final now = DateTime.now();
    final normalizedTarget = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final normalizedToday = DateTime(now.year, now.month, now.day);
    final int daysRemaining = normalizedTarget.difference(normalizedToday).inDays;
    final double weeksRemaining = daysRemaining / 7;

    int shotsPerDay = daysRemaining <= 0 ? (shotsRemaining > 0 ? shotsRemaining : 0) : (shotsRemaining <= 0 ? 0 : (shotsRemaining / daysRemaining).ceil());
    int shotsPerWeek = weeksRemaining <= 0 ? (shotsRemaining > 0 ? shotsRemaining : 0) : (shotsRemaining <= 0 ? 0 : (shotsRemaining / weeksRemaining).ceil().toInt());
    final int perPlayerDay = (shotsPerDay / numPlayers).round();
    final int perPlayerWeek = (shotsPerWeek / numPlayers).round();

    String perDayText, perWeekText;
    if (normalizedTarget.isBefore(normalizedToday)) {
      final int daysPast = normalizedToday.difference(normalizedTarget).inDays;
      perDayText = "${daysPast.abs()} days past goal";
      perWeekText = shotsRemaining <= 0 ? "goal met!" : "${_nf.format(shotsRemaining)} remaining";
    } else {
      perDayText = shotsRemaining < 1 ? "done!" : (perPlayerDay <= 999 ? "$perPlayerDay / day / player" : "${_nf.format(perPlayerDay)} / day / player");
      perWeekText = shotsRemaining < 1 ? "done!" : (perPlayerWeek <= 999 ? "$perPlayerWeek / week / player" : "${_nf.format(perPlayerWeek)} / week / player");
    }
    return {'perDayText': perDayText.toLowerCase(), 'perWeekText': perWeekText.toLowerCase()};
  }

  Widget _buildPlayerItem(_PlayerPreview p, int index, {String? teamPrimaryColorHex}) {
    final String name = p.profile?.displayName ?? 'Player';
    String? photoUrl = p.profile?.photoUrl;
    if (photoUrl != null && photoUrl.startsWith('file:///')) {
      photoUrl = photoUrl.substring('file:///'.length);
      if (photoUrl.startsWith('/')) photoUrl = photoUrl.substring(1);
    }
    final bool isYou = p.uid == widget.currentUserId;
    final bool bg = index % 2 == 0;
    final int place = index + 1;

    Color badgeColor;
    Color badgeTextColor = Colors.white;
    if (place == 1) {
      badgeColor = const Color(0xFFFFD700);
      badgeTextColor = Colors.black;
    } else if (place == 2) {
      badgeColor = const Color(0xFFC0C0C0);
      badgeTextColor = Colors.black87;
    } else if (place == 3) {
      badgeColor = const Color(0xFFCD7F32);
    } else {
      badgeColor = isYou ? colorFromHex(teamPrimaryColorHex).withOpacity(0.8) : Theme.of(context).colorScheme.onSurface.withOpacity(0.3);
    }

    const double avatarRadius = 32;
    ImageProvider? avatarImage;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('http')) {
        avatarImage = NetworkImage(photoUrl);
      } else if (photoUrl.startsWith('assets/')) {
        avatarImage = AssetImage(photoUrl);
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: bg ? Theme.of(context).cardTheme.color : Colors.transparent,
      leading: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: avatarRadius * 2,
            height: avatarRadius * 2,
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              backgroundImage: avatarImage,
              child: avatarImage == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 28, color: colorFromHex(teamPrimaryColorHex))) : null,
            ),
          ),
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Text('$place', style: TextStyle(fontFamily: 'NovecentoSans', fontWeight: FontWeight.bold, fontSize: 14, color: badgeTextColor)),
            ),
          ),
        ],
      ),
      title: Text(
        name,
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 20,
          color: isYou ? colorFromHex(teamPrimaryColorHex) : Theme.of(context).colorScheme.onSurface,
          fontWeight: isYou ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: SizedBox(
        height: 60,
        child: Stack(
          children: [
            Text(
              _nf.format(p.totalShots),
              style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            Positioned(
              top: 30,
              right: 0,
              child: Text(
                'shots',
                style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85), fontWeight: FontWeight.w400, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = Team.fromSnapshot(widget.teamDoc);
    final teamId = widget.teamDoc.id;
    final teamName = team.name ?? 'Team';
    final int goalTotal = team.goalTotal ?? 0;
    final int playerCount = team.players?.length ?? 0;
    final DateTime targetDate = team.targetDate ?? DateTime.now().add(const Duration(days: 100));

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Team name header ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    buildTeamLogoWidget(
                      context: context,
                      logoAsset: team.logoAsset,
                      primaryColorHex: team.primaryColor,
                      size: 50,
                      iconSize: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoSizeText(
                            teamName,
                            maxLines: 1,
                            style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 24, color: Theme.of(context).colorScheme.onPrimary),
                          ),
                          Text(
                            '$playerCount ${playerCount == 1 ? "player" : "players"}',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.08)),

              // ── Scrollable body ──────────────────────────────────────
              Expanded(
                child: FutureBuilder<List<_PlayerPreview>>(
                  future: _playersFuture,
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
                    }
                    final players = snap.data ?? [];
                    final int teamTotal = players.fold(0, (sum, p) => sum + p.totalShots);
                    final double totalShotsPercentage = goalTotal > 0 ? (teamTotal / goalTotal.toDouble()).clamp(0.0, 1.0) : 0.0;
                    final double totalShotsWidth = totalShotsPercentage * (MediaQuery.of(context).size.width - 60);
                    final shotTexts = _calcShotTexts(teamTotal, team);

                    return ListView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.zero,
                      children: [
                        // ── Goal row (matches Team.dart) ─────────────────
                        Container(
                          padding: const EdgeInsets.only(top: 5, bottom: 0),
                          margin: const EdgeInsets.only(bottom: 10, top: 15),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text("Goal".toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 26, fontFamily: 'NovecentoSans')),
                              SizedBox(
                                width: 150,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "${_nf.format(goalTotal)} shots by:".toLowerCase(),
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: 'NovecentoSans', fontSize: 14),
                                    ),
                                    Text(
                                      DateFormat('MMMM d, y').format(targetDate),
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 110,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _showShotsPerDay = !_showShotsPerDay),
                                      child: AutoSizeText(
                                        _showShotsPerDay ? shotTexts['perDayText']! : shotTexts['perWeekText']!,
                                        maxFontSize: 20,
                                        maxLines: 1,
                                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'NovecentoSans', fontSize: 20),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => setState(() => _showShotsPerDay = !_showShotsPerDay),
                                    borderRadius: BorderRadius.circular(30),
                                    child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.swap_vert, size: 18)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Progress label ───────────────────────────────
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text("Progress".toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 22, fontFamily: 'NovecentoSans')),
                        ]),
                        const SizedBox(height: 5),

                        // ── Progress bar (matches Team.dart) ─────────────
                        Column(children: [
                          Container(
                            width: MediaQuery.of(context).size.width,
                            margin: const EdgeInsets.symmetric(horizontal: 30),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Theme.of(context).cardTheme.color),
                            clipBehavior: Clip.antiAlias,
                            child: Row(children: [
                              Tooltip(
                                message: "${_nf.format(teamTotal)} shots".toLowerCase(),
                                textStyle: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                                child: Container(height: 40, width: teamTotal > 0 ? totalShotsWidth : 0, decoration: BoxDecoration(color: colorFromHex(team.primaryColor))),
                              ),
                            ]),
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width - 30,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
                            clipBehavior: Clip.antiAlias,
                            child: Row(children: [
                              Container(
                                height: 40,
                                width: totalShotsWidth < 35
                                    ? 50
                                    : totalShotsWidth > (MediaQuery.of(context).size.width - 110)
                                        ? totalShotsWidth - 175
                                        : totalShotsWidth,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: AutoSizeText(_nf.format(teamTotal), textAlign: TextAlign.right, maxFontSize: 18, maxLines: 1, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Theme.of(context).colorScheme.onPrimary)),
                              ),
                              Text(" / ${_nf.format(goalTotal)}", textAlign: TextAlign.right, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Theme.of(context).colorScheme.onPrimary)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 5),

                        // ── Player list ──────────────────────────────────
                        if (players.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Center(child: Text('No players yet', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45), fontSize: 15))),
                          )
                        else
                          ...players.asMap().entries.map((e) => _buildPlayerItem(e.value, e.key, teamPrimaryColorHex: team.primaryColor)),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),

              // ── Join button ──────────────────────────────────────────
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _joining
                          ? null
                          : () async {
                              setState(() => _joining = true);
                              await widget.onJoin(teamId, teamName);
                              if (mounted) Navigator.of(context).pop();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorFromHex(team.primaryColor),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: colorFromHex(team.primaryColor).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _joining
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              'Join $teamName'.toUpperCase(),
                              style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Colors.white, letterSpacing: 0.5),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerPreview {
  final String uid;
  final UserProfile? profile;
  final int totalShots;
  const _PlayerPreview({required this.uid, required this.profile, required this.totalShots});
}

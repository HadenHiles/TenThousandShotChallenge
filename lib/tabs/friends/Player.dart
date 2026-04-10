import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/widgets/CrAvatarBadge.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/widgets/AchievementStatsRow.dart';
import 'package:tenthousandshotchallenge/widgets/UserAchievementsReadOnly.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';

class Player extends StatefulWidget {
  const Player({super.key, this.uid});

  final String? uid;

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  final user = FirebaseAuth.instance.currentUser;

  UserProfile? _userPlayer;
  bool _loadingPlayer = false;
  ScrollController? sessionsController;
  bool? _isFriend = false;
  List<DropdownMenuItem<dynamic>>? _attemptDropdownItems = [];
  String? _selectedIterationId;
  bool _showAchievements = false;

  @override
  void initState() {
    super.initState();

    setState(() {
      _loadingPlayer = true;
    });

    FirebaseFirestore.instance.collection('users').doc(widget.uid).get().then((uDoc) {
      _userPlayer = UserProfile.fromSnapshot(uDoc);

      setState(() {
        _loadingPlayer = false;
      });
    });

    sessionsController = ScrollController();

    _loadIsFriend();
    _getAttempts();
  }

  Future<void> _loadIsFriend() async {
    await FirebaseFirestore.instance.collection('teammates').doc(user!.uid).collection('teammates').doc(widget.uid).get().then((snapshot) {
      setState(() {
        _isFriend = snapshot.exists;
      });
    });
  }

  Future<void> _getAttempts() async {
    await FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').orderBy('start_date', descending: false).get().then((snapshot) {
      List<DropdownMenuItem> iterations = [];
      snapshot.docs.asMap().forEach((i, iDoc) {
        iterations.add(DropdownMenuItem<String>(
          value: iDoc.reference.id,
          child: Text(
            "challenge ".toLowerCase() + (i + 1).toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 26,
              fontFamily: 'NovecentoSans',
            ),
          ),
        ));
      });

      setState(() {
        if (iterations.isNotEmpty) {
          _selectedIterationId = iterations[iterations.length - 1].value;
        }
        _attemptDropdownItems = iterations;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamProvider<NetworkStatus>(
      create: (context) {
        return NetworkStatusService().networkStatusController.stream;
      },
      initialData: NetworkStatus.Online,
      child: NetworkAwareWidget(
        offlineChild: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              right: 0,
              bottom: 0,
              left: 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Image(
                  image: AssetImage('assets/images/logo.png'),
                ),
                Text(
                  "Where's the wifi bud?".toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: "NovecentoSans",
                    fontSize: 24,
                  ),
                ),
                const SizedBox(
                  height: 25,
                ),
                const CircularProgressIndicator(
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        onlineChild: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  collapsedHeight: 65,
                  expandedHeight: 65,
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
                      onPressed: () {
                        context.pop();
                      },
                    ),
                  ),
                  actions: [
                    !_isFriend!
                        ? widget.uid == user!.uid
                            ? const SizedBox()
                            : Container(
                                margin: const EdgeInsets.only(top: 10),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.add,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    Feedback.forTap(context);

                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text(
                                            "Invite ${_userPlayer!.displayName} to be your friend?",
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontSize: 20,
                                            ),
                                          ),
                                          backgroundColor: Theme.of(context).colorScheme.surface,
                                          content: Text(
                                            "They will receive an invite notification from you.",
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                Navigator.of(context).pop();
                                                inviteFriend(user!.uid, widget.uid!, Provider.of<FirebaseFirestore>(context, listen: false)).then((success) {
                                                  if (success!) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        backgroundColor: Theme.of(context).cardTheme.color,
                                                        content: Text(
                                                          "${_userPlayer!.displayName} Invited!",
                                                          style: TextStyle(
                                                            color: Theme.of(context).colorScheme.onPrimary,
                                                          ),
                                                        ),
                                                        duration: const Duration(seconds: 4),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        backgroundColor: Theme.of(context).cardTheme.color,
                                                        content: Text(
                                                          "Failed to invite ${_userPlayer!.displayName} :(",
                                                          style: TextStyle(
                                                            color: Theme.of(context).colorScheme.onPrimary,
                                                          ),
                                                        ),
                                                        duration: const Duration(seconds: 4),
                                                      ),
                                                    );
                                                  }
                                                });
                                              },
                                              child: Text(
                                                "Invite",
                                                style: TextStyle(color: Theme.of(context).primaryColor),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              )
                        : widget.uid == user!.uid
                            ? const SizedBox()
                            : Container(
                                margin: const EdgeInsets.only(top: 10),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Theme.of(context).primaryColor,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    Feedback.forTap(context);
                                    dialog(
                                      context,
                                      ConfirmDialog(
                                        "Remove Friend?",
                                        Text(
                                          "Are you sure you want to unfriend ${_userPlayer!.displayName}?",
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        "Cancel",
                                        () {
                                          Navigator.of(context).pop();
                                        },
                                        "Continue",
                                        () {
                                          // Use go_router for navigation instead of pushReplacement
                                          goToAppSection(
                                            context,
                                            AppSection.community,
                                            communitySection: CommunitySection.friends,
                                          );

                                          removePlayerFromFriends(
                                            _userPlayer!.reference!.id,
                                            Provider.of<FirebaseAuth>(context, listen: false),
                                            Provider.of<FirebaseFirestore>(context, listen: false),
                                          ).then((success) {
                                            if (success) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: Theme.of(context).cardTheme.color,
                                                  duration: const Duration(milliseconds: 2500),
                                                  content: Text(
                                                    '${_userPlayer!.displayName} was removed.',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: Theme.of(context).cardTheme.color,
                                                  duration: const Duration(milliseconds: 4000),
                                                  content: Text(
                                                    'Error removing Player :(',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                ),
                                              );

                                              Navigator.of(context).pop();
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ],
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      titlePadding: null,
                      centerTitle: false,
                      background: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: _loadingPlayer
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: CircularProgressIndicator(),
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.only(top: 15),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 15),
                                  width: 60,
                                  height: 60,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(60),
                                        child: SizedBox(
                                          width: 60,
                                          height: 60,
                                          child: UserAvatar(
                                            user: _userPlayer,
                                            backgroundColor: Colors.transparent,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -4,
                                        bottom: -4,
                                        child: CrAvatarBadgeStream(
                                          userId: widget.uid!,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: (MediaQuery.of(context).size.width - 100) * 0.6,
                                      child: StreamBuilder<DocumentSnapshot>(
                                        // ignore: deprecated_member_use
                                        stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const Column(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Center(
                                                  child: SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }

                                          UserProfile userProfile = UserProfile.fromSnapshot(snapshot.data as DocumentSnapshot);

                                          return AutoSizeText(
                                            userProfile.displayName != null && userProfile.displayName!.isNotEmpty ? userProfile.displayName! : _userPlayer!.displayName!,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).textTheme.bodyLarge!.color,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    StreamBuilder(
                                        stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').snapshots(),
                                        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                                          if (!snapshot.hasData) {
                                            return const Center(
                                              child: SizedBox(
                                                width: 120,
                                                height: 2,
                                                child: LinearProgressIndicator(),
                                              ),
                                            );
                                          } else {
                                            int total = 0;
                                            for (var doc in snapshot.data!.docs) {
                                              total += Iteration.fromSnapshot(doc).total!;
                                            }

                                            return Text(
                                              total.toString() + " Lifetime Shots".toLowerCase(),
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontFamily: 'NovecentoSans',
                                                color: Theme.of(context).colorScheme.onPrimary,
                                              ),
                                            );
                                          }
                                        }),
                                    StreamBuilder(
                                        stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').snapshots(),
                                        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                                          if (!snapshot.hasData) {
                                            return const Center(
                                              child: SizedBox(
                                                width: 120,
                                                height: 2,
                                                child: LinearProgressIndicator(),
                                              ),
                                            );
                                          } else {
                                            Duration totalDuration = const Duration();
                                            for (var doc in snapshot.data!.docs) {
                                              totalDuration += Iteration.fromSnapshot(doc).totalDuration!;
                                            }

                                            return totalDuration > const Duration()
                                                ? Text(
                                                    "IN ${printDuration(totalDuration, true)}",
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontFamily: 'NovecentoSans',
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  )
                                                : Container();
                                          }
                                        }),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              width: (MediaQuery.of(context).size.width - 100) * 0.4,
                              margin: const EdgeInsets.only(right: 10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AutoSizeText(
                                    _userPlayer?.email ?? 'Private Email',
                                    maxLines: 1,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 22,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 10, right: 5),
                                        child: Text(
                                          "challenge ".toUpperCase(),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontSize: 20,
                                            fontFamily: 'NovecentoSans',
                                          ),
                                        ),
                                      ),
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').snapshots(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            return Text(
                                              (snapshot.data!.docs.length).toString(),
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onPrimary,
                                                fontSize: 34,
                                                fontFamily: 'NovecentoSans',
                                              ),
                                            );
                                          }

                                          return Container();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Achievements section: collapsible header with inline badges (mirror Profile)
                        GestureDetector(
                          onTap: () {
                            setState(() => _showAchievements = !_showAchievements);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: lighten(Theme.of(context).colorScheme.primary, 0.1),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            margin: const EdgeInsets.only(top: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Achievements'.toUpperCase(),
                                        style: Theme.of(context).textTheme.headlineSmall,
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: AchievementStatsRow(
                                          userId: widget.uid!,
                                          padding: EdgeInsets.zero,
                                          inline: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _showAchievements ? Icons.expand_less : Icons.expand_more,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                            child: UserAchievementsReadOnly(userId: widget.uid!),
                          ),
                          crossFadeState: _showAchievements ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                          sizeCurve: Curves.easeInOut,
                        ),
                        // ── Challenger Road card ──────────────────────────
                        _buildCrSection(context),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            DropdownButton<dynamic>(
                              onChanged: (value) {
                                setState(() {
                                  _selectedIterationId = value;
                                });
                              },
                              underline: Container(),
                              dropdownColor: Theme.of(context).colorScheme.primary,
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              value: _selectedIterationId,
                              items: _attemptDropdownItems,
                            ),
                            Column(
                              children: [
                                Text(
                                  "Wrist".toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 18,
                                    fontFamily: 'NovecentoSans',
                                  ),
                                ),
                                Container(
                                  width: 30,
                                  height: 25,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: const BoxDecoration(color: wristShotColor),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Opacity(
                                        opacity: 0.75,
                                        child: Text(
                                          "W",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontFamily: 'NovecentoSans',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  "Snap".toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 18,
                                    fontFamily: 'NovecentoSans',
                                  ),
                                ),
                                Container(
                                  width: 30,
                                  height: 25,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: const BoxDecoration(color: snapShotColor),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Opacity(
                                        opacity: 0.75,
                                        child: Text(
                                          "SN",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontFamily: 'NovecentoSans',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  "Backhand".toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 18,
                                    fontFamily: 'NovecentoSans',
                                  ),
                                ),
                                Container(
                                  width: 30,
                                  height: 25,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: const BoxDecoration(color: backhandShotColor),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Opacity(
                                        opacity: 0.75,
                                        child: Text(
                                          "B",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontFamily: 'NovecentoSans',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  "Slap".toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 18,
                                    fontFamily: 'NovecentoSans',
                                  ),
                                ),
                                Container(
                                  width: 30,
                                  height: 25,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: const BoxDecoration(color: slapShotColor),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Opacity(
                                        opacity: 0.75,
                                        child: Text(
                                          "SL",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontFamily: 'NovecentoSans',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 15,
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _selectedIterationId == null ? null : FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').doc(_selectedIterationId).collection('sessions').orderBy('date', descending: true).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final sessions = snapshot.data!.docs;
                              if (sessions.isEmpty) {
                                return Center(
                                  child: Text(
                                    "${_userPlayer?.displayName?.split(' ').first ?? 'Player'} doesn't have any sessions yet".toLowerCase(),
                                    style: TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              }
                              return RefreshIndicator(
                                color: Theme.of(context).primaryColor,
                                onRefresh: () async {}, // Optionally implement refresh logic
                                child: ListView.builder(
                                  controller: sessionsController,
                                  itemCount: sessions.length,
                                  itemBuilder: (_, int index) {
                                    final doc = sessions[index];
                                    return _buildSessionItem(ShootingSession.fromSnapshot(doc), index % 2 == 0);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    sessionsController!.dispose();
    super.dispose();
  }

  Widget _buildCrSection(BuildContext context) {
    if (widget.uid == null) return const SizedBox.shrink();
    return StreamBuilder<ChallengerRoadUserSummary>(
      stream: ChallengerRoadService().watchUserSummary(widget.uid!),
      builder: (context, snap) {
        final summary = snap.data;
        if (summary == null || (summary.totalAttempts == 0 && summary.badges.isEmpty)) {
          return const SizedBox.shrink();
        }
        return _CrPlayerCard(
          userId: widget.uid!,
          summary: summary,
          playerName: _userPlayer?.displayName?.split(' ').first ?? 'Player',
        );
      },
    );
  }

  Widget _buildSessionItem(ShootingSession s, bool showBackground) {
    // Skip sessions with 0 total shots to prevent rendering issues
    if (s.total == null || s.total! <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.only(top: 5, bottom: 15),
      decoration: BoxDecoration(
        color: showBackground ? Theme.of(context).cardTheme.color : Colors.transparent,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  printDate(s.date!),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontFamily: 'NovecentoSans',
                  ),
                ),
                Text(
                  printDuration(s.duration!, true),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontFamily: 'NovecentoSans',
                  ),
                ),
                Text(
                  s.total.toString() + " Shots".toLowerCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontFamily: 'NovecentoSans',
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: MediaQuery.of(context).size.width - 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      width: calculateSessionShotWidth(s, s.totalWrist!),
                      height: 30,
                      decoration: const BoxDecoration(
                        color: wristShotColor,
                      ),
                      child: s.totalWrist! < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  s.totalWrist.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalSnap!),
                      height: 30,
                      decoration: const BoxDecoration(
                        color: snapShotColor,
                      ),
                      child: s.totalSnap! < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  s.totalSnap.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalBackhand!),
                      height: 30,
                      decoration: const BoxDecoration(
                        color: backhandShotColor,
                      ),
                      child: s.totalBackhand! < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  s.totalBackhand.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalSlap!),
                      height: 30,
                      decoration: const BoxDecoration(
                        color: slapShotColor,
                      ),
                      child: s.totalSlap! < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  s.totalSlap.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width - 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    SizedBox(
                      width: calculateSessionShotWidth(s, s.totalWrist!),
                      child: s.totalWrist! < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.5,
                                  child: Text(
                                    "W",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    SizedBox(
                      width: calculateSessionShotWidth(s, s.totalSnap!),
                      child: s.totalSnap! < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.5,
                                  child: Text(
                                    "SN",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    SizedBox(
                      width: calculateSessionShotWidth(s, s.totalBackhand!),
                      child: s.totalBackhand! < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.5,
                                  child: Text(
                                    "B",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    SizedBox(
                      width: calculateSessionShotWidth(s, s.totalSlap!),
                      child: s.totalSlap! < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.5,
                                  child: Text(
                                    "SL",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double calculateSessionShotWidth(ShootingSession session, int shotCount) {
    // Prevent division by zero
    if (session.total == null || session.total! <= 0) {
      return 0.0;
    }
    double percentage = (shotCount / session.total!);
    return (MediaQuery.of(context).size.width - 30) * percentage;
  }
}

// ── Challenger Road player card ───────────────────────────────────────────────

class _CrPlayerCard extends StatelessWidget {
  const _CrPlayerCard({
    required this.userId,
    required this.summary,
    required this.playerName,
  });

  final String userId;
  final ChallengerRoadUserSummary summary;
  final String playerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = summary.badges.toSet();

    // Derive the headline based on outcomes.
    final bool roadComplete = badges.contains('cr_the_general') || badges.contains('cr_playoff_mode');
    final int? shots = summary.allTimeBestLevelShots;
    String headline;
    if (roadComplete) {
      if (shots != null && shots < 10000) {
        headline = 'road complete — ${_fmtShots(shots)} shots';
      } else if (shots != null && shots == 10000) {
        headline = 'road complete — exactly 10,000 shots';
      } else if (shots != null) {
        headline = 'road complete — ${_fmtShots(shots)} shots';
      } else {
        headline = 'challenger road: complete!';
      }
    } else if (summary.allTimeBestLevel > 0) {
      final t = summary.totalAttempts;
      headline = 'reached level ${summary.allTimeBestLevel} · $t attempt${t == 1 ? '' : 's'}';
    } else {
      headline = '${summary.badges.length} badge${summary.badges.length == 1 ? '' : 's'} earned';
    }

    return FutureBuilder<List<ChallengerRoadBadgeDefinition>>(
      future: ChallengerRoadService().getBadgeCatalog(),
      builder: (context, catSnap) {
        final catalog = catSnap.data ?? const [];
        final byId = {for (final d in catalog) d.id: d};
        final featured = summary.featuredBadges;

        return Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: lighten(theme.colorScheme.primary, 0.08),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.route_rounded, color: theme.primaryColor, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'CHALLENGER ROAD',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 13,
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.65),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Headline
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  headline,
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 19,
                    color: roadComplete ? const Color(0xFFFFD700) : theme.colorScheme.onSurface,
                    shadows: roadComplete ? [const Shadow(color: Color(0xFFFFD700), blurRadius: 8)] : null,
                  ),
                ),
              ),
              // Stats chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    _statPill(context, '${summary.totalAttempts}', 'attempts'),
                    const SizedBox(width: 6),
                    _statPill(context, _fmtShots(summary.allTimeTotalChallengerRoadShots), 'cr shots'),
                    const SizedBox(width: 6),
                    _statPill(context, '${summary.badges.length}', 'badges'),
                  ],
                ),
              ),
              // Featured badges
              if (featured.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    'FEATURED',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 16, 0),
                  child: Row(
                    children: [
                      for (final id in featured.take(3)) _featuredBadge(context, byId[id]),
                    ],
                  ),
                ),
              ],
              // View all
              if (summary.badges.isNotEmpty)
                InkWell(
                  onTap: () => _showAllBadges(context, catalog, byId),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'view all ${summary.badges.length} badge${summary.badges.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 15,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, color: theme.primaryColor, size: 16),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _statPill(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: theme.colorScheme.onSurface)),
            Text(label, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _featuredBadge(BuildContext context, ChallengerRoadBadgeDefinition? def) {
    if (def == null) return const SizedBox(width: 70);
    final color = _badgeColor(def);
    final icon = _badgeIcon(def);
    return GestureDetector(
      onTap: () => _showBadgeDetail(context, def, color, icon),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 62,
              child: Text(
                def.effectiveName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, ChallengerRoadBadgeDefinition def, Color color, IconData icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(def.effectiveName, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: Theme.of(context).colorScheme.onSurface))),
              ]),
              const SizedBox(height: 8),
              Text('Unlocked', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: Colors.green)),
              const SizedBox(height: 10),
              Text(def.effectiveDescription, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85))),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllBadges(BuildContext context, List<ChallengerRoadBadgeDefinition> catalog, Map<String, ChallengerRoadBadgeDefinition> byId) {
    final earned = summary.badges;
    final earnedDefs = earned.map((id) => byId[id]).whereType<ChallengerRoadBadgeDefinition>().toList()
      ..sort((a, b) {
        // Sort: legendary first, then by name
        int tierVal(ChallengerRoadBadgeTier t) {
          switch (t) {
            case ChallengerRoadBadgeTier.legendary:
              return 0;
            case ChallengerRoadBadgeTier.epic:
              return 1;
            case ChallengerRoadBadgeTier.hidden:
              return 2;
            case ChallengerRoadBadgeTier.rare:
              return 3;
            case ChallengerRoadBadgeTier.uncommon:
              return 4;
            case ChallengerRoadBadgeTier.common:
              return 5;
          }
        }

        final tv = tierVal(a.tier).compareTo(tierVal(b.tier));
        return tv != 0 ? tv : a.name.compareTo(b.name);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Icon(Icons.military_tech_rounded, color: Theme.of(context).primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "${playerName}'s badges".toUpperCase(),
                    style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: earnedDefs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (_, i) {
                  final def = earnedDefs[i];
                  final color = _badgeColor(def);
                  final icon = _badgeIcon(def);
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showBadgeDetail(context, def, color, icon),
                    child: SizedBox(
                      width: 104,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.18),
                              border: Border.all(color: color, width: 2.0),
                              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
                            ),
                            child: Icon(icon, size: 26, color: color),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            def.effectiveName,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 11, color: Theme.of(context).colorScheme.onSurface, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _badgeColor(ChallengerRoadBadgeDefinition def) {
    switch (def.tier) {
      case ChallengerRoadBadgeTier.legendary:
        return const Color(0xFFFFD700);
      case ChallengerRoadBadgeTier.epic:
        return const Color(0xFFAB47BC);
      case ChallengerRoadBadgeTier.hidden:
        return const Color(0xFF78909C);
      default:
        break;
    }
    switch (def.category) {
      case ChallengerRoadBadgeCategory.firstSteps:
        return const Color(0xFF42A5F5);
      case ChallengerRoadBadgeCategory.withinRunEfficiency:
        return const Color(0xFF26C6DA);
      case ChallengerRoadBadgeCategory.crossAttemptImprovement:
        return const Color(0xFF66BB6A);
      case ChallengerRoadBadgeCategory.grindAndResilience:
        return const Color(0xFF8D6E63);
      case ChallengerRoadBadgeCategory.levelAdvancement:
        return const Color(0xFF26A69A);
      case ChallengerRoadBadgeCategory.crShotMilestones:
        return const Color(0xFFFF7043);
      case ChallengerRoadBadgeCategory.crSessionAccuracy:
        return const Color(0xFF5C6BC0);
      case ChallengerRoadBadgeCategory.hotStreaks:
        return const Color(0xFFEF5350);
      case ChallengerRoadBadgeCategory.challengeMastery:
        return const Color(0xFF5C6BC0);
      case ChallengerRoadBadgeCategory.multiAttemptCareer:
        return const Color(0xFF29B6F6);
      case ChallengerRoadBadgeCategory.eliteEndgame:
        return const Color(0xFFFFD700);
      case ChallengerRoadBadgeCategory.chirpy:
        return const Color(0xFF78909C);
    }
  }

  static IconData _badgeIcon(ChallengerRoadBadgeDefinition def) {
    switch (def.category) {
      case ChallengerRoadBadgeCategory.firstSteps:
        return Icons.route_rounded;
      case ChallengerRoadBadgeCategory.withinRunEfficiency:
        return Icons.bolt_rounded;
      case ChallengerRoadBadgeCategory.crossAttemptImprovement:
        return Icons.trending_up_rounded;
      case ChallengerRoadBadgeCategory.grindAndResilience:
        return Icons.shield_rounded;
      case ChallengerRoadBadgeCategory.levelAdvancement:
        return Icons.stairs_rounded;
      case ChallengerRoadBadgeCategory.crShotMilestones:
        return Icons.workspace_premium_rounded;
      case ChallengerRoadBadgeCategory.crSessionAccuracy:
        return Icons.gps_fixed_rounded;
      case ChallengerRoadBadgeCategory.hotStreaks:
        return Icons.local_fire_department_rounded;
      case ChallengerRoadBadgeCategory.challengeMastery:
        return Icons.emoji_events_rounded;
      case ChallengerRoadBadgeCategory.multiAttemptCareer:
        return Icons.repeat_rounded;
      case ChallengerRoadBadgeCategory.eliteEndgame:
        return Icons.military_tech_rounded;
      case ChallengerRoadBadgeCategory.chirpy:
        return Icons.sports_hockey_rounded;
    }
  }
}

String _fmtShots(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

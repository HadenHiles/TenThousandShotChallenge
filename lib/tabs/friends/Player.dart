import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';

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
    await FirebaseFirestore.instance
        .collection('iterations')
        .doc(widget.uid)
        .collection('iterations')
        .orderBy('start_date', descending: false)
        .get()
        .then((snapshot) {
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
                        navigatorKey.currentState!.pop();
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
                                                inviteFriend(user!.uid, widget.uid!, Provider.of<FirebaseFirestore>(context, listen: false))
                                                    .then((success) {
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
                                          navigatorKey.currentState!.pushReplacement(
                                            MaterialPageRoute(builder: (context) {
                                              return Navigation(
                                                title: NavigationTitle(title: "Players".toUpperCase()),
                                                selectedIndex: 1,
                                              );
                                            }),
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
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(60),
                                  ),
                                  child: SizedBox(
                                    height: 60,
                                    child: UserAvatar(
                                      user: _userPlayer,
                                      backgroundColor: Colors.transparent,
                                    ),
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
                                            userProfile.displayName != null && userProfile.displayName!.isNotEmpty
                                                ? userProfile.displayName!
                                                : _userPlayer!.displayName!,
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
                                        stream: FirebaseFirestore.instance
                                            .collection('iterations')
                                            .doc(widget.uid)
                                            .collection('iterations')
                                            .snapshots(),
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
                                        stream: FirebaseFirestore.instance
                                            .collection('iterations')
                                            .doc(widget.uid)
                                            .collection('iterations')
                                            .snapshots(),
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
                                    _userPlayer!.email!,
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
                                        stream: FirebaseFirestore.instance
                                            .collection('iterations')
                                            .doc(widget.uid)
                                            .collection('iterations')
                                            .snapshots(),
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
                        Divider(
                          height: 25,
                          color: Theme.of(context).cardTheme.color,
                        ),
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
                            stream: _selectedIterationId == null
                                ? null
                                : FirebaseFirestore.instance
                                    .collection('iterations')
                                    .doc(widget.uid)
                                    .collection('iterations')
                                    .doc(_selectedIterationId)
                                    .collection('sessions')
                                    .orderBy('date', descending: true)
                                    .snapshots(),
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

  Widget _buildSessionItem(ShootingSession s, bool showBackground) {
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
    double percentage = (shotCount / session.total!);
    return (MediaQuery.of(context).size.width - 30) * percentage;
  }
}

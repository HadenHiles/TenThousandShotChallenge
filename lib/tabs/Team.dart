// ignore_for_file: constant_identifier_names

import 'package:auto_size_text/auto_size_text.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/friends/Player.dart';
import 'package:tenthousandshotchallenge/tabs/profile/QR.dart';
import 'package:tenthousandshotchallenge/tabs/team/CreateTeam.dart';
import 'package:tenthousandshotchallenge/tabs/team/JoinTeam.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import '../main.dart';

const TEAM_HEADER_HEIGHT = 65.0;

class TeamPage extends StatefulWidget {
  const TeamPage({Key? key}) : super(key: key);

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class Plyr {
  UserProfile? profile;
  int? shots;

  Plyr(this.profile, this.shots);
}

class _TeamPageState extends State<TeamPage> with SingleTickerProviderStateMixin {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;
  DateTime? _targetDate;
  final TextEditingController _targetDateController = TextEditingController();
  bool _showShotsPerDay = true;
  bool hasTeam = false;
  bool isOwner = false;
  int numPlayers = 1;
  List<Plyr>? players = [];
  bool isLoadingPlayers = true;
  List<ShootingSession>? sessions = [];
  int teamTotalShots = 0;
  String? shotsPerDayText;
  String? shotsPerWeekText;
  Team? team;
  bool isLoadingTeam = true;
  UserProfile? userProfile;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<Null> _loadTeam() async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).get().then((uDoc) async {
      if (uDoc.exists) {
        userProfile = UserProfile.fromSnapshot(uDoc);

        if (userProfile!.teamId != null) {
          await FirebaseFirestore.instance.collection('teams').doc(userProfile!.teamId).get().then((tSnap) async {
            if (tSnap.exists) {
              Team t = Team.fromSnapshot(tSnap);

              if (!t.players!.contains(user!.uid)) {
                // Remove the user's assigned team so they can join a new one
                uDoc.reference.update({'team_id': null}).then((value) {});
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                        "You have been removed from team \"${t.name}\" by the team owner.".toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 24,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You are free to join a new team whenever you wish.",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (BuildContext context) {
                            return const JoinTeam();
                          })),
                          child: Text(
                            "Ok".toUpperCase(),
                            style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).primaryColor),
                          ),
                        ),
                      ],
                    );
                  },
                );
              } else {
                setState(() {
                  team = t;
                  hasTeam = true;
                  if (t.ownerId == user!.uid) {
                    isOwner = true;
                  }

                  _targetDate = t.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100);
                });

                _targetDateController.text = DateFormat('MMMM d, y').format(t.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100));

                // Load the team total
                List<ShootingSession> sList = [];
                int teamTotal = 0;
                List<Plyr> plyrs = [];
                numPlayers = team == null ? 1 : team!.players!.length;

                await Future.forEach(team!.players!, (String pId) async {
                  await FirebaseFirestore.instance.collection('users').doc(pId).get().then((uDoc) async {
                    UserProfile u = UserProfile.fromSnapshot(uDoc);
                    Plyr p = Plyr(u, 0);

                    await FirebaseFirestore.instance.collection('iterations').doc(u.reference!.id).collection('iterations').get().then((i) async {
                      if (i.docs.isNotEmpty) {
                        await Future.forEach(i.docs, (DocumentSnapshot iDoc) async {
                          Iteration i = Iteration.fromSnapshot(iDoc);

                          await i.reference!.collection("sessions").where('date', isGreaterThanOrEqualTo: team!.startDate).where('date', isLessThanOrEqualTo: team!.targetDate).orderBy('date', descending: true).get().then((seshs) async {
                            int pShots = 0;
                            for (var i = 0; i < seshs.docs.length; i++) {
                              ShootingSession s = ShootingSession.fromSnapshot(seshs.docs[i]);
                              sList.add(s);
                              teamTotal += s.total!;
                              pShots += s.total!;

                              if (i == seshs.docs.length - 1) {
                                // Last session
                                p.shots = pShots;
                              }
                            }
                          });
                        });
                      }
                    }).then((_) {
                      plyrs.add(p);
                      _updateShotCalculations();
                    });
                  });
                }).then((value) {
                  _updateTeamTotal(sList, teamTotal);
                  _updateShotCalculations();

                  setState(() {
                    plyrs.sort((a, b) => a.shots!.compareTo(b.shots!));
                    players = plyrs.reversed.toList();
                    isLoadingPlayers = false;
                    isLoadingTeam = false;
                  });
                }).onError((error, stackTrace) => null);
              }
            }
          });
        }
      }

      setState(() {
        isLoadingPlayers = false;
        isLoadingTeam = false;
      });
    });
  }

  _updateTeamTotal(List<ShootingSession> sList, int teamTotal) {
    setState(() {
      sessions = sList;
      teamTotalShots = teamTotal;
    });
  }

  _updateShotCalculations() {
    int? total = teamTotalShots;
    int shotsRemaining = team!.goalTotal! - total;
    int daysRemaining = _targetDate!.difference(DateTime.now()).inDays;
    double weeksRemaining = double.parse((daysRemaining / 7).toStringAsFixed(4));

    int shotsPerDay = 0;
    if (daysRemaining <= 1) {
      shotsPerDay = shotsRemaining;
    } else {
      shotsPerDay = shotsRemaining <= daysRemaining ? 1 : (shotsRemaining / daysRemaining).round();
    }

    int shotsPerWeek = 0;
    if (weeksRemaining <= 1) {
      shotsPerWeek = shotsRemaining;
    } else {
      shotsPerWeek = shotsRemaining <= weeksRemaining ? 1 : (shotsRemaining.toDouble() / weeksRemaining).round().toInt();
    }

    int shotsPerPlayerDay = (shotsPerDay / numPlayers).round();
    int shotsPerPlayerWeek = (shotsPerWeek / numPlayers).round();

    shotsPerDayText = shotsRemaining < 1
        ? "Done!".toLowerCase()
        : shotsPerDay <= 999
            ? "$shotsPerPlayerDay / Day / Player".toLowerCase()
            : "${numberFormat.format(shotsPerPlayerDay)} / Day / Player".toLowerCase();
    shotsPerWeekText = shotsRemaining < 1
        ? "Done!".toLowerCase()
        : shotsPerWeek <= 999
            ? "$shotsPerPlayerWeek / Week / Player".toLowerCase()
            : "${numberFormat.format(shotsPerPlayerWeek)} / Week / Player".toLowerCase();

    if (_targetDate!.compareTo(DateTime.now()) < 0) {
      daysRemaining = DateTime.now().difference(team!.targetDate!).inDays * -1;

      shotsPerDayText = "${daysRemaining.abs()} Days Past Goal".toLowerCase();
      shotsPerWeekText = shotsRemaining <= 999 ? shotsRemaining.toString() + " remaining".toLowerCase() : numberFormat.format(shotsRemaining) + " remaining".toLowerCase();
    }

    setState(() {
      shotsPerDayText = shotsPerDayText;
      shotsPerWeekText = shotsPerWeekText;
    });
  }

  @override
  Widget build(BuildContext context) {
    var f = NumberFormat("###,###,###", "en_US");
    _targetDateController.text = DateFormat('MMMM d, y').format(team?.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100));
    double totalShotsWidth = 0;
    double totalShotsPercentage = 0;

    if (team != null) {
      totalShotsPercentage = (teamTotalShots / team!.goalTotal!) > 1 ? 1 : (teamTotalShots / team!.goalTotal!);
      totalShotsWidth = totalShotsPercentage * (MediaQuery.of(context).size.width - 60);
    }

    return SingleChildScrollView(
      physics: const ScrollPhysics(),
      child: Column(
        mainAxisAlignment: ((team == null && userProfile != null && userProfile!.teamId == null) || isLoadingPlayers) ? MainAxisAlignment.center : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          (team == null && userProfile != null && userProfile!.teamId == null) || isLoadingPlayers
              ? Container(
                  margin: const EdgeInsets.only(top: 100),
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                )
              : !hasTeam
                  ? SizedBox(
                      width: MediaQuery.of(context).size.width - 30,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 40),
                            child: Text(
                              "Tap + to create a team".toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 20,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 15),
                            child: Center(
                              child: Ink(
                                decoration: ShapeDecoration(
                                  color: Theme.of(context).cardTheme.color,
                                  shape: const CircleBorder(),
                                ),
                                child: IconButton(
                                  color: Theme.of(context).cardTheme.color,
                                  onPressed: () {
                                    navigatorKey.currentState!.push(MaterialPageRoute(builder: (BuildContext context) {
                                      return const CreateTeam();
                                    }));
                                  },
                                  iconSize: 40,
                                  icon: Icon(
                                    Icons.add,
                                    size: 40,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Divider(
                            height: 50,
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 40),
                            child: Text(
                              "Or join an existing team".toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 20,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 15),
                            child: Center(
                              child: Ink(
                                child: MaterialButton(
                                  color: Theme.of(context).cardTheme.color,
                                  child: Text(
                                    "Join Team".toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      fontSize: 20,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                  onPressed: () {
                                    navigatorKey.currentState!.push(MaterialPageRoute(builder: (BuildContext context) {
                                      return const JoinTeam();
                                    }));
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        _targetDate == null
                            ? Container(
                                margin: const EdgeInsets.only(top: 10),
                              )
                            : Container(
                                padding: const EdgeInsets.only(top: 5, bottom: 0),
                                margin: const EdgeInsets.only(
                                  bottom: 10,
                                  top: 15,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Goal".toUpperCase(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 26,
                                        fontFamily: 'NovecentoSans',
                                      ),
                                    ),
                                    Stack(
                                      children: [
                                        SizedBox(
                                          width: 150,
                                          child: AutoSizeTextField(
                                            controller: _targetDateController,
                                            style: const TextStyle(fontSize: 12),
                                            maxLines: 1,
                                            maxFontSize: 14,
                                            decoration: InputDecoration(
                                              labelText: "${f.format(int.parse(team!.goalTotal.toString()))} Shots By:".toLowerCase(),
                                              labelStyle: TextStyle(
                                                color: preferences!.darkMode! ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
                                                fontFamily: "NovecentoSans",
                                                fontSize: 22,
                                              ),
                                              focusColor: Theme.of(context).colorScheme.primary,
                                              border: null,
                                              disabledBorder: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              contentPadding: const EdgeInsets.all(2),
                                              fillColor: Theme.of(context).colorScheme.primaryContainer,
                                            ),
                                            readOnly: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        SizedBox(
                                          width: 110,
                                          child: teamTotalShots == 0 && isLoadingTeam
                                              ? Center(
                                                  child: CircularProgressIndicator(
                                                    color: Theme.of(context).primaryColor,
                                                  ),
                                                )
                                              : GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _showShotsPerDay = !_showShotsPerDay;
                                                    });
                                                  },
                                                  child: AutoSizeText(
                                                    _showShotsPerDay ? shotsPerDayText! : shotsPerWeekText!,
                                                    maxFontSize: 20,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                      fontFamily: "NovecentoSans",
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        InkWell(
                                          enableFeedback: true,
                                          focusColor: Theme.of(context).colorScheme.primaryContainer,
                                          onTap: () {
                                            setState(() {
                                              _showShotsPerDay = !_showShotsPerDay;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(30),
                                          child: const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: Icon(
                                              Icons.swap_vert,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Progress".toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 22,
                                fontFamily: 'NovecentoSans',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Column(
                          children: [
                            Container(
                              width: (MediaQuery.of(context).size.width),
                              margin: const EdgeInsets.symmetric(horizontal: 30),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(context).cardTheme.color,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Tooltip(
                                    message: "$teamTotalShots Shots".toLowerCase(),
                                    preferBelow: false,
                                    textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                                    child: Container(
                                      height: 40,
                                      width: teamTotalShots > 0 ? totalShotsPercentage * totalShotsWidth : 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: const BoxDecoration(
                                        color: wristShotColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: (MediaQuery.of(context).size.width - 30),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    height: 40,
                                    width: totalShotsWidth < 35
                                        ? 50
                                        : totalShotsWidth > (MediaQuery.of(context).size.width - 110)
                                            ? totalShotsWidth - 175
                                            : totalShotsWidth,
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: AutoSizeText(
                                      teamTotalShots <= 999 ? teamTotalShots.toString() : numberFormat.format(teamTotalShots),
                                      textAlign: TextAlign.right,
                                      maxFontSize: 18,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontFamily: 'NovecentoSans',
                                        fontSize: 18,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: Text(
                                          " / ${numberFormat.format(team!.goalTotal)}",
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontFamily: 'NovecentoSans',
                                            fontSize: 18,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        players!.isEmpty
                            ? SizedBox(
                                child: Column(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 40),
                                      child: Text(
                                        "No Players on the Team (yet!)".toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          fontSize: 20,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 15),
                                      child: Center(
                                        child: Ink(
                                          decoration: ShapeDecoration(
                                            color: Theme.of(context).cardTheme.color,
                                            shape: const CircleBorder(),
                                          ),
                                          child: IconButton(
                                            color: Theme.of(context).cardTheme.color,
                                            onPressed: () {
                                              showTeamQRCode(user);
                                            },
                                            iconSize: 40,
                                            icon: Icon(
                                              Icons.share,
                                              size: 40,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SizedBox(
                                child: ListView.builder(
                                  padding: EdgeInsets.only(top: 0, right: 0, left: 0, bottom: AppBar().preferredSize.height),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: players!.length + 1,
                                  itemBuilder: (_, int index) {
                                    if (index < players!.length) {
                                      final Plyr p = players![index];
                                      return _buildPlayerItem(p, index % 2 == 0 ? true : false, index + 1);
                                    }

                                    return players!.isNotEmpty
                                        ? Container()
                                        : const Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  height: 25,
                                                  width: 25,
                                                  child: CircularProgressIndicator(),
                                                ),
                                              ],
                                            ),
                                          );
                                  },
                                ),
                              ),
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildPlayerItem(Plyr plyr, bool bg, int place) {
    return GestureDetector(
      onTap: () {
        Feedback.forTap(context);

        navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
          return Player(uid: plyr.profile!.reference!.id);
        }));
      },
      child: (team!.ownerId == user!.uid && user!.uid != plyr.profile!.reference!.id)
          ? Dismissible(
              key: UniqueKey(),
              onDismissed: (direction) async {
                Fluttertoast.showToast(
                  msg: '${plyr.profile!.displayName} removed from the team',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Theme.of(context).cardTheme.color,
                  textColor: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 16.0,
                );

                setState(() {
                  isLoadingPlayers = true;
                });

                await removePlayerFromTeam(team!.id!, plyr.profile!.reference!.id).then((deleted) {
                  if (!deleted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Theme.of(context).cardTheme.color,
                        content: Text(
                          "Sorry this player can't be removed from your team",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        duration: const Duration(milliseconds: 1500),
                      ),
                    );
                  }

                  setState(() {
                    players!.remove(plyr);
                  });

                  _loadTeam().then(
                    (_) => setState(() {
                      setState(() {
                        isLoadingPlayers = false;
                      });
                    }),
                  );
                });
              },
              confirmDismiss: (DismissDirection direction) async {
                return await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                        "Remove Player?".toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 24,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Are you sure you want to remove this player from your team?",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            "Cancel".toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            "Delete".toUpperCase(),
                            style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).primaryColor),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              background: Container(
                color: Theme.of(context).primaryColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 15),
                      child: Text(
                        "Delete".toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 15),
                      child: const Icon(
                        Icons.delete,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: bg ? Theme.of(context).cardTheme.color : Colors.transparent,
                ),
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    _outputPlace(place),
                    Container(
                      margin: const EdgeInsets.only(left: 0, right: 15),
                      width: 60,
                      height: 60,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: SizedBox(
                        height: 60,
                        child: UserAvatar(
                          user: plyr.profile,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            plyr.profile!.displayName != null
                                ? SizedBox(
                                    width: MediaQuery.of(context).size.width - 250,
                                    child: AutoSizeText(
                                      plyr.profile!.displayName!,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).textTheme.bodyLarge!.color,
                                      ),
                                    ),
                                  )
                                : Container(),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 135,
                              child: AutoSizeText(
                                "${plyr.shots} Shots",
                                maxLines: 1,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontFamily: 'NovecentoSans',
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: bg ? Theme.of(context).cardTheme.color : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  _outputPlace(place),
                  Container(
                    margin: const EdgeInsets.only(left: 0, right: 15),
                    width: 60,
                    height: 60,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: SizedBox(
                      height: 60,
                      child: UserAvatar(
                        user: plyr.profile,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          plyr.profile!.displayName != null
                              ? SizedBox(
                                  width: MediaQuery.of(context).size.width - 250,
                                  child: AutoSizeText(
                                    plyr.profile!.displayName!,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).textTheme.bodyLarge!.color,
                                    ),
                                  ),
                                )
                              : Container(),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 135,
                            child: AutoSizeText(
                              "${plyr.shots} Shots",
                              maxLines: 1,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: 'NovecentoSans',
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _outputPlace(int place) {
    if ([1, 2, 3].contains(place)) {
      switch (place) {
        case 1:
          return Container(
            margin: const EdgeInsets.only(left: 10, right: 0, top: 20, bottom: 20),
            width: 20,
            height: 20,
            child: SizedBox(
              width: 50,
              height: 50,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.antiAlias,
                child: SvgPicture.asset(
                  "assets/images/1st.svg",
                  semanticsLabel: '1st',
                ),
              ),
            ),
          );
        case 2:
          return Container(
            margin: const EdgeInsets.only(left: 10, right: 0, top: 20, bottom: 20),
            width: 20,
            height: 20,
            child: SizedBox(
              width: 50,
              height: 50,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.antiAlias,
                child: SvgPicture.asset(
                  "assets/images/2nd.svg",
                  semanticsLabel: '2nd',
                ),
              ),
            ),
          );
        case 3:
          return Container(
            margin: const EdgeInsets.only(left: 10, right: 0, top: 20, bottom: 20),
            width: 20,
            height: 20,
            child: SizedBox(
              width: 50,
              height: 50,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.antiAlias,
                child: SvgPicture.asset(
                  "assets/images/3rd.svg",
                  semanticsLabel: '3rd',
                ),
              ),
            ),
          );
        default:
          return Container(
            margin: const EdgeInsets.only(left: 10, right: 0, top: 20, bottom: 20),
            width: 20,
            height: 20,
            child: SizedBox(
              width: 50,
              height: 50,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.antiAlias,
                child: SvgPicture.asset(
                  "assets/images/1st.svg",
                  semanticsLabel: '1st',
                ),
              ),
            ),
          );
      }
    } else {
      return Container(
        margin: const EdgeInsets.only(left: 10, right: 0, top: 20, bottom: 20),
        width: 20,
        height: 20,
        child: Text(
          place.toString().toUpperCase(),
          style: TextStyle(
            color: preferences!.darkMode! ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
            fontFamily: "NovecentoSans",
            fontSize: 14,
          ),
        ),
      );
    }
  }
}

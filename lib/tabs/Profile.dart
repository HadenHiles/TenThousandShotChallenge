import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/profile/History.dart';
import 'package:tenthousandshotchallenge/tabs/profile/QR.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditProfile.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key, this.sessionPanelController, this.updateSessionShotsCB}) : super(key: key);

  final PanelController? sessionPanelController;
  final Function? updateSessionShotsCB;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;

  final GlobalKey _avatarMenuKey = GlobalKey();

  UserProfile userProfile = UserProfile('', '', FirebaseAuth.instance.currentUser!.photoURL, true, true, null, '');
  bool _isLoading = true;
  List<DocumentSnapshot> _sessions = [];
  List<DropdownMenuItem> _attemptDropdownItems = [];
  String? _selectedIterationId;

  DateTime? firstSessionDate = DateTime.now();
  DateTime? latestSessionDate = DateTime.now();

  @override
  void initState() {
    FirebaseFirestore.instance.collection('users').doc(user!.uid).get().then((uDoc) {
      userProfile = UserProfile.fromSnapshot(uDoc);
    });

    super.initState();

    _loadFirstLastSession();
    _loadRecentSessions();
    _getAttempts();
  }

  Future<Null> _loadFirstLastSession() async {
    await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: false).get().then((iterationSnap) async {
      if (iterationSnap.docs.isNotEmpty) {
        await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(iterationSnap.docs.first.id).collection('sessions').orderBy('date', descending: false).get().then((sessionsSnap) {
          if (sessionsSnap.docs.isNotEmpty) {
            ShootingSession first = ShootingSession.fromSnapshot(sessionsSnap.docs.first);
            ShootingSession latest = ShootingSession.fromSnapshot(sessionsSnap.docs.last);

            setState(() {
              firstSessionDate = first.date;
              latestSessionDate = latest.date;
            });
          }
        });
      }
    });
  }

  Future<Null> _getAttempts() async {
    await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').orderBy('start_date', descending: false).get().then((snapshot) {
      List<DropdownMenuItem> iterations = [];
      snapshot.docs.asMap().forEach((i, iDoc) {
        iterations.add(DropdownMenuItem<String>(
          value: iDoc.reference.id,
          child: Text(
            "challenge ${(i + 1).toString().toLowerCase()}",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 26,
              fontFamily: 'NovecentoSans',
            ),
          ),
        ));
      });

      setState(() {
        _selectedIterationId = iterations[iterations.length - 1].value;
        _attemptDropdownItems = iterations;
      });
    });
  }

  Future<Null> _loadRecentSessions() async {
    await Future.delayed(const Duration(milliseconds: 500));

    await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).get().then((snapshot) {
      List<DocumentSnapshot> sessions = [];
      snapshot.reference.collection('sessions').orderBy('date', descending: true).limit(3).get().then((sSnap) {
        for (var s in sSnap.docs) {
          sessions.add(s);
        }

        if (sessions.isNotEmpty) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _sessions = sessions;
            });
          }
        } else {
          setState(() => _isLoading = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            PopupMenuButton(
                              key: _avatarMenuKey,
                              color: Theme.of(context).colorScheme.primary,
                              iconSize: 40,
                              icon: Container(),
                              itemBuilder: (_) => <PopupMenuItem<String>>[
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Change Avatar".toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                      Icon(
                                        Icons.edit,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'qr_code',
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Show QR Code".toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                      Icon(
                                        Icons.qr_code_2_rounded,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
                                    return const EditProfile();
                                  }));
                                } else if (value == 'qr_code') {
                                  showQRCode(user);
                                }
                              },
                            ),
                            Container(
                              width: 60,
                              height: 60,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: GestureDetector(
                                onLongPress: () {
                                  Feedback.forLongPress(context);

                                  navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
                                    return const EditProfile();
                                  }));
                                },
                                onTap: () {
                                  Feedback.forTap(context);
                                  dynamic state = _avatarMenuKey.currentState;
                                  state.showButtonMenu();
                                },
                                child: SizedBox(
                                  height: 60,
                                  width: 60,
                                  child: UserAvatar(
                                    user: UserProfile(user!.displayName, user!.email, userProfile.photoUrl, true, userProfile.friendNotifications, null, preferences!.fcmToken),
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                          stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
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

                            return SizedBox(
                              width: (MediaQuery.of(context).size.width - 100) * 0.5,
                              child: AutoSizeText(
                                userProfile.displayName != null && userProfile.displayName!.isNotEmpty ? userProfile.displayName! : user!.displayName!,
                                maxLines: 1,
                                maxFontSize: 22,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge!.color,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      StreamBuilder(
                          stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').snapshots(),
                          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                            if (!snapshot.hasData) {
                              return Center(
                                child: SizedBox(
                                  width: (MediaQuery.of(context).size.width - 100) * 0.5,
                                  height: 2,
                                  child: const LinearProgressIndicator(),
                                ),
                              );
                            } else {
                              int total = 0;
                              for (var doc in snapshot.data!.docs) {
                                total += Iteration.fromSnapshot(doc).total!;
                              }

                              return SizedBox(
                                width: (MediaQuery.of(context).size.width - 100) * 0.5,
                                child: AutoSizeText(
                                  total > 999 ? numberFormat.format(total) + " Lifetime Shots".toLowerCase() : total.toString() + " Lifetime Shots".toLowerCase(),
                                  maxFontSize: 20,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontFamily: 'NovecentoSans',
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              );
                            }
                          }),
                      StreamBuilder(
                          stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').snapshots(),
                          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                            if (!snapshot.hasData) {
                              return Center(
                                child: SizedBox(
                                  width: (MediaQuery.of(context).size.width - 100) * 0.5,
                                  height: 2,
                                  child: const LinearProgressIndicator(),
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
                margin: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return SizedBox(
                            width: (MediaQuery.of(context).size.width - 100) * 0.3,
                            child: AutoSizeText(
                              "challenge ".toLowerCase() + (snapshot.data!.docs.length).toString().toLowerCase(),
                              maxFontSize: 34,
                              maxLines: 1,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 34,
                                fontFamily: 'NovecentoSans',
                              ),
                            ),
                          );
                        }

                        return Container();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                Iteration i = Iteration.fromSnapshot(snapshot.data as DocumentSnapshot);

                if (i.endDate != null) {
                  int daysTaken = i.endDate!.difference(firstSessionDate!).inDays + 1;
                  daysTaken = daysTaken < 1 ? 1 : daysTaken;
                  String endDate = DateFormat('MMMM d, y').format(i.endDate!);
                  String iterationDescription;
                  String goalDescription = "";
                  String fTotal = i.total! > 999 ? numberFormat.format(i.total) : i.total.toString();

                  if (daysTaken <= 1) {
                    iterationDescription = "$fTotal shots in $daysTaken day";
                  } else {
                    iterationDescription = "$fTotal shots in $daysTaken days";
                  }

                  if (i.targetDate != null) {
                    String targetDate = DateFormat('MMMM d, y').format(i.targetDate!);
                    int daysBeforeAfterTarget = i.targetDate!.difference(i.endDate!).inDays;

                    if (daysBeforeAfterTarget > 0) {
                      if (daysBeforeAfterTarget.abs() <= 1) {
                        goalDescription += " ${daysBeforeAfterTarget.abs()} day before goal";
                      } else {
                        goalDescription += " ${daysBeforeAfterTarget.abs()} days before goal";
                      }
                    } else if (daysBeforeAfterTarget < 0) {
                      if (daysBeforeAfterTarget.abs() <= 1) {
                        goalDescription += " ${daysBeforeAfterTarget.abs()} day after goal";
                      } else {
                        goalDescription += " ${daysBeforeAfterTarget.abs()} days after goal";
                      }
                    }

                    goalDescription += " ($targetDate)";
                  } else {
                    goalDescription += "completed on $endDate";
                  }

                  return SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 60,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 8,
                            ),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  FontAwesomeIcons.hockeyPuck,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                                // Top Left
                                Positioned(
                                  left: -6,
                                  top: -6,
                                  child: Icon(
                                    FontAwesomeIcons.hockeyPuck,
                                    size: 8,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                                // Bottom Left
                                Positioned(
                                  left: -5,
                                  bottom: -5,
                                  child: Icon(
                                    FontAwesomeIcons.hockeyPuck,
                                    size: 6,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                                // Top right
                                Positioned(
                                  right: -4,
                                  top: -6,
                                  child: Icon(
                                    FontAwesomeIcons.hockeyPuck,
                                    size: 6,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                                // Bottom right
                                Positioned(
                                  right: -4,
                                  bottom: -8,
                                  child: Icon(
                                    FontAwesomeIcons.hockeyPuck,
                                    size: 8,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            AutoSizeText(
                              iterationDescription.toLowerCase(),
                              maxFontSize: 18,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontFamily: "NovecentoSans",
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              FontAwesomeIcons.calendarCheck,
                              size: 20,
                            ),
                            const SizedBox(
                              width: 4,
                            ),
                            AutoSizeText(
                              goalDescription.toLowerCase(),
                              maxFontSize: 18,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontFamily: "NovecentoSans",
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                } else {
                  int daysSoFar = latestSessionDate!.difference(firstSessionDate!).inDays + 1;
                  daysSoFar = daysSoFar < 1 ? 1 : daysSoFar;
                  String? iterationDescription;
                  String goalDescription = "";
                  int remainingShots = 10000 - i.total!;
                  String fRemainingShots = remainingShots > 999 ? numberFormat.format(remainingShots) : remainingShots.toString();
                  String fTotal = i.total! > 999 ? numberFormat.format(i.total) : i.total.toString();

                  if (daysSoFar <= 1 && daysSoFar != 0) {
                    iterationDescription = "$fTotal shots in $daysSoFar day";
                  } else {
                    iterationDescription = "$fTotal shots in $daysSoFar days";
                  }

                  if (i.targetDate != null && remainingShots > 0) {
                    String? targetDate = DateFormat("MM/dd/yyyy").format(i.targetDate!);
                    int daysBeforeAfterTarget = i.targetDate!.difference(DateTime.now()).inDays;
                    if (i.targetDate!.compareTo(DateTime.now()) < 0) {
                      daysBeforeAfterTarget = DateTime.now().difference(i.targetDate!).inDays * -1;
                    }

                    if (daysBeforeAfterTarget > 0) {
                      if (daysBeforeAfterTarget <= 1 && daysBeforeAfterTarget != 0) {
                        goalDescription += "${daysBeforeAfterTarget.abs()} day left to take $fRemainingShots shots";
                      } else {
                        goalDescription += "${daysBeforeAfterTarget.abs()} days left to take $fRemainingShots shots";
                      }
                    } else if (daysBeforeAfterTarget < 0) {
                      if (daysBeforeAfterTarget == -1) {
                        goalDescription += "${daysBeforeAfterTarget.abs()} day past goal ($targetDate)";
                      } else {
                        goalDescription += "${daysBeforeAfterTarget.abs()} days past goal ($targetDate)";
                      }
                    } else {
                      goalDescription += "1 day left to take $fRemainingShots shots";
                    }
                  }

                  return SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 60,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: (remainingShots >= 10000 || remainingShots <= 0) ? MainAxisAlignment.center : MainAxisAlignment.spaceEvenly,
                      children: [
                        remainingShots >= 10000
                            ? Container()
                            : Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.hockeyPuck,
                                        size: 14,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                      // Top Left
                                      Positioned(
                                        left: -6,
                                        top: -6,
                                        child: Icon(
                                          FontAwesomeIcons.hockeyPuck,
                                          size: 8,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                      // Bottom Left
                                      Positioned(
                                        left: -5,
                                        bottom: -5,
                                        child: Icon(
                                          FontAwesomeIcons.hockeyPuck,
                                          size: 6,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                      // Top right
                                      Positioned(
                                        right: -4,
                                        top: -6,
                                        child: Icon(
                                          FontAwesomeIcons.hockeyPuck,
                                          size: 6,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                      // Bottom right
                                      Positioned(
                                        right: -4,
                                        bottom: -8,
                                        child: Icon(
                                          FontAwesomeIcons.hockeyPuck,
                                          size: 8,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * .3,
                                    child: AutoSizeText(
                                      iterationDescription.toLowerCase(),
                                      maxFontSize: 18,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontFamily: "NovecentoSans",
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        remainingShots <= 0
                            ? Container()
                            : Row(
                                children: [
                                  const Icon(
                                    FontAwesomeIcons.calendarCheck,
                                    size: 20,
                                  ),
                                  const SizedBox(
                                    width: 2,
                                  ),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * .4,
                                    child: AutoSizeText(
                                      goalDescription != "" ? goalDescription.toLowerCase() : "N/A".toLowerCase(),
                                      maxFontSize: 18,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontFamily: "NovecentoSans",
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  );
                }
              }

              return Container();
            },
          ),
          Container(
            decoration: BoxDecoration(color: lighten(Theme.of(context).colorScheme.primary, 0.1)),
            padding: const EdgeInsets.only(top: 5, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  "Recent Sessions".toUpperCase(),
                  style: Theme.of(context).textTheme.headlineSmall,
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
          ),
          _buildSessionList(_sessions),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(darken(Theme.of(context).colorScheme.primaryContainer, 0.05)),
                  padding: WidgetStateProperty.all(const EdgeInsets.only(top: 10, right: 12, bottom: 12, left: 12)),
                ),
                onPressed: () {
                  navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
                    return const History();
                  }));
                },
                child: Row(
                  children: [
                    Text(
                      "History".toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 24,
                        fontFamily: 'NovecentoSans',
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4, left: 5),
                      child: Icon(
                        Icons.history_rounded,
                        size: 28,
                        color: Theme.of(context).colorScheme.onPrimary,
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

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildSessionList(List<DocumentSnapshot> sessions) {
    List<Widget> items = [];
    if (_sessions.isNotEmpty) {
      int i = 0;
      for (DocumentSnapshot s in sessions) {
        items.add(_buildSessionItem(ShootingSession.fromSnapshot(s), i++));
      }

      return Column(children: items);
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 25, bottom: 35),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _isLoading
                  ? SizedBox(
                      height: 25,
                      width: 25,
                      child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                    )
                  : _sessions.isEmpty
                      ? Text(
                          "You don't have any sessions yet".toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16,
                          ),
                        )
                      : Container()
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionItem(ShootingSession s, int i) {
    return AbsorbPointer(
      absorbing: _selectedIterationId != _attemptDropdownItems[_attemptDropdownItems.length - 1].value,
      child: Dismissible(
        key: UniqueKey(),
        onDismissed: (direction) async {
          Fluttertoast.showToast(
            msg: '${s.total} shots deleted',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Theme.of(context).cardTheme.color,
            textColor: Theme.of(context).colorScheme.onPrimary,
            fontSize: 16.0,
          );

          await deleteSession(s).then((deleted) {
            if (!deleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Theme.of(context).cardTheme.color,
                  content: Text(
                    "Sorry this session can't be deleted",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  duration: const Duration(milliseconds: 1500),
                ),
              );
            }

            _sessions.clear();
            _loadRecentSessions();
          });
        },
        confirmDismiss: (DismissDirection direction) async {
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  "Delete Session?".toUpperCase(),
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
                      "Are you sure you want to delete this shooting session forever?",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    Container(
                      height: 120,
                      margin: const EdgeInsets.only(top: 15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You will lose:",
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            s.total.toString() + " Shots".toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            "Taken on:",
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            printDate(s.date!),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
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
          padding: const EdgeInsets.only(top: 5, bottom: 15),
          decoration: BoxDecoration(
            color: i % 2 == 0 ? Colors.transparent : Theme.of(context).cardTheme.color,
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
                    Row(
                      children: [
                        Text(
                          s.total.toString() + " Shots".toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontFamily: 'NovecentoSans',
                          ),
                        ),
                        _selectedIterationId != _attemptDropdownItems[_attemptDropdownItems.length - 1].value
                            ? Container()
                            : SizedBox(
                                height: 24,
                                width: 24,
                                child: PopupMenuButton(
                                  key: UniqueKey(),
                                  color: Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
                                  icon: Icon(
                                    Icons.more_horiz_rounded,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 24,
                                  ),
                                  itemBuilder: (_) => <PopupMenuItem<String>>[
                                    i >= 0
                                        ? PopupMenuItem<String>(child: Container())
                                        : PopupMenuItem<String>(
                                            value: 'resume',
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Resume".toUpperCase(),
                                                  style: TextStyle(
                                                    fontFamily: 'NovecentoSans',
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.play_arrow,
                                                  color: wristShotColor,
                                                ),
                                              ],
                                            ),
                                          ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Delete".toUpperCase(),
                                            style: TextStyle(
                                              fontFamily: 'NovecentoSans',
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          Icon(
                                            Icons.delete,
                                            color: Colors.red.shade600,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) async {
                                    if (value == 'resume') {
                                      if (!sessionService.isRunning) {
                                        Feedback.forTap(context);
                                        sessionService.start();
                                        widget.sessionPanelController!.open();
                                        widget.updateSessionShotsCB!();
                                      } else {
                                        dialog(
                                          context,
                                          ConfirmDialog(
                                            "Override current session?",
                                            Text(
                                              "Starting a new session will override your existing one.\n\nWould you like to continue?",
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
                                              Feedback.forTap(context);
                                              sessionService.reset();
                                              Navigator.of(context).pop();
                                              sessionService.start();
                                              widget.sessionPanelController!.show();
                                            },
                                          ),
                                        );
                                      }
                                    } else if (value == 'delete') {
                                      return await showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text(
                                              "Delete Session?".toUpperCase(),
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
                                                  "Are you sure you want to delete this shooting session forever?",
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                  ),
                                                ),
                                                Container(
                                                  height: 120,
                                                  margin: const EdgeInsets.only(top: 15),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "You will lose:",
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Theme.of(context).colorScheme.onPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 5,
                                                      ),
                                                      Text(
                                                        s.total.toString() + " Shots".toUpperCase(),
                                                        style: TextStyle(
                                                          fontFamily: 'NovecentoSans',
                                                          fontSize: 20,
                                                          color: Theme.of(context).colorScheme.onPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 5,
                                                      ),
                                                      Text(
                                                        "Taken on:",
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Theme.of(context).colorScheme.onPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 5,
                                                      ),
                                                      Text(
                                                        printDate(s.date!),
                                                        style: TextStyle(
                                                          fontFamily: 'NovecentoSans',
                                                          fontSize: 20,
                                                          color: Theme.of(context).colorScheme.onPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: Theme.of(context).colorScheme.primary,
                                            actions: <Widget>[
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(),
                                                child: Text(
                                                  "Cancel".toUpperCase(),
                                                  style: TextStyle(
                                                    fontFamily: 'NovecentoSans',
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  Navigator.of(context).pop();
                                                  Fluttertoast.showToast(
                                                    msg: '${s.total} shots deleted',
                                                    toastLength: Toast.LENGTH_SHORT,
                                                    gravity: ToastGravity.BOTTOM,
                                                    timeInSecForIosWeb: 1,
                                                    backgroundColor: Theme.of(context).cardTheme.color,
                                                    textColor: Theme.of(context).colorScheme.onPrimary,
                                                    fontSize: 16.0,
                                                  );

                                                  await deleteSession(s).then((deleted) {
                                                    if (!deleted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          backgroundColor: Theme.of(context).cardTheme.color,
                                                          content: Text(
                                                            "Sorry this session can't be deleted",
                                                            style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onPrimary,
                                                            ),
                                                          ),
                                                          duration: const Duration(milliseconds: 1500),
                                                        ),
                                                      );
                                                    }

                                                    _sessions.clear();
                                                    _loadRecentSessions();
                                                  });
                                                },
                                                child: Text(
                                                  "Delete".toUpperCase(),
                                                  style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).primaryColor),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    }
                                  },
                                ),
                              ),
                      ],
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
                                    SizedBox(
                                      width: calculateSessionShotWidth(s, s.totalWrist!),
                                      child: AutoSizeText(
                                        s.totalWrist.toString(),
                                        maxFontSize: 14,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        Container(
                          width: calculateSessionShotWidth(s, s.totalSnap!),
                          height: 30,
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            color: snapShotColor,
                          ),
                          child: s.totalSnap! < 1
                              ? Container()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: calculateSessionShotWidth(s, s.totalSnap!),
                                      child: AutoSizeText(
                                        s.totalSnap.toString(),
                                        maxFontSize: 14,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
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
                                    SizedBox(
                                      width: calculateSessionShotWidth(s, s.totalBackhand!),
                                      child: AutoSizeText(
                                        s.totalBackhand.toString(),
                                        maxFontSize: 14,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.clip,
                                      ),
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
                                    SizedBox(
                                      width: calculateSessionShotWidth(s, s.totalSlap!),
                                      child: AutoSizeText(
                                        s.totalSlap.toString(),
                                        maxFontSize: 14,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  double calculateSessionShotWidth(ShootingSession session, int shotCount) {
    double percentage = (shotCount / session.total!);
    return (MediaQuery.of(context).size.width - 30) * percentage;
  }
}

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

class History extends StatefulWidget {
  const History({super.key, this.sessionPanelController, this.updateSessionShotsCB});

  final PanelController? sessionPanelController;
  final Function? updateSessionShotsCB;

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;
  ScrollController? sessionsController;
  DocumentSnapshot? _lastVisible;
  bool? _isLoading = true;
  final List<DocumentSnapshot> _sessions = [];
  List<DropdownMenuItem> _attemptDropdownItems = [];
  String? _selectedIterationId;

  DateTime firstSessionDate = DateTime.now();
  DateTime latestSessionDate = DateTime.now();

  @override
  void initState() {
    sessionsController = ScrollController()..addListener(_scrollListener);

    super.initState();

    _loadFirstLastSession();
    _loadHistory();
    _getAttempts();
  }

  Future<Null> _loadFirstLastSession() async {
    if (_selectedIterationId == null) {
      await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: false).get().then((iterationSnap) {
        if (iterationSnap.docs.isNotEmpty) {
          setState(() {
            _selectedIterationId = iterationSnap.docs.first.id;
          });
        }
      });
    }

    await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).collection('sessions').orderBy('date', descending: false).get().then((sessionsSnap) {
      if (sessionsSnap.docs.isNotEmpty) {
        ShootingSession first = ShootingSession.fromSnapshot(sessionsSnap.docs.first);
        ShootingSession latest = ShootingSession.fromSnapshot(sessionsSnap.docs.last);

        setState(() {
          firstSessionDate = first.date!;
          latestSessionDate = latest.date!;
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

  Future<Null> _loadHistory() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (_lastVisible == null) {
      await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).get().then((snapshot) {
        List<DocumentSnapshot> sessions = [];
        snapshot.reference.collection('sessions').orderBy('date', descending: true).limit(8).get().then((sSnap) {
          for (var s in sSnap.docs) {
            sessions.add(s);
          }

          if (sessions.isNotEmpty) {
            _lastVisible = sessions[sessions.length - 1];

            if (mounted) {
              setState(() {
                _isLoading = false;
                _sessions.addAll(sessions);
              });
            }
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        });
      });
    } else {
      await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).get().then((snapshot) {
        List<DocumentSnapshot> sessions = [];
        snapshot.reference.collection('sessions').orderBy('date', descending: true).startAfter([_lastVisible!['date']]).limit(5).get().then((sSnap) {
              for (var s in sSnap.docs) {
                sessions.add(s);
              }

              if (sessions.isNotEmpty) {
                _lastVisible = sessions[sessions.length - 1];
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _sessions.addAll(sessions);
                  });
                }
              } else {
                setState(() => _isLoading = false);
              }
            });
      });
    }
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
                  expandedHeight: 85,
                  automaticallyImplyLeading: false,
                  backgroundColor: HomeTheme.darkTheme.colorScheme.primary,
                  iconTheme: Theme.of(context).iconTheme,
                  actionsIconTheme: Theme.of(context).iconTheme,
                  floating: true,
                  pinned: true,
                  leading: Container(
                    margin: const EdgeInsets.only(top: 10),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).appBarTheme.backgroundColor,
                        size: 28,
                      ),
                      onPressed: () {
                        navigatorKey.currentState!.pop();
                      },
                    ),
                  ),
                  actions: const [],
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(
                      color: HomeTheme.darkTheme.colorScheme.primaryContainer,
                    ),
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      centerTitle: true,
                      title: NavigationTitle(title: "Shooting History".toUpperCase()),
                      background: Container(
                        color: HomeTheme.darkTheme.colorScheme.primaryContainer,
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      DropdownButton<dynamic>(
                        onChanged: (value) {
                          setState(() {
                            _isLoading = true;
                            _sessions.clear();
                            _lastVisible = null;
                            _selectedIterationId = value;
                            _loadFirstLastSession();
                            _loadHistory();
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
                ),
                Container(
                  decoration: BoxDecoration(color: lighten(Theme.of(context).colorScheme.primary, 0.1)),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        Iteration i = Iteration.fromSnapshot(snapshot.data as DocumentSnapshot);

                        if (i.endDate != null) {
                          int daysTaken = i.endDate!.difference(firstSessionDate).inDays + 1;
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
                          int daysSoFar = latestSessionDate.difference(firstSessionDate).inDays + 1;
                          daysSoFar = daysSoFar < 1 ? 1 : daysSoFar;
                          String? targetDate;
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
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: Theme.of(context).primaryColor,
                    child: ListView.builder(
                      controller: sessionsController,
                      padding: EdgeInsets.only(
                        top: 0,
                        right: 0,
                        bottom: !sessionService.isRunning ? AppBar().preferredSize.height : AppBar().preferredSize.height + 65,
                        left: 0,
                      ),
                      itemCount: _sessions.length + 1,
                      itemBuilder: (_, int index) {
                        if (index < _sessions.length) {
                          final DocumentSnapshot document = _sessions[index];
                          return _buildSessionItem(ShootingSession.fromSnapshot(document), index);
                        }
                        return Container(
                          margin: const EdgeInsets.only(top: 25, bottom: 35),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _isLoading!
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
                        );
                      },
                    ),
                    onRefresh: () async {
                      _sessions.clear();
                      _lastVisible = null;
                      await _loadHistory();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    sessionsController!.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    if (!_isLoading!) {
      if (sessionsController!.position.pixels == sessionsController!.position.maxScrollExtent) {
        setState(() => _isLoading = true);
        _loadHistory();
      }
    }
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
            _lastVisible = null;
            _loadHistory();
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
                                                    _lastVisible = null;
                                                    _loadHistory();
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

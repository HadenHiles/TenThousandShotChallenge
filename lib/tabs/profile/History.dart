import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
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
  final user = FirebaseAuth.instance.currentUser;
  ScrollController? sessionsController;
  String? _selectedIterationId;

  DateTime firstSessionDate = DateTime.now();
  DateTime latestSessionDate = DateTime.now();

  @override
  void initState() {
    sessionsController = ScrollController();
    super.initState();
  }

  Future<void> _loadFirstLastSession(String? iterationId) async {
    if (iterationId == null) return;
    final snap = await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(iterationId).collection('sessions').orderBy('date', descending: false).get();
    if (snap.docs.isNotEmpty) {
      ShootingSession first = ShootingSession.fromSnapshot(snap.docs.first);
      ShootingSession latest = ShootingSession.fromSnapshot(snap.docs.last);
      setState(() {
        firstSessionDate = first.date!;
        latestSessionDate = latest.date!;
      });
    }
  }

  // Helper to get if the selected iteration is completed
  bool _isCurrentIterationCompleted(AsyncSnapshot<DocumentSnapshot> iterationSnapshot) {
    if (iterationSnapshot.hasData && iterationSnapshot.data!.exists) {
      final iteration = Iteration.fromSnapshot(iterationSnapshot.data!);
      return iteration.complete ?? false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamProvider<NetworkStatus>(
      create: (context) => NetworkStatusService().networkStatusController.stream,
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
                // Attempts dropdown (realtime)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').orderBy('start_date', descending: false).snapshots(),
                  builder: (context, snapshot) {
                    List<DropdownMenuItem<String>> items = [];
                    if (snapshot.hasData) {
                      snapshot.data!.docs.asMap().forEach((i, iDoc) {
                        items.add(DropdownMenuItem<String>(
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
                      // Set default if not set
                      if (_selectedIterationId == null && items.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _selectedIterationId = items.last.value;
                            _loadFirstLastSession(_selectedIterationId);
                          });
                        });
                      }
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          DropdownButton<String>(
                            onChanged: (value) {
                              setState(() {
                                _selectedIterationId = value;
                                _loadFirstLastSession(_selectedIterationId);
                              });
                            },
                            underline: Container(),
                            dropdownColor: Theme.of(context).colorScheme.primary,
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            value: _selectedIterationId,
                            items: items,
                          ),
                          _shotTypeColumn("Wrist", wristShotColor, "W"),
                          _shotTypeColumn("Snap", snapShotColor, "SN"),
                          _shotTypeColumn("Backhand", backhandShotColor, "B"),
                          _shotTypeColumn("Slap", slapShotColor, "SL"),
                        ],
                      ),
                    );
                  },
                ),
                // Iteration summary (realtime)
                Container(
                  decoration: BoxDecoration(color: lighten(Theme.of(context).colorScheme.primary, 0.1)),
                  child: _selectedIterationId == null
                      ? Container()
                      : StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
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
                                  String targetDate = DateFormat('M/d/y').format(i.targetDate!);
                                  int daysBeforeAfterTarget = i.targetDate!.difference(i.endDate!).inDays;

                                  if (daysBeforeAfterTarget > 0) {
                                    goalDescription += " ${daysBeforeAfterTarget.abs()} day${daysBeforeAfterTarget.abs() == 1 ? '' : 's'} before goal";
                                  } else if (daysBeforeAfterTarget < 0) {
                                    goalDescription += " ${daysBeforeAfterTarget.abs()} day${daysBeforeAfterTarget.abs() == 1 ? '' : 's'} after goal";
                                  }

                                  goalDescription += " ($targetDate)";
                                } else {
                                  goalDescription += "completed on $endDate";
                                }

                                return _iterationSummaryRow(iterationDescription, goalDescription);
                              } else {
                                int daysSoFar = latestSessionDate.difference(firstSessionDate).inDays + 1;
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
                                  int daysBeforeAfterTarget = i.targetDate!.difference(DateTime.now()).inDays;
                                  if (i.targetDate!.compareTo(DateTime.now()) < 0) {
                                    daysBeforeAfterTarget = DateTime.now().difference(i.targetDate!).inDays * -1;
                                  }

                                  if (daysBeforeAfterTarget > 0) {
                                    goalDescription += "${daysBeforeAfterTarget.abs()} day${daysBeforeAfterTarget.abs() == 1 ? '' : 's'} left to take $fRemainingShots shots";
                                  } else if (daysBeforeAfterTarget < 0) {
                                    goalDescription += "${daysBeforeAfterTarget.abs()} day${daysBeforeAfterTarget.abs() == 1 ? '' : 's'} past goal";
                                  } else {
                                    goalDescription += "1 day left to take $fRemainingShots shots";
                                  }
                                }

                                return _iterationSummaryRow(iterationDescription, goalDescription);
                              }
                            }
                            return Container();
                          },
                        ),
                ),
                // Sessions list (realtime)
                Expanded(
                  child: _selectedIterationId == null
                      ? Container()
                      : StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
                          builder: (context, iterationSnapshot) {
                            final iterationCompleted = _isCurrentIterationCompleted(iterationSnapshot);
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').doc(_selectedIterationId).collection('sessions').orderBy('date', descending: true).snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                  return Center(
                                    child: Text(
                                      "You don't have any sessions yet".toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'NovecentoSans',
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  );
                                }
                                final sessions = snapshot.data!.docs;
                                return RefreshIndicator(
                                  color: Theme.of(context).primaryColor,
                                  onRefresh: () async {
                                    // No-op: StreamBuilder handles updates
                                  },
                                  child: ListView.builder(
                                    controller: sessionsController,
                                    padding: EdgeInsets.only(
                                      top: 0,
                                      right: 0,
                                      bottom: !sessionService.isRunning ? AppBar().preferredSize.height : AppBar().preferredSize.height + 65,
                                      left: 0,
                                    ),
                                    itemCount: sessions.length,
                                    itemBuilder: (_, int index) {
                                      final document = sessions[index];
                                      return _buildSessionItem(
                                        ShootingSession.fromSnapshot(document),
                                        index,
                                        iterationCompleted, // Pass completed status
                                      );
                                    },
                                  ),
                                );
                              },
                            );
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

  Widget _shotTypeColumn(String label, Color color, String abbr) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
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
          decoration: BoxDecoration(color: color),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.75,
                child: Text(
                  abbr,
                  style: const TextStyle(
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
    );
  }

  Widget _iterationSummaryRow(String iterationDescription, String goalDescription) {
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
              const SizedBox(width: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(FontAwesomeIcons.hockeyPuck, size: 14, color: Theme.of(context).colorScheme.onPrimary),
                  Positioned(left: -6, top: -6, child: Icon(FontAwesomeIcons.hockeyPuck, size: 8, color: Theme.of(context).colorScheme.onPrimary)),
                  Positioned(left: -5, bottom: -5, child: Icon(FontAwesomeIcons.hockeyPuck, size: 6, color: Theme.of(context).colorScheme.onPrimary)),
                  Positioned(right: -4, top: -6, child: Icon(FontAwesomeIcons.hockeyPuck, size: 6, color: Theme.of(context).colorScheme.onPrimary)),
                  Positioned(right: -4, bottom: -8, child: Icon(FontAwesomeIcons.hockeyPuck, size: 8, color: Theme.of(context).colorScheme.onPrimary)),
                ],
              ),
              const SizedBox(width: 8),
              AutoSizeText(
                iterationDescription.toLowerCase(),
                maxFontSize: 16,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontFamily: "NovecentoSans",
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FontAwesomeIcons.calendarCheck, size: 20),
              const SizedBox(width: 4),
              AutoSizeText(
                goalDescription.toLowerCase(),
                maxFontSize: 18,
                maxLines: 2,
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
  }

  Widget _buildSessionItem(ShootingSession s, int i, bool iterationCompleted) {
    return AbsorbPointer(
      absorbing: iterationCompleted,
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
          await deleteSession(s);
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
                          const SizedBox(height: 5),
                          Text(
                            s.total.toString() + " Shots".toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Taken on:",
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
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
                      ],
                    ),
                  ],
                ),
              ),
              // Shot bars
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
                        _shotBar(s, s.totalWrist!, wristShotColor),
                        _shotBar(s, s.totalSnap!, snapShotColor),
                        _shotBar(s, s.totalBackhand!, backhandShotColor),
                        _shotBar(s, s.totalSlap!, slapShotColor),
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
                        _shotLabel(s, s.totalWrist!, "W"),
                        _shotLabel(s, s.totalSnap!, "SN"),
                        _shotLabel(s, s.totalBackhand!, "B"),
                        _shotLabel(s, s.totalSlap!, "SL"),
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

  Widget _shotBar(ShootingSession s, int shotCount, Color color) {
    return Container(
      width: calculateSessionShotWidth(s, shotCount),
      height: 30,
      decoration: BoxDecoration(color: color),
      child: shotCount < 1
          ? Container()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: calculateSessionShotWidth(s, shotCount),
                  child: AutoSizeText(
                    shotCount.toString(),
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
    );
  }

  Widget _shotLabel(ShootingSession s, int shotCount, String label) {
    return SizedBox(
      width: calculateSessionShotWidth(s, shotCount),
      child: shotCount < 1
          ? Container()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Opacity(
                  opacity: 0.5,
                  child: Text(
                    label,
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
    );
  }

  double calculateSessionShotWidth(ShootingSession session, int shotCount) {
    double percentage = (shotCount / session.total!);
    return (MediaQuery.of(context).size.width - 30) * percentage;
  }
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/ShotCount.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/ShotBreakdownDonut.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import '../main.dart';

class Shots extends StatefulWidget {
  Shots({Key key, this.sessionPanelController}) : super(key: key);

  final PanelController sessionPanelController;

  @override
  _ShotsState createState() => _ShotsState();
}

class _ShotsState extends State<Shots> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;
  DateTime _targetDate;
  TextEditingController _targetDateController = TextEditingController();
  bool _showShotsPerDay = true;

  @override
  void initState() {
    super.initState();
    _loadTargetDate();
  }

  Future<Null> _loadTargetDate() async {
    await FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).get().then((iSnap) {
      if (iSnap.docs.isNotEmpty) {
        Iteration i = Iteration.fromSnapshot(iSnap.docs[0]);
        setState(() {
          _targetDate = i.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100);
        });

        _targetDateController.text = DateFormat('MMMM d, y').format(i.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100));
      }
    });
  }

  void _editTargetDate() {
    DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1),
      maxTime: DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day),
      onChanged: (date) {},
      onConfirm: (date) async {
        setState(() {
          _targetDate = date;
        });

        _targetDateController.text = DateFormat('MMMM d, y').format(date);

        await FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).get().then((iSnap) async {
          if (iSnap.docs.isNotEmpty) {
            DocumentReference ref = iSnap.docs[0].reference;
            Iteration i = Iteration.fromSnapshot(iSnap.docs[0]);
            Iteration updated = Iteration(i.startDate, date, i.endDate, i.totalDuration, i.total, i.totalWrist, i.totalSnap, i.totalSlap, i.totalBackhand, i.complete);
            await ref.update(updated.toMap()).then((_) async {
              _loadTargetDate();
            });
          }
        });
      },
      currentTime: _targetDate,
      locale: LocaleType.en,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                margin: EdgeInsets.only(
                  bottom: 15,
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
                        Container(
                          width: 150,
                          child: StreamBuilder(
                            stream: FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                );
                              } else if (snapshot.data.docs.length > 0) {
                                Iteration i = Iteration.fromSnapshot(snapshot.data.docs[0]);

                                _targetDateController.text = DateFormat('MMMM d, y').format(i.targetDate);

                                return TextField(
                                  controller: _targetDateController,
                                  decoration: InputDecoration(
                                    labelText: "10,000 Shots By:".toUpperCase(),
                                    labelStyle: TextStyle(
                                      color: preferences.darkMode ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryVariant, 0.3),
                                      fontFamily: "NovecentoSans",
                                      fontSize: 22,
                                    ),
                                    focusColor: Theme.of(context).colorScheme.primary,
                                    border: null,
                                    disabledBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.all(2),
                                    fillColor: Theme.of(context).colorScheme.primaryVariant,
                                  ),
                                  readOnly: true,
                                  onTap: () {
                                    _editTargetDate();
                                  },
                                );
                              } else {
                                return Container();
                              }
                            },
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: 0,
                          child: InkWell(
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.edit,
                                size: 18,
                              ),
                            ),
                            enableFeedback: true,
                            focusColor: Theme.of(context).colorScheme.primaryVariant,
                            onTap: _editTargetDate,
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 80,
                          child: StreamBuilder(
                            stream: FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                );
                              } else if (snapshot.data.docs.length > 0) {
                                Iteration i = Iteration.fromSnapshot(snapshot.data.docs[0]);
                                int total = i.total >= 10000 ? 10000 : i.total;
                                int shotsRemaining = 10000 - total;
                                int daysRemaining = i.targetDate.difference(DateTime.now()).inDays;
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

                                String shotsPerDayText = shotsRemaining < 1
                                    ? "Done!".toUpperCase()
                                    : shotsPerDay <= 999
                                        ? shotsPerDay.toString() + " / Day".toUpperCase()
                                        : numberFormat.format(shotsPerDay) + " / Day".toUpperCase();
                                String shotsPerWeekText = shotsRemaining < 1
                                    ? "Done!".toUpperCase()
                                    : shotsPerWeek <= 999
                                        ? shotsPerWeek.toString() + " / Week".toUpperCase()
                                        : numberFormat.format(shotsPerWeek) + " / Week".toUpperCase();

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showShotsPerDay = !_showShotsPerDay;
                                    });
                                  },
                                  child: AutoSizeText(
                                    _showShotsPerDay ? shotsPerDayText : shotsPerWeekText,
                                    maxFontSize: 26,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontFamily: "NovecentoSans",
                                      fontSize: 26,
                                    ),
                                  ),
                                );
                              } else {
                                return Container();
                              }
                            },
                          ),
                        ),
                        InkWell(
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.swap_vert,
                              size: 18,
                            ),
                          ),
                          enableFeedback: true,
                          focusColor: Theme.of(context).colorScheme.primaryVariant,
                          onTap: () {
                            setState(() {
                              _showShotsPerDay = !_showShotsPerDay;
                            });
                          },
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    "Progress".toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 26,
                      fontFamily: 'NovecentoSans',
                    ),
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
                        margin: EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(color: wristShotColor),
                        child: Column(
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
                        margin: EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(color: snapShotColor),
                        child: Column(
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
                        margin: EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(color: backhandShotColor),
                        child: Column(
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
                        margin: EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(color: slapShotColor),
                        child: Column(
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
              SizedBox(
                height: 25,
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: LinearProgressIndicator(),
                    );
                  } else if (snapshot.data.docs.length > 0) {
                    Iteration iteration = Iteration.fromSnapshot(snapshot.data.docs[0]);
                    int maxIterationTotalForWidth = iteration.total <= 10000 ? iteration.total : 10000;
                    int iterationTotal = iteration.total < 10000 ? 10000 : iteration.total;
                    double totalShotsWidth = (maxIterationTotalForWidth / 10000) * (MediaQuery.of(context).size.width - 60);

                    return Column(
                      children: [
                        Container(
                          width: (MediaQuery.of(context).size.width),
                          margin: EdgeInsets.symmetric(horizontal: 30),
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
                              Container(
                                height: 40,
                                width: (iteration.totalWrist / iterationTotal) * totalShotsWidth,
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: wristShotColor,
                                ),
                              ),
                              Container(
                                height: 40,
                                width: (iteration.totalSnap / iterationTotal) * totalShotsWidth,
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: snapShotColor,
                                ),
                              ),
                              Container(
                                height: 40,
                                width: (iteration.totalBackhand / iterationTotal) * totalShotsWidth,
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: backhandShotColor,
                                ),
                              ),
                              Container(
                                height: 40,
                                width: (iteration.totalSlap / iterationTotal) * totalShotsWidth,
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: slapShotColor,
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
                                    ? 40
                                    : totalShotsWidth > (MediaQuery.of(context).size.width - 140)
                                        ? totalShotsWidth - 65
                                        : totalShotsWidth,
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  iteration.total <= 999 ? iteration.total.toString() : numberFormat.format(iteration.total),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: 'NovecentoSans',
                                    fontSize: 22,
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
                                    padding: EdgeInsets.symmetric(horizontal: 2),
                                    child: Text(
                                      " / " + numberFormat.format(10000),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontFamily: 'NovecentoSans',
                                        fontSize: 22,
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
                    );
                  } else {
                    return Container();
                  }
                },
              ),
              SizedBox(
                height: 25,
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SizedBox(
                          height: 150,
                          width: 150,
                          child: CircularProgressIndicator(),
                        ),
                      ],
                    );
                  } else if (snapshot.data.docs.length > 0) {
                    Iteration iteration = Iteration.fromSnapshot(snapshot.data.docs[0]);
                    List<ShotCount> shotCounts = [
                      ShotCount('Wrist'.toUpperCase(), iteration.totalWrist ?? 0, charts.MaterialPalette.cyan.shadeDefault),
                      ShotCount('Snap'.toUpperCase(), iteration.totalSnap ?? 0, charts.MaterialPalette.blue.shadeDefault),
                      ShotCount('Backhand'.toUpperCase(), iteration.totalBackhand ?? 0, charts.MaterialPalette.indigo.shadeDefault),
                      ShotCount('Slap'.toUpperCase(), iteration.totalSlap ?? 0, charts.MaterialPalette.teal.shadeDefault),
                    ];

                    List<charts.Series<ShotCount, dynamic>> shotCountSeries = [
                      charts.Series<ShotCount, dynamic>(
                        id: 'Shots',
                        domainFn: (ShotCount shot, _) => shot.type,
                        measureFn: (ShotCount shot, _) => shot.count,
                        data: shotCounts,
                        colorFn: (ShotCount shot, _) => shot.color,
                        // Set a label accessor to control the text of the arc label.
                        labelAccessorFn: (ShotCount row, _) => '${row.type}\n${row.count}',
                      ),
                    ];

                    return Container(
                      height: MediaQuery.of(context).size.height * 0.3,
                      width: MediaQuery.of(context).size.width * 0.75,
                      child: iteration.total < 1
                          ? Container(
                              child: Text(
                                "Tap \"Start Shooting\" to record a shooting session!".toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : ShotBreakdownDonut(shotCountSeries),
                    );
                  } else {
                    return Container(
                      child: Column(
                        children: [
                          Text(
                            "You haven't taken any shots yet".toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Text(
                            "Tap \"Start Shooting\" to begin!".toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          SessionServiceProvider(
            service: sessionService,
            child: AnimatedBuilder(
              animation: sessionService, // listen to ChangeNotifier
              builder: (context, child) {
                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.only(
                          bottom: !sessionService.isRunning ? AppBar().preferredSize.height : AppBar().preferredSize.height + 65,
                        ),
                        child: Column(
                          children: [
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data.docs.length > 0) {
                                  Iteration iteration = Iteration.fromSnapshot(snapshot.data.docs[0]);

                                  return iteration.total < 10000
                                      ? Container()
                                      : Container(
                                          width: MediaQuery.of(context).size.width - 30,
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              primary: Colors.white,
                                              padding: EdgeInsets.all(10),
                                              backgroundColor: Theme.of(context).cardTheme.color,
                                            ),
                                            onPressed: () {
                                              dialog(
                                                context,
                                                ConfirmDialog(
                                                  "Start a new challenge?",
                                                  Text(
                                                    "Your current challenge data will remain in your profile.\n\nWould you like to continue?",
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onBackground,
                                                    ),
                                                  ),
                                                  "Cancel",
                                                  () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  "Continue",
                                                  () {
                                                    startNewIteration().then((success) {
                                                      if (success) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            backgroundColor: Theme.of(context).cardTheme.color,
                                                            duration: Duration(milliseconds: 1200),
                                                            content: Text(
                                                              'Challenge restarted!',
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
                                                            duration: Duration(milliseconds: 1200),
                                                            content: Text(
                                                              'There was an error restarting the challenge :(',
                                                              style: TextStyle(
                                                                color: Theme.of(context).colorScheme.onPrimary,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    });

                                                    navigatorKey.currentState.pop();
                                                  },
                                                ),
                                              );
                                            },
                                            child: Text(
                                              'Start New Challenge'.toUpperCase(),
                                              style: TextStyle(
                                                fontFamily: 'NovecentoSans',
                                                color: Theme.of(context).colorScheme.onPrimary,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        );
                                }
                                return Container();
                              },
                            ),
                            sessionService.isRunning
                                ? Container()
                                : Container(
                                    padding: EdgeInsets.symmetric(vertical: 15),
                                    width: MediaQuery.of(context).size.width - 30,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        primary: Colors.white,
                                        padding: EdgeInsets.all(10),
                                        backgroundColor: Theme.of(context).buttonColor,
                                      ),
                                      onPressed: () {
                                        if (!sessionService.isRunning) {
                                          sessionService.start();
                                          widget.sessionPanelController.open();
                                        } else {
                                          dialog(
                                            context,
                                            ConfirmDialog(
                                              "Override current session?",
                                              Text(
                                                "Starting a new session will override your existing one.\n\nWould you like to continue?",
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onBackground,
                                                ),
                                              ),
                                              "Cancel",
                                              () {
                                                Navigator.of(context).pop();
                                              },
                                              "Continue",
                                              () {
                                                sessionService.reset();
                                                Navigator.of(context).pop();
                                                sessionService.start();
                                                widget.sessionPanelController.show();
                                              },
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        'Start Shooting'.toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/ShotCount.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/ShotBreakdownDonut.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        Column(
          children: [
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
                } else {
                  Iteration iteration = Iteration.fromSnapshot(snapshot.data.docs[0]);
                  double totalShotsWidth = (iteration.total / 10000) * (MediaQuery.of(context).size.width - 30);

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
                              width: (iteration.totalWrist / 10000) * totalShotsWidth,
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: wristShotColor,
                              ),
                            ),
                            Container(
                              height: 40,
                              width: (iteration.totalSnap / 10000) * totalShotsWidth,
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: snapShotColor,
                              ),
                            ),
                            Container(
                              height: 40,
                              width: (iteration.totalBackhand / 10000) * totalShotsWidth,
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: backhandShotColor,
                              ),
                            ),
                            Container(
                              height: 40,
                              width: (iteration.totalSlap / 10000) * totalShotsWidth,
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
                              width: totalShotsWidth < 25 ? 40 : totalShotsWidth,
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
                } else {
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
                    height: 280,
                    width: MediaQuery.of(context).size.width - 100,
                    child: iteration.total < 1
                        ? Container(
                            child: Text(
                              "No shots recorded for this challenge yet. Check your profile for your session history.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : ShotBreakdownDonut(shotCountSeries),
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
    );
  }
}

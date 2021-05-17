import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/ShotCount.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
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
  List<Iteration> _iterations = [];

  @override
  void initState() {
    List<Iteration> iterations = [];
    FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').get().then((snapshot) {
      snapshot.docs.forEach((doc) {
        iterations.add(Iteration.fromMap(doc.data()));
      });

      setState(() {
        _iterations = iterations;
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _iterations.length < 1
            ? Container()
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return SizedBox(
                      height: 30,
                      width: 30,
                      child: CircularProgressIndicator(),
                    );
                  } else {
                    List<ShotCount> shotCounts = [
                      ShotCount('Wrist'.toUpperCase(), Iteration.fromMap(snapshot.data.docs[0].data()).totalWrist ?? 0, charts.MaterialPalette.cyan.shadeDefault),
                      ShotCount('Snap'.toUpperCase(), Iteration.fromMap(snapshot.data.docs[0].data()).totalSnap ?? 0, charts.MaterialPalette.blue.shadeDefault),
                      ShotCount('Backhand'.toUpperCase(), Iteration.fromMap(snapshot.data.docs[0].data()).totalBackhand ?? 0, charts.MaterialPalette.indigo.shadeDefault),
                      ShotCount('Slap'.toUpperCase(), Iteration.fromMap(snapshot.data.docs[0].data()).totalSlap ?? 0, charts.MaterialPalette.teal.shadeDefault),
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
                      child: ShotBreakdownDonut(shotCountSeries),
                    );
                  }
                },
              ),
        SessionServiceProvider(
          service: sessionService,
          child: AnimatedBuilder(
            animation: sessionService, // listen to ChangeNotifier
            builder: (context, child) {
              return Container(
                padding: EdgeInsets.only(
                  bottom: !sessionService.isRunning ? AppBar().preferredSize.height : AppBar().preferredSize.height + 65,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
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
              );
            },
          ),
        ),
      ],
    );
  }
}

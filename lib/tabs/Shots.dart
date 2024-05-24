import 'package:auto_size_text/auto_size_text.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../main.dart';

class Shots extends StatefulWidget {
  const Shots({Key? key, required this.sessionPanelController}) : super(key: key);

  final PanelController sessionPanelController;

  @override
  State<Shots> createState() => _ShotsState();
}

class _ShotsState extends State<Shots> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;
  DateTime? _targetDate;
  final TextEditingController _targetDateController = TextEditingController();
  bool _showShotsPerDay = true;

  @override
  void initState() {
    super.initState();
    _loadTargetDate();
  }

  Future<Null> _loadTargetDate() async {
    await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: false).get().then((iSnap) {
      if (iSnap.docs.isNotEmpty) {
        Iteration i = Iteration.fromSnapshot(iSnap.docs[0]);
        setState(() {
          _targetDate = i.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100);
        });

        _targetDateController.text = DateFormat('MMMM d, y').format(i.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100));
      } else {
        setState(() {
          _targetDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100);
        });

        _targetDateController.text = DateFormat('MMMM d, y').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100));
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

        await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: false).get().then((iSnap) async {
          if (iSnap.docs.isNotEmpty) {
            DocumentReference ref = iSnap.docs[0].reference;
            Iteration i = Iteration.fromSnapshot(iSnap.docs[0]);
            Iteration updated = Iteration(i.startDate, date, i.endDate, i.totalDuration, i.total, i.totalWrist, i.totalSnap, i.totalSlap, i.totalBackhand, i.complete, DateTime.now());
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        Column(
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
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return CircularProgressIndicator(
                                      color: Theme.of(context).primaryColor,
                                    );
                                  } else if (snapshot.data!.docs.isNotEmpty) {
                                    Iteration i = Iteration.fromSnapshot(snapshot.data!.docs[0]);

                                    _targetDateController.text = DateFormat('MMMM d, y').format(i.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100));

                                    return AutoSizeTextField(
                                      controller: _targetDateController,
                                      style: const TextStyle(fontSize: 20),
                                      maxLines: 1,
                                      maxFontSize: 20,
                                      decoration: InputDecoration(
                                        labelText: "10,000 Shots By:".toLowerCase(),
                                        labelStyle: TextStyle(
                                          color: preferences!.darkMode! ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
                                          fontFamily: "NovecentoSans",
                                        ),
                                        focusColor: Theme.of(context).colorScheme.primary,
                                        border: null,
                                        disabledBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(2),
                                        fillColor: Theme.of(context).colorScheme.primaryContainer,
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
                                enableFeedback: true,
                                focusColor: Theme.of(context).colorScheme.primaryContainer,
                                onTap: _editTargetDate,
                                borderRadius: BorderRadius.circular(30),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.edit,
                                    size: 18,
                                  ),
                                ),
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
                              width: 80,
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    );
                                  } else if (snapshot.data!.docs.isNotEmpty) {
                                    Iteration i = Iteration.fromSnapshot(snapshot.data!.docs[0]);
                                    int? total = i.total! >= 10000 ? 10000 : i.total;
                                    int shotsRemaining = 10000 - total!;
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

                                    String shotsPerDayText = shotsRemaining < 1
                                        ? "Done!".toLowerCase()
                                        : shotsPerDay <= 999
                                            ? shotsPerDay.toString() + " / Day".toLowerCase()
                                            : numberFormat.format(shotsPerDay) + " / Day".toLowerCase();
                                    String shotsPerWeekText = shotsRemaining < 1
                                        ? "Done!".toLowerCase()
                                        : shotsPerWeek <= 999
                                            ? shotsPerWeek.toString() + " / Week".toLowerCase()
                                            : numberFormat.format(shotsPerWeek) + " / Week".toLowerCase();

                                    if (_targetDate!.compareTo(DateTime.now()) < 0) {
                                      daysRemaining = DateTime.now().difference(i.targetDate!).inDays * -1;

                                      shotsPerDayText = "${daysRemaining.abs()} Days Past Goal".toLowerCase();
                                      shotsPerWeekText = shotsRemaining <= 999 ? shotsRemaining.toString() + " remaining".toLowerCase() : numberFormat.format(shotsRemaining) + " remaining".toLowerCase();
                                    }

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
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: LinearProgressIndicator(),
                  );
                } else if (snapshot.data!.docs.isNotEmpty) {
                  Iteration iteration = Iteration.fromSnapshot(snapshot.data!.docs[0]);
                  int? maxIterationTotalForWidth = iteration.total! <= 10000 ? iteration.total : 10000;
                  int? iterationTotal = iteration.total;
                  double totalShotsWidth = (maxIterationTotalForWidth! / 10000) * (MediaQuery.of(context).size.width - 60);

                  return Column(
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
                              message: "${iteration.totalWrist} Wrist Shots".toLowerCase(),
                              preferBelow: false,
                              textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                              child: Container(
                                height: 40,
                                width: iteration.totalWrist! > 0 ? (iteration.totalWrist! / iterationTotal!) * totalShotsWidth : 0,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: const BoxDecoration(
                                  color: wristShotColor,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: "${iteration.totalSnap} Snap Shots".toLowerCase(),
                              preferBelow: false,
                              textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                              child: Container(
                                height: 40,
                                width: iteration.totalSnap! > 0 ? (iteration.totalSnap! / iterationTotal!) * totalShotsWidth : 0,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: const BoxDecoration(
                                  color: snapShotColor,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: "${iteration.totalBackhand} Backhands".toLowerCase(),
                              preferBelow: false,
                              textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                              child: Container(
                                height: 40,
                                width: iteration.totalBackhand! > 0 ? (iteration.totalBackhand! / iterationTotal!) * totalShotsWidth : 0,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: const BoxDecoration(
                                  color: backhandShotColor,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: "${iteration.totalSlap} Slap Shots".toLowerCase(),
                              preferBelow: false,
                              textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                              child: Container(
                                height: 40,
                                width: iteration.totalSlap! > 0 ? (iteration.totalSlap! / iterationTotal!) * totalShotsWidth : 0,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: const BoxDecoration(
                                  color: slapShotColor,
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
                                  ? 40
                                  : totalShotsWidth > (MediaQuery.of(context).size.width - 140)
                                      ? totalShotsWidth - 65
                                      : totalShotsWidth,
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                iteration.total! <= 999 ? iteration.total.toString() : numberFormat.format(iteration.total),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Text(
                                    " / ${numberFormat.format(10000)}",
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
            const SizedBox(
              height: 5,
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Column(
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
                } else if (snapshot.data!.docs.isNotEmpty) {
                  Iteration iteration = Iteration.fromSnapshot(snapshot.data!.docs[0]);
                  List<ShotCount> shotCounts = [
                    ShotCount('W'.toUpperCase(), iteration.totalWrist ?? 0, Colors.cyan),
                    ShotCount('SN'.toUpperCase(), iteration.totalSnap ?? 0, Colors.blue),
                    ShotCount('B'.toUpperCase(), iteration.totalBackhand ?? 0, Colors.indigo),
                    ShotCount('SL'.toUpperCase(), iteration.totalSlap ?? 0, Colors.teal),
                  ];

                  return Column(
                    children: [
                      Container(
                        margin: EdgeInsets.only(
                          left: MediaQuery.of(context).size.width * .1,
                          right: MediaQuery.of(context).size.width * .1,
                          bottom: 5,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
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
                                SizedBox(
                                  width: 50,
                                  child: AutoSizeText(
                                    iteration.totalWrist! > 999 ? numberFormat.format(iteration.totalWrist).toLowerCase() : iteration.totalWrist.toString().toLowerCase(),
                                    maxFontSize: 18,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 18,
                                      fontFamily: 'NovecentoSans',
                                    ),
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
                                SizedBox(
                                  width: 50,
                                  child: AutoSizeText(
                                    iteration.totalSnap! > 999 ? numberFormat.format(iteration.totalSnap).toLowerCase() : iteration.totalSnap.toString().toLowerCase(),
                                    maxFontSize: 18,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 18,
                                      fontFamily: 'NovecentoSans',
                                    ),
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
                                SizedBox(
                                  width: 50,
                                  child: AutoSizeText(
                                    iteration.totalBackhand! > 999 ? numberFormat.format(iteration.totalBackhand).toLowerCase() : iteration.totalBackhand.toString().toLowerCase(),
                                    maxFontSize: 18,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 18,
                                      fontFamily: 'NovecentoSans',
                                    ),
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
                                SizedBox(
                                  width: 50,
                                  child: AutoSizeText(
                                    iteration.totalSlap! > 999 ? numberFormat.format(iteration.totalSlap).toLowerCase() : iteration.totalSlap.toString().toLowerCase(),
                                    maxFontSize: 18,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 18,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: iteration.total! < 1
                            ? Text(
                                "Tap \"Start Shooting\" to record a shooting session!".toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              )
                            : Stack(
                                children: [
                                  Positioned(
                                    top: MediaQuery.of(context).size.height * (0.3 / 2),
                                    left: MediaQuery.of(context).size.width * (0.7 / 2),
                                    child: Transform.translate(
                                      offset: const Offset(-14, -16),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(
                                            FontAwesomeIcons.hockeyPuck,
                                            size: 30,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                          // Top Left
                                          Positioned(
                                            left: -13,
                                            top: -13,
                                            child: Icon(
                                              FontAwesomeIcons.hockeyPuck,
                                              size: 18,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          // Bottom Left
                                          Positioned(
                                            left: -12,
                                            bottom: -12,
                                            child: Icon(
                                              FontAwesomeIcons.hockeyPuck,
                                              size: 14,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          // Top right
                                          Positioned(
                                            right: -12,
                                            top: -12,
                                            child: Icon(
                                              FontAwesomeIcons.hockeyPuck,
                                              size: 14,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          // Bottom right
                                          Positioned(
                                            right: -12,
                                            bottom: -14,
                                            child: Icon(
                                              FontAwesomeIcons.hockeyPuck,
                                              size: 18,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ShotBreakdownDonut(shotCounts),
                                ],
                              ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Text(
                        "You haven't taken any shots yet".toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        "Tap \"Start Shooting\" to begin!".toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 28,
                        ),
                      ),
                    ],
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
                            stream: FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: false).snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                Iteration iteration = Iteration.fromSnapshot(snapshot.data!.docs[0]);

                                return iteration.total! < 10000
                                    ? Container()
                                    : SizedBox(
                                        width: MediaQuery.of(context).size.width - 30,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.all(10),
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
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                ),
                                                "Cancel",
                                                () {
                                                  Navigator.of(context).pop();
                                                },
                                                "Continue",
                                                () {
                                                  startNewIteration().then((success) {
                                                    if (success!) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          backgroundColor: Theme.of(context).cardTheme.color,
                                                          duration: const Duration(milliseconds: 1200),
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
                                                          duration: const Duration(milliseconds: 1200),
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

                                                  navigatorKey.currentState!.pop();
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
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  width: MediaQuery.of(context).size.width - 30,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.all(10),
                                      backgroundColor: Theme.of(context).primaryColor,
                                    ),
                                    onPressed: () {
                                      if (!sessionService.isRunning) {
                                        Feedback.forTap(context);
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
                                              widget.sessionPanelController.show();
                                            },
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      'Start Shooting'.toUpperCase(),
                                      style: const TextStyle(
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

// ignore_for_file: constant_identifier_names

import 'package:auto_size_text/auto_size_text.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:intl/intl.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import '../main.dart';

const TEAM_HEADER_HEIGHT = 65.0;

class Team extends StatefulWidget {
  const Team({Key? key}) : super(key: key);

  @override
  State<Team> createState() => _TeamState();
}

class _TeamState extends State<Team> with SingleTickerProviderStateMixin {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;
  DateTime? _targetDate;
  final TextEditingController _targetDateController = TextEditingController();
  bool _showShotsPerDay = true;
  bool hasTeam = false;
  UserProfile? userProfile;

  @override
  void initState() {
    FirebaseFirestore.instance.collection('users').doc(user!.uid).get().then((uDoc) {
      userProfile = UserProfile.fromSnapshot(uDoc);
    });

    super.initState();
    _loadTeam();
    _loadTargetDate();
  }

  Future<Null> _loadTeam() async {
    if (userProfile!.teamId!.isNotEmpty) {
      setState(() {
        hasTeam = true;
      });
      await FirebaseFirestore.instance.collection('teams').where('owner', isEqualTo: user!.uid).limit(1).get().then((tSnap) async {
        if (tSnap.docs.isNotEmpty) {}
      });
    }
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
                              top: -2,
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
          ],
        ),
      ],
    );
  }
}

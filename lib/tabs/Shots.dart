import 'package:auto_size_text/auto_size_text.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
import 'package:tenthousandshotchallenge/widgets/WeeklyAchievementsWidget.dart';
import '../main.dart';

class Shots extends StatefulWidget {
  const Shots({super.key, required this.sessionPanelController});

  final PanelController sessionPanelController;

  @override
  State<Shots> createState() => _ShotsState();
}

class _ShotsState extends State<Shots> {
  // Static variables
  DateTime? _targetDate;
  final TextEditingController _targetDateController = TextEditingController();
  bool _showShotsPerDay = true;
  Iteration? currentIteration;

  // Move streams to instance variables to avoid recreating in build
  late final Future<QuerySnapshot> _activeIterationFuture;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) {
      // Always initialize _activeIterationFuture to avoid LateInitializationError
      _activeIterationFuture = Future.value(FakeQuerySnapshot());
      // Redirect to login after first build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          GoRouter.of(context).go('/login');
        }
      });
    } else {
      _activeIterationFuture = firestore.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).get();
    }
  }

  void _editTargetDate() {
    DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1),
      maxTime: DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day),
      onChanged: (date) {},
      onConfirm: (date) async {
        if (!mounted) return;
        setState(() {
          _targetDate = date;
        });
        _targetDateController.text = DateFormat('MMMM d, y').format(date);
        final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
        if (user == null) return;
        await Provider.of<FirebaseFirestore>(context, listen: false).collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).get().then((iSnap) async {
          if (iSnap.docs.isNotEmpty) {
            DocumentReference ref = iSnap.docs[0].reference;
            Iteration i = Iteration.fromSnapshot(iSnap.docs[0]);
            if (!mounted) return;
            setState(() {
              currentIteration = i;
            });
            Iteration updated = Iteration(i.startDate, date, i.endDate, i.totalDuration, i.total, i.totalWrist, i.totalSnap, i.totalSlap, i.totalBackhand, i.complete, DateTime.now());
            await ref.update(updated.toMap());
            // Update the text field and state immediately so UI reflects the new date
            setState(() {
              _targetDate = date;
              _targetDateController.text = DateFormat('MMMM d, y').format(date);
            });
            // Force rebuild to update shots/day and week calculation
            setState(() {});
          }
        });
      },
      currentTime: _targetDate,
      locale: LocaleType.en,
    );
  }

  bool _achievementsCollapsed = true;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
        return Column(
          key: const Key('shots_tab_body'),
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    FutureBuilder<QuerySnapshot>(
                      future: _activeIterationFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).primaryColor,
                            ),
                          );
                        } else if (snapshot.data!.docs.isNotEmpty) {
                          Iteration i = Iteration.fromSnapshot(snapshot.data!.docs[0]);
                          // Only update _targetDate and controller if they are null (first load)
                          if (_targetDate == null) {
                            _targetDate = i.targetDate;
                            _targetDateController.text = DateFormat('MMMM d, y').format(i.targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100));
                          }
                          return Row(
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
                                      style: const TextStyle(fontSize: 20),
                                      maxLines: 1,
                                      maxFontSize: 20,
                                      decoration: InputDecoration(
                                        labelText: "10,000 Shots By:".toLowerCase(),
                                        labelStyle: TextStyle(
                                          color: (preferences?.darkMode == true) ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
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
                                    child: user == null
                                        ? Container()
                                        : Builder(
                                            builder: (context) {
                                              int? total = i.total! >= 10000 ? 10000 : i.total;
                                              int shotsRemaining = 10000 - total!;
                                              // Use _targetDate if set, otherwise fallback to i.targetDate
                                              DateTime? targetDate = _targetDate ?? i.targetDate;
                                              int daysRemaining = targetDate != null ? targetDate.difference(DateTime.now()).inDays : 0;
                                              double weeksRemaining = daysRemaining > 0 ? double.parse((daysRemaining / 7).toStringAsFixed(4)) : 0;
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
                                              if (targetDate != null && targetDate.compareTo(DateTime.now()) < 0) {
                                                daysRemaining = DateTime.now().difference(targetDate).inDays * -1;
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
                          );
                        } else {
                          return Container();
                        }
                      },
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
                    FutureBuilder<QuerySnapshot>(
                      future: _activeIterationFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
                          return const Center(
                            child: LinearProgressIndicator(),
                          );
                        } else if (snapshot.data!.docs.isNotEmpty) {
                          Iteration iteration = Iteration.fromSnapshot(snapshot.data!.docs[0]);
                          int maxIterationTotalForWidth = (iteration.total ?? 0) <= 10000 ? (iteration.total ?? 0) : 10000;
                          int iterationTotal = iteration.total ?? 0;
                          double totalShotsWidth = (maxIterationTotalForWidth / 10000) * (MediaQuery.of(context).size.width - 60);
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
                                    Builder(
                                      builder: (context) => Tooltip(
                                        message: "${iteration.totalWrist ?? 0} Wrist Shots".toLowerCase(),
                                        preferBelow: false,
                                        textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                                        child: Container(
                                          height: 40,
                                          width: (iteration.totalWrist ?? 0) > 0 ? ((iteration.totalWrist ?? 0) / (iterationTotal == 0 ? 1 : iterationTotal)) * totalShotsWidth : 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: const BoxDecoration(
                                            color: wristShotColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Builder(
                                      builder: (context) => Tooltip(
                                        message: "${iteration.totalSnap ?? 0} Snap Shots".toLowerCase(),
                                        preferBelow: false,
                                        textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                                        child: Container(
                                          height: 40,
                                          width: (iteration.totalSnap ?? 0) > 0 ? ((iteration.totalSnap ?? 0) / (iterationTotal == 0 ? 1 : iterationTotal)) * totalShotsWidth : 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: const BoxDecoration(
                                            color: snapShotColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Builder(
                                      builder: (context) => Tooltip(
                                        message: "${iteration.totalBackhand ?? 0} Backhands".toLowerCase(),
                                        preferBelow: false,
                                        textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                                        child: Container(
                                          height: 40,
                                          width: (iteration.totalBackhand ?? 0) > 0 ? ((iteration.totalBackhand ?? 0) / (iterationTotal == 0 ? 1 : iterationTotal)) * totalShotsWidth : 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: const BoxDecoration(
                                            color: backhandShotColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Builder(
                                      builder: (context) => Tooltip(
                                        message: "${iteration.totalSlap ?? 0} Slap Shots".toLowerCase(),
                                        preferBelow: false,
                                        textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                                        child: Container(
                                          height: 40,
                                          width: (iteration.totalSlap ?? 0) > 0 ? ((iteration.totalSlap ?? 0) / (iterationTotal == 0 ? 1 : iterationTotal)) * totalShotsWidth : 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: const BoxDecoration(
                                            color: slapShotColor,
                                          ),
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
                                        iterationTotal <= 999 ? iterationTotal.toString() : numberFormat.format(iterationTotal),
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

                    // Weekly Achievements collapsible section below progress bar
                    Card(
                      color: Theme.of(context).cardTheme.color,
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _achievementsCollapsed = !_achievementsCollapsed;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amberAccent, size: 28),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Weekly Achievements',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontFamily: 'NovecentoSans',
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    _achievementsCollapsed ? Icons.expand_more : Icons.expand_less,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 250),
                            crossFadeState: _achievementsCollapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            firstChild: Container(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 10),
                              child: WeeklyAchievementsWidget(showResetCountdown: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    FutureBuilder<QuerySnapshot>(
                      future: _activeIterationFuture,
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
                            ShotCount('Wrist'.toUpperCase(), iteration.totalWrist ?? 0, Colors.cyan),
                            ShotCount('Snap'.toUpperCase(), iteration.totalSnap ?? 0, Colors.blue),
                            ShotCount('Backhand'.toUpperCase(), iteration.totalBackhand ?? 0, Colors.indigo),
                            ShotCount('Slap'.toUpperCase(), iteration.totalSlap ?? 0, Colors.teal),
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
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
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
                                    ),
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
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
                                    ),
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
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
                                    ),
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
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
                                    : Container(
                                        margin: const EdgeInsets.only(top: 50),
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              top: MediaQuery.of(context).size.height * (0.3 / 2),
                                              left: MediaQuery.of(context).size.width * (0.7 / 2),
                                              child: Transform.translate(
                                                offset: const Offset(-14, -40),
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
                              ),
                              isThreeButtonAndroidNavigation(context)
                                  ? SizedBox(
                                      height: MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight,
                                    )
                                  : const SizedBox(height: 30),
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
              ),
            ),
            // Only wrap the session controls in SessionServiceProvider/AnimatedBuilder
            SessionServiceProvider(
              service: sessionService,
              child: AnimatedBuilder(
                animation: sessionService,
                builder: (context, child) {
                  return SafeArea(
                    top: false,
                    child: Container(
                      padding: EdgeInsets.only(
                        bottom: !sessionService.isRunning ? AppBar().preferredSize.height : AppBar().preferredSize.height + 65,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FutureBuilder<QuerySnapshot>(
                            future: _activeIterationFuture,
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
                                                  startNewIteration(
                                                    Provider.of<FirebaseAuth>(context, listen: false),
                                                    Provider.of<FirebaseFirestore>(context, listen: false),
                                                  ).then((success) {
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
                                                  context.pop();
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
                                  padding: isThreeButtonAndroidNavigation(context)
                                      ? EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight)
                                      : EdgeInsets.only(
                                          bottom: 15,
                                        ),
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
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// Minimal fake QuerySnapshot for empty state
class FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];
  @override
  int get size => 0;
  @override
  SnapshotMetadata get metadata => throw UnimplementedError();
}

import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/tabs/profile/QR.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTextField.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/widgets/MobileScanner/barcode_scanner_simple.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

class EditTeam extends StatefulWidget {
  const EditTeam({super.key});

  @override
  State<EditTeam> createState() => _EditTeamState();
}

class _EditTeamState extends State<EditTeam> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final f = NumberFormat("###,###,###", "en_US");
  final TextEditingController teamNameTextFieldController = TextEditingController();
  final TextEditingController teamShotGoalTextFieldController = TextEditingController();
  int? _goalTotal = 0;
  final TextEditingController startDateController = TextEditingController();
  DateTime? _startDate = DateTime.now();
  final TextEditingController targetDateController = TextEditingController();
  DateTime? _targetDate = DateTime.now().add(const Duration(days: 100));
  Team? team;
  bool _public = false;

  @override
  void initState() {
    FirebaseFirestore.instance.collection('users').doc(user!.uid).get().then((uDoc) {
      UserProfile userProfile = UserProfile.fromSnapshot(uDoc);

      FirebaseFirestore.instance.collection('teams').doc(userProfile.teamId).get().then((tDoc) {
        setState(() {
          team = Team.fromSnapshot(tDoc);
          _goalTotal = team!.goalTotal;
          _startDate = team!.startDate;
          _targetDate = team!.targetDate;
          _public = team!.public!;
        });

        teamNameTextFieldController.text = team!.name!;
        teamShotGoalTextFieldController.text = team!.goalTotal!.toString();
        startDateController.text = DateFormat('MMMM d, y').format(team!.startDate!);
        targetDateController.text = DateFormat('MMMM d, y').format(team!.targetDate!);
      });
    });

    super.initState();
  }

  Future<DateTime> _editDate(TextEditingController dateController, DateTime currentDate, DateTime minTime, DateTime maxTime) async {
    DateTime returnDate = currentDate;

    await DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: minTime,
      maxTime: maxTime,
      onChanged: (date) {},
      onConfirm: (date) async {
        dateController.text = DateFormat('MMMM d, y').format(date);
        returnDate = date;
      },
      currentTime: currentDate,
      locale: LocaleType.en,
    );

    return returnDate;
  }

  void _saveTeam() {
    FirebaseFirestore.instance.collection('teams').doc(team!.id).update({
      'name': teamNameTextFieldController.text.toUpperCase().toString(),
      'goal_total': _goalTotal,
      'start_date': _startDate,
      'target_date': _targetDate,
      'public': _public,
    }).then((value) {});

    Fluttertoast.showToast(
      msg: 'Team saved!'.toUpperCase(),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Theme.of(context).cardTheme.color,
      textColor: Theme.of(context).colorScheme.onPrimary,
      fontSize: 16.0,
    );

    _backToTeamPage();
  }

  void _backToTeamPage() {
    Navigator.of(context)
        .pushReplacement(
          MaterialPageRoute(
            builder: (BuildContext context) {
              return Navigation(
                selectedIndex: 2,
                actions: [
                  team!.ownerId != user!.uid
                      ? const SizedBox()
                      : Container(
                          margin: const EdgeInsets.only(top: 10),
                          child: IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: HomeTheme.darkTheme.colorScheme.onPrimary,
                              size: 28,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
                                return const EditTeam();
                              }));
                            },
                          ),
                        ),
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    child: IconButton(
                      icon: Icon(
                        Icons.qr_code_2_rounded,
                        color: HomeTheme.darkTheme.colorScheme.onPrimary,
                        size: 28,
                      ),
                      onPressed: () async {
                        await showTeamQRCode(context).then((hasTeam) async {
                          if (!hasTeam) {
                            final barcodeScanRes = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const BarcodeScannerSimple(title: "Scan Team QR Code"),
                              ),
                            );

                            joinTeam(
                              barcodeScanRes,
                              Provider.of<FirebaseAuth>(context, listen: false),
                              Provider.of<FirebaseFirestore>(context, listen: false),
                            ).then((success) {
                              navigatorKey.currentState!.pushReplacement(MaterialPageRoute(builder: (context) {
                                return Navigation(
                                  selectedIndex: 2,
                                );
                              }));
                            });
                          }
                        });
                      },
                    ),
                  ),
                ],
              );
            },
            maintainState: false,
          ),
        )
        .then((value) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
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
                      expandedHeight: 65,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      floating: true,
                      pinned: true,
                      leading: Container(
                        margin: const EdgeInsets.only(top: 10),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      flexibleSpace: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: FlexibleSpaceBar(
                          collapseMode: CollapseMode.parallax,
                          titlePadding: null,
                          centerTitle: false,
                          title: const BasicTitle(title: "Edit Team"),
                          background: Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                      actions: [
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          child: IconButton(
                            icon: Icon(
                              Icons.check,
                              color: Colors.green.shade600,
                              size: 28,
                            ),
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _saveTeam();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ];
                },
                body: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Team Name:".toLowerCase(),
                                      style: TextStyle(
                                        color: preferences!.darkMode!
                                            ? darken(Theme.of(context).colorScheme.onPrimary, 0.4)
                                            : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
                                        fontFamily: "NovecentoSans",
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                    BasicTextField(
                                      keyboardType: TextInputType.text,
                                      hintText: 'Enter a team name',
                                      controller: teamNameTextFieldController,
                                      validator: (value) {
                                        if (value.isEmpty) {
                                          return 'Please enter a team name';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Team Shooting Goal (number of total team shots)".toLowerCase(),
                                      style: TextStyle(
                                        color: preferences!.darkMode!
                                            ? darken(Theme.of(context).colorScheme.onPrimary, 0.4)
                                            : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
                                        fontFamily: "NovecentoSans",
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                    BasicTextField(
                                      keyboardType: TextInputType.number,
                                      hintText: '# of shots the team is aiming to take',
                                      controller: teamShotGoalTextFieldController,
                                      validator: (value) {
                                        if (value.isEmpty) {
                                          return 'Please enter a shooting goal (number of shots)';
                                        } else if (int.tryParse(value) == null) {
                                          return 'Please enter a valid number';
                                        } else {
                                          setState(() {
                                            _goalTotal = int.parse(value);
                                          });
                                        }

                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Starting From:".toLowerCase(),
                                            style: TextStyle(
                                              color: preferences!.darkMode!
                                                  ? darken(Theme.of(context).colorScheme.onPrimary, 0.4)
                                                  : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
                                              fontFamily: "NovecentoSans",
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.left,
                                          ),
                                          Text(
                                            "By Target Completion Date:".toLowerCase(),
                                            style: TextStyle(
                                              color: preferences!.darkMode!
                                                  ? darken(Theme.of(context).colorScheme.onPrimary, 0.4)
                                                  : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
                                              fontFamily: "NovecentoSans",
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.left,
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.4,
                                            child: AutoSizeTextField(
                                              controller: startDateController,
                                              style: const TextStyle(fontSize: 12),
                                              maxLines: 1,
                                              maxFontSize: 18,
                                              decoration: InputDecoration(
                                                focusColor: Theme.of(context).colorScheme.primary,
                                                contentPadding: const EdgeInsets.all(15),
                                                fillColor: Theme.of(context).colorScheme.primaryContainer,
                                              ),
                                              readOnly: true,
                                              onTap: () async {
                                                await _editDate(
                                                  startDateController,
                                                  team!.startDate!,
                                                  DateTime(DateTime.now().year - 5, DateTime.now().month, DateTime.now().day),
                                                  DateTime.now(),
                                                ).then((date) {
                                                  setState(() {
                                                    _startDate = date;
                                                  });
                                                });
                                              },
                                            ),
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.1,
                                            child: Text(
                                              'To'.toUpperCase(),
                                              style: TextStyle(
                                                color: preferences!.darkMode!
                                                    ? darken(Theme.of(context).colorScheme.onPrimary, 0.4)
                                                    : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
                                                fontFamily: "NovecentoSans",
                                                fontSize: 14,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.4,
                                            child: AutoSizeTextField(
                                              controller: targetDateController,
                                              style: const TextStyle(fontSize: 12),
                                              maxLines: 1,
                                              maxFontSize: 18,
                                              decoration: InputDecoration(
                                                focusColor: Theme.of(context).colorScheme.primary,
                                                contentPadding: const EdgeInsets.all(15),
                                                fillColor: Theme.of(context).colorScheme.primaryContainer,
                                              ),
                                              readOnly: true,
                                              onTap: () async {
                                                await _editDate(
                                                  targetDateController,
                                                  team!.targetDate!,
                                                  _startDate!,
                                                  DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day),
                                                ).then((date) {
                                                  setState(() {
                                                    _targetDate = date;
                                                  });
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Public',
                                              style: Theme.of(context).textTheme.bodyLarge,
                                            ),
                                            Switch(
                                              value: _public,
                                              onChanged: (bool value) {
                                                setState(() {
                                                  _public = value;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              floatingActionButton: Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.all(0),
                padding: const EdgeInsets.all(0),
                child: TextButton(
                  onPressed: () {
                    dialog(
                      context,
                      ConfirmDialog(
                        "Delete team \"${team!.name}\"?".toLowerCase(),
                        Text(
                          "The team will be deleted and all its data will be lost.\n\nWould you like to continue?",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        "Cancel",
                        () {
                          Navigator.of(context).pop();
                        },
                        "Continue",
                        () async {
                          await deleteTeam(team!.id!, Provider.of<FirebaseAuth>(context, listen: false),
                                  Provider.of<FirebaseFirestore>(context, listen: false))
                              .then((r) {
                            if (r) {
                              Fluttertoast.showToast(
                                msg: 'Team deleted!'.toUpperCase(),
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Theme.of(context).cardTheme.color,
                                textColor: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 16.0,
                              );

                              Navigator.of(context).pushReplacement(MaterialPageRoute(
                                builder: (context) {
                                  return const Navigation(selectedIndex: 2);
                                },
                                maintainState: false,
                              ));
                            } else {
                              Fluttertoast.showToast(
                                msg: 'Failed to delete team :('.toUpperCase(),
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.redAccent,
                                textColor: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 16.0,
                              );

                              Navigator.of(context).pop();
                            }
                          });
                        },
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).cardTheme.color,
                    backgroundColor: Theme.of(context).cardTheme.color,
                    disabledForegroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0))),
                  ),
                  child: FittedBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Delete Team".toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontFamily: 'NovecentoSans',
                            fontSize: 24,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 3, left: 4),
                          child: Icon(
                            Icons.delete_forever,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

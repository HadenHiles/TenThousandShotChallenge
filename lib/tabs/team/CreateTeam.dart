import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTextField.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

class CreateTeam extends StatefulWidget {
  const CreateTeam({super.key});

  @override
  State<CreateTeam> createState() => _CreateTeamState();
}

class _CreateTeamState extends State<CreateTeam> {
  User? get user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;
  final _formKey = GlobalKey<FormState>();
  final f = NumberFormat("###,###,###", "en_US");
  final TextEditingController teamNameTextFieldController = TextEditingController();
  final TextEditingController teamShotGoalTextFieldController = TextEditingController(text: "100000");
  int? _goalTotal = 100000;
  final TextEditingController startDateController = TextEditingController();
  DateTime? _startDate = DateTime.now();
  final TextEditingController targetDateController = TextEditingController();
  DateTime? _targetDate = DateTime.now().add(const Duration(days: 100));
  bool _public = false;
  Team? team;

  @override
  void initState() {
    super.initState();
    team = Team("", DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day), DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100), 100000, user?.uid ?? "", true, true, []);
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
    setState(() {
      team!.name = teamNameTextFieldController.text.toUpperCase().toString();
      team!.goalTotal = _goalTotal!;
      team!.startDate = _startDate!;
      team!.targetDate = _targetDate!;
      team!.public = _public;
      team!.ownerId = user!.uid;
      team!.ownerParticipating = true;
    });

    FirebaseFirestore.instance.collection('teams').add(team!.toMap()).then((value) {
      setState(() {
        team!.id = value.id;
      });

      FirebaseFirestore.instance.collection('teams').doc(team!.id).update({'id': team!.id}).then((uValue) {
        Fluttertoast.showToast(
          msg: 'Team "${team!.name}" was created!'.toLowerCase(),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Theme.of(context).cardTheme.color,
          textColor: Theme.of(context).colorScheme.onPrimary,
          fontSize: 16.0,
        );

        FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get().then((u) async {
          UserProfile user = UserProfile.fromSnapshot(u);
          user.id = FirebaseAuth.instance.currentUser!.uid;
          user.teamId = team!.id;
          // Save the updated user doc with the new team id
          u.reference.set(user.toMap()).then((value) {
            // Add the current user to the team players list
            return FirebaseFirestore.instance
                .collection('teams')
                .doc(team!.id)
                .update({
                  'players': [user.id]
                })
                .then((value) => true)
                .onError((error, stackTrace) => false);
          }).onError((error, stackTrace) => false);
        });

        // Navigate to team tab using canonical /app route with tab query param
        context.go('/app?tab=team');
      }).onError((error, stackTrace) {
        Fluttertoast.showToast(
          msg: 'There was an error creating team "${team!.name}" :('.toLowerCase(),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Theme.of(context).colorScheme.error,
          textColor: Colors.white70,
          fontSize: 16.0,
        );
      });
    }).onError((error, stackTrace) {
      Fluttertoast.showToast(
        msg: 'There was an error creating team "${team!.name}" :('.toLowerCase(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Theme.of(context).colorScheme.error,
        textColor: Colors.white70,
        fontSize: 16.0,
      );
    });
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
                          title: const BasicTitle(title: "Create Team"),
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
                                        color: preferences!.darkMode! ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
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
                                        color: preferences!.darkMode! ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
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
                                              color: preferences!.darkMode! ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
                                              fontFamily: "NovecentoSans",
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.left,
                                          ),
                                          Text(
                                            "By Target Completion Date:".toLowerCase(),
                                            style: TextStyle(
                                              color: preferences!.darkMode! ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
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
                                                color: preferences!.darkMode! ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
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
            ),
          ),
        );
      },
    );
  }
}

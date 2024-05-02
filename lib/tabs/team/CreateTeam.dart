import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

class CreateTeam extends StatefulWidget {
  const CreateTeam({Key? key}) : super(key: key);

  @override
  State<CreateTeam> createState() => _CreateTeamState();
}

class _CreateTeamState extends State<CreateTeam> {
  final user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameFieldController = TextEditingController();
  Team? team = Team("", DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day), DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100), 100000, FirebaseAuth.instance.currentUser!.uid, true, true);

  void _saveTeam() {
    setState(() {
      team!.name = nameFieldController.text;
    });
    FirebaseFirestore.instance.collection('teams').add(team!.toMap()).then((value) {
      setState(() {
        team!.id = value.id;
      });

      FirebaseFirestore.instance.collection('teams').doc(value.id).update({'id': value.id}).then((uValue) {
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
          user.teamId = team!.id;
          user.teamOwner = true;
          // Save the updated user doc with the new team id
          return await FirebaseFirestore.instance.doc(u.reference.id).set(user.toMap()).then((value) => true).onError((error, stackTrace) => false);
        });

        navigatorKey.currentState!.pushReplacement(MaterialPageRoute(builder: (context) {
          return const Navigation(selectedIndex: 2);
        }));
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
          backgroundColor: Theme.of(context).colorScheme.background,
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
                        navigatorKey.currentState!.pop();
                      },
                    ),
                  ),
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.background,
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
            body: GestureDetector(
              onTap: () {
                Feedback.forTap(context);

                FocusScopeNode currentFocus = FocusScope.of(context);

                if (!currentFocus.hasPrimaryFocus) {
                  currentFocus.unfocus();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          margin: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.05),
                          width: (MediaQuery.of(context).size.width * 0.7) - 10,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Team Name'.toUpperCase(),
                                    labelText: "Team Name".toUpperCase(),
                                    alignLabelWithHint: true,
                                    labelStyle: TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                    hintStyle: TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      fontSize: 20,
                                      color: Theme.of(context).cardTheme.color,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontFamily: 'NovecentoSans',
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  onChanged: (value) async {
                                    if (value.isNotEmpty) {
                                      team!.name = value;

                                      setState(() {
                                        team = team;
                                      });
                                    }
                                  },
                                  controller: nameFieldController,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return 'Enter a team name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Public',
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    Switch(
                                      value: team!.public!,
                                      onChanged: (bool value) {
                                        team!.public = value;
                                        setState(() {
                                          team = team;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

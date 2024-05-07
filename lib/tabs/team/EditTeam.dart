import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTextField.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

class EditTeam extends StatefulWidget {
  const EditTeam({Key? key}) : super(key: key);

  @override
  State<EditTeam> createState() => _EditTeamState();
}

class _EditTeamState extends State<EditTeam> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController teamNameTextFieldController = TextEditingController();
  Team? team;

  @override
  void initState() {
    FirebaseFirestore.instance.collection('users').doc(user!.uid).get().then((uDoc) {
      UserProfile userProfile = UserProfile.fromSnapshot(uDoc);

      FirebaseFirestore.instance.collection('teams').doc(userProfile.teamId).get().then((tDoc) {
        setState(() {
          team = Team.fromSnapshot(tDoc);
        });

        teamNameTextFieldController.text = team!.name!;
      });
    });

    super.initState();
  }

  void _saveTeam() {
    FirebaseFirestore.instance.collection('teams').doc(team!.id).update({
      'name': teamNameTextFieldController.text.toUpperCase().toString(),
    }).then((value) {});

    Fluttertoast.showToast(
      msg: 'Team saved!'.toLowerCase(),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Theme.of(context).cardTheme.color,
      textColor: Theme.of(context).colorScheme.onPrimary,
      fontSize: 16.0,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return Navigation(selectedIndex: 2, title: NavigationTitle(title: teamNameTextFieldController.text.toUpperCase()));
        },
        maintainState: false,
      ),
    );
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
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (BuildContext context) {
                          return const Navigation(selectedIndex: 2);
                        }));
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: BasicTextField(
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
                          ),
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
  }
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/tabs/team/CreateTeam.dart';
import 'package:tenthousandshotchallenge/widgets/MobileScanner/barcode_scanner_simple.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

class JoinTeam extends StatefulWidget {
  const JoinTeam({super.key});

  @override
  State<JoinTeam> createState() => _JoinTeamState();
}

class _JoinTeamState extends State<JoinTeam> {
  final user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController searchFieldController = TextEditingController();

  List<DocumentSnapshot> _teams = [];
  bool _isSearching = false;
  int? _selectedTeam;

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
                        navigatorKey.currentState!.pop();
                      },
                    ),
                  ),
                  actions: [
                    _selectedTeam == null
                        ? Container()
                        : Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: TextButton(
                              style: Theme.of(context).textButtonTheme.style,
                              onPressed: () {
                                joinTeam(_teams[_selectedTeam!].id).then((success) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Theme.of(context).cardTheme.color,
                                        content: Text(
                                          "Joined team ${Team.fromSnapshot(_teams[_selectedTeam!]).name}!",
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );

                                    setState(() {
                                      _selectedTeam = null;
                                      _teams = [];
                                    });
                                    searchFieldController.text = "";

                                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) {
                                      return const Navigation(
                                        selectedIndex: 2,
                                        title: NavigationTitle(title: "Team"),
                                      );
                                    }));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Theme.of(context).cardTheme.color,
                                        content: Text(
                                          "Failed to join ${Team.fromSnapshot(_teams[_selectedTeam!]).name} :(",
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                });
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 125,
                                    child: AutoSizeText(
                                      ('Join ${Team.fromSnapshot(_teams[_selectedTeam!]).name}').toUpperCase(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontFamily: "NovecentoSans",
                                        fontSize: 18,
                                        height: 1.1,
                                      ),
                                      textAlign: TextAlign.right,
                                      maxLines: 2,
                                      maxFontSize: 18,
                                    ),
                                  ),
                                  Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ],
                              ),
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
                                    hintText: 'Enter Team Name or ID'.toUpperCase(),
                                    labelText: "Find team".toUpperCase(),
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
                                      setState(() {
                                        _isSearching = true;
                                      });

                                      List<DocumentSnapshot> teams = [];
                                      if (value.isNotEmpty) {
                                        await FirebaseFirestore.instance.collection('teams').orderBy('name_lowercase', descending: false).where('public', isEqualTo: true).startAt([value.toLowerCase()]).endAt(['${value.toLowerCase()}\uf8ff']).get().then((tSnaps) async {
                                              for (var tDoc in tSnaps.docs) {
                                                if (tDoc.reference.id != user!.uid) {
                                                  teams.add(tDoc);
                                                }
                                              }
                                            });
                                        if (teams.isEmpty) {
                                          await FirebaseFirestore.instance.collection('teams').orderBy('code', descending: false).where('code', isEqualTo: value.toUpperCase()).get().then((tSnaps) async {
                                            for (var tDoc in tSnaps.docs) {
                                              teams.add(tDoc);
                                            }
                                          });
                                        }

                                        await Future.delayed(const Duration(milliseconds: 500));

                                        setState(() {
                                          _teams = teams;
                                          _isSearching = false;
                                        });
                                      }

                                      setState(() {
                                        _teams = teams;
                                        _isSearching = false;
                                      });
                                    } else {
                                      setState(() {
                                        _teams = [];
                                        _isSearching = false;
                                      });
                                    }
                                  },
                                  controller: searchFieldController,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return 'Enter team name or ID';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Scan".toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 20,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(right: 0),
                                child: IconButton(
                                  onPressed: () async {
                                    final barcodeScanRes = await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const BarcodeScannerSimple(title: "Scan Team QR Code"),
                                      ),
                                    );

                                    joinTeam(barcodeScanRes).then((success) async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Theme.of(context).cardTheme.color,
                                          content: Text(
                                            "You joined the team!",
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          duration: const Duration(milliseconds: 2500),
                                        ),
                                      );

                                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                                        builder: (context) {
                                          return const Navigation(
                                            selectedIndex: 2,
                                          );
                                        },
                                        maintainState: false,
                                      ));
                                    }).onError((error, stackTrace) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Theme.of(context).cardTheme.color,
                                          content: Text(
                                            "There was an error scanning your teams QR code :(",
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          duration: const Duration(milliseconds: 4000),
                                        ),
                                      );
                                    });
                                  },
                                  icon: Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 50,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: _isSearching && _teams.isEmpty && searchFieldController.text.isNotEmpty
                          ? Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Center(
                                  child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                                )
                              ],
                            )
                          : _teams.isEmpty && searchFieldController.text.isNotEmpty
                              ? Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 40),
                                      child: Text(
                                        "Couldn't find your team?",
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          fontSize: 20,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 25),
                                      child: Text(
                                        "Create a new team!".toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          fontSize: 26,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 5),
                                      child: IconButton(
                                        onPressed: () {
                                          navigatorKey.currentState!.push(MaterialPageRoute(builder: (BuildContext context) {
                                            return const CreateTeam();
                                          }));
                                        },
                                        icon: Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 40,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  children: _buildTeamResults(),
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
  }

  List<Widget> _buildTeamResults() {
    List<Widget> teams = [];
    _teams.asMap().forEach((i, doc) {
      Team team = Team.fromSnapshot(doc);

      teams.add(
        GestureDetector(
          onTap: () {
            Feedback.forTap(context);

            FocusScopeNode currentFocus = FocusScope.of(context);

            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }

            setState(() {
              _selectedTeam = _selectedTeam == i ? null : i;
              searchFieldController.text = searchFieldController.text;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: _selectedTeam == i ? Theme.of(context).cardTheme.color : Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            child: Row(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        team.name != null
                            ? SizedBox(
                                width: MediaQuery.of(context).size.width - 235,
                                child: AutoSizeText(
                                  team.name!,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                ),
                              )
                            : Container(),
                      ],
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 135,
                          child: AutoSizeText(
                            "${team.players!.length} Players",
                            maxLines: 1,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'NovecentoSans',
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });

    return teams;
  }
}

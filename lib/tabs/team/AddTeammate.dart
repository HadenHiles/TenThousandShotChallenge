import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';

class AddTeammate extends StatefulWidget {
  AddTeammate({Key key}) : super(key: key);

  @override
  _AddTeammateState createState() => _AddTeammateState();
}

class _AddTeammateState extends State<AddTeammate> {
  final user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController searchFieldController = TextEditingController();

  List<DocumentSnapshot> _teammates = [];
  bool _isSearching = false;
  int _selectedTeammate;

  Future<bool> scanBarcodeNormal() async {
    String barcodeScanRes;

    // Invitee uid (from_uid)
    barcodeScanRes = await FlutterBarcodeScanner.scanBarcode("#ff6666", "Cancel", true, ScanMode.QR);
    print(barcodeScanRes);

    return acceptTeammateBarcode(barcodeScanRes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
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
                margin: EdgeInsets.only(top: 10),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                  onPressed: () {
                    navigatorKey.currentState.pop();
                  },
                ),
              ),
              flexibleSpace: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).backgroundColor,
                ),
                child: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  titlePadding: null,
                  centerTitle: false,
                  title: BasicTitle(title: "Invite Teammate"),
                  background: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
              actions: [
                _selectedTeammate == null
                    ? Container()
                    : Container(
                        margin: EdgeInsets.only(top: 10),
                        child: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 28,
                          ),
                          onPressed: () {
                            sendInvite(user.uid, _teammates[_selectedTeammate].id).then((success) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(UserProfile.fromSnapshot(_teammates[_selectedTeammate]).displayName.toString() + " Invited!"),
                                    duration: Duration(seconds: 4),
                                  ),
                                );

                                setState(() {
                                  _selectedTeammate = null;
                                  _teammates = [];
                                });
                                searchFieldController.text = "";
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Failed to invite " + UserProfile.fromSnapshot(_teammates[_selectedTeammate]).displayName.toString() + " :("),
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                            });
                          },
                        ),
                      ),
              ],
            ),
          ];
        },
        body: Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      margin: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.05),
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                hintText: 'Search Name or Email'.toUpperCase(),
                                hintStyle: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  color: Theme.of(context).cardTheme.color,
                                ),
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontFamily: 'NovecentoSans',
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              onChanged: (value) async {
                                if (value.length >= 1) {
                                  setState(() {
                                    _isSearching = true;
                                  });

                                  List<DocumentSnapshot> users = [];
                                  if (value.isNotEmpty) {
                                    await FirebaseFirestore.instance.collection('users').orderBy('display_name_lowercase', descending: false).startAt([value.toLowerCase()]).endAt([value.toLowerCase() + '\uf8ff']).get().then((uSnaps) async {
                                          uSnaps.docs.forEach((uDoc) {
                                            if (uDoc.reference.id != user.uid) {
                                              users.add(uDoc);
                                            }
                                          });
                                        });
                                    if (users.length < 1) {
                                      await FirebaseFirestore.instance.collection('users').orderBy('email', descending: false).startAt([value.toLowerCase()]).endAt([value.toLowerCase() + '\uf8ff']).get().then((uSnaps) async {
                                            uSnaps.docs.forEach((uDoc) {
                                              if (uDoc.reference.id != user.uid) {
                                                users.add(uDoc);
                                              }
                                            });
                                          });
                                    }

                                    await new Future.delayed(new Duration(milliseconds: 500));

                                    setState(() {
                                      _teammates = users;
                                      _isSearching = false;
                                    });
                                  }

                                  setState(() {
                                    _teammates = users;
                                    _isSearching = false;
                                  });
                                }
                              },
                              controller: searchFieldController,
                              validator: (value) {
                                if (value.isEmpty) {
                                  return 'Enter a name or email address';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: IconButton(
                        onPressed: () {
                          scanBarcodeNormal().then((success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("You are now teammates!"),
                                duration: Duration(milliseconds: 2500),
                              ),
                            );

                            navigatorKey.currentState.pushReplacement(MaterialPageRoute(builder: (context) {
                              return Navigation(
                                title: NavigationTitle(title: "Team".toUpperCase()),
                                selectedIndex: 1,
                              );
                            }));
                          }).onError((error, stackTrace) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("There was an error scanning your teammates QR code :("),
                                duration: Duration(milliseconds: 4000),
                              ),
                            );
                          });
                        },
                        icon: Icon(
                          Icons.qr_code_2_rounded,
                          size: 35,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: _isSearching && _teammates.length < 1
                    ? Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(
                            child: CircularProgressIndicator(),
                          )
                        ],
                      )
                    : _teammates.length < 1 && searchFieldController.text.length > 0
                        ? Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                margin: EdgeInsets.only(top: 40),
                                child: Text(
                                  "No teammates found",
                                  style: TextStyle(
                                    fontFamily: 'NovecentoSans',
                                    fontSize: 20,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            ],
                          )
                        : ListView(
                            children: _buildTeammateResults(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTeammateResults() {
    List<Widget> teammates = [];
    _teammates.asMap().forEach((i, doc) {
      UserProfile teammate = UserProfile.fromSnapshot(doc);

      teammates.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedTeammate = _selectedTeammate == i ? null : i;
              searchFieldController.text = searchFieldController.text;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: _selectedTeammate == i ? Theme.of(context).cardTheme.color : Colors.transparent,
            ),
            padding: EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                _selectedTeammate == i
                    ? Container(
                        height: 60,
                        width: 60,
                        margin: EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(30)),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedTeammate = null;
                              searchFieldController.text = searchFieldController.text;
                            });
                          },
                          icon: Icon(
                            Icons.check,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Container(
                        margin: EdgeInsets.symmetric(horizontal: 15),
                        child: SizedBox(
                          height: 60,
                          child: UserAvatar(
                            user: teammate,
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        teammate.displayName != null
                            ? Container(
                                width: MediaQuery.of(context).size.width - 235,
                                child: AutoSizeText(
                                  teammate.displayName,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).textTheme.bodyText1.color,
                                  ),
                                ),
                              )
                            : Container(),
                        teammate.email != null
                            ? Container(
                                width: MediaQuery.of(context).size.width - 235,
                                child: AutoSizeText(
                                  teammate.email,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onPrimary,
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
                        Container(
                          width: 135,
                          child: StreamBuilder(
                              stream: FirebaseFirestore.instance.collection('iterations').doc(teammate.reference.id).collection('iterations').snapshots(),
                              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                                if (!snapshot.hasData) {
                                  return Center(
                                    child: SizedBox(
                                      width: 120,
                                      height: 2,
                                      child: LinearProgressIndicator(),
                                    ),
                                  );
                                } else {
                                  int total = 0;
                                  snapshot.data.docs.forEach((doc) {
                                    total += Iteration.fromSnapshot(doc).total;
                                  });

                                  return AutoSizeText(
                                    total.toString() + " Lifetime Shots",
                                    maxLines: 1,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'NovecentoSans',
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  );
                                }
                              }),
                        ),
                        Container(
                          child: StreamBuilder(
                              stream: FirebaseFirestore.instance.collection('iterations').doc(teammate.reference.id).collection('iterations').snapshots(),
                              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                                if (!snapshot.hasData) {
                                  return Center(
                                    child: SizedBox(
                                      width: 120,
                                      height: 2,
                                      child: LinearProgressIndicator(),
                                    ),
                                  );
                                } else {
                                  Duration totalDuration = Duration();
                                  snapshot.data.docs.forEach((doc) {
                                    totalDuration += Iteration.fromSnapshot(doc).totalDuration;
                                  });

                                  return totalDuration > Duration()
                                      ? Text(
                                          "IN " + printDuration(totalDuration, true),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontFamily: 'NovecentoSans',
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        )
                                      : Container();
                                }
                              }),
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

    return teammates;
  }
}

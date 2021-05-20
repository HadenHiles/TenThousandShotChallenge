import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/Invite.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';

class Team extends StatefulWidget {
  Team({Key key}) : super(key: key);

  @override
  _TeamState createState() => _TeamState();
}

class _TeamState extends State<Team> {
  final user = FirebaseAuth.instance.currentUser;

  bool _isLoadingTeammates = false;
  List<DocumentSnapshot> _teammates = [];

  bool _isLoadingInvites = false;
  List<DocumentSnapshot> _invites = [];

  @override
  void initState() {
    _isLoadingTeammates = true;
    _loadTeammates();

    _isLoadingInvites = true;
    _loadInvites();

    super.initState();
  }

  Future<Null> _loadInvites() async {
    await FirebaseFirestore.instance.collection('invites').doc(user.uid).collection('invites').orderBy('date', descending: true).get().then((snapshot) async {
      if (snapshot.docs.length > 0) {
        await new Future.delayed(new Duration(milliseconds: 500));
        List<DocumentSnapshot> invites = [];

        snapshot.docs.forEach((doc) {
          String fromUid = Invite.fromSnapshot(doc).fromUid;

          FirebaseFirestore.instance.collection('users').doc(fromUid).get().then((uSnap) {
            invites.add(uSnap);

            if (invites != null && invites.length > 0) {
              if (mounted) {
                setState(() {
                  _isLoadingInvites = false;
                  _invites.addAll(invites);
                });
              }
            } else {
              setState(() {
                _isLoadingInvites = false;
              });
            }
          });
        });
      }
    });
  }

  Future<Null> _loadTeammates() async {
    await FirebaseFirestore.instance.collection('teammates').doc(user.uid).collection('teammates').orderBy('display_name', descending: false).get().then((snapshot) async {
      if (snapshot.docs.length > 0) {
        await new Future.delayed(new Duration(milliseconds: 500));
        List<DocumentSnapshot> teammates = [];

        snapshot.docs.forEach((doc) async {
          await FirebaseFirestore.instance.collection('users').doc(UserProfile.fromSnapshot(doc).reference.id).get().then((uSnap) {
            teammates.add(uSnap);

            if (teammates != null && teammates.length > 0) {
              if (mounted) {
                setState(() {
                  _isLoadingTeammates = false;
                  _teammates.addAll(teammates);
                });
              }
            } else {
              setState(() {
                _isLoadingTeammates = false;
              });
            }
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.primary,
          appBar: AppBar(
            toolbarHeight: 50,
            backgroundColor: Theme.of(context).colorScheme.primary,
            bottom: TabBar(
              tabs: [
                Tab(
                  text: "Teammates".toUpperCase(),
                ),
                Tab(
                  text: "Invites".toUpperCase(),
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              RefreshIndicator(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _isLoadingTeammates || _teammates.length < 1
                        ? Container(
                            child: Text("No Friends."),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 15,
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  'Teammates'.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'NovecentoSans',
                                    fontSize: 28,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 15,
                              ),
                              Container(
                                height: MediaQuery.of(context).size.height - 350,
                                child: ListView.builder(
                                  padding: EdgeInsets.all(0),
                                  itemCount: _invites.length + 1,
                                  itemBuilder: (_, int index) {
                                    if (index < _invites.length) {
                                      final DocumentSnapshot document = _invites[index];
                                      return _buildTeammateItem(UserProfile.fromSnapshot(document), index % 2 == 0 ? true : false);
                                    }

                                    return !_isLoadingInvites
                                        ? Container()
                                        : Container(
                                            child: Center(
                                              child: Container(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.max,
                                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    SizedBox(
                                                      height: 25,
                                                      width: 25,
                                                      child: CircularProgressIndicator(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
                onRefresh: () async {
                  _teammates.clear();
                  await _loadTeammates();
                },
              ),
              RefreshIndicator(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _isLoadingInvites || _invites.length < 1
                        ? Container(
                            child: Text("No Invites"),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 15,
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  'Invites'.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'NovecentoSans',
                                    fontSize: 28,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 15,
                              ),
                              Container(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: ListView.builder(
                                  padding: EdgeInsets.all(0),
                                  itemCount: _invites.length + 1,
                                  itemBuilder: (_, int index) {
                                    if (index < _invites.length) {
                                      final DocumentSnapshot document = _invites[index];
                                      return _buildTeammateInviteItem(UserProfile.fromSnapshot(document), index % 2 == 0 ? true : false);
                                    }

                                    return !_isLoadingInvites
                                        ? Container()
                                        : Container(
                                            child: Center(
                                              child: Container(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.max,
                                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    SizedBox(
                                                      height: 25,
                                                      width: 25,
                                                      child: CircularProgressIndicator(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
                onRefresh: () async {
                  _invites.clear();
                  await _loadInvites();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeammateItem(UserProfile teammate, bool bg) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: bg ? Theme.of(context).cardTheme.color : Colors.transparent,
        ),
        padding: EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
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
    );
  }

  Widget _buildTeammateInviteItem(UserProfile teammate, bool bg) {
    return Dismissible(
      key: UniqueKey(),
      onDismissed: (direction) async {
        await deleteInvite(teammate.reference.id, user.uid).then((deleted) {
          if (deleted == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: new Text("There was an error deleting the invite :("),
                duration: Duration(milliseconds: 1500),
              ),
            );
          } else if (!deleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: new Text("The invite couldn't be deleted"),
                duration: Duration(milliseconds: 1500),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: new Text("Invite from ${teammate.displayName} deleted"),
                duration: Duration(milliseconds: 1500),
              ),
            );
          }

          _invites.clear();
          _loadInvites();
        });
      },
      confirmDismiss: (DismissDirection direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                "Delete Invite from ${teammate.displayName}?".toUpperCase(),
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 24,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Are you sure you want to delete this teammate's invite?",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    "Cancel".toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    "Delete".toUpperCase(),
                    style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).primaryColor),
                  ),
                ),
              ],
            );
          },
        );
      },
      background: Container(
        color: Theme.of(context).primaryColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              margin: EdgeInsets.only(left: 15),
              child: Text(
                "Delete".toUpperCase(),
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(right: 15),
              child: Icon(
                Icons.delete,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg ? Theme.of(context).cardTheme.color : Colors.transparent,
        ),
        padding: EdgeInsets.symmetric(vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 15),
                  child: SizedBox(
                    height: 60,
                    child: UserAvatar(
                      user: teammate,
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  child: TextButton(
                    onPressed: () {
                      acceptInvite(Invite(teammate.reference.id, DateTime.now())).then((accepted) {
                        if (accepted == null || !accepted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: new Text("Error accepting invite from ${teammate.displayName} :("),
                              duration: Duration(milliseconds: 2500),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: new Text("Invite from ${teammate.displayName} accepted!"),
                              duration: Duration(milliseconds: 1500),
                            ),
                          );
                        }
                      });
                    },
                    child: Text(
                      "Accept".toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.blue.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

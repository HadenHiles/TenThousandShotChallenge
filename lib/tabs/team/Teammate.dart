import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';

class Teammate extends StatefulWidget {
  Teammate({Key key, this.uid}) : super(key: key);

  final String uid;

  @override
  _TeammateState createState() => _TeammateState();
}

class _TeammateState extends State<Teammate> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;

  UserProfile _userTeammate;
  bool _loadingTeammate = false;
  ScrollController sessionsController;
  DocumentSnapshot _lastVisible;
  bool _isLoading;
  List<DocumentSnapshot> _sessions = [];
  List<DropdownMenuItem> _attemptDropdownItems = [];
  String _selectedIterationId;

  @override
  void initState() {
    setState(() {
      _loadingTeammate = true;
    });

    FirebaseFirestore.instance.collection('users').doc(widget.uid).get().then((uDoc) {
      _userTeammate = UserProfile.fromSnapshot(uDoc);

      setState(() {
        _loadingTeammate = false;
      });
    });

    sessionsController = new ScrollController()..addListener(_scrollListener);

    super.initState();

    _isLoading = true;

    _loadHistory();

    _getAttempts();
  }

  Future<Null> _getAttempts() async {
    await FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').orderBy('start_date', descending: false).get().then((snapshot) {
      List<DropdownMenuItem> iterations = [];
      snapshot.docs.asMap().forEach((i, iDoc) {
        iterations.add(DropdownMenuItem<String>(
          value: iDoc.reference.id,
          child: Text(
            "attempt ".toUpperCase() + (i + 1).toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 26,
              fontFamily: 'NovecentoSans',
            ),
          ),
        ));
      });

      setState(() {
        _selectedIterationId = iterations[iterations.length - 1].value;
        _attemptDropdownItems = iterations;
      });
    });
  }

  Future<Null> _loadHistory() async {
    await new Future.delayed(new Duration(milliseconds: 500));

    if (_lastVisible == null) {
      await FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').doc(_selectedIterationId).get().then((snapshot) {
        List<DocumentSnapshot> sessions = [];
        snapshot.reference.collection('sessions').orderBy('date', descending: true).limit(5).get().then((sSnap) {
          sSnap.docs.forEach((s) {
            sessions.add(s);
          });

          if (sessions != null && sessions.length > 0) {
            _lastVisible = sessions[sessions.length - 1];

            if (mounted) {
              setState(() {
                _isLoading = false;
                _sessions.addAll(sessions);
              });
            }
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        });
      });
    } else {
      await FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').doc(_selectedIterationId).get().then((snapshot) {
        List<DocumentSnapshot> sessions = [];
        snapshot.reference.collection('sessions').orderBy('date', descending: true).startAfter([_lastVisible['date']]).limit(5).get().then((sSnap) {
              sSnap.docs.forEach((s) {
                sessions.add(s);
              });

              if (sessions != null && sessions.length > 0) {
                _lastVisible = sessions[sessions.length - 1];
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _sessions.addAll(sessions);
                  });
                }
              } else {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: Duration(milliseconds: 1200),
                    content: Text('No more sessions!'),
                  ),
                );
              }
            });
      });
    }
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
              actions: [
                Container(
                  margin: EdgeInsets.only(top: 10),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    onPressed: () {
                      dialog(
                        context,
                        ConfirmDialog(
                          "Remove Teammate?",
                          Text(
                            "Are you sure you want to remove ${_userTeammate.displayName} from your team?",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                          "Cancel",
                          () {
                            Navigator.of(context).pop();
                          },
                          "Continue",
                          () {
                            deleteTeammate(_userTeammate.reference.id).then((success) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: Duration(milliseconds: 2500),
                                    content: Text('${_userTeammate.displayName} was removed from your team.'),
                                  ),
                                );

                                navigatorKey.currentState.pushReplacement(
                                  MaterialPageRoute(builder: (context) {
                                    return Navigation(
                                      title: NavigationTitle(title: "Team".toUpperCase()),
                                      selectedIndex: 1,
                                    );
                                  }),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: Duration(milliseconds: 4000),
                                    content: Text('There was an error removing teammate :('),
                                  ),
                                );

                                Navigator.of(context).pop();
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
              flexibleSpace: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).backgroundColor,
                ),
                child: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  titlePadding: null,
                  centerTitle: false,
                  background: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
          ];
        },
        body: _loadingTeammate
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              )
            : Container(
                padding: EdgeInsets.only(top: 15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 15),
                              child: SizedBox(
                                height: 60,
                                child: UserAvatar(
                                  user: UserProfile(_userTeammate.displayName, _userTeammate.email, _userTeammate.photoUrl),
                                  backgroundColor: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 200,
                                  child: StreamBuilder<DocumentSnapshot>(
                                    // ignore: deprecated_member_use
                                    stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData)
                                        return Column(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Center(
                                              child: SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(),
                                              ),
                                            ),
                                          ],
                                        );

                                      UserProfile userProfile = UserProfile.fromSnapshot(snapshot.data);

                                      return AutoSizeText(
                                        userProfile.displayName != null && userProfile.displayName.isNotEmpty ? userProfile.displayName : _userTeammate.displayName,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).textTheme.bodyText1.color,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Container(
                                  child: StreamBuilder(
                                      stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').snapshots(),
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

                                          return Text(
                                            total.toString() + " Lifetime Shots",
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
                                      stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').snapshots(),
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
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 15),
                          child: Row(
                            children: [
                              Container(
                                margin: EdgeInsets.only(top: 5, right: 2),
                                child: Text(
                                  "attempt ",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 20,
                                    fontFamily: 'NovecentoSans',
                                  ),
                                ),
                              ),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Text(
                                      (snapshot.data.docs.length).toString(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 34,
                                        fontFamily: 'NovecentoSans',
                                      ),
                                    );
                                  }

                                  return Container();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      height: 25,
                      color: Theme.of(context).cardTheme.color,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DropdownButton(
                          onChanged: (value) {
                            setState(() {
                              _isLoading = true;
                              _sessions.clear();
                              _lastVisible = null;
                              _selectedIterationId = value;
                              _loadHistory();
                            });
                          },
                          underline: Container(),
                          dropdownColor: Theme.of(context).colorScheme.primary,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          value: _selectedIterationId,
                          items: _attemptDropdownItems,
                        ),
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
                              margin: EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(color: wristShotColor),
                              child: Column(
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
                              margin: EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(color: snapShotColor),
                              child: Column(
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
                              margin: EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(color: backhandShotColor),
                              child: Column(
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
                              margin: EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(color: slapShotColor),
                              child: Column(
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
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        child: ListView.builder(
                          controller: sessionsController,
                          padding: EdgeInsets.only(
                            top: 0,
                            right: 0,
                            bottom: !sessionService.isRunning ? AppBar().preferredSize.height : AppBar().preferredSize.height + 65,
                            left: 0,
                          ),
                          itemCount: _sessions.length + 1,
                          itemBuilder: (_, int index) {
                            if (index < _sessions.length) {
                              final DocumentSnapshot document = _sessions[index];
                              return _buildSessionItem(ShootingSession.fromSnapshot(document), index % 2 == 0 ? true : false);
                            }
                            return Container(
                              margin: EdgeInsets.only(top: 9, bottom: 35),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _isLoading
                                      ? SizedBox(
                                          height: 25,
                                          width: 25,
                                          child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                                        )
                                      : _sessions.length < 1
                                          ? Text(
                                              "You don't have any sessions yet".toUpperCase(),
                                              style: TextStyle(
                                                fontFamily: 'NovecentoSans',
                                                color: Theme.of(context).colorScheme.onPrimary,
                                                fontSize: 16,
                                              ),
                                            )
                                          : Container()
                                ],
                              ),
                            );
                          },
                        ),
                        onRefresh: () async {
                          _sessions.clear();
                          _lastVisible = null;
                          await _loadHistory();
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    sessionsController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    if (!_isLoading) {
      if (sessionsController.position.pixels == sessionsController.position.maxScrollExtent) {
        setState(() => _isLoading = true);
        _loadHistory();
      }
    }
  }

  Widget _buildSessionItem(ShootingSession s, bool showBackground) {
    return Container(
      padding: EdgeInsets.only(top: 5, bottom: 15),
      decoration: BoxDecoration(
        color: showBackground ? Theme.of(context).cardTheme.color : Colors.transparent,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  printDate(s.date),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontFamily: 'NovecentoSans',
                  ),
                ),
                Text(
                  printDuration(s.duration, true),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontFamily: 'NovecentoSans',
                  ),
                ),
                Text(
                  s.total.toString() + " Shots".toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontFamily: 'NovecentoSans',
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: MediaQuery.of(context).size.width - 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      width: calculateSessionShotWidth(s, s.totalWrist),
                      height: 30,
                      decoration: BoxDecoration(
                        color: wristShotColor,
                      ),
                      child: s.totalWrist < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  s.totalWrist.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalSnap),
                      height: 30,
                      decoration: BoxDecoration(
                        color: snapShotColor,
                      ),
                      child: s.totalSnap < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  s.totalSnap.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalBackhand),
                      height: 30,
                      decoration: BoxDecoration(
                        color: backhandShotColor,
                      ),
                      child: s.totalBackhand < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  s.totalBackhand.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalSlap),
                      height: 30,
                      decoration: BoxDecoration(
                        color: slapShotColor,
                      ),
                      child: s.totalSlap < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  s.totalSlap.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width - 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      width: calculateSessionShotWidth(s, s.totalWrist),
                      child: s.totalWrist < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.5,
                                  child: Text(
                                    "W",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalSnap),
                      child: s.totalSnap < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.5,
                                  child: Text(
                                    "SN",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalBackhand),
                      child: s.totalBackhand < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.5,
                                  child: Text(
                                    "B",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalSlap),
                      child: s.totalSlap < 1
                          ? Container()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.5,
                                  child: Text(
                                    "SL",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontFamily: 'NovecentoSans',
                                    ),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double calculateSessionShotWidth(ShootingSession session, int shotCount) {
    double percentage = (shotCount / session.total);
    return (MediaQuery.of(context).size.width - 30) * percentage;
  }
}

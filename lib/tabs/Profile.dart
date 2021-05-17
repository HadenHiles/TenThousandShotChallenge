import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';

class Profile extends StatefulWidget {
  Profile({Key key}) : super(key: key);

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;
  final Color wristShotColor = Color(0xff741d1d);
  final Color snapShotColor = Color(0xffae2b2b);
  final Color slapShotColor = HomeTheme.lightTheme.primaryColor;
  final Color backhandShotColor = Color(0xffd35050);

  UserProfile userProfile;
  List<Iteration> _iterations = [];
  ScrollController sessionsController;
  DocumentSnapshot _lastVisible;
  bool _isLoading;
  List<DocumentSnapshot> _sessions = [];

  @override
  void initState() {
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((uDoc) {
      userProfile = UserProfile.fromSnapshot(uDoc);
    });

    sessionsController = new ScrollController()..addListener(_scrollListener);

    super.initState();

    _isLoading = true;

    _loadHistory();
  }

  Future<Null> _loadHistory() async {
    List<Iteration> iterations = [];

    await FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').get().then((snapshot) async {
      snapshot.docs.forEach((doc) {
        iterations.add(Iteration.fromMap(doc.data()));
      });

      setState(() {
        _iterations = iterations;
      });

      if (snapshot.docs.length > 0) {
        await new Future.delayed(new Duration(milliseconds: 500));

        List<DocumentSnapshot> sessions = [];
        if (_lastVisible == null)
          await FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').orderBy('start_date', descending: true).get().then((snapshot) {
            snapshot.docs.forEach((doc) {
              doc.reference.collection('sessions').orderBy('date', descending: true).limit(7).get().then((sSnap) {
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
                      content: Text('No more sessions!'),
                    ),
                  );
                }
              });
            });
          });
        else
          await FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').orderBy('start_date', descending: true).get().then((snapshot) {
            snapshot.docs.forEach((doc) {
              doc.reference.collection('sessions').orderBy('date', descending: true).startAfter([_lastVisible['date']]).limit(7).get().then((sSnap) {
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
                          content: Text('No more sessions!'),
                        ),
                      );
                    }
                  });
            });
          });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                        child: StreamBuilder<DocumentSnapshot>(
                          // ignore: deprecated_member_use
                          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
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

                            return Text(
                              userProfile.displayName != null && userProfile.displayName.isNotEmpty ? userProfile.displayName : user.displayName,
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
                            stream: FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').snapshots(),
                            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              } else {
                                int total = 0;
                                snapshot.data.docs.forEach((doc) {
                                  total += Iteration.fromMap(doc.data()).total;
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
                        "x",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 20,
                          fontFamily: 'NovecentoSans',
                        ),
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(
                            snapshot.data.docs.length.toString(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 34,
                              fontFamily: 'NovecentoSans',
                            ),
                          );
                        }

                        return null;
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
              Text(
                "My Sessions".toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 26,
                  fontFamily: 'NovecentoSans',
                ),
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
                    return _buildSessionItem(ShootingSession.fromMap(document.data()), index % 2 == 0 ? true : false);
                  }
                  return Container(
                    child: Center(
                      child: Opacity(
                        opacity: _isLoading ? 1.0 : 0.0,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 9),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _iterations.length < 1
                                  ? Text("No shooting sessions yet")
                                  : SizedBox(
                                      height: 25,
                                      width: 25,
                                      child: CircularProgressIndicator(),
                                    ),
                            ],
                          ),
                        ),
                      ),
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

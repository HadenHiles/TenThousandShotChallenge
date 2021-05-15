import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
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
  int _totalShots = 0;
  List<ShootingSession> _sessions = [];

  @override
  void initState() {
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((uDoc) {
      userProfile = UserProfile.fromSnapshot(uDoc);
    });

    loadHistory();

    super.initState();
  }

  void loadHistory() async {
    await getIterations(user.uid).then((iterations) {
      iterations.forEach((i) {
        setState(() {
          _totalShots += i.total;
        });
      });
    });

    await getActiveIterationId(user.uid).then((iterationId) async {
      await getShootingSessions(user.uid, iterationId).then((sessions) {
        setState(() {
          _sessions = sessions;
        });
      });
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(right: 15),
                child: SizedBox(
                  height: 75,
                  child: UserAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                                child: CircularProgressIndicator(),
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
                    child: Text(
                      _totalShots.toString() + " Lifetime Shots".toUpperCase(),
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
          SizedBox(
            height: 25,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "W",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    decoration: BoxDecoration(color: wristShotColor),
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
                    decoration: BoxDecoration(color: snapShotColor),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "SN",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                    decoration: BoxDecoration(color: slapShotColor),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "SL",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                    decoration: BoxDecoration(color: backhandShotColor),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "B",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
            height: 25,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                top: 0,
                right: 0,
                bottom: AppBar().preferredSize.height,
                left: 0,
              ),
              children: _sessions.length < 1
                  ? [
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                        ],
                      ),
                    ]
                  : buildSessionsList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Container> buildSessionsList() {
    List<Container> sessions = [];
    _sessions.asMap().forEach((i, s) {
      sessions.add(
        Container(
          padding: EdgeInsets.only(top: 5, bottom: 25),
          decoration: BoxDecoration(
            color: i % 2 == 0 ? Theme.of(context).cardTheme.color : Colors.transparent,
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
                      padding: EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: wristShotColor,
                      ),
                      child: s.totalWrist < 1
                          ? Container()
                          : Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Column(
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
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalSnap),
                      height: 30,
                      padding: EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: snapShotColor,
                      ),
                      child: s.totalSnap < 1
                          ? Container()
                          : Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Column(
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
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalSlap),
                      height: 30,
                      padding: EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: slapShotColor,
                      ),
                      child: s.totalSlap < 1
                          ? Container()
                          : Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Column(
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
                              ],
                            ),
                    ),
                    Container(
                      width: calculateSessionShotWidth(s, s.totalBackhand),
                      height: 30,
                      padding: EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: backhandShotColor,
                      ),
                      child: s.totalBackhand < 1
                          ? Container()
                          : Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Column(
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
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });

    return sessions;
  }

  double calculateSessionShotWidth(ShootingSession session, int shotCount) {
    double percentage = (shotCount / session.total);
    return (MediaQuery.of(context).size.width - 30) * percentage;
  }
}

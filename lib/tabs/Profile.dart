import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/tabs/profile/SessionChart.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';

class Profile extends StatefulWidget {
  Profile({Key key}) : super(key: key);

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;
  UserProfile userProfile;
  List<Iteration> _iterations;
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
      setState(() {
        _iterations = iterations;
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
      padding: EdgeInsets.only(left: 25, right: 25, bottom: 125),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 25),
                child: SizedBox(
                  height: 100,
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
                      _totalShots.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'NovecentoSans',
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: SessionChart.withSampleData(),
          ),
        ],
      ),
    );
  }

  List<ListTile> buildSessionsList() {
    List<ListTile> sessions = [];
    _sessions.forEach((s) {
      sessions.add(
        ListTile(
          title: Text(
            s.total.toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      );
    });

    return sessions;
  }
}

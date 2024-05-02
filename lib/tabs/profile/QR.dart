import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';

void showQRCode(User? user) {
  showDialog(
    context: navigatorKey.currentContext!,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          "Friends can add you with this".toUpperCase(),
          style: const TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 24,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: user!.uid,
                backgroundColor: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              "Close".toUpperCase(),
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      );
    },
  );
}

void showTeamQRCode(User? u) {
  FirebaseFirestore.instance.collection("users").doc(u!.uid).get().then((uDoc) {
    UserProfile user = UserProfile.fromSnapshot(uDoc);

    FirebaseFirestore.instance.collection("teams").where('id', isEqualTo: user.teamId).limit(1).get().then((tDoc) {
      Team team = Team.fromSnapshot(tDoc.docs[0]);

      showDialog(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              "People can join your team with this".toUpperCase(),
              style: const TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 24,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: team.id!,
                    backgroundColor: Colors.white70,
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  "Close".toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  });
}

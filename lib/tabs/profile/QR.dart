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

void showTeamQRCode(UserProfile u) {
  FirebaseFirestore.instance.collection("teams").where('id', isEqualTo: u.teamId).limit(1).get().then((tDoc) {
    Team team = Team.fromSnapshot(tDoc.docs[0]);

    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Scan this QR code from the\n \"Join Team\" screen".toUpperCase(),
            style: const TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
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
              Divider(
                color: Theme.of(context).colorScheme.onPrimary,
                height: 20,
              ),
              Text(
                "Or use your team code:".toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                height: 60,
                width: 220,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    padding: const EdgeInsets.all(5),
                    child: SelectableText(
                      team.code!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontFamily: "NovecentoSans",
                        fontSize: 24,
                      ),
                    ),
                  ),
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
}

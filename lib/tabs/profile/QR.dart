import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rotating_icon_button/rotating_icon_button.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:word_generator/word_generator.dart';

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

Future<bool> showTeamQRCode(BuildContext context) async {
  User? user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;

  if (user != null) {
    return FirebaseFirestore.instance.collection("users").doc(user.uid).get().then((uDoc) async {
      UserProfile u = UserProfile.fromSnapshot(uDoc);

      if (u.teamId != null) {
        FirebaseFirestore.instance.collection("teams").where('id', isEqualTo: u.teamId).limit(1).get().then((tDoc) {
          Team team = Team.fromSnapshot(tDoc.docs[0]);

          showDialog(
            context: navigatorKey.currentContext!,
            builder: (BuildContext context) {
              Team t = team;
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 60,
                              child: Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                  ),
                                  padding: const EdgeInsets.all(5),
                                  child: SelectableText(
                                    t.code!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontFamily: "NovecentoSans",
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            t.ownerId != user.uid
                                ? const SizedBox(width: 0)
                                : RotatingIconButton(
                                    onTap: () async {
                                      final wordGenerator = WordGenerator();
                                      String newCode = wordGenerator.randomNoun().toUpperCase() + wordGenerator.randomVerb().toUpperCase() + Random().nextInt(9999).toString().padLeft(4, '0');

                                      await FirebaseFirestore.instance.collection('teams').doc(t.id).update({'code': newCode}).then((_) {
                                        setState(() {
                                          t.code = newCode;
                                        });
                                      });
                                    },
                                    elevation: 10.0,
                                    shadowColor: Colors.transparent,
                                    borderRadius: 20.0,
                                    rotateType: RotateType.full,
                                    duration: const Duration(milliseconds: 1000),
                                    curve: Curves.easeInOut,
                                    clockwise: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                      horizontal: 0,
                                    ),
                                    background: Colors.transparent,
                                    child: Icon(
                                      Icons.refresh,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                          ],
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
            },
          );
          return true;
        });

        return true;
      } else {
        return false;
      }
    });
  } else {
    return false;
  }
}

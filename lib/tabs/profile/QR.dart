import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rotating_icon_button/rotating_icon_button.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamIdentityPicker.dart';
import 'package:word_generator/word_generator.dart';

void showQRCode(BuildContext context, User? user) {
  if (user == null) return;
  final Color qrColor = Theme.of(context).primaryColor;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          "Friend QR Code".toUpperCase(),
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 20,
            color: qrColor,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                "Have friends scan this code to add you.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: qrColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: qrColor.withValues(alpha: 0.5), width: 1.5),
              ),
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: user.uid,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: qrColor,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: qrColor,
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: qrColor, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: user.photoURL != null ? Image.network(user.photoURL!, fit: BoxFit.cover) : Icon(Icons.person_rounded, color: qrColor, size: 30),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Close".toUpperCase(),
              style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).colorScheme.onSurface),
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
            context: context,
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
                          child: Builder(builder: (context) {
                            final Color qrColor = colorFromHex(t.primaryColor);
                            return Container(
                              decoration: BoxDecoration(
                                color: colorFromHex(t.darkAccentColor).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: qrColor.withValues(alpha: 0.5), width: 1.5),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  QrImageView(
                                    data: team.id!,
                                    backgroundColor: Colors.white,
                                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                                    eyeStyle: QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: qrColor,
                                    ),
                                    dataModuleStyle: QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: qrColor,
                                    ),
                                  ),
                                  if (t.logoAsset != null)
                                    buildTeamLogoWidget(
                                      context: context,
                                      logoAsset: t.logoAsset,
                                      primaryColorHex: t.primaryColor,
                                      darkAccentHex: t.darkAccentColor,
                                      lightAccentHex: t.lightAccentColor,
                                      size: 52,
                                      iconSize: 26,
                                    ),
                                ],
                              ),
                            );
                          }),
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

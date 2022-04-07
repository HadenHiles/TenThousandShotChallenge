import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tenthousandshotchallenge/main.dart';

void showQRCode(User user) {
  showDialog(
    context: navigatorKey.currentContext,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          "Friends can add you with this".toUpperCase(),
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 24,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              child: QrImage(
                data: user.uid,
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

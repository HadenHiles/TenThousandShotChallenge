import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import '../main.dart';

class Shots extends StatefulWidget {
  Shots({Key key, this.sessionPanelController}) : super(key: key);

  final PanelController sessionPanelController;

  @override
  _ShotsState createState() => _ShotsState();
}

class _ShotsState extends State<Shots> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 50,
          width: MediaQuery.of(context).size.width - 10,
          child: TextButton(
            style: TextButton.styleFrom(
              primary: Colors.white,
              backgroundColor: Theme.of(context).buttonColor,
            ),
            onPressed: () {
              if (!sessionService.isRunning) {
                sessionService.start();
                widget.sessionPanelController.open();
              } else {
                dialog(
                  context,
                  ConfirmDialog(
                    "Override current session?",
                    Text(
                      "Starting a new session will override your existing one.\n\nWould you like to continue?",
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
                      sessionService.reset();
                      Navigator.of(context).pop();
                      sessionService.start();
                      widget.sessionPanelController.show();
                    },
                  ),
                );
              }
            },
            child: Text(
              'Start Shooting'.toUpperCase(),
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

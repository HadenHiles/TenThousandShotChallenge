import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';

void dialog(BuildContext context, ConfirmDialog dialog) {
  // set up the buttons
  Widget cancelButton = TextButton(
    child: Text(
      dialog.cancelText ?? "Cancel",
      style: TextStyle(
        color: Theme.of(context).colorScheme.onBackground,
      ),
    ),
    onPressed: dialog.cancelCallback ?? () {},
  );
  Widget continueButton = TextButton(
    child: Text(
      dialog.continueText ?? "Continue",
      style: TextStyle(color: Colors.red),
    ),
    onPressed: dialog.continueCallback ?? () {},
  );

  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: Text(
      dialog.title ?? "Are you sure?",
      style: TextStyle(
        color: Theme.of(context).primaryColor,
        fontSize: 20,
      ),
    ),
    backgroundColor: Theme.of(context).colorScheme.background,
    content: dialog.body != null
        ? dialog.body
        : Text(
            "This action cannot be undone.",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
    actions: [
      cancelButton,
      continueButton,
    ],
  );

  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

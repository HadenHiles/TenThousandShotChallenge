import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';

void dialog(BuildContext context, ConfirmDialog dialog) {
  // set up the buttons
  Widget cancelButton = TextButton(
    onPressed: dialog.cancelCallback ?? () {},
    child: Text(
      dialog.cancelText ?? "Cancel",
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
  Widget continueButton = TextButton(
    onPressed: dialog.continueCallback ?? () {},
    child: Text(
      dialog.continueText ?? "Continue",
      style: const TextStyle(color: Colors.red),
    ),
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
    backgroundColor: Theme.of(context).colorScheme.surface,
    content: dialog.body ??
        Text(
          "This action cannot be undone.",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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

import 'package:flutter/material.dart';

class ConfirmDialog {
  final String? title;
  final Widget? body;
  final String? cancelText;
  final VoidCallback? cancelCallback;
  final String? continueText;
  final VoidCallback? continueCallback;

  ConfirmDialog(this.title, this.body, this.cancelText, this.cancelCallback, this.continueText, this.continueCallback);
}

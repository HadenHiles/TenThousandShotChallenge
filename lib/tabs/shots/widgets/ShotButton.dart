import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class ShotTypeButton extends StatelessWidget {
  const ShotTypeButton({Key key, this.type, this.active, this.onPressed}) : super(key: key);

  final String type;
  final bool active;
  final Function onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        primary: active ? Colors.white : Theme.of(context).colorScheme.onPrimary,
        backgroundColor: active ? Theme.of(context).buttonColor : Theme.of(context).cardTheme.color,
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 5),
      ),
      onPressed: onPressed,
      child: Container(
        width: MediaQuery.of(context).size.width * .2,
        child: AutoSizeText(
          type.toUpperCase(),
          maxFontSize: 24,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

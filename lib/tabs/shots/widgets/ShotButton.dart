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
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      onPressed: onPressed,
      child: Text(type.toUpperCase()),
    );
  }
}

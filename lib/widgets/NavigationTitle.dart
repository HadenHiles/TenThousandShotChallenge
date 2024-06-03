import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class NavigationTitle extends StatelessWidget {
  const NavigationTitle({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: AutoSizeText(
        title!.toUpperCase(),
        maxLines: 1,
        maxFontSize: 18,
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 18,
          color: Theme.of(context).appBarTheme.backgroundColor,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}

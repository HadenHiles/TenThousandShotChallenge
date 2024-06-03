import 'package:flutter/material.dart';

class BasicTitle extends StatelessWidget {
  const BasicTitle({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Text(
        title!.toUpperCase(),
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

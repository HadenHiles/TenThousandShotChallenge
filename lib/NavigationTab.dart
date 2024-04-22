import 'package:flutter/material.dart';

class NavigationTab extends StatefulWidget {
  const NavigationTab({Key? key, this.title, this.leading, this.actions, this.body}) : super(key: key);

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? body;

  @override
  State<NavigationTab> createState() => _NavigationTabState();
}

class _NavigationTabState extends State<NavigationTab> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: widget.body,
    );
  }
}

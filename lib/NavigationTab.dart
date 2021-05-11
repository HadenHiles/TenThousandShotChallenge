import 'package:flutter/material.dart';

class NavigationTab extends StatefulWidget {
  NavigationTab({Key key, this.title, this.actions, this.body}) : super(key: key);

  final Widget title;
  final List<Widget> actions;
  final Widget body;

  @override
  _NavigationTabState createState() => _NavigationTabState();
}

class _NavigationTabState extends State<NavigationTab> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      margin: EdgeInsets.only(top: 40),
      child: widget.body,
    );
  }
}

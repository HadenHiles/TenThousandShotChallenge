import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';

class Team extends StatefulWidget {
  Team({Key key}) : super(key: key);

  @override
  _TeamState createState() => _TeamState();
}

class _TeamState extends State<Team> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).size.height - (MediaQuery.of(context).padding.top + 1),
          margin: EdgeInsets.only(
            top: 0,
            right: 0,
            bottom: 0,
            left: 0,
          ),
          child: NestedScrollView(
            clipBehavior: Clip.antiAlias,
            scrollDirection: Axis.vertical,
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              // These are the slivers that show up in the "outer" scroll view.
              return [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar(
                    floating: false,
                    primary: true,
                    toolbarHeight: 0,
                    collapsedHeight: 0,
                    expandedHeight: 0,
                    forceElevated: false,
                    titleSpacing: 0,
                    backgroundColor: HomeTheme.darkTheme.colorScheme.primaryContainer,
                  ),
                ),
              ];
            },
            body: Column(),
          ),
        ),
      ],
    );
  }
}

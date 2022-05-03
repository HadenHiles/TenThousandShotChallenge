import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';

const TEAM_HEADER_HEIGHT = 65.0;

class Team extends StatefulWidget {
  Team({Key key}) : super(key: key);

  @override
  _TeamState createState() => _TeamState();
}

class _TeamState extends State<Team> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  AnimationController _rotationController;

  @override
  void initState() {
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).size.height - (MediaQuery.of(context).padding.top + 1) - TEAM_HEADER_HEIGHT,
          child: NestedScrollView(
            clipBehavior: Clip.antiAlias,
            scrollDirection: Axis.vertical,
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              // These are the slivers that show up in the "outer" scroll view.
              return [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar(
                    floating: true,
                    primary: true,
                    collapsedHeight: TEAM_HEADER_HEIGHT,
                    expandedHeight: TEAM_HEADER_HEIGHT,
                    forceElevated: false,
                    titleSpacing: 2,
                    backgroundColor: HomeTheme.darkTheme.colorScheme.primary,
                    title: GestureDetector(
                      onTap: () {
                        _rotationController.forward();
                        _showTeamBottomSheetModal();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Team Name",
                            style: HomeTheme.darkTheme.textTheme.bodyText1,
                          ),
                          SizedBox(
                            width: 5,
                          ),
                          RotationTransition(
                            turns: Tween(begin: 0.0, end: 0.5).animate(_rotationController),
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: HomeTheme.darkTheme.textTheme.bodyText1.color,
                                size: HomeTheme.darkTheme.textTheme.bodyText1.fontSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

  void _showTeamBottomSheetModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height - 85,
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15.0),
                topRight: Radius.circular(15.0),
              ),
            ),
            child: TeamList(),
          ),
        );
      },
      enableDrag: true,
      isScrollControlled: true,
      isDismissible: true,
    ).whenComplete(() {
      _rotationController.reverse();
    });
  }
}

class TeamList extends StatefulWidget {
  TeamList({Key key}) : super(key: key);

  @override
  State<TeamList> createState() => _TeamListState();
}

class _TeamListState extends State<TeamList> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          ListTile(
            title: Text("Old Paint Cans"),
          ),
        ],
      ),
    );
  }
}

import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/tabs/Shots.dart';
import 'package:tenthousandshotchallenge/tabs/Profile.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/Settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/NavigationTab.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'models/Preferences.dart';

// This is the stateful widget that the main application instantiates.
class Navigation extends StatefulWidget {
  Navigation({Key key}) : super(key: key);

  @override
  _NavigationState createState() => _NavigationState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _NavigationState extends State<Navigation> {
  // State variables
  Widget _title;
  List<Widget> _actions;
  int _selectedIndex = 0;
  final logo = Container(
    height: 40,
    padding: EdgeInsets.only(top: 6),
    child: Image.asset('assets/images/logo-text-only.png'),
  );

  static List<NavigationTab> _tabs = [
    NavigationTab(
      title: Container(
        height: 40,
        padding: EdgeInsets.only(top: 6),
        child: Image.asset('assets/images/logo-text-only.png'),
      ),
      actions: [],
      body: Shots(),
    ),
    NavigationTab(
      title: NavigationTitle(title: "Profile"),
      actions: [
        Container(
          margin: EdgeInsets.only(top: 10),
          child: IconButton(
            icon: Icon(
              Icons.settings,
              size: 28,
            ),
            onPressed: () {
              navigatorKey.currentState.push(MaterialPageRoute(builder: (BuildContext context) {
                return ProfileSettings();
              }));
            },
          ),
        ),
      ],
      body: Profile(),
    ),
  ];

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
      _selectedIndex = index;
      _title = index == 0 ? logo : _tabs[index].title;
      _actions = _tabs[index].actions;
    });
  }

  @override
  void initState() {
    _loadPreferences();

    setState(() {
      _title = logo;
      _actions = [];
    });

    super.initState();
  }

  // Load shared preferences
  void _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool darkMode = prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark;
    int puckCount = prefs.getInt('puck_count') ?? 25;

    Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(Preferences(darkMode, puckCount));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              collapsedHeight: 65,
              expandedHeight: 125,
              backgroundColor: HomeTheme.darkTheme.colorScheme.primary,
              iconTheme: Theme.of(context).iconTheme,
              actionsIconTheme: Theme.of(context).iconTheme,
              floating: true,
              pinned: true,
              flexibleSpace: DecoratedBox(
                decoration: BoxDecoration(
                  color: HomeTheme.darkTheme.colorScheme.primaryVariant,
                ),
                child: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  centerTitle: true,
                  title: _title,
                  background: Container(
                    color: HomeTheme.darkTheme.colorScheme.primaryVariant,
                  ),
                ),
              ),
              actions: _actions,
            ),
          ];
        },
        body: Container(
          padding: EdgeInsets.only(bottom: 0),
          child: _tabs.elementAt(_selectedIndex),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_hockey),
            label: 'Shots',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        backgroundColor: Theme.of(context).backgroundColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).colorScheme.onPrimary,
        onTap: _onItemTapped,
      ),
    );
  }
}

import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/Shots.dart';
import 'package:tenthousandshotchallenge/tabs/Profile.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/Settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/tabs/shots/StartShooting.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/NavigationTab.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'models/Preferences.dart';

final PanelController sessionPanelController = PanelController();

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
  // State variables
  PanelState _sessionPanelState = PanelState.CLOSED;
  double _bottomNavOffsetPercentage = 0;

  final logo = Container(
    height: 40,
    padding: EdgeInsets.only(top: 6),
    child: Image.asset('assets/images/logo-text-only.png'),
  );

  final List<NavigationTab> _tabs = [
    NavigationTab(
      title: Container(
        height: 40,
        padding: EdgeInsets.only(top: 6),
        child: Image.asset('assets/images/logo-text-only.png'),
      ),
      actions: [],
      body: Shots(sessionPanelController: sessionPanelController),
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
              color: HomeTheme.darkTheme.appBarTheme.iconTheme.color,
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

    if (!sessionPanelController.isPanelClosed) {
      sessionPanelController.close();
      setState(() {
        _sessionPanelState = PanelState.CLOSED;
      });
    }
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
    preferences = Preferences(darkMode, puckCount);

    Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(preferences);
  }

  @override
  Widget build(BuildContext context) {
    return SessionServiceProvider(
      service: sessionService,
      child: Scaffold(
        body: SlidingUpPanel(
          backdropEnabled: true,
          controller: sessionPanelController,
          maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
          minHeight: sessionService.isRunning ? 65 : 0,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          onPanelOpened: () {
            setState(() {
              _sessionPanelState = PanelState.OPEN;
            });
          },
          onPanelClosed: () {
            setState(() {
              _sessionPanelState = PanelState.CLOSED;
            });
          },
          onPanelSlide: (double offset) {
            setState(() {
              _bottomNavOffsetPercentage = offset;
            });
          },
          panel: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryVariant,
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: sessionService, // listen to ChangeNotifier
                  builder: (context, child) {
                    return ListTile(
                      tileColor: Theme.of(context).primaryColor,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            printWeekday(DateTime.now()) + " Session",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                              fontFamily: "NovecentoSans",
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                printDuration(sessionService.currentDuration, true),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSecondary,
                                  fontFamily: "NovecentoSans",
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: InkWell(
                        child: Icon(
                          _sessionPanelState == PanelState.CLOSED ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                      onTap: () {
                        if (sessionPanelController.isPanelClosed) {
                          sessionPanelController.open();
                          setState(() {
                            _sessionPanelState = PanelState.OPEN;
                          });
                        } else {
                          sessionPanelController.close();
                          setState(() {
                            _sessionPanelState = PanelState.CLOSED;
                          });
                        }
                      },
                    );
                  },
                ),
                StartShooting(sessionPanelController: sessionPanelController),
              ],
            ),
          ),
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
        ),
        bottomNavigationBar: SizedOverflowBox(
          alignment: AlignmentDirectional.topCenter,
          size: Size.fromHeight(AppBar().preferredSize.height - (AppBar().preferredSize.height * _bottomNavOffsetPercentage)),
          child: BottomNavigationBar(
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
        ),
      ),
    );
  }
}

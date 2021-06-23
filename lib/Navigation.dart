import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/services.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/services/VersionCheck.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/More.dart';
import 'package:tenthousandshotchallenge/tabs/Shots.dart';
import 'package:tenthousandshotchallenge/tabs/Profile.dart';
import 'package:tenthousandshotchallenge/tabs/Team.dart';
import 'package:tenthousandshotchallenge/tabs/profile/QR.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/Settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/tabs/shots/StartShooting.dart';
import 'package:tenthousandshotchallenge/tabs/team/AddTeammate.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/NavigationTab.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'models/Preferences.dart';

final PanelController sessionPanelController = PanelController();

// This is the stateful widget that the main application instantiates.
class Navigation extends StatefulWidget {
  Navigation({Key key, this.title, this.selectedIndex}) : super(key: key);

  final Widget title;
  final int selectedIndex;

  @override
  _NavigationState createState() => _NavigationState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _NavigationState extends State<Navigation> {
  String _connectionStatus = 'Unknown';
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult> _connectivitySubscription;

  // State variables
  Widget _title;
  Widget _leading;
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

  static List<NavigationTab> _tabs = [
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
      title: NavigationTitle(title: "Team".toUpperCase()),
      actions: [
        Container(
          margin: EdgeInsets.only(top: 10),
          child: IconButton(
            icon: Icon(
              Icons.add,
              color: HomeTheme.darkTheme.colorScheme.onPrimary,
              size: 28,
            ),
            onPressed: () {
              navigatorKey.currentState.push(MaterialPageRoute(builder: (BuildContext context) {
                return AddTeammate();
              }));
            },
          ),
        ),
      ],
      body: Team(),
    ),
    NavigationTab(
      title: NavigationTitle(title: "More".toUpperCase()),
      body: More(),
    ),
    NavigationTab(
      title: NavigationTitle(title: "Profile".toUpperCase()),
      leading: Container(
        margin: EdgeInsets.only(top: 10),
        child: IconButton(
          icon: Icon(
            Icons.qr_code_2_rounded,
            color: HomeTheme.darkTheme.colorScheme.onPrimary,
            size: 28,
          ),
          onPressed: () {
            showQRCode(user);
          },
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(top: 10),
          child: IconButton(
            icon: Icon(
              Icons.settings,
              color: HomeTheme.darkTheme.colorScheme.onPrimary,
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
      _leading = _tabs[index].leading;
      _actions = _tabs[index].actions;
    });

    if (sessionPanelController.isAttached) {
      if (!sessionPanelController.isPanelClosed) {
        sessionPanelController.close();
        setState(() {
          _sessionPanelState = PanelState.CLOSED;
        });
      }
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initConnectivity() async {
    ConnectivityResult result = ConnectivityResult.none;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      print(e.toString());
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) {
      return Future.value(null);
    }

    return _updateConnectionStatus(result);
  }

  @override
  void initState() {
    try {
      versionCheck(context);
    } catch (e) {
      print(e);
    }

    _loadPreferences();

    setState(() {
      _title = widget.title != null ? widget.title : logo;
      _leading = Container();
      _actions = [];
      _selectedIndex = widget.selectedIndex;
      _onItemTapped(widget.selectedIndex);
    });

    initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    super.initState();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.none:
        setState(() => _connectionStatus = result.toString());
        break;
      default:
        setState(() => _connectionStatus = 'Failed to get connectivity.');
        break;
    }
  }

  // Load shared preferences
  void _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool darkMode = prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark;
    int puckCount = prefs.getInt('puck_count') ?? 25;
    String fcmToken = prefs.getString('fcm_token');

    // Potentially update user's FCM Token if stale
    if (preferences.fcmToken != fcmToken) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'fcm_token': fcmToken}).then((_) => null);
    }

    // Update the preferences reference with the latest settings
    preferences = Preferences(darkMode, puckCount, fcmToken);

    Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(preferences);
  }

  @override
  Widget build(BuildContext context) {
    return _connectionStatus != "ConnectivityResult.mobile" && _connectionStatus != "ConnectivityResult.wifi"
        ? Scaffold(
            body: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                right: 0,
                bottom: 0,
                left: 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image(
                    image: AssetImage('assets/images/logo.png'),
                  ),
                  Text(
                    "Where's the wifi bud?".toUpperCase(),
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: "NovecentoSans",
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  CircularProgressIndicator(
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          )
        : SessionServiceProvider(
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
                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                            ),
                            child: ListTile(
                              tileColor: Theme.of(context).primaryColor, // This doesn't work in latest flutter upgrade
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
                                Feedback.forTap(context);
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
                            ),
                          );
                        },
                      ),
                      StartShooting(sessionPanelController: sessionPanelController),
                    ],
                  ),
                ),
                body: NestedScrollView(
                  headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                    return _selectedIndex == 2
                        ? []
                        : [
                            SliverAppBar(
                              collapsedHeight: 65,
                              expandedHeight: 125,
                              automaticallyImplyLeading: false,
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
                              leading: _leading,
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
                      icon: Icon(Icons.people),
                      label: 'Team',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.more_horiz),
                      label: 'More',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                  currentIndex: _selectedIndex,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  selectedItemColor: Theme.of(context).primaryColor,
                  unselectedItemColor: Theme.of(context).colorScheme.onPrimary,
                  onTap: _onItemTapped,
                ),
              ),
            ),
          );
  }
}

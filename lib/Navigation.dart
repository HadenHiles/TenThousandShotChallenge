import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/VersionCheck.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/Explore.dart';
import 'package:tenthousandshotchallenge/tabs/Shots.dart';
import 'package:tenthousandshotchallenge/tabs/Profile.dart';
import 'package:tenthousandshotchallenge/tabs/Friends.dart';
import 'package:tenthousandshotchallenge/tabs/Team.dart';
import 'package:tenthousandshotchallenge/tabs/profile/QR.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/Settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/tabs/shots/StartShooting.dart';
import 'package:tenthousandshotchallenge/tabs/friends/AddFriend.dart';
import 'package:tenthousandshotchallenge/tabs/team/EditTeam.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/NavigationTab.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'models/Preferences.dart';

final PanelController sessionPanelController = PanelController();

// This is the stateful widget that the main application instantiates.
class Navigation extends StatefulWidget {
  const Navigation({Key? key, this.title, this.selectedIndex, this.actions}) : super(key: key);

  final Widget? title;
  final int? selectedIndex;
  final List<Widget>? actions;

  @override
  State<Navigation> createState() => _NavigationState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _NavigationState extends State<Navigation> {
  // State variables
  Widget? _title;
  Widget? _leading;
  List<Widget>? _actions;
  int _selectedIndex = 0;
  // State variables
  PanelState _sessionPanelState = PanelState.CLOSED;
  double _bottomNavOffsetPercentage = 0;
  Team? team;
  UserProfile? userProfile;

  final logo = Container(
    height: 40,
    padding: const EdgeInsets.only(top: 6),
    child: Image.asset('assets/images/logo-text-only.png'),
  );

  final List<NavigationTab> _tabs = [
    NavigationTab(
      title: Container(
        height: 40,
        padding: const EdgeInsets.only(top: 6),
        child: Image.asset('assets/images/logo-text-only.png'),
      ),
      actions: const [],
      body: Shots(sessionPanelController: sessionPanelController),
    ),
    NavigationTab(
      title: NavigationTitle(title: "Friends".toUpperCase()),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          child: IconButton(
            icon: Icon(
              Icons.add,
              color: HomeTheme.darkTheme.colorScheme.onPrimary,
              size: 28,
            ),
            onPressed: () {
              navigatorKey.currentState?.push(MaterialPageRoute(builder: (BuildContext context) {
                return const AddFriend();
              }));
            },
          ),
        ),
      ],
      body: const Friends(),
    ),
    NavigationTab(
      title: NavigationTitle(title: "Team".toUpperCase()),
      body: const TeamPage(),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          child: IconButton(
            icon: Icon(
              Icons.qr_code_2_rounded,
              color: HomeTheme.darkTheme.colorScheme.onPrimary,
              size: 28,
            ),
            onPressed: () {
              showTeamQRCode();
            },
          ),
        ),
      ],
    ),
    const NavigationTab(
      title: null,
      body: Explore(),
    ),
    NavigationTab(
      title: NavigationTitle(title: "Profile".toUpperCase()),
      leading: Container(
        margin: const EdgeInsets.only(top: 10),
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
          margin: const EdgeInsets.only(top: 10),
          child: IconButton(
            icon: Icon(
              Icons.settings,
              color: HomeTheme.darkTheme.colorScheme.onPrimary,
              size: 28,
            ),
            onPressed: () {
              navigatorKey.currentState!.push(MaterialPageRoute(builder: (BuildContext context) {
                return const ProfileSettings();
              }));
            },
          ),
        ),
      ],
      body: const Profile(),
    ),
  ];

  void _onItemTapped(int index) async {
    if (index == 2) {
      _loadTeam();
    }

    setState(() {
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

  @override
  void initState() {
    try {
      versionCheck(context);
    } catch (e) {
      print(e);
    }

    _loadPreferences();

    _loadTeam();

    setState(() {
      _title = widget.selectedIndex == 0 ? logo : widget.title;
      _leading = Container();
      _actions = widget.actions ?? [];
      _selectedIndex = widget.selectedIndex!;
      _tabs[widget.selectedIndex!] = NavigationTab(
        title: widget.selectedIndex == 0 ? logo : widget.title,
        body: _tabs[_selectedIndex].body,
        actions: _actions!.isNotEmpty ? _actions : _tabs[_selectedIndex].actions,
      );

      _onItemTapped(widget.selectedIndex!);
    });

    super.initState();
  }

  // Load shared preferences
  void _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool darkMode = prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark;
    int puckCount = prefs.getInt('puck_count') ?? 25;
    bool friendNotifications = prefs.getBool('friend_notifications') ?? true;
    DateTime targetDate = prefs.getString('target_date') != null ? DateTime.parse(prefs.getString('target_date')!) : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100);
    String fcmToken = prefs.getString('fcm_token')!;

    // Potentially update user's FCM Token if stale
    if (preferences!.fcmToken != fcmToken) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'fcm_token': fcmToken}).then((_) => null);
    }

    // Update the preferences reference with the latest settings
    preferences = Preferences(darkMode, puckCount, friendNotifications, targetDate, fcmToken);

    if (mounted) {
      Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(preferences);
    }
  }

  Future<Null> _loadTeam() async {
    await FirebaseFirestore.instance.collection('users').doc(user?.uid).get().then((uDoc) async {
      if (uDoc.exists) {
        UserProfile userProfile = UserProfile.fromSnapshot(uDoc);

        if (userProfile.teamId != null) {
          await FirebaseFirestore.instance.collection('teams').doc(userProfile.teamId).get().then((tSnap) async {
            if (tSnap.exists) {
              Team t = Team.fromSnapshot(tSnap);

              setState(() {
                team = t;

                _tabs[2] = NavigationTab(
                  title: NavigationTitle(title: team!.name ?? "Team".toUpperCase()),
                  body: const TeamPage(),
                  actions: [
                    team!.ownerId != user!.uid
                        ? const SizedBox()
                        : Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: HomeTheme.darkTheme.colorScheme.onPrimary,
                                size: 28,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
                                  return const EditTeam();
                                }));
                              },
                            ),
                          ),
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        icon: Icon(
                          Icons.qr_code_2_rounded,
                          color: HomeTheme.darkTheme.colorScheme.onPrimary,
                          size: 28,
                        ),
                        onPressed: () {
                          showTeamQRCode();
                        },
                      ),
                    ),
                  ],
                );
              });
            }
          });
        }
      }
    });
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
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          onPanelOpened: () {
            sessionService.resume();
            setState(() {
              _sessionPanelState = PanelState.OPEN;
            });
          },
          onPanelClosed: () {
            sessionService.pause();
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
              color: Theme.of(context).colorScheme.primaryContainer,
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
                              "${printWeekday(DateTime.now())} Session",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSecondary,
                                fontFamily: "NovecentoSans",
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () {
                                    Feedback.forLongPress(context);

                                    if (!sessionService.isPaused) {
                                      sessionService.pause();
                                    } else {
                                      sessionService.resume();
                                    }
                                  },
                                  focusColor: darken(Theme.of(context).primaryColor, 0.2),
                                  enableFeedback: true,
                                  borderRadius: BorderRadius.circular(30),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Icon(
                                      sessionService.isPaused ? Icons.play_arrow : Icons.pause,
                                      size: 30,
                                      color: Colors.white,
                                    ),
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
                          ],
                        ),
                        trailing: InkWell(
                          focusColor: darken(Theme.of(context).primaryColor, 0.6),
                          enableFeedback: true,
                          borderRadius: BorderRadius.circular(30),
                          child: Icon(
                            _sessionPanelState == PanelState.CLOSED ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                          onTap: () {
                            Feedback.forLongPress(context);

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
                        contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
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
                      ),
                    );
                  },
                ),
                StartShooting(sessionPanelController: sessionPanelController),
              ],
            ),
          ),
          body: StreamProvider<NetworkStatus>(
            create: (context) {
              return NetworkStatusService().networkStatusController.stream;
            },
            initialData: NetworkStatus.Online,
            child: NetworkAwareWidget(
              onlineChild: NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  return [3].contains(_selectedIndex)
                      ? []
                      : [
                          SliverAppBar(
                            collapsedHeight: 65,
                            expandedHeight: 85,
                            automaticallyImplyLeading: [4].contains(_selectedIndex) ? true : false,
                            backgroundColor: HomeTheme.darkTheme.colorScheme.primary,
                            iconTheme: Theme.of(context).iconTheme,
                            actionsIconTheme: Theme.of(context).iconTheme,
                            centerTitle: true,
                            floating: true,
                            pinned: true,
                            flexibleSpace: DecoratedBox(
                              decoration: BoxDecoration(
                                color: HomeTheme.darkTheme.colorScheme.primaryContainer,
                              ),
                              child: FlexibleSpaceBar(
                                collapseMode: CollapseMode.parallax,
                                centerTitle: true,
                                titlePadding: const EdgeInsets.symmetric(vertical: 15),
                                title: _title,
                                background: Container(
                                  color: HomeTheme.darkTheme.colorScheme.primaryContainer,
                                ),
                              ),
                            ),
                            leading: _leading,
                            actions: _actions,
                          ),
                        ];
                },
                body: Container(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: _tabs.elementAt(_selectedIndex),
                ),
              ),
              offlineChild: Scaffold(
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
                      const Image(
                        image: AssetImage('assets/images/logo.png'),
                      ),
                      Text(
                        "Where's the wifi bud?".toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: "NovecentoSans",
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(
                        height: 25,
                      ),
                      const CircularProgressIndicator(
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
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
                icon: Icon(Icons.play_arrow_rounded),
                label: 'Start',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_rounded),
                label: 'Friends',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events_rounded),
                label: 'Team',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: 'Explore',
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/authentication/auth.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditProfile.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditPuckCount.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfileSettings extends StatefulWidget {
  ProfileSettings({Key key}) : super(key: key);

  @override
  _ProfileSettingsState createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  // State settings values
  bool _darkMode = false;
  bool _publicProfile = true;
  bool _refreshingShots = false;
  bool _shotsRefreshedOnce = false;

  @override
  void initState() {
    super.initState();

    _loadSettings();
  }

  //Loading counter value on start
  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      _darkMode = (prefs.getBool('dark_mode') ?? false);
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((snapshot) {
      UserProfile u = UserProfile.fromSnapshot(snapshot);
      setState(() {
        _publicProfile = u.public ?? false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamProvider<NetworkStatus>(
      create: (context) {
        return NetworkStatusService().networkStatusController.stream;
      },
      initialData: NetworkStatus.Online,
      child: NetworkAwareWidget(
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
        ),
        onlineChild: Scaffold(
          backgroundColor: Theme.of(context).backgroundColor,
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  collapsedHeight: 65,
                  expandedHeight: 65,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  floating: true,
                  pinned: true,
                  leading: Container(
                    margin: EdgeInsets.only(top: 10),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 28,
                      ),
                      onPressed: () {
                        navigatorKey.currentState.pop();
                      },
                    ),
                  ),
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).backgroundColor,
                    ),
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      titlePadding: null,
                      centerTitle: false,
                      title: BasicTitle(title: "Settings"),
                      background: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                  ),
                  actions: [],
                ),
              ];
            },
            body: SettingsList(
              backgroundColor: Theme.of(context).colorScheme.primaryVariant,
              lightBackgroundColor: Theme.of(context).colorScheme.primaryVariant,
              darkBackgroundColor: Theme.of(context).colorScheme.primaryVariant,
              sections: [
                SettingsSection(
                  title: 'General',
                  titleTextStyle: Theme.of(context).textTheme.headline6,
                  tiles: [
                    SettingsTile(
                      title: 'How many pucks do you have?',
                      titleTextStyle: Theme.of(context).textTheme.bodyText1,
                      subtitleTextStyle: Theme.of(context).textTheme.bodyText2,
                      leading: Container(
                        margin: EdgeInsets.only(left: 10),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              FontAwesomeIcons.hockeyPuck,
                              size: 14,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            // Top Left
                            Positioned(
                              left: -6,
                              top: -6,
                              child: Icon(
                                FontAwesomeIcons.hockeyPuck,
                                size: 8,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            // Bottom Left
                            Positioned(
                              left: -5,
                              bottom: -5,
                              child: Icon(
                                FontAwesomeIcons.hockeyPuck,
                                size: 6,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            // Top right
                            Positioned(
                              right: -4,
                              top: -6,
                              child: Icon(
                                FontAwesomeIcons.hockeyPuck,
                                size: 6,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            // Bottom right
                            Positioned(
                              right: -4,
                              bottom: -8,
                              child: Icon(
                                FontAwesomeIcons.hockeyPuck,
                                size: 8,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onPressed: (BuildContext context) {
                        navigatorKey.currentState.push(
                          MaterialPageRoute(
                            builder: (context) {
                              return EditPuckCount();
                            },
                          ),
                        );
                      },
                    ),
                    SettingsTile.switchTile(
                      titleTextStyle: Theme.of(context).textTheme.bodyText1,
                      title: 'Dark Mode',
                      leading: Icon(
                        Icons.brightness_2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      switchValue: _darkMode,
                      onToggle: (bool value) async {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        setState(() {
                          _darkMode = !_darkMode;
                          prefs.setBool('dark_mode', _darkMode);
                        });

                        Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(
                          Preferences(
                            value,
                            prefs.getInt('puck_count'),
                            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
                            prefs.getString('fcm_token'),
                          ),
                        );
                      },
                    ),
                    SettingsTile(
                      title: "Recalculate Shot Totals",
                      titleTextStyle: Theme.of(context).textTheme.bodyText1,
                      subtitleTextStyle: Theme.of(context).textTheme.bodyText2,
                      subtitle: "Use this if your shot count is out of sync",
                      enabled: true,
                      leading: _refreshingShots
                          ? Container(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Theme.of(context).primaryColor,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      onPressed: (context) async {
                        if (_shotsRefreshedOnce) {
                          setState(() {
                            _refreshingShots = true;
                          });

                          Future.delayed(Duration(milliseconds: 800)).then(
                            (value) => setState(() {
                              _refreshingShots = false;
                            }),
                          );
                        } else {
                          setState(() {
                            _refreshingShots = true;
                          });
                          await recalculateIterationTotals().then((_) {
                            Future.delayed(Duration(milliseconds: 200)).then(
                              (value) {
                                setState(() {
                                  _refreshingShots = false;
                                  _shotsRefreshedOnce = true;
                                });

                                Fluttertoast.showToast(
                                  msg: 'Finished recalculating shot totals',
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  timeInSecForIosWeb: 1,
                                  backgroundColor: Theme.of(context).cardTheme.color,
                                  textColor: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 16.0,
                                );
                              },
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  titleTextStyle: Theme.of(context).textTheme.headline6,
                  title: 'Account',
                  tiles: [
                    SettingsTile.switchTile(
                      titleTextStyle: Theme.of(context).textTheme.bodyText1,
                      title: 'Public',
                      leading: Icon(
                        Icons.privacy_tip_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      switchValue: _publicProfile,
                      onToggle: (bool value) async {
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'public': !_publicProfile}).then((_) {
                          setState(() {
                            _publicProfile = !_publicProfile;
                          });
                        });
                      },
                    ),
                    SettingsTile(
                      title: 'Edit Profile',
                      titleTextStyle: Theme.of(context).textTheme.bodyText1,
                      subtitleTextStyle: Theme.of(context).textTheme.bodyText2,
                      leading: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: (BuildContext context) {
                        navigatorKey.currentState.push(
                          MaterialPageRoute(
                            builder: (context) {
                              return EditProfile();
                            },
                          ),
                        );
                      },
                    ),
                    SettingsTile(
                      title: 'Logout',
                      titleTextStyle: TextStyle(
                        color: Colors.red,
                        fontSize: Theme.of(context).textTheme.bodyText1.fontSize,
                      ),
                      subtitleTextStyle: Theme.of(context).textTheme.bodyText2,
                      leading: Icon(
                        Icons.logout,
                        color: Colors.red,
                      ),
                      onPressed: (BuildContext context) {
                        signOut();

                        navigatorKey.currentState.pop();
                        navigatorKey.currentState.pushReplacement(
                          MaterialPageRoute(
                            builder: (context) {
                              return Login();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

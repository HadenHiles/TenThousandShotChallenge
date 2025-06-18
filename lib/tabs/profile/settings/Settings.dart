import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:url_launcher/url_launcher_string.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  // State settings values
  bool _darkMode = false;
  bool _friendNotifications = true;
  bool _publicProfile = true;
  bool _refreshingShots = false;
  bool _shotsRefreshedOnce = false;

  // Simulated subscription level (replace with RevenueCat or your backend)
  String _subscriptionLevel = "Free"; // Can be "Free", "Premium", or "Pro"

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSubscriptionLevel();
  }

  //Loading counter value on start
  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      _darkMode = (prefs.getBool('dark_mode') ?? false);
    });

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).get().then((snapshot) {
      UserProfile u = UserProfile.fromSnapshot(snapshot);
      setState(() {
        _publicProfile = u.public ?? false;
        _friendNotifications = u.friendNotifications ?? true;
      });
    });
  }

  // Simulate loading subscription level (replace with RevenueCat logic)
  Future<void> _loadSubscriptionLevel() async {
    // TODO: Replace this with your actual subscription check
    // For demonstration, we'll just keep it as "Free"
    setState(() {
      _subscriptionLevel = "Free";
      // _subscriptionLevel = "Premium";
      // _subscriptionLevel = "Pro";
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
        onlineChild: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
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
                    margin: const EdgeInsets.only(top: 10),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 28,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      titlePadding: null,
                      centerTitle: false,
                      title: const BasicTitle(title: "Settings"),
                      background: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                  ),
                  actions: const [],
                ),
              ];
            },
            body: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 70), // Add enough space for the footer
                  child: SettingsList(
                    lightTheme: SettingsThemeData(
                      settingsListBackground: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    darkTheme: SettingsThemeData(
                      settingsListBackground: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    sections: [
                      // Subscription Section
                      SettingsSection(
                        title: Text(
                          'Subscription',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        tiles: [
                          SettingsTile(
                            title: Text(
                              'Subscription Level',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            description: Text(
                              _subscriptionLevel,
                              style: TextStyle(
                                color: _subscriptionLevel == "Free"
                                    ? Colors.grey
                                    : _subscriptionLevel == "Premium"
                                        ? Colors.blue
                                        : Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            leading: Icon(
                              Icons.workspace_premium,
                              color: _subscriptionLevel == "Free"
                                  ? Colors.grey
                                  : _subscriptionLevel == "Premium"
                                      ? Colors.blue
                                      : Colors.amber,
                            ),
                            onPressed: (BuildContext context) {
                              // Show a dialog or navigate to a subscription management screen
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Manage Subscription'),
                                  content: Text(
                                    _subscriptionLevel == "Free" ? "Upgrade to Premium or Pro to unlock advanced features like shot accuracy tracking and more!" : "You are currently on the $_subscriptionLevel plan.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                    if (_subscriptionLevel == "Free")
                                      ElevatedButton(
                                        onPressed: () {
                                          // TODO: Integrate RevenueCat paywall here
                                          Navigator.of(context).pop();
                                          Fluttertoast.showToast(
                                            msg: 'Subscription flow coming soon!',
                                            toastLength: Toast.LENGTH_SHORT,
                                          );
                                        },
                                        child: const Text('Upgrade'),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SettingsSection(
                        title: Text(
                          'General',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        tiles: [
                          SettingsTile(
                            title: Text(
                              'How many pucks do you have?',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            leading: Container(
                              margin: const EdgeInsets.only(left: 10),
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
                              navigatorKey.currentState!.push(
                                MaterialPageRoute(
                                  builder: (context) {
                                    return const EditPuckCount();
                                  },
                                ),
                              );
                            },
                          ),
                          SettingsTile.switchTile(
                            title: Text(
                              'Dark Mode',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            leading: Icon(
                              Icons.brightness_2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            initialValue: _darkMode,
                            onToggle: (bool value) async {
                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              setState(() {
                                _darkMode = !_darkMode;
                                prefs.setBool('dark_mode', _darkMode);
                              });

                              if (context.mounted) {
                                Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(
                                  Preferences(
                                    value,
                                    prefs.getInt('puck_count'),
                                    prefs.getBool('friend_notifications'),
                                    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
                                    prefs.getString('fcm_token'),
                                  ),
                                );
                              }
                            },
                          ),
                          SettingsTile(
                            title: Text(
                              "Recalculate Shot Totals",
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            description: Text(
                              "Use this if your shot count is out of sync",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            enabled: true,
                            leading: _refreshingShots
                                ? SizedBox(
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

                                Future.delayed(const Duration(milliseconds: 800)).then(
                                  (value) => setState(() {
                                    _refreshingShots = false;
                                  }),
                                );
                              } else {
                                setState(() {
                                  _refreshingShots = true;
                                });
                                await recalculateIterationTotals().then((_) {
                                  Future.delayed(const Duration(milliseconds: 200)).then(
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
                        title: Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
                        tiles: [
                          SettingsTile.switchTile(
                            title: Text(
                              'Friend Session Notifications',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            leading: Icon(
                              Icons.brightness_2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            initialValue: _friendNotifications,
                            onToggle: (bool value) async {
                              SharedPreferences prefs = await SharedPreferences.getInstance();

                              await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'friend_notifications': !_friendNotifications}).then((_) {
                                setState(() {
                                  _friendNotifications = !_friendNotifications;
                                  prefs.setBool('friend_notifications', _friendNotifications);
                                });
                              });

                              if (context.mounted) {
                                Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(
                                  Preferences(
                                    prefs.getBool('dark_mode'),
                                    prefs.getInt('puck_count'),
                                    value,
                                    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
                                    prefs.getString('fcm_token'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      SettingsSection(
                        title: Text(
                          'Account',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        tiles: [
                          SettingsTile.switchTile(
                            title: Text(
                              'Public',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            leading: Icon(
                              Icons.privacy_tip_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            initialValue: _publicProfile,
                            onToggle: (bool value) async {
                              await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'public': !_publicProfile}).then((_) {
                                setState(() {
                                  _publicProfile = !_publicProfile;
                                });
                              });
                            },
                          ),
                          SettingsTile(
                            title: Text(
                              'Edit Profile',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            leading: Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            onPressed: (BuildContext context) {
                              navigatorKey.currentState!.push(
                                MaterialPageRoute(
                                  builder: (context) {
                                    return const EditProfile();
                                  },
                                ),
                              );
                            },
                          ),
                          SettingsTile(
                            title: Row(
                              children: [
                                Text(
                                  'Delete Account',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: RotatedBox(
                                    quarterTurns: 2,
                                    child: Icon(
                                      Icons.info_outlined,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            leading: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            onPressed: (BuildContext context) {
                              showDialog(
                                context: context,
                                builder: (_) {
                                  return AlertDialog(
                                    title: const Text(
                                      "Are you absolutely sure you want to delete your account?",
                                      style: TextStyle(
                                        fontFamily: 'NovecentoSans',
                                        fontSize: 24,
                                      ),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "All of your data will be lost, and there is no undoing this action. The app will close upon continuing with deletion.",
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: Text(
                                          "Cancel".toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'NovecentoSans',
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          FirebaseAuth.instance.currentUser!.delete().then((_) {
                                            navigatorKey.currentState!.pop();
                                            navigatorKey.currentState!.pushReplacement(MaterialPageRoute(builder: (_) {
                                              return const Login();
                                            }));

                                            SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                                          }).onError((FirebaseAuthException error, stackTrace) {
                                            String msg = error.code == "requires-recent-login" ? "This action requires a recent login, please logout and try again." : "Error deleting account, please email admin@howtohockey.com";
                                            Fluttertoast.showToast(
                                              msg: msg,
                                              toastLength: Toast.LENGTH_LONG,
                                              gravity: ToastGravity.BOTTOM,
                                              timeInSecForIosWeb: 1,
                                              backgroundColor: Theme.of(context).cardTheme.color,
                                              textColor: Theme.of(context).colorScheme.onPrimary,
                                              fontSize: 16.0,
                                            );
                                          });
                                        },
                                        child: Text(
                                          "Delete Account".toUpperCase(),
                                          style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).primaryColor),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          SettingsTile(
                            title: Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: Theme.of(context).textTheme.bodyLarge!.fontSize,
                              ),
                            ),
                            leading: const Icon(
                              Icons.logout,
                              color: Colors.red,
                            ),
                            onPressed: (BuildContext context) {
                              signOut();

                              navigatorKey.currentState!.pop();
                              navigatorKey.currentState!.pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) {
                                    return const Login();
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
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 0, bottom: 5),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3), //color of shadow
                          spreadRadius: 2, //spread radius
                          blurRadius: 10, // blur radius
                          offset: const Offset(0, 0), // changes position of shadow
                          //first paramerter of offset is left-right
                          //second parameter is top to down
                        ),
                      ],
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              FontAwesomeIcons.github,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                            TextButton(
                              style: ButtonStyle(
                                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 0, horizontal: 10)),
                                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                              ),
                              onPressed: () async {
                                String link = "https://github.com/HadenHiles";
                                await canLaunchUrlString(link).then((can) {
                                  launchUrlString(link).catchError((err) {
                                    print(err);
                                    return false;
                                  });
                                });
                              },
                              child: Text(
                                "Developed by Haden Hiles".toLowerCase(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 16,
                                  fontFamily: "NovecentoSans",
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.all(0),
                          height: 35,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                FontAwesomeIcons.copyright,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 10,
                              ),
                              TextButton(
                                style: ButtonStyle(
                                  padding: WidgetStateProperty.all(const EdgeInsets.only(bottom: 2, left: 5)),
                                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                                ),
                                onPressed: () async {
                                  String link = "https://howtohockey.com";
                                  await canLaunchUrlString(link).then((can) {
                                    launchUrlString(link).catchError((err) {
                                      print(err);
                                      return false;
                                    });
                                  });
                                },
                                child: Text(
                                  "How To Hockey Inc.".toLowerCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 14,
                                    fontFamily: "NovecentoSans",
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

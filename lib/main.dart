import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Setup a navigation key so that we can navigate without context
final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

// Global variables
Preferences preferences = Preferences(false, 25);
final sessionService = SessionService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the connection to our firebase project
  await Firebase.initializeApp();

  // Load app settings
  SharedPreferences prefs = await SharedPreferences.getInstance();
  preferences = Preferences(
    prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark,
    prefs.getInt('puck_count') ?? 25,
  );

  runApp(
    ChangeNotifierProvider<PreferencesStateNotifier>(
      create: (_) => PreferencesStateNotifier(),
      child: Home(),
    ),
  );
}

class Home extends StatelessWidget {
  // Get a reference to the potentially signed in firebase user
  final user = FirebaseAuth.instance.currentUser;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Lock device orientation to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return Consumer<PreferencesStateNotifier>(
      builder: (context, settingsState, child) {
        preferences = settingsState.preferences;

        return MaterialApp(
          title: '10,000 Shot Challenge',
          navigatorKey: navigatorKey,
          theme: HomeTheme.lightTheme,
          darkTheme: HomeTheme.darkTheme,
          themeMode: preferences.darkMode ? ThemeMode.dark : ThemeMode.system,
          home: user != null ? Navigation() : Login(),
        );
      },
    );
  }
}

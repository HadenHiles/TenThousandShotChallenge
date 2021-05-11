import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/models/Settings.dart';
import 'package:tenthousandshotchallenge/theme/SettingsStateNotifier.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Setup a navigation key so that we can navigate without context
final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

// Create a global variable for referencing app settings
Settings settings = Settings(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the connection to our firebase project
  await Firebase.initializeApp();

  // Load app settings
  SharedPreferences prefs = await SharedPreferences.getInstance();
  settings = Settings(
    prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark,
  );

  runApp(
    ChangeNotifierProvider<SettingsStateNotifier>(
      create: (_) => SettingsStateNotifier(),
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

    return Consumer<SettingsStateNotifier>(
      builder: (context, settingsState, child) {
        settings = settingsState.settings;

        return MaterialApp(
          title: '10,000 Shot Challenge',
          navigatorKey: navigatorKey,
          theme: HomeTheme.lightTheme,
          darkTheme: HomeTheme.darkTheme,
          themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.system,
          home: user != null ? Navigation() : Login(),
        );
      },
    );
  }
}

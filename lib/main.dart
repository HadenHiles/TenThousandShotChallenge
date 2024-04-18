import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tenthousandshotchallenge/IntroScreen.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/services/authentication/auth.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:global_configuration/global_configuration.dart';

// Setup a navigation key so that we can navigate without context
final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

// Global variables
final user = FirebaseAuth.instance.currentUser;
Preferences? preferences = Preferences(false, 25, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100), null);
final sessionService = SessionService();
final Color wristShotColor = Color(0xff00BCD4);
final Color snapShotColor = Color(0xff2296F3);
final Color backhandShotColor = Color(0xff4050B5);
final Color slapShotColor = Color(0xff009688);
bool introShown = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the connection to our firebase project
  await Firebase.initializeApp();
  final appleSignInAvailable = await AppleSignInAvailable.check();

  // Load global app configurations
  await GlobalConfiguration().loadFromAsset("youtube_settings");

  // Load user preferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  preferences = Preferences(
    prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark,
    prefs.getInt('puck_count') ?? 25,
    prefs.getString('target_date') != null ? DateTime.parse(prefs.getString('target_date')!) : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
    prefs.getString('fcm_token'),
  );

  introShown = prefs.getBool('intro_shown') == null ? false : true;

  /**
   * Firebase messaging setup
   */
  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  // Only relevant for IOS
  NotificationSettings settings = await firebaseMessaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  // Get the user's FCM token
  firebaseMessaging.getToken().then((token) {
    if (preferences!.fcmToken != token) {
      prefs.setString('fcm_token', token!); // Svae the fcm token to local storage (will save to firestore after user authenticates)
    }

    print("FCM token: $token"); // Print the Token in Console
  });

  // Listen for firebase messages
  FirebaseMessaging.onBackgroundMessage(_messageHandler);
  // Listen for message clicks
  FirebaseMessaging.onMessageOpenedApp.listen(_messageClickHandler);

  runApp(
    Provider<AppleSignInAvailable>.value(
      value: appleSignInAvailable,
      child: ChangeNotifierProvider<PreferencesStateNotifier>(
        create: (_) => PreferencesStateNotifier(),
        child: Home(),
      ),
    ),
  );
}

/*
 * Called when a background message is sent from firebase cloud messaging
 */
Future<void> _messageHandler(RemoteMessage message) async {
  print('background message ${message.notification!.body}');
}

Future<void> _messageClickHandler(RemoteMessage message) async {
  print('Background message clicked!');
}

class Home extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Lock device orientation to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    FirebaseAnalytics analytics = FirebaseAnalytics.instance;

    return Consumer<PreferencesStateNotifier>(
      builder: (context, settingsState, child) {
        preferences = settingsState.preferences;

        return MaterialApp(
          title: '10,000 Shot Challenge',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: preferences!.darkMode! ? HomeTheme.darkTheme : HomeTheme.lightTheme,
          darkTheme: HomeTheme.darkTheme,
          themeMode: preferences!.darkMode! ? ThemeMode.dark : ThemeMode.system,
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: analytics),
          ],
          home: !introShown
              ? IntroScreen()
              : (user != null
                  ? Navigation(
                      title: null,
                      selectedIndex: 0,
                    )
                  : Login()),
        );
      },
    );
  }
}

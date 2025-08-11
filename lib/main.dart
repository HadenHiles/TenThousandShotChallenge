import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/services/authentication/auth.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:global_configuration/global_configuration.dart';
import 'router.dart';
import 'package:go_router/go_router.dart';

// Global variables
final user = FirebaseAuth.instance.currentUser;
Preferences? preferences = Preferences(false, 25, true, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100), null);
final sessionService = SessionService();
const Color wristShotColor = Color(0xff00BCD4);
const Color snapShotColor = Color(0xff2296F3);
const Color backhandShotColor = Color(0xff4050B5);
const Color slapShotColor = Color(0xff009688);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock device orientation to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize the connection to our firebase project
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final appleSignInAvailable = await AppleSignInAvailable.check();

  // RevenueCat will be initialized after user login

  // Load global app configurations
  await GlobalConfiguration().loadFromAsset("youtube_settings");

  // Load user preferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  preferences = Preferences(
    prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark,
    prefs.getInt('puck_count') ?? 25,
    prefs.getBool('friend_notifications') ?? true,
    prefs.getString('target_date') != null ? DateTime.parse(prefs.getString('target_date')!) : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
    prefs.getString('fcm_token'),
  );

  // Load intro_shown synchronously before building the app
  final introShown = prefs.getBool('intro_shown') ?? false;
  final introShownNotifier = IntroShownNotifier.withValue(introShown);

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
  print('User granted permission: \\${settings.authorizationStatus}');

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

  // Check for camera permissions
  await Permission.camera.request();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppleSignInAvailable>.value(value: appleSignInAvailable),
        ChangeNotifierProvider<PreferencesStateNotifier>(
          create: (_) => PreferencesStateNotifier(),
        ),
        Provider<Preferences>.value(value: preferences!),
        Provider<FirebaseAuth>.value(value: FirebaseAuth.instance),
        Provider<FirebaseFirestore>.value(value: FirebaseFirestore.instance),
        Provider<FirebaseAnalytics>.value(value: FirebaseAnalytics.instance),
        ChangeNotifierProvider<CustomerInfoNotifier>(
          create: (_) => CustomerInfoNotifier(),
        ),
        Provider<NetworkStatusService>(
          create: (context) => NetworkStatusService(
            isTesting: false, // Always false in production
          ),
        ),
        ChangeNotifierProvider<IntroShownNotifier>.value(value: introShownNotifier),
      ],
      child: Home(introShownNotifier: introShownNotifier),
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

Future<void> initRevenueCat(String? appUserID) async {
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration? configuration;

  if (Platform.isAndroid) {
    configuration = PurchasesConfiguration("goog_lMkTFgSIHgkcidnIYJvtHQCzQKs");
  } else if (Platform.isIOS) {
    configuration = PurchasesConfiguration("appl_PcUjDTGDZGysagZYobhltwmeGrq");
  }

  if (configuration != null) {
    configuration.appUserID = appUserID;
    await Purchases.configure(configuration);
  }
}

// Optional: kept for backward compatibility but unused now
Future<CustomerInfo?> getCustomerInfo() async {
  try {
    return await Purchases.getCustomerInfo();
  } on PlatformException catch (e) {
    print('Error fetching customer info: ${e.message}');
    return null;
  }
}

class Home extends StatefulWidget {
  final IntroShownNotifier introShownNotifier;
  const Home({super.key, required this.introShownNotifier});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final AuthChangeNotifier _authNotifier;
  User? _lastUser;
  late final VoidCallback _authListener;

  @override
  void initState() {
    super.initState();
    _authNotifier = AuthChangeNotifier(Provider.of<FirebaseAuth>(context, listen: false));
    WidgetsBinding.instance.addObserver(this);
    // Create the GoRouter instance once and reuse it
    _router = createAppRouter(
      Provider.of<FirebaseAnalytics>(context, listen: false),
      authNotifier: _authNotifier,
      introShownNotifier: widget.introShownNotifier,
    );

    // Listen for auth changes via _authNotifier and initialize RevenueCat when user is available
    _authListener = () async {
      final user = _authNotifier.user;
      if (user != null && user.uid != _lastUser?.uid) {
        await initRevenueCat(user.uid);
        // After login, ensure notifier is available and refreshed
        try {
          final notifier = Provider.of<CustomerInfoNotifier>(context, listen: false);
          notifier.attach();
          await notifier.refresh();
        } catch (_) {}
        _lastUser = user;
        // Set user's timezone in Firestore
        try {
          final String timezone = await FlutterTimezone.getLocalTimezone();
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'timezone': timezone,
          }, SetOptions(merge: true));
        } catch (e) {
          // Optionally log error
        }
      }
    };
    _authNotifier.addListener(_authListener);
    // Trigger once in case user is already logged in
    _authListener();
  }

  @override
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authNotifier.removeListener(_authListener);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // On resume, invalidate cache and refresh entitlements
      Purchases.invalidateCustomerInfoCache();
      try {
        final notifier = Provider.of<CustomerInfoNotifier>(context, listen: false);
        notifier.attach();
        notifier.refresh();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only rebuild for theme changes, not router
    return Consumer<PreferencesStateNotifier>(
      builder: (context, settingsState, child) {
        preferences = settingsState.preferences;
        return MaterialApp.router(
          title: '10,000 Shot Challenge',
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          theme: preferences!.darkMode! ? HomeTheme.darkTheme : HomeTheme.lightTheme,
          darkTheme: HomeTheme.darkTheme,
          themeMode: preferences!.darkMode! ? ThemeMode.dark : ThemeMode.system,
        );
      },
    );
  }
}

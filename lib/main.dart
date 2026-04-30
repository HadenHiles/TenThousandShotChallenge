import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'services/RevenueCatConfig.dart';
import 'services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/services/LocalNotificationService.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/OfflineSessionQueue.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/services/authentication/auth.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:global_configuration/global_configuration.dart';
import 'router.dart';
import 'package:go_router/go_router.dart';
import 'package:overlay_support/overlay_support.dart';

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

  // Load intro_shown synchronously before building the app; compare stored version
  // against the current app version so updates prompt the welcome screen again.
  final packageInfo = await PackageInfo.fromPlatform();
  final introShownVersion = prefs.getString('intro_shown_version');
  final introShown = introShownVersion == packageInfo.version;
  final introShownNotifier = IntroShownNotifier.withValue(introShown);

  // Initialize local notifications (channels + timezone setup).
  await LocalNotificationService.initialize();

  // Re-schedule the daily reminder so it survives reboots and reinstalls.
  final reminderH = prefs.getInt('reminder_hour') ?? 17;
  final reminderM = prefs.getInt('reminder_minute') ?? 0;
  await LocalNotificationService.scheduleDailyReminder(hour: reminderH, minute: reminderM);

  // Initialize navigation environment (Android SDK + system paddings)
  await initNavigationEnvironment();

  /**
   * Firebase messaging setup
   */
  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  // Get the user's FCM token
  // Note: the OS notification permission dialog is now requested during the
  // onboarding intro / permissions screen - not here at cold start.
  firebaseMessaging.getToken().then((token) {
    if (token != null && preferences!.fcmToken != token) {
      prefs.setString('fcm_token', token);
    }
  }).catchError((e) {
    // On iOS the APNS token may not be available immediately at cold start
    // (e.g. first launch, device just booted). The token will be obtained
    // later via onTokenRefresh, so this is safe to ignore.
    debugPrint('FCM getToken skipped: $e');
  });

  // Refresh token whenever FCM rotates it so Firestore stays up to date.
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final savedPrefs = await SharedPreferences.getInstance();
    await savedPrefs.setString('fcm_token', newToken);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({'fcm_token': newToken});
    }
  });

  // Show FCM messages that arrive while the app is in the foreground as an
  // in-app banner so no system notification is added to the tray.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final title = notification.title ?? 'New notification';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showInAppBanner(title: title, body: notification.body);
      return;
    }
    // Wait until the Firestore notification doc actually lands before
    // showing the banner so the list is already populated when tapped.
    _showBannerWhenReady(uid: uid, title: title, body: notification.body);
  });

  // Listen for firebase background messages
  FirebaseMessaging.onBackgroundMessage(_messageHandler);
  // Listen for message clicks (app in background, not terminated)
  FirebaseMessaging.onMessageOpenedApp.listen(_messageClickHandler);

  // Handle cold-start: app was terminated and launched by tapping a notification.
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    LocalNotificationService.pendingRoute = '/notifications';
  }

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
        ChangeNotifierProvider<PermissionsNotifier>(
          create: (_) => PermissionsNotifier(),
        ),
      ],
      child: Home(introShownNotifier: introShownNotifier),
    ),
  );
}

/*
 * Called when a background FCM message is received.
 * Note: data-only messages have no notification field - guard against null.
 */
Future<void> _messageHandler(RemoteMessage message) async {
  final body = message.notification?.body ?? message.data['body'];
  print('background message: $body');
}

Future<void> _messageClickHandler(RemoteMessage message) async {
  // Route all FCM notification taps to the in-app notification centre.
  LocalNotificationService.pendingRoute = '/notifications';
}

/// Show the in-app banner immediately (used as a fallback when uid is unknown).
void _showInAppBanner({required String title, String? body}) {
  showOverlayNotification(
    (context) => _FcmBanner(title: title, body: body),
    duration: const Duration(seconds: 6),
  );
}

/// Listen for the Firestore notification document created by the Cloud Function
/// and show the banner as soon as it arrives. Falls back to showing after 20s
/// if Firestore is slow.
void _showBannerWhenReady({
  required String uid,
  required String title,
  String? body,
}) {
  // Accept any notification doc created within the last 60 seconds so we're
  // tolerant of minor clock skew between server and client.
  final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
  Timer? timer;

  void show() {
    timer?.cancel();
    sub?.cancel();
    _showInAppBanner(title: title, body: body);
  }

  sub = FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').orderBy('created_at', descending: true).limit(1).snapshots().listen((snapshot) {
    if (snapshot.docs.isEmpty) return;
    final ts = snapshot.docs.first.data()['created_at'];
    if (ts is Timestamp && ts.toDate().isAfter(cutoff)) {
      show();
    }
  });

  // Fallback: show after 20s even if Firestore hasn't synced.
  timer = Timer(const Duration(seconds: 20), show);
}

Future<void> initRevenueCat(String? appUserID) async {
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration? configuration;

  if (Platform.isAndroid) {
    configuration = PurchasesConfiguration("goog_lMkTFgSIHgkcidnIYJvtHQCzQKs");
    print('RevenueCat: Initializing for Android with user: $appUserID');
  } else if (Platform.isIOS) {
    configuration = PurchasesConfiguration("appl_PcUjDTGDZGysagZYobhltwmeGrq");
    print('RevenueCat: Initializing for iOS with user: $appUserID');
  }

  if (configuration != null) {
    configuration.appUserID = appUserID;
    try {
      await Purchases.configure(configuration);
      RevenueCatConfig.configured = true;
      print('RevenueCat: Successfully configured');

      // Check if offerings are available
      try {
        final offerings = await Purchases.getOfferings();
        print('RevenueCat: Found ${offerings.all.length} offerings');
        if (offerings.current != null) {
          print('RevenueCat: Current offering: ${offerings.current!.identifier}');
          print('RevenueCat: Available packages: ${offerings.current!.availablePackages.length}');
        } else {
          print('RevenueCat: WARNING - No current offering found! Configure offerings in RevenueCat dashboard.');
        }
      } catch (e) {
        print('RevenueCat: Error fetching offerings: $e');
      }
    } catch (e) {
      print('RevenueCat: Configuration failed: $e');
      RevenueCatConfig.configured = false;
    }
  } else {
    print('RevenueCat: Platform not supported or configuration is null');
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

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
      permissionsNotifier: Provider.of<PermissionsNotifier>(context, listen: false),
    );
    // Give LocalNotificationService a reference so notification taps can navigate.
    LocalNotificationService.setRouter(_router);

    // Listen for auth changes via _authNotifier and initialize RevenueCat when user is available
    _authListener = () async {
      final user = _authNotifier.user;
      if (user != null && user.uid != _lastUser?.uid) {
        await initRevenueCat(user.uid);
        if (RevenueCatConfig.configured) {
          try {
            final notifier = Provider.of<CustomerInfoNotifier>(context, listen: false);
            notifier.attach();
            await notifier.refresh();

            // Show the Pro Access Paywall for first-time users (onboarding)
            final prefs = await SharedPreferences.getInstance();
            final paywallShown = prefs.getBool('paywall_shown') ?? false;
            if (!paywallShown && !notifier.isPro && context.mounted) {
              await prefs.setBool('paywall_shown', true);
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (context.mounted) {
                  await presentPaywallIfNeeded(context);
                }
              });
            }
          } catch (_) {}
        }
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

    // Sync queued offline sessions as soon as connectivity comes back.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      if (results.contains(ConnectivityResult.none)) return;
      final auth = Provider.of<FirebaseAuth>(context, listen: false);
      final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
      await OfflineSessionQueue.instance.syncPending(auth, firestore);
    });
  }

  @override
  @override
  void dispose() {
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _authNotifier.removeListener(_authListener);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-enable Firestore network now that the app is foregrounded.
      FirebaseFirestore.instance.enableNetwork().catchError((_) {});
      if (RevenueCatConfig.configured) {
        // On resume, invalidate cache and refresh entitlements
        Purchases.invalidateCustomerInfoCache();
        try {
          final notifier = Provider.of<CustomerInfoNotifier>(context, listen: false);
          notifier.attach();
          notifier.refresh();
        } catch (_) {}
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Disable Firestore's persistent connection while the app is in the
      // background so the SDK doesn't spam DNS-failure warnings when Android
      // restricts network access for background processes.
      FirebaseFirestore.instance.disableNetwork().catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only rebuild for theme changes, not router
    return Consumer<PreferencesStateNotifier>(
      builder: (context, settingsState, child) {
        preferences = settingsState.preferences;
        return OverlaySupport.global(
          child: MaterialApp.router(
            title: '10,000 Shot Challenge',
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            theme: (preferences!.darkMode! || MediaQuery.of(context).platformBrightness == Brightness.dark) ? HomeTheme.darkTheme : HomeTheme.lightTheme,
            darkTheme: HomeTheme.darkTheme,
            themeMode: preferences!.darkMode! ? ThemeMode.dark : ThemeMode.system,
            builder: (ctx, child) {
              // Safe MediaQuery available here
              final extraBottom = isThreeButtonAndroidNavigation(ctx) ? MediaQuery.paddingOf(ctx).bottom : 0.0;
              return Padding(
                padding: EdgeInsets.only(bottom: extraBottom),
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}

/// Top-of-screen banner shown when an FCM message arrives while the app is
/// in the foreground. Tapping it navigates to the in-app notification centre.
class _FcmBanner extends StatelessWidget {
  const _FcmBanner({required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              OverlaySupportEntry.of(context)!.dismiss();
              LocalNotificationService.cancelForegroundMessages();
              LocalNotificationService.pushTo('/notifications');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (body != null && body!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            body!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    onPressed: () => OverlaySupportEntry.of(context)!.dismiss(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

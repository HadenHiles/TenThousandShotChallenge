import 'dart:async';
import 'dart:io';

import 'package:fvp/fvp.dart' as fvp;

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
import 'package:tenthousandshotchallenge/services/ObservabilityService.dart';
import 'package:tenthousandshotchallenge/services/OfflineSessionQueue.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/services/TeamMembershipService.dart';
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

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    ObservabilityService.installGlobalErrorHandlers();
    runApp(const AppBootstrap());
  }, (error, stackTrace) {
    ObservabilityService.recordError(
      error,
      stackTrace,
      reason: 'Uncaught root zone error',
      fatal: true,
    );
  });
}

typedef AppInitializer = Future<Widget> Function();

Future<FirebaseApp>? _firebaseInitialization;

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, this.initializer = _initializeApp});

  final AppInitializer initializer;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  static const _startupTimeout = Duration(seconds: 20);

  Widget? _app;
  Object? _error;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    // Let Flutter replace the native launch screen before invoking plugins.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final attempt = ++_attempt;
    if (mounted) {
      setState(() {
        _app = null;
        _error = null;
      });
    }

    try {
      final app = await widget.initializer().timeout(_startupTimeout);
      if (!mounted || attempt != _attempt) return;
      setState(() => _app = app);
    } catch (error, stackTrace) {
      _logStartupError('application', error, stackTrace);
      ObservabilityService.recordError(
        error,
        stackTrace,
        reason: 'Application initialization failed',
      );
      if (!mounted || attempt != _attempt) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xffCC3333),
        body: SafeArea(
          child: Center(
            child: _error == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to start the app',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: _initialize, child: const Text('Retry')),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

Future<Widget> _initializeApp() async {
  // Use fvp as the video_player backend so WebM (VP8/VP9) works on iOS.
  //
  // Restricted to iOS only – on Android the default ExoPlayer backend already
  // supports WebM/VP9 natively and handles Firebase Storage URLs correctly.
  // fvp's libmdk network stack on Android does not handle the Firebase Storage
  // auth-token URL format reliably, which caused WebM videos to silently fail.
  //
  // Decoder priority on iOS:
  //   1. VT       – libmdk's own VideoToolbox decoder (hardware H.264/HEVC)
  //   2. VideoToolbox – FFmpeg's VideoToolbox decoder, which maps directly to
  //                     the iOS VP9 hardware decode path (A9+ / iOS 11+).
  //                     The libmdk VT decoder only activates VP9 hardware on
  //                     macOS 11+, so this explicit entry is needed for iOS.
  //   3. FFmpeg   – software fallback for any codec not covered above.
  try {
    fvp.registerWith(options: {
      'platforms': ['ios'],
      'video.decoders': ['VT', 'VideoToolbox', 'FFmpeg'],
    });
  } catch (error, stackTrace) {
    _reportOptionalStartupError('video backend', error, stackTrace);
  }

  // Reduce Flutter's image cache from the 100 MB default to limit heap
  // pressure on low-memory Android devices.
  PaintingBinding.instance.imageCache.maximumSize = 50;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB

  // Lock device orientation to portrait mode
  await _runOptionalStartupTask(
    'device orientation',
    () => SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  // Share an in-flight initialization across retries. Native initialization
  // cannot be cancelled when a Dart timeout fires, and starting it twice can
  // leave Firebase in an inconsistent state.
  final firebaseInitialization = _firebaseInitialization ??= Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await firebaseInitialization.timeout(const Duration(seconds: 15));
  } catch (error) {
    if (error is! TimeoutException && identical(_firebaseInitialization, firebaseInitialization)) {
      _firebaseInitialization = null;
    }
    rethrow;
  }
  await ObservabilityService.initialize();
  await ObservabilityService.logEvent('app_started');
  AppleSignInAvailable appleSignInAvailable;
  try {
    appleSignInAvailable = await AppleSignInAvailable.check().timeout(const Duration(seconds: 5));
  } catch (error, stackTrace) {
    _reportOptionalStartupError('Apple Sign In availability', error, stackTrace);
    appleSignInAvailable = AppleSignInAvailable(false);
  }

  // RevenueCat will be initialized after user login

  // Load global app configurations
  await _runOptionalStartupTask(
    'global configuration',
    () => GlobalConfiguration().loadFromAsset("youtube_settings"),
  );

  // Load user preferences
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 5));
  } catch (error, stackTrace) {
    _reportOptionalStartupError('shared preferences', error, stackTrace);
  }
  final storedPuckCount = prefs?.getInt('puck_count');
  final puckCount = sanitizePuckCount(storedPuckCount);
  if (prefs != null && puckCount != storedPuckCount) {
    await _runOptionalStartupTask('puck count repair', () => prefs!.setInt('puck_count', puckCount));
  }
  final storedTargetDate = prefs?.getString('target_date');
  final targetDate = storedTargetDate == null ? null : DateTime.tryParse(storedTargetDate);
  preferences = Preferences(
    prefs?.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark,
    puckCount,
    prefs?.getBool('friend_notifications') ?? true,
    targetDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
    prefs?.getString('fcm_token'),
  );

  // Load intro_shown synchronously before building the app; compare stored version
  // against the current app version so updates prompt the welcome screen again.
  String? appVersion;
  try {
    appVersion = (await PackageInfo.fromPlatform().timeout(const Duration(seconds: 5))).version;
  } catch (error, stackTrace) {
    _reportOptionalStartupError('package information', error, stackTrace);
  }
  final introShownVersion = prefs?.getString('intro_shown_version');
  final introShown = appVersion != null && introShownVersion == appVersion;
  final introShownNotifier = IntroShownNotifier.withValue(introShown);

  _configureFirebaseMessaging(prefs);
  unawaited(_initializeOptionalServices(prefs));

  return MultiProvider(
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
  );
}

Future<void> _initializeOptionalServices(SharedPreferences? prefs) async {
  await _runOptionalStartupTask('navigation environment', initNavigationEnvironment);

  var notificationsInitialized = false;
  try {
    await LocalNotificationService.initialize().timeout(const Duration(seconds: 10));
    notificationsInitialized = true;
  } catch (error, stackTrace) {
    _reportOptionalStartupError('local notifications', error, stackTrace);
  }
  if (!notificationsInitialized) return;

  await _runOptionalStartupTask(
    'daily reminder',
    () => LocalNotificationService.scheduleDailyReminder(
      hour: prefs?.getInt('reminder_hour') ?? 17,
      minute: prefs?.getInt('reminder_minute') ?? 0,
    ),
  );
}

bool _firebaseMessagingConfigured = false;

void _configureFirebaseMessaging(SharedPreferences? prefs) {
  if (_firebaseMessagingConfigured) return;
  _firebaseMessagingConfigured = true;

  try {
    final firebaseMessaging = FirebaseMessaging.instance;
    unawaited(_refreshFcmToken(firebaseMessaging, prefs));

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        final savedPrefs = await SharedPreferences.getInstance();
        await savedPrefs.setString('fcm_token', newToken);
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({'fcm_token': newToken});
        }
      } catch (error, stackTrace) {
        _reportOptionalStartupError('FCM token refresh', error, stackTrace);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      final title = notification.title ?? 'New notification';
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _showInAppBanner(title: title, body: notification.body);
        return;
      }
      _showBannerWhenReady(uid: uid, title: title, body: notification.body);
    });

    FirebaseMessaging.onBackgroundMessage(_messageHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_messageClickHandler);
    unawaited(_handleInitialMessage(firebaseMessaging));
  } catch (error, stackTrace) {
    _reportOptionalStartupError('Firebase Messaging setup', error, stackTrace);
  }
}

Future<void> _refreshFcmToken(FirebaseMessaging messaging, SharedPreferences? prefs) async {
  try {
    if (Platform.isIOS || Platform.isMacOS) {
      final apnsToken = await messaging.getAPNSToken().timeout(const Duration(seconds: 10));
      if (apnsToken == null) return;
    }

    final token = await messaging.getToken().timeout(const Duration(seconds: 10));
    if (token != null && preferences?.fcmToken != token) {
      await prefs?.setString('fcm_token', token);
      preferences?.fcmToken = token;
    }
  } catch (error, stackTrace) {
    _reportOptionalStartupError('FCM token', error, stackTrace);
  }
}

Future<void> _handleInitialMessage(FirebaseMessaging messaging) async {
  try {
    final initialMessage = await messaging.getInitialMessage().timeout(const Duration(seconds: 10));
    if (initialMessage != null) {
      LocalNotificationService.navigateTo('/notifications');
    }
  } catch (error, stackTrace) {
    _reportOptionalStartupError('initial notification', error, stackTrace);
  }
}

Future<void> _runOptionalStartupTask(
  String name,
  Future<void> Function() operation,
) async {
  try {
    final traceName = 'startup_${name.replaceAll(' ', '_').toLowerCase()}';
    await ObservabilityService.trace(
      traceName,
      operation,
      reportErrors: false,
    ).timeout(const Duration(seconds: 10));
  } catch (error, stackTrace) {
    _reportOptionalStartupError(name, error, stackTrace);
  }
}

void _reportOptionalStartupError(String name, Object error, StackTrace stackTrace) {
  _logStartupError('optional service: $name', error, stackTrace);
  ObservabilityService.recordError(
    error,
    stackTrace,
    reason: 'Optional startup service failed: $name',
  );
}

void _logStartupError(String stage, Object error, StackTrace stackTrace) {
  debugPrint('Startup failure ($stage): $error');
  debugPrintStack(stackTrace: stackTrace);
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

  // After resuming from setLogLevel we have exclusive access until the next
  // await, so the flag checks and the configuring=true assignment are atomic.
  //
  // Guard against calling configure() more than once - calling it a second
  // time corrupts the SDK state on iOS and produces Error 23
  // (configurationError) during a subsequent purchase attempt.
  if (RevenueCatConfig.configured || RevenueCatConfig.configuring) {
    if (RevenueCatConfig.configured && appUserID != null) {
      try {
        await Purchases.logIn(appUserID);
        print('RevenueCat: Logged in user: $appUserID');
      } catch (e) {
        print('RevenueCat: logIn failed: $e');
      }
    }
    return;
  }
  RevenueCatConfig.configuring = true; // Set before the next await to prevent concurrent configure calls.

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
      RevenueCatConfig.configuring = false;
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
      RevenueCatConfig.configuring = false;
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
        // Set _lastUser immediately (before any await) so re-entrant calls
        // from a second auth-state emission see the updated value and skip.
        _lastUser = user;
        unawaited(ObservabilityService.setUser(user.uid));
        try {
          await TeamMembershipService.reconcileUserMemberships(
            userId: user.uid,
            firestore: Provider.of<FirebaseFirestore>(context, listen: false),
          );
        } catch (error, stackTrace) {
          ObservabilityService.recordError(
            error,
            stackTrace,
            reason: 'Reconciling team memberships after authentication',
          );
        }
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
          } catch (error, stackTrace) {
            ObservabilityService.recordError(
              error,
              stackTrace,
              reason: 'Refreshing RevenueCat customer context',
            );
          }
        }
        // Set user's timezone in Firestore
        try {
          final String timezone = await FlutterTimezone.getLocalTimezone();
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'timezone': timezone,
          }, SetOptions(merge: true));
        } catch (error, stackTrace) {
          ObservabilityService.recordError(
            error,
            stackTrace,
            reason: 'Updating user timezone',
          );
        }
      } else if (user == null && _lastUser != null) {
        _lastUser = null;
        unawaited(ObservabilityService.setUser(null));
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

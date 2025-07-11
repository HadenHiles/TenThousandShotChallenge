import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/IntroScreen.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/Settings.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditProfile.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditPuckCount.dart';
import 'package:tenthousandshotchallenge/tabs/friends/AddFriend.dart';
import 'package:tenthousandshotchallenge/tabs/team/CreateTeam.dart';
import 'package:tenthousandshotchallenge/tabs/team/EditTeam.dart';
import 'package:tenthousandshotchallenge/tabs/team/JoinTeam.dart';
import 'package:tenthousandshotchallenge/tabs/profile/History.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;
  AuthChangeNotifier(FirebaseAuth auth) {
    _sub = auth.authStateChanges().listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class IntroShownNotifier extends ChangeNotifier {
  bool? _introShown;
  bool get introShown => _introShown ?? false;

  IntroShownNotifier() {
    _load();
  }

  IntroShownNotifier.withValue(bool value) {
    _introShown = value;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _introShown = prefs.getBool('intro_shown') ?? false;
    notifyListeners();
  }

  void setIntroShown(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_shown', value);
    _introShown = value;
    notifyListeners();
  }
}

GoRouter createAppRouter(
  FirebaseAnalytics analytics, {
  required AuthChangeNotifier authNotifier,
  required IntroShownNotifier introShownNotifier,
  String initialLocation = '/app',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: Listenable.merge([authNotifier, introShownNotifier]),
    observers: [FirebaseAnalyticsObserver(analytics: analytics)],
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const Login(),
      ),
      GoRoute(
        path: '/intro',
        builder: (context, state) => const IntroScreen(),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) {
          final tabId = state.uri.queryParameters['tab'] ?? 'start';
          return Navigation(tabId: tabId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const ProfileSettings(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfile(),
      ),
      GoRoute(
        path: '/edit-puck-count',
        builder: (context, state) => const EditPuckCount(),
      ),
      GoRoute(
        path: '/add-friend',
        builder: (context, state) => const AddFriend(),
      ),
      GoRoute(
        path: '/create-team',
        builder: (context, state) => const CreateTeam(),
      ),
      GoRoute(
        path: '/edit-team',
        builder: (context, state) => const EditTeam(),
      ),
      GoRoute(
        path: '/join-team',
        builder: (context, state) => const JoinTeam(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const History(),
      ),
    ],
    redirect: (context, state) {
      // Skip redirects in widget tests or emulator mode
      if (Platform.environment.containsKey('FLUTTER_TEST') || Platform.environment['USE_FIREBASE_EMULATOR'] == 'true') {
        return null;
      }
      final auth = Provider.of<FirebaseAuth>(context, listen: false);
      final user = auth.currentUser;
      final path = state.fullPath ?? state.uri.toString();
      final introShown = introShownNotifier.introShown;
      debugPrint('[GoRouter redirect] user: '
          '[${user?.uid}], path: [$path], introShown: [$introShown], ');
      // If introShown is null, don't redirect yet (wait for async load)
      if (introShownNotifier._introShown == null) return null;
      // Only redirect to /app if on /login, and user is logged in
      if (user != null && path == '/login') return '/app';
      if (!introShown && path != '/intro') return '/intro';
      if (user == null && path != '/login' && path != '/intro') return '/login';
      return null;
    },
  );
}

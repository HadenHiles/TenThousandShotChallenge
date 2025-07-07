import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/IntroScreen.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';

class AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;
  AuthChangeNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final AuthChangeNotifier authNotifier = AuthChangeNotifier();

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

final IntroShownNotifier introShownNotifier = IntroShownNotifier();

GoRouter createAppRouter(FirebaseAnalytics analytics) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([authNotifier, introShownNotifier]),
    observers: [FirebaseAnalyticsObserver(analytics: analytics)],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _RootRedirect(),
      ),
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
        builder: (context, state) => const Navigation(tabId: 'start'),
      ),
    ],
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final path = state.fullPath ?? state.uri.toString();
      final introShown = introShownNotifier.introShown;
      if (!introShown && path != '/intro') return '/intro';
      if (user == null && path != '/login' && path != '/intro') return '/login';
      if (user != null && (path == '/login' || path == '/')) return '/app';
      return null;
    },
  );
}

class _RootRedirect extends StatelessWidget {
  const _RootRedirect();
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

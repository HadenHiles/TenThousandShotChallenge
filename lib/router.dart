import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/IntroScreen.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/tabs/friends/AddFriend.dart';
import 'package:tenthousandshotchallenge/tabs/friends/CompareStats.dart';
import 'package:tenthousandshotchallenge/tabs/friends/Player.dart';
import 'package:tenthousandshotchallenge/tabs/friends/PlayerAchievementsScreen.dart';
import 'package:tenthousandshotchallenge/tabs/friends/PlayerSessionsScreen.dart';
import 'package:tenthousandshotchallenge/tabs/profile/AccuracyScreen.dart';
import 'package:tenthousandshotchallenge/tabs/profile/AchievementsScreen.dart';
import 'package:tenthousandshotchallenge/tabs/profile/ChallengerRoadProfileScreen.dart';
import 'package:tenthousandshotchallenge/tabs/profile/History.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditProfile.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/EditPuckCount.dart';
import 'package:tenthousandshotchallenge/tabs/profile/settings/Settings.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/ChallengerRoadTeaserView.dart';
import 'package:tenthousandshotchallenge/tabs/team/CreateTeam.dart';
import 'package:tenthousandshotchallenge/tabs/notifications/NotificationsScreen.dart';
import 'package:tenthousandshotchallenge/tabs/team/EditTeam.dart';
import 'package:tenthousandshotchallenge/tabs/team/JoinTeam.dart';

/// Route path pattern for the player detail route (go_router syntax).
const _playerRoutePath = '/player/:id';

abstract final class AppRouteNames {
  static const permissions = 'auth_permissions';
  static const login = 'auth_login';
  static const intro = 'auth_intro';
  static const train = 'train_home';
  static const communityFriends = 'community_friends';
  static const communityTeam = 'community_team';
  static const learn = 'learn_home';
  static const me = 'me_home';
  static const addFriend = 'community_add_friend';
  static const player = 'community_player';
  static const createTeam = 'community_create_team';
  static const editTeam = 'community_edit_team';
  static const joinTeam = 'community_join_team';
  static const settings = 'me_settings';
  static const editProfile = 'me_edit_profile';
  static const editPuckCount = 'me_edit_puck_count';
  static const history = 'me_history';
  static const profileAccuracy = 'me_accuracy';
  static const profileAchievements = 'me_achievements';
  static const profileChallengerRoad = 'me_challenger_road';
  static const challengerRoad = 'train_challenger_road';
  static const compareStats = 'community_compare_stats';
  static const notifications = 'me_notifications';
}

String _appShellRouteName(GoRouterState state) {
  final tabId = state.uri.queryParameters['tab'];
  final section = state.uri.queryParameters['section'];

  switch (tabId) {
    case 'friends':
      return AppRouteNames.communityFriends;
    case 'team':
      return AppRouteNames.communityTeam;
    case 'community':
      return section == CommunitySection.team.name ? AppRouteNames.communityTeam : AppRouteNames.communityFriends;
    case 'explore':
    case 'learn':
      return AppRouteNames.learn;
    case 'profile':
    case 'me':
      return AppRouteNames.me;
    case 'start':
    case 'train':
    default:
      return AppRouteNames.train;
  }
}

class AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;
  final FirebaseAuth _auth;
  AuthChangeNotifier(FirebaseAuth auth) : _auth = auth {
    _sub = _auth.authStateChanges().listen((_) => notifyListeners());
  }

  User? get user => _auth.currentUser;
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

/// Tracks whether the user has granted the permissions the app needs.
/// Checks status at startup; existing users who are missing permissions
/// are redirected to [PermissionsScreen] automatically.
class PermissionsNotifier extends ChangeNotifier {
  bool? _needsPermissions; // null while the async check is pending

  bool get needsPermissions => _needsPermissions ?? false;
  bool get checked => _needsPermissions != null;

  PermissionsNotifier() {
    _check();
  }

  /// Use in tests (or after granting permissions) to skip the async OS check.
  PermissionsNotifier.withGranted() {
    _needsPermissions = false;
  }

  Future<void> _check() async {
    final camera = await Permission.camera.status;
    final notification = await Permission.notification.status;
    bool batteryOk = true;
    if (Platform.isAndroid) {
      final battery = await Permission.ignoreBatteryOptimizations.status;
      batteryOk = battery.isGranted;
    }
    _needsPermissions = !camera.isGranted || !notification.isGranted || !batteryOk;
    notifyListeners();
  }

  /// Re-run the permission check (call after granting permissions).
  Future<void> refresh() => _check();

  /// Mark permissions as handled for this session so the router won't
  /// redirect. The next cold start will re-check actual OS status.
  void markGranted() {
    _needsPermissions = false;
    notifyListeners();
  }
}

List<RouteBase> _buildAuthRoutes() {
  return [
    GoRoute(
      path: AppRoutePaths.login,
      name: AppRouteNames.login,
      builder: (context, state) => const Login(),
    ),
    GoRoute(
      path: AppRoutePaths.intro,
      name: AppRouteNames.intro,
      builder: (context, state) => const IntroScreen(),
    ),
    GoRoute(
      path: AppRoutePaths.permissions,
      name: AppRouteNames.permissions,
      builder: (context, state) => const PermissionsScreen(),
    ),
  ];
}

List<RouteBase> _buildShellRoutes() {
  return [
    GoRoute(
      path: AppRoutePaths.app,
      pageBuilder: (context, state) {
        final tabId = state.uri.queryParameters['tab'] ?? 'start';
        final communitySection = state.uri.queryParameters['section'];
        return MaterialPage<void>(
          key: state.pageKey,
          name: _appShellRouteName(state),
          child: Navigation(tabId: tabId, communitySection: communitySection),
        );
      },
    ),
  ];
}

List<RouteBase> _buildCommunityRoutes() {
  return [
    GoRoute(
      path: AppRoutePaths.addFriend,
      name: AppRouteNames.addFriend,
      builder: (context, state) => const AddFriend(),
    ),
    GoRoute(
      path: _playerRoutePath,
      name: AppRouteNames.player,
      builder: (context, state) {
        final playerId = state.pathParameters['id'];
        return Player(uid: playerId);
      },
    ),
    GoRoute(
      path: '/player/:id/achievements',
      builder: (context, state) {
        final playerId = state.pathParameters['id']!;
        final extra = state.extra as Map<String, String?>?;
        return PlayerAchievementsScreen(
          userId: playerId,
          playerName: extra?['playerName'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/player/:id/sessions',
      builder: (context, state) {
        final playerId = state.pathParameters['id']!;
        final extra = state.extra as Map<String, String?>?;
        return PlayerSessionsScreen(
          userId: playerId,
          playerName: extra?['playerName'] ?? '',
          initialIterationId: extra?['iterationId'],
        );
      },
    ),
    GoRoute(
      path: '/compare-stats/:friendId',
      name: AppRouteNames.compareStats,
      builder: (context, state) {
        final friendId = state.pathParameters['friendId']!;
        return CompareStats(friendUid: friendId);
      },
    ),
    GoRoute(
      path: AppRoutePaths.createTeam,
      name: AppRouteNames.createTeam,
      builder: (context, state) => const CreateTeam(),
    ),
    GoRoute(
      path: AppRoutePaths.editTeam,
      name: AppRouteNames.editTeam,
      builder: (context, state) => const EditTeam(),
    ),
    GoRoute(
      path: AppRoutePaths.joinTeam,
      name: AppRouteNames.joinTeam,
      builder: (context, state) => const JoinTeam(),
    ),
  ];
}

List<RouteBase> _buildMeRoutes() {
  return [
    GoRoute(
      path: AppRoutePaths.notifications,
      name: AppRouteNames.notifications,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: AppRoutePaths.settings,
      name: AppRouteNames.settings,
      builder: (context, state) => const ProfileSettings(),
    ),
    GoRoute(
      path: AppRoutePaths.editProfile,
      name: AppRouteNames.editProfile,
      builder: (context, state) => const EditProfile(),
    ),
    GoRoute(
      path: AppRoutePaths.editPuckCount,
      name: AppRouteNames.editPuckCount,
      builder: (context, state) => const EditPuckCount(),
    ),
    GoRoute(
      path: AppRoutePaths.history,
      name: AppRouteNames.history,
      builder: (context, state) => History(initialIterationId: state.extra as String?),
    ),
    GoRoute(
      path: AppRoutePaths.profileAccuracy,
      name: AppRouteNames.profileAccuracy,
      builder: (context, state) => AccuracyScreen(initialIterationId: state.extra as String?),
    ),
    GoRoute(
      path: AppRoutePaths.profileAchievements,
      name: AppRouteNames.profileAchievements,
      builder: (context, state) => const AchievementsScreen(),
    ),
    GoRoute(
      path: AppRoutePaths.profileChallengerRoad,
      name: AppRouteNames.profileChallengerRoad,
      builder: (context, state) => const ChallengerRoadProfileScreen(),
    ),
  ];
}

List<RouteBase> _buildTrainRoutes() {
  return [
    GoRoute(
      path: AppRoutePaths.challengerRoad,
      name: AppRouteNames.challengerRoad,
      builder: (context, state) => const ChallengerRoadTeaserView(),
    ),
  ];
}

GoRouter createAppRouter(
  FirebaseAnalytics analytics, {
  required AuthChangeNotifier authNotifier,
  required IntroShownNotifier introShownNotifier,
  required PermissionsNotifier permissionsNotifier,
  String initialLocation = AppRoutePaths.app,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: Listenable.merge([authNotifier, introShownNotifier, permissionsNotifier]),
    observers: [FirebaseAnalyticsObserver(analytics: analytics)],
    routes: [
      ..._buildAuthRoutes(),
      ..._buildShellRoutes(),
      ..._buildTrainRoutes(),
      ..._buildCommunityRoutes(),
      ..._buildMeRoutes(),
    ],
    redirect: (context, state) {
      final auth = Provider.of<FirebaseAuth>(context, listen: false);
      final user = auth.currentUser;
      final path = state.fullPath ?? state.uri.toString();
      final introShown = introShownNotifier.introShown;
      // If introShown is null, don't redirect yet (wait for async load)
      if (introShownNotifier._introShown == null) return null;
      // Only redirect to /app if on /login, and user is logged in
      if (user != null && path == AppRoutePaths.login) {
        return appSectionLocation(AppSection.train);
      }
      // New user: show full intro flow first
      if (!introShown && path != AppRoutePaths.intro) return AppRoutePaths.intro;
      // Existing user with missing permissions: show permissions screen
      if (introShown && permissionsNotifier.checked && permissionsNotifier.needsPermissions && path != AppRoutePaths.permissions) {
        return AppRoutePaths.permissions;
      }
      if (user == null && path != AppRoutePaths.login && path != AppRoutePaths.intro && path != AppRoutePaths.permissions) {
        return AppRoutePaths.login;
      }
      return null;
    },
  );
}

/// Central source of truth for all named route paths in the app.
///
/// Import this in any file that needs to build or push to a route,
/// rather than using hardcoded string literals.
abstract final class AppRoutePaths {
  static const login = '/login';
  static const intro = '/intro';
  static const permissions = '/permissions';
  static const app = '/app';
  static const settings = '/settings';
  static const editProfile = '/edit-profile';
  static const editPuckCount = '/edit-puck-count';
  static const addFriend = '/add-friend';
  static const createTeam = '/create-team';
  static const editTeam = '/edit-team';
  static const joinTeam = '/join-team';
  static const teamActivity = '/team-activity';
  static const history = '/history';
  static const challengerRoad = '/challenger-road';

  static const profileAccuracy = '/profile/accuracy';
  static const profileAchievements = '/profile/achievements';
  static const profileChallengerRoad = '/profile/challenger-road';

  /// Parameterised player-profile path: `/player/<id>`.
  static String playerPathFor(String id) => '/player/$id';

  /// Parameterised player achievements path: `/player/<id>/achievements`.
  static String playerAchievementsPathFor(String id) => '/player/$id/achievements';

  /// Parameterised player sessions path: `/player/<id>/sessions`.
  static String playerSessionsPathFor(String id) => '/player/$id/sessions';

  /// Parameterised compare-stats path: `/compare-stats/<friendUid>`.
  static String compareStatsPathFor(String friendUid) => '/compare-stats/$friendUid';

  /// Challenger Road profile screen deep-linked to a specific badge.
  static String profileChallengerRoadFor(String badgeId) => '/profile/challenger-road?badgeId=$badgeId';

  /// In-app notification centre.
  static const notifications = '/notifications';
}

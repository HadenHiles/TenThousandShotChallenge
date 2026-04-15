import 'package:health/health.dart';

/// Writes a hockey session's shot count to Apple Health (iOS) or Google Fit (Android)
/// as [HealthDataType.WORKOUT] (sport type: Hockey / Other Sport).
///
/// Call [writeSession] after a successful Firestore save.
/// Permissions are requested lazily the first time this is called.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final _health = Health();

  static const _types = [HealthDataType.WORKOUT];
  static const _permissions = [HealthDataAccess.WRITE];

  bool _authorised = false;

  /// Request write permission for workouts. Returns true if granted.
  Future<bool> requestPermissions() async {
    try {
      _authorised = await _health.requestAuthorization(_types, permissions: _permissions);
    } catch (_) {
      _authorised = false;
    }
    return _authorised;
  }

  /// Write [durationMinutes] of ice hockey workout to Apple Health / Google Fit.
  /// [shotCount] is stored in the title / note for context.
  ///
  /// Returns true on success, false if permission was denied or writing fails.
  Future<bool> writeSession({
    required DateTime start,
    required DateTime end,
    required int shotCount,
  }) async {
    if (!_authorised) {
      final granted = await requestPermissions();
      if (!granted) return false;
    }

    try {
      final success = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.HOCKEY,
        start: start,
        end: end,
      );
      return success;
    } catch (_) {
      return false;
    }
  }
}

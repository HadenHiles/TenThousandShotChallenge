import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/services/HealthService.dart';

void main() {
  group('HealthService', () {
    // The health package requires platform channels which are unavailable in
    // the test environment. HealthService.requestPermissions() catches all
    // exceptions and returns false, ensuring no crash in tests.

    test('requestPermissions returns false when platform unavailable', () async {
      final result = await HealthService.instance.requestPermissions();
      expect(result, isFalse);
    });

    test('writeSession returns false when not authorized', () async {
      final result = await HealthService.instance.writeSession(
        start: DateTime(2024, 1, 1, 9, 0),
        end: DateTime(2024, 1, 1, 9, 30),
        shotCount: 200,
      );
      expect(result, isFalse);
    });

    test('writeSession handles end before start gracefully', () async {
      final result = await HealthService.instance.writeSession(
        start: DateTime(2024, 1, 1, 10, 0),
        end: DateTime(2024, 1, 1, 9, 0), // end before start
        shotCount: 0,
      );
      expect(result, isFalse);
    });

    test('singleton always returns same instance', () {
      expect(HealthService.instance, same(HealthService.instance));
    });
  });
}

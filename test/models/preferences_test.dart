import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';

void main() {
  group('puck count validation', () {
    test('clamps missing and out-of-range stored values', () {
      expect(sanitizePuckCount(null), defaultPuckCount);
      expect(sanitizePuckCount(-1), minimumPuckCount);
      expect(sanitizePuckCount(501), maximumPuckCount);
    });

    test('accepts only values from 1 through 500', () {
      expect(validatePuckCount('1'), isNull);
      expect(validatePuckCount('500'), isNull);
      expect(validatePuckCount('0'), isNotNull);
      expect(validatePuckCount('501'), isNotNull);
      expect(validatePuckCount('not a number'), isNotNull);
    });
  });
}

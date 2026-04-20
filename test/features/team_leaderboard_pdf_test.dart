import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamLeaderboardPdf.dart';

void main() {
  group('LeaderboardPlayer', () {
    test('stores name and shots correctly', () {
      const player = LeaderboardPlayer(name: 'Alice', shots: 1500);
      expect(player.name, 'Alice');
      expect(player.shots, 1500);
    });

    test('shots of zero is valid', () {
      const player = LeaderboardPlayer(name: 'Bob', shots: 0);
      expect(player.shots, 0);
    });

    test('large shot counts are stored accurately', () {
      const player = LeaderboardPlayer(name: 'Elite Player', shots: 9999);
      expect(player.shots, 9999);
    });
  });

  group('UserProfile - practiceReminders and healthSync fields', () {
    test('practiceReminders defaults to null when not provided', () {
      final profile = UserProfile('Alice', 'a@b.com', null, true, true, null, null);
      expect(profile.practiceReminders, isNull);
    });

    test('healthSync defaults to null when not provided', () {
      final profile = UserProfile('Alice', 'a@b.com', null, true, true, null, null);
      expect(profile.healthSync, isNull);
    });

    test('practiceReminders can be set to true', () {
      final profile = UserProfile('Alice', 'a@b.com', null, true, true, null, null, practiceReminders: true);
      expect(profile.practiceReminders, isTrue);
    });

    test('healthSync can be set to true', () {
      final profile = UserProfile('Alice', 'a@b.com', null, true, true, null, null, healthSync: true);
      expect(profile.healthSync, isTrue);
    });

    test('toMap serializes practiceReminders', () {
      final profile = UserProfile('Alice', 'a@b.com', null, true, true, null, null, practiceReminders: true);
      final map = profile.toMap();
      expect(map['practice_reminders'], isTrue);
    });

    test('toMap serializes healthSync', () {
      final profile = UserProfile('Alice', 'a@b.com', null, true, true, null, null, healthSync: true);
      final map = profile.toMap();
      expect(map['health_sync'], isTrue);
    });

    test('toMap defaults practice_reminders to false when null', () {
      final profile = UserProfile('Alice', 'a@b.com', null, true, true, null, null);
      expect(profile.toMap()['practice_reminders'], isFalse);
    });

    test('toMap defaults health_sync to false when null', () {
      final profile = UserProfile('Alice', 'a@b.com', null, true, true, null, null);
      expect(profile.toMap()['health_sync'], isFalse);
    });

    test('fromMap reads practice_reminders correctly', () {
      final map = {
        'display_name': 'Bob',
        'email': 'b@c.com',
        'practice_reminders': true,
        'health_sync': false,
      };
      final profile = UserProfile.fromMap(map);
      expect(profile.practiceReminders, isTrue);
      expect(profile.healthSync, isFalse);
    });

    test('fromMap defaults practice_reminders to false when absent', () {
      final map = {'display_name': 'Bob', 'email': 'b@c.com'};
      final profile = UserProfile.fromMap(map);
      expect(profile.practiceReminders, isFalse);
    });

    test('fromMap defaults health_sync to false when absent', () {
      final map = {'display_name': 'Bob', 'email': 'b@c.com'};
      final profile = UserProfile.fromMap(map);
      expect(profile.healthSync, isFalse);
    });
  });
}

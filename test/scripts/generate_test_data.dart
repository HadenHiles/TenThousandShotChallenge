#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

// Script to generate test data JSON files for CLI-based import
// This script outputs users.json, teams.json, iterations.json, invites.json in test/test_data/

void main() async {
  print('📊 Generating test data JSON files for CLI import...');

  final users = [
    {
      'uid': 'user1',
      'email': 'test.beginner@howtohockey.com',
      'display_name': 'Rookie Player',
      'photo_url': 'https://example.com/avatar1.jpg',
      'public': true,
      'skill': 'beginner',
    },
    {
      'uid': 'user2',
      'email': 'test.intermediate@howtohockey.com',
      'display_name': 'Intermediate Shooter',
      'photo_url': 'https://example.com/avatar2.jpg',
      'public': true,
      'skill': 'intermediate',
    },
    {
      'uid': 'user3',
      'email': 'test.expert@howtohockey.com',
      'display_name': 'Elite Sniper',
      'photo_url': 'https://example.com/avatar3.jpg',
      'public': true,
      'skill': 'expert',
    },
    {
      'uid': 'user4',
      'email': 'test.private@howtohockey.com',
      'display_name': 'Private Player',
      'photo_url': 'https://example.com/avatar4.jpg',
      'public': false,
      'skill': 'intermediate',
    },
    {
      'uid': 'user5',
      'email': 'test.teamcaptain@howtohockey.com',
      'display_name': 'Team Captain',
      'photo_url': 'https://example.com/avatar5.jpg',
      'public': true,
      'skill': 'expert',
    },
  ];
  final teams = [
    {
      'id': 'team1',
      'name': 'The Elite Snipers',
      'members': ['user5', 'user2', 'user3'],
    },
    {
      'id': 'team2',
      'name': 'Rookie Rangers',
      'members': ['user1'],
    },
  ];
  final iterations = [
    {
      'uid': 'user1',
      'iterations': [
        {
          'start_date': DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
          'target_date': DateTime.now().add(Duration(days: 70)).toIso8601String(),
          'complete': false,
          'sessions': [
            {
              'date': DateTime.now().toIso8601String(),
              'shots': [
                {'type': 'wrist', 'count': 25},
                {'type': 'snap', 'count': 20},
              ]
            }
          ]
        }
      ]
    },
    {
      'uid': 'user2',
      'iterations': [
        {
          'start_date': DateTime.now().subtract(Duration(days: 40)).toIso8601String(),
          'target_date': DateTime.now().add(Duration(days: 60)).toIso8601String(),
          'complete': false,
          'sessions': [
            {
              'date': DateTime.now().toIso8601String(),
              'shots': [
                {'type': 'wrist', 'count': 30},
                {'type': 'snap', 'count': 25},
              ]
            }
          ]
        }
      ]
    }
  ];
  final invites = [
    {
      'from_uid': 'user1',
      'to_uid': 'user2',
      'date': DateTime.now().toIso8601String(),
    },
    {
      'from_uid': 'user4',
      'to_uid': 'user5',
      'date': DateTime.now().toIso8601String(),
    },
  ];

  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path; // project root
  final testDataDir = Directory('$scriptDir/test/test_data');
  await testDataDir.create(recursive: true);
  await File('${testDataDir.path}/users.json').writeAsString(JsonEncoder.withIndent('  ').convert(users));
  await File('${testDataDir.path}/teams.json').writeAsString(JsonEncoder.withIndent('  ').convert(teams));
  await File('${testDataDir.path}/iterations.json').writeAsString(JsonEncoder.withIndent('  ').convert(iterations));
  await File('${testDataDir.path}/invites.json').writeAsString(JsonEncoder.withIndent('  ').convert(invites));

  print('✅ Test data JSON files generated in test/test_data/');
}

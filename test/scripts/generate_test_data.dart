#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

// Script to generate test data JSON files for CLI-based import
// This script outputs users.json, teams.json, iterations.json, invites.json in test/test_data/

void main() async {
  print('📊 Generating test data JSON files for CLI import...');

  final users = {
    'user1': {
      'id': 'user1',
      'email': 'test.beginner@howtohockey.com',
      'display_name': 'Rookie Player',
      'photo_url': 'https://example.com/avatar1.jpg',
      'public': true,
      'skill': 'beginner',
      'team_id': 'team2',
      'friend_notifications': true,
      'fcm_token': 'fcm_token_user1',
    },
    'user2': {
      'id': 'user2',
      'email': 'test.intermediate@howtohockey.com',
      'display_name': 'Intermediate Shooter',
      'photo_url': 'https://example.com/avatar2.jpg',
      'public': true,
      'skill': 'intermediate',
      'team_id': 'team1',
      'friend_notifications': false,
      'fcm_token': 'fcm_token_user2',
    },
    'user3': {
      'id': 'user3',
      'email': 'test.expert@howtohockey.com',
      'display_name': 'Elite Sniper',
      'photo_url': 'https://example.com/avatar3.jpg',
      'public': true,
      'skill': 'expert',
      'team_id': 'team1',
      'friend_notifications': true,
      'fcm_token': 'fcm_token_user3',
    },
    'user4': {
      'id': 'user4',
      'email': 'test.private@howtohockey.com',
      'display_name': 'Private Player',
      'photo_url': 'https://example.com/avatar4.jpg',
      'public': false,
      'skill': 'intermediate',
      'team_id': null,
      'friend_notifications': false,
      'fcm_token': null,
    },
    'user5': {
      'id': 'user5',
      'email': 'test.teamcaptain@howtohockey.com',
      'display_name': 'Team Captain',
      'photo_url': 'https://example.com/avatar5.jpg',
      'public': true,
      'skill': 'expert',
      'team_id': 'team1',
      'friend_notifications': true,
      'fcm_token': 'fcm_token_user5',
    },
  };

  final teams = {
    'team1': {
      'id': 'team1',
      'name': 'The Elite Snipers',
      'players': ['user5', 'user2', 'user3'],
      'owner_id': 'user5',
    },
    'team2': {
      'id': 'team2',
      'name': 'Rookie Rangers',
      'players': ['user1'],
      'owner_id': 'user1',
    },
  };

  // Iterations: map of userId (docID) to iterations subcollection (map of iterationId to iteration fields)
  final now = DateTime.now();
  final iterations = {
    'user1': {
      'iterations': {
        'iteration1': {
          'id': null,
          'start_date': now.subtract(Duration(days: 30)).toIso8601String(),
          'target_date': now.add(Duration(days: 70)).toIso8601String(),
          'end_date': null,
          'total_duration': 3600,
          'total': 10000,
          'total_wrist': 4000,
          'total_snap': 3000,
          'total_slap': 2000,
          'total_backhand': 1000,
          'complete': false,
          'updated_at': now.toIso8601String(),
          'sessions': {
            'session1': {
              'id': null,
              'date': now.subtract(Duration(days: 9)).toIso8601String(),
              'duration': 600,
              'total': 2500,
              'total_wrist': 1000,
              'total_snap': 500,
              'total_slap': 500,
              'total_backhand': 500,
              'shots': {
                'shot1': {
                  'id': null,
                  'date': now.subtract(Duration(days: 9)).toIso8601String(),
                  'type': 'wrist',
                  'count': 1000,
                },
                'shot2': {
                  'id': null,
                  'date': now.subtract(Duration(days: 1)).toIso8601String(),
                  'type': 'snap',
                  'count': 500,
                },
                'shot3': {
                  'id': null,
                  'date': now.subtract(Duration(days: 1)).toIso8601String(),
                  'type': 'slap',
                  'count': 500,
                },
                'shot4': {
                  'id': null,
                  'date': now.subtract(Duration(days: 1)).toIso8601String(),
                  'type': 'backhand',
                  'count': 500,
                }
              }
            }
          }
        },
        'iteration2': {
          'id': null,
          'start_date': now.subtract(Duration(days: 100)).toIso8601String(),
          'target_date': now.subtract(Duration(days: 60)).toIso8601String(),
          'end_date': now.subtract(Duration(days: 61)).toIso8601String(),
          'total_duration': 8000,
          'total': 10000,
          'total_wrist': 4000,
          'total_snap': 3000,
          'total_slap': 2000,
          'total_backhand': 1000,
          'complete': true,
          'updated_at': now.subtract(Duration(days: 61)).toIso8601String(),
          'sessions': {
            'session1': {
              'id': null,
              'date': now.subtract(Duration(days: 99)).toIso8601String(),
              'duration': 2000,
              'total': 5000,
              'total_wrist': 2000,
              'total_snap': 1500,
              'total_slap': 1000,
              'total_backhand': 500,
              'shots': {
                'shot1': {
                  'id': null,
                  'date': now.subtract(Duration(days: 99)).toIso8601String(),
                  'type': 'wrist',
                  'count': 2000,
                },
                'shot2': {
                  'id': null,
                  'date': now.subtract(Duration(days: 99)).toIso8601String(),
                  'type': 'snap',
                  'count': 1500,
                },
                'shot3': {
                  'id': null,
                  'date': now.subtract(Duration(days: 99)).toIso8601String(),
                  'type': 'slap',
                  'count': 1000,
                },
                'shot4': {
                  'id': null,
                  'date': now.subtract(Duration(days: 99)).toIso8601String(),
                  'type': 'backhand',
                  'count': 500,
                }
              }
            }
          }
        }
      }
    },
    'user2': {
      'iterations': {
        'iteration1': {
          'id': null,
          'start_date': now.subtract(Duration(days: 40)).toIso8601String(),
          'target_date': now.add(Duration(days: 60)).toIso8601String(),
          'end_date': null,
          'total_duration': 1800,
          'total': 5000,
          'total_wrist': 2000,
          'total_snap': 1500,
          'total_slap': 1000,
          'total_backhand': 500,
          'complete': false,
          'updated_at': now.toIso8601String(),
          'sessions': {
            'session1': {
              'id': null,
              'date': now.toIso8601String(),
              'duration': 900,
              'total': 2000,
              'total_wrist': 1000,
              'total_snap': 500,
              'total_slap': 300,
              'total_backhand': 200,
              'shots': {
                'shot1': {
                  'id': null,
                  'date': now.toIso8601String(),
                  'type': 'wrist',
                  'count': 1000,
                },
                'shot2': {
                  'id': null,
                  'date': now.toIso8601String(),
                  'type': 'snap',
                  'count': 500,
                },
                'shot3': {
                  'id': null,
                  'date': now.toIso8601String(),
                  'type': 'slap',
                  'count': 300,
                },
                'shot4': {
                  'id': null,
                  'date': now.toIso8601String(),
                  'type': 'backhand',
                  'count': 200,
                }
              }
            }
          }
        }
      }
    }
  };

  // Invites: map of userId (docID) to invites subcollection (map of from_uid to invite fields)
  final invites = {
    'user2': {
      'invites': {
        'user1': {
          'id': null,
          'from_uid': 'user1',
          'date': DateTime.now().toIso8601String(),
        }
      }
    },
    'user5': {
      'invites': {
        'user4': {
          'id': null,
          'from_uid': 'user4',
          'date': DateTime.now().toIso8601String(),
        }
      }
    }
  };

  // Friends test data: map of userId (docID) to friends subcollection (map of friendId to user fields)
  Map<String, dynamic> friends = {};
  // Build a lookup of userId to user fields for easy reference
  final userMap = users;
  // Define friend relationships (userId: [friendIds])
  final friendLinks = {
    'user1': ['user2', 'user5'],
    'user2': ['user1', 'user3'],
    'user3': ['user2'],
    'user4': [],
    'user5': ['user1'],
  };
  friendLinks.forEach((userId, friendIds) {
    final friendsSubcollection = <String, dynamic>{};
    for (final friendId in friendIds) {
      final friend = userMap[friendId];
      if (friend != null) {
        friendsSubcollection[friendId] = {
          'id': friend['uid'],
          'display_name': friend['display_name'],
          'email': friend['email'],
          'photo_url': friend['photo_url'],
          'public': friend['public'],
          'friend_notifications': friend['friend_notifications'],
          'team_id': friend['team_id'],
          'fcm_token': friend['fcm_token'],
        };
      }
    }
    friends[userId] = {'teammates': friendsSubcollection};
  });

  // Explore tab mock data (split into separate objects, no top-level collection key)
  final learnVideos = {
    'vid1': {
      'id': 'vid1',
      'title': 'Test Video',
      'content': '<p>Test Content</p>',
      'order': 1,
      'buttonUrl': '',
      'buttonText': '',
    },
  };
  final trainingPrograms = {
    'prog1': {
      'id': 'prog1',
      'title': 'Test Program',
      'image': 'https://example.com/image.png',
      'url': 'https://example.com',
      'order': 1,
    },
  };
  final learnToPlay = {
    'learn1': {
      'id': 'learn1',
      'title': 'Test Learn',
      'image': 'https://example.com/image.png',
      'url': 'https://example.com',
      'order': 1,
    },
  };
  final merch = {
    'merch1': {
      'id': 'merch1',
      'title': 'Test Merch',
      'image': 'https://example.com/image.png',
      'url': 'https://example.com',
      'order': 1,
    },
  };

  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path; // project root
  final testDataDir = Directory('$scriptDir/test/test_data');
  await testDataDir.create(recursive: true);
  await File('${testDataDir.path}/users.json').writeAsString(JsonEncoder.withIndent('  ').convert(users));
  await File('${testDataDir.path}/teams.json').writeAsString(JsonEncoder.withIndent('  ').convert(teams));
  await File('${testDataDir.path}/iterations.json').writeAsString(JsonEncoder.withIndent('  ').convert(iterations));
  await File('${testDataDir.path}/invites.json').writeAsString(JsonEncoder.withIndent('  ').convert(invites));
  await File('${testDataDir.path}/friends.json').writeAsString(JsonEncoder.withIndent('  ').convert(friends));
  // Write each explore tab section to its own file
  await File('${testDataDir.path}/learn_videos.json').writeAsString(JsonEncoder.withIndent('  ').convert(learnVideos));
  await File('${testDataDir.path}/training_programs.json').writeAsString(JsonEncoder.withIndent('  ').convert(trainingPrograms));
  await File('${testDataDir.path}/learn_to_play.json').writeAsString(JsonEncoder.withIndent('  ').convert(learnToPlay));
  await File('${testDataDir.path}/merch.json').writeAsString(JsonEncoder.withIndent('  ').convert(merch));

  print('✅ Test data JSON files generated in test/test_data/');
}

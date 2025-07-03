#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

// Script to create test users in the REAL Firebase project using CLI tools
// ⚠️  USE WITH CAUTION - This creates real data in production!

void main() async {
  print('🎯 Ten Thousand Shot Challenge - Real Firebase Test Users (CLI)');
  print('===============================================================');
  print('⚠️  WARNING: This will create REAL test data in your Firebase project!');
  print('');

  stdout.write('Are you sure you want to continue? (yes/no): ');
  final confirmation = stdin.readLineSync();

  if (confirmation?.toLowerCase() != 'yes') {
    print('❌ Operation cancelled');
    exit(0);
  }

  // Step 1: Prepare test users CSV for Firebase Auth import
  final testUsers = [
    {
      'email': 'test.beginner@howtohockey.com',
      'password': 'TestPass123!',
      'displayName': 'Rookie Player',
      'skill': 'beginner',
      'photoUrl': 'https://example.com/avatar1.jpg',
    },
    {
      'email': 'test.intermediate@howtohockey.com',
      'password': 'TestPass123!',
      'displayName': 'Intermediate Shooter',
      'skill': 'intermediate',
      'photoUrl': 'https://example.com/avatar2.jpg',
    },
    {
      'email': 'test.expert@howtohockey.com',
      'password': 'TestPass123!',
      'displayName': 'Elite Sniper',
      'skill': 'expert',
      'photoUrl': 'https://example.com/avatar3.jpg',
    },
    {
      'email': 'test.private@howtohockey.com',
      'password': 'TestPass123!',
      'displayName': 'Private Player',
      'skill': 'intermediate',
      'photoUrl': 'https://example.com/avatar4.jpg',
    },
    {
      'email': 'test.teamcaptain@howtohockey.com',
      'password': 'TestPass123!',
      'displayName': 'Team Captain',
      'skill': 'expert',
      'photoUrl': 'https://example.com/avatar5.jpg',
    },
  ];

  final csvPath = 'test/scripts/real_test_users.csv';
  final csvFile = File(csvPath);
  final csvSink = csvFile.openWrite();
  csvSink.writeln('email,password,displayName,photoUrl,skill');
  for (final user in testUsers) {
    csvSink.writeln('${user['email']},${user['password']},${user['displayName']},${user['photoUrl']},${user['skill']}');
  }
  await csvSink.close();

  // Step 2: Import users using Firebase CLI
  print('🔑 Importing users to Firebase Auth...');
  final authResult = await Process.run(
    'firebase',
    [
      'auth:import',
      csvPath,
      '--hash-algo=SCRYPT',
      '--rounds=8',
      '--mem-cost=14',
      '--project=ten-thousand-puck-challenge',
    ],
    runInShell: true,
  );
  stdout.write(authResult.stdout);
  stderr.write(authResult.stderr);

  // Step 3: Prepare Firestore data JSON for firestore-seed
  final firestoreData = <String, dynamic>{};
  for (final user in testUsers) {
    final uid = user['email']!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    firestoreData['users/$uid'] = {
      'id': uid,
      'display_name': user['displayName'],
      'display_name_lowercase': user['displayName']!.toLowerCase(),
      'email': user['email'],
      'photo_url': user['photoUrl'],
      'public': user['skill'] != 'private',
      'friend_notifications': true,
      'team_id': null,
      'fcm_token': 'test_fcm_token_$uid',
    };
    firestoreData['iterations/$uid/iterations/iteration1'] = {
      'start_date': DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
      'target_date': DateTime.now().add(Duration(days: 70)).toIso8601String(),
      'end_date': null,
      'total_duration': 0,
      'total': 0,
      'total_wrist': 0,
      'total_snap': 0,
      'total_slap': 0,
      'total_backhand': 0,
      'complete': false,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
  final firestoreJsonPath = 'test/scripts/real_test_users_firestore.json';
  final firestoreJsonFile = File(firestoreJsonPath);
  await firestoreJsonFile.writeAsString(JsonEncoder.withIndent('  ').convert(firestoreData));

  // Step 4: Import Firestore data using firestore-seed
  print('🌱 Seeding Firestore data...');
  final seedResult = await Process.run(
    'firestore-seed',
    [
      '--data',
      firestoreJsonPath,
      '--project',
      'ten-thousand-puck-challenge',
    ],
    runInShell: true,
  );
  stdout.write(seedResult.stdout);
  stderr.write(seedResult.stderr);

  print('✅ Real test users and Firestore data created successfully!');
  print('📧 User info CSV: $csvPath');
  print('📄 Firestore data JSON: $firestoreJsonPath');
}

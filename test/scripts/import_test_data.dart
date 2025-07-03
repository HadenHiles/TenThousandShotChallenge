#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

// Script to import test data into Firebase emulators using CLI tools
// Run: dart test/scripts/import_test_data.dart

void main() async {
  print('🔥 Importing test data to Firebase emulators using CLI tools...');

  await importUsers();
  await importFirestore();

  print('✅ Test data imported successfully!');
  print('🌐 Open Firebase Emulator UI: http://localhost:4000');
}

Future<void> importUsers() async {
  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path; // project root
  final testDataDir = '$scriptDir/test/test_data';
  final usersData = await _loadJsonFile('$testDataDir/users.json');
  final tmpDir = Directory.systemTemp;
  final csvPath = '${tmpDir.path}/tmp_users.csv';
  final csvFile = File(csvPath);
  final csvSink = csvFile.openWrite();
  csvSink.writeln('email,password,localId,displayName');
  for (final user in usersData) {
    csvSink.writeln('${user['email']},testpass123,${user['uid']},${user['display_name']}');
  }
  await csvSink.close();

  final result = await Process.run(
    'firebase',
    [
      'auth:import',
      csvPath,
      '--hash-algo=SCRYPT',
      '--rounds=8',
      '--mem-cost=14',
      '--project=demo-project',
      '--local',
    ],
    runInShell: true,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  await csvFile.delete();
}

Future<void> importFirestore() async {
  print('🌱 Seeding Firestore data using firestore-seed...');
  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path; // project root
  final testDataDir = '$scriptDir/test/test_data';
  final collections = [
    'users.json',
    'teams.json',
    'iterations.json',
    'invites.json',
  ];
  for (final file in collections) {
    final path = File('$testDataDir/$file').absolute.path;
    final result = await Process.run(
      'firestore-seed',
      [
        '--data',
        path,
        '--emulatorHost',
        'localhost:8080',
        '--project',
        'demo-project',
      ],
      runInShell: true,
      workingDirectory: scriptDir, // Set working directory to project root
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
  }
}

Future<dynamic> _loadJsonFile(String path) async {
  final file = File(path);
  final content = await file.readAsString();
  return jsonDecode(content);
}

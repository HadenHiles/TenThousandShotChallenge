#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';

// Complete Test Suite Runner for Ten Thousand Shot Challenge
// This script runs all tests in the proper order with Firebase emulators

Future<String> _findProjectRoot() async {
  // Start from the script's directory and walk up until we find pubspec.yaml with # PROJECT_ROOT
  Directory dir = File(Platform.script.toFilePath()).parent;
  while (true) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (await pubspec.exists()) {
      final lines = await pubspec.readAsLines();
      if (lines.any((line) => line.trim() == '# PROJECT_ROOT')) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw Exception('Could not find project root (pubspec.yaml with # PROJECT_ROOT)');
    }
    dir = parent;
  }
}

void main(List<String> arguments) async {
  // Robustly set working directory to project root
  final projectRoot = await _findProjectRoot();
  Directory.current = projectRoot;

  final verbose = arguments.contains('--verbose');
  final skipEmulators = arguments.contains('--skip-emulators');

  print('🎯 Ten Thousand Shot Challenge - Complete Test Suite');
  print('===================================================');
  print('');

  final stopwatch = Stopwatch()..start();
  Process? emulatorProcess;

  // Set up signal handlers for graceful cleanup
  ProcessSignal.sigint.watch().listen((signal) async {
    print('\n🛑 Received interrupt signal, cleaning up...');
    if (emulatorProcess != null) {
      await _stopEmulators(emulatorProcess);
    }
    await _cleanupGeneratedTestArtifacts(projectRoot);
    exit(1);
  });

  ProcessSignal.sigterm.watch().listen((signal) async {
    print('\n🛑 Received termination signal, cleaning up...');
    if (emulatorProcess != null) {
      await _stopEmulators(emulatorProcess);
    }
    await _cleanupGeneratedTestArtifacts(projectRoot);
    exit(1);
  });

  try {
    // Step 1: Check prerequisites
    await _checkPrerequisites();

    // Step 2: Generate test data
    await _generateTestData(verbose);

    // Step 3: Start emulators (if not skipped)
    if (!skipEmulators) {
      emulatorProcess = await _startEmulators(verbose);
      await _waitForEmulators();
    }

    // Step 4: Import test data to emulators
    if (!skipEmulators) {
      await _importTestData(verbose);
    }

    // Step 5: Run unit tests
    await _runUnitTests(verbose, projectRoot);

    // Step 6: Run integration tests
    if (!skipEmulators) {
      await _runIntegrationTests(verbose, projectRoot);
    }

    // Step 7: Run widget tests
    await _runWidgetTests(verbose, projectRoot);

    // Step 8: Cleanup
    if (emulatorProcess != null) {
      await _stopEmulators(emulatorProcess);
    }
    await _cleanupGeneratedTestArtifacts(projectRoot);

    stopwatch.stop();

    print('');
    print('🎉 Complete Test Suite Finished Successfully!');
    print('⏱️  Total Time: [1m[32m[0m${stopwatch.elapsed.inSeconds} seconds');
    print('✅ All tests passed!');
  } catch (e) {
    stopwatch.stop();
    print('');
    print('❌ Test Suite Failed: $e');
    print('⏱️  Time: ${stopwatch.elapsed.inSeconds} seconds');

    // Always cleanup emulators and test artifacts on failure
    if (emulatorProcess != null) {
      print('🧹 Cleaning up emulators...');
      await _stopEmulators(emulatorProcess);
    }
    await _cleanupGeneratedTestArtifacts(projectRoot);

    exit(1);
  }
}

Future<void> _checkPrerequisites() async {
  print('🔍 Checking Prerequisites...');

  // Check if Firebase CLI is installed
  final firebaseResult = await Process.run('which', ['firebase']);
  if (firebaseResult.exitCode != 0) {
    throw Exception('Firebase CLI not found. Install with: npm install -g firebase-tools');
  }

  // Check if Flutter is available
  final flutterResult = await Process.run('which', ['flutter']);
  if (flutterResult.exitCode != 0) {
    throw Exception('Flutter not found. Make sure Flutter is in your PATH');
  }

  print('✅ Prerequisites check passed');
}

Future<void> _generateTestData(bool verbose) async {
  print('📊 Generating Test Data...');

  // Use absolute path to the script
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final generatorPath = File('$scriptDir/generate_test_data.dart').absolute.path;
  final projectRoot = await _findProjectRoot();

  final result = await Process.run('dart', [generatorPath], workingDirectory: projectRoot);

  if (verbose) {
    print(result.stdout);
  }

  if (result.exitCode != 0) {
    print(result.stderr);
    throw Exception('Test data generation failed');
  }

  print('✅ Test data generated');
}

Future<void> _importTestData(bool verbose) async {
  print('📥 Importing Test Data to Emulators...');

  // Use absolute path to the script
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final importPath = File('$scriptDir/import_test_data.dart').absolute.path;
  final projectRoot = await _findProjectRoot();

  final result = await Process.run('dart', [importPath], workingDirectory: projectRoot);

  if (verbose) {
    print(result.stdout);
  }

  if (result.exitCode != 0) {
    print(result.stderr);
    throw Exception('Test data import failed');
  }

  print('✅ Test data imported');
}

Future<Process?> _startEmulators(bool verbose) async {
  // Always attempt to kill any existing Firebase Emulator processes, regardless of port status
  print('🔥 Stopping any existing Firebase Emulator processes...');
  final projectRoot = await _findProjectRoot();
  try {
    await Process.run('pkill', ['-f', 'firebase.*emulators'], workingDirectory: projectRoot);
    await Future.delayed(Duration(seconds: 2));
    print('✅ Existing Firebase Emulator processes killed');
  } catch (e) {
    // Ignore errors, might not have any running
    print('ℹ️  No existing Firebase Emulator processes found');
  }

  // Optionally, check if port 4000 is still in use and warn the user
  try {
    final result = await Process.run('curl', ['-s', '-f', 'http://localhost:4000'], workingDirectory: projectRoot);
    if (result.exitCode == 0) {
      print('⚠️  Port 4000 still appears to be in use. Will attempt to start emulators anyway.');
    }
  } catch (e) {
    // Port is not in use, continue
  }

  print('🔥 Starting Firebase Emulators...');

  // Create emulator data directory
  await Directory('test/emulator_data').create(recursive: true);

  // Start emulators using Process.start
  final process = await Process.start(
    'firebase',
    ['emulators:start', '--only', 'auth,firestore,ui', '--import=./test/emulator_data', '--export-on-exit=./test/emulator_data'],
    workingDirectory: projectRoot,
  );

  if (verbose) {
    print('🔥 Emulators command executed with PID: \\${process.pid}');
  }

  return process;
}

Future<void> _waitForEmulators() async {
  print('⏳ Waiting for emulators to start...');

  // Wait up to 60 seconds for emulators to be ready
  for (int i = 0; i < 60; i++) {
    try {
      final result = await Process.run('curl', ['-s', 'http://localhost:4000']);
      if (result.exitCode == 0) {
        print('✅ Emulators are ready');
        return;
      }
    } catch (e) {
      // Continue waiting
    }

    await Future.delayed(Duration(seconds: 1));
    if (i % 10 == 0) {
      print('   Still waiting... (${i}s)');
    }
  }

  throw Exception('Emulators failed to start within 60 seconds');
}

Future<void> _runUnitTests(bool verbose, String projectRoot) async {
  print('🧪 Running Unit Tests...');

  final result = await Process.run(
    'flutter',
    ['test', '--reporter=expanded'],
    workingDirectory: projectRoot,
  );

  if (verbose) {
    print(result.stdout);
  }

  if (result.exitCode != 0) {
    print(result.stderr);
    throw Exception('Unit tests failed');
  }

  print('✅ Unit tests passed');
}

Future<void> _runIntegrationTests(bool verbose, String projectRoot) async {
  print('🔗 Running Integration Tests...');

  final result = await Process.run(
    'flutter',
    ['test', 'test/firestore_integration_test.dart', '--reporter=expanded'],
    workingDirectory: projectRoot,
  );

  if (verbose) {
    print(result.stdout);
  }

  if (result.exitCode != 0) {
    print(result.stderr);
    throw Exception('Integration tests failed');
  }

  print('✅ Integration tests passed');
}

Future<void> _runWidgetTests(bool verbose, String projectRoot) async {
  print('🎨 Running Widget Tests...');

  final result = await Process.run(
    'flutter',
    ['test', 'test/widgets/', '--reporter=expanded'],
    workingDirectory: projectRoot,
  );

  if (verbose) {
    print(result.stdout);
  }

  if (result.exitCode != 0) {
    print(result.stderr);
    throw Exception('Widget tests failed');
  }

  print('✅ Widget tests passed');
}

Future<void> _stopEmulators(Process? emulatorProcess) async {
  print('🛑 Stopping Emulators...');

  if (emulatorProcess != null) {
    print('   Terminating emulator process (PID: \${emulatorProcess.pid})...');
    emulatorProcess.kill(ProcessSignal.sigterm);
  } else {
    // Fallback to script if process is null (e.g. emulators were already running)
    await Process.run('bash', ['scripts/stop_emulators.sh']);
  }

  print('✅ Emulators stopped');
}

Future<void> _cleanupGeneratedTestArtifacts(String projectRoot) async {
  print('🧹 Cleaning up generated test artifacts...');
  final pathsToDelete = [
    'test/emulator_data',
    'test/test_data',
    'test/firebase-export',
    'firebase-export',
    'test/unit_test_assets',
    // Add any other generated test folders/files here
  ];
  for (final relPath in pathsToDelete) {
    final dir = Directory('$projectRoot/$relPath');
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
        print('   Deleted $relPath');
      } catch (e) {
        print('   Failed to delete $relPath: $e');
      }
    }
    final file = File('$projectRoot/$relPath');
    if (await file.exists()) {
      try {
        await file.delete();
        print('   Deleted file $relPath');
      } catch (e) {
        print('   Failed to delete file $relPath: $e');
      }
    }
  }
  print('✅ Test artifacts cleanup complete');
}

# Ten Thousand Shot Challenge - Testing Guide

## Overview

This project uses a robust test suite with local Firebase emulators, CLI tools, and custom scripts to ensure reliable, isolated testing. All test data and emulator state are generated and imported automatically. No production data is touched.

---

## Quick Start: Full Test Suite

**Recommended:** Run the complete test suite, which will:

- Generate test data
- Start Firebase emulators
- Import test data
- Run all unit, integration, and widget tests
- Clean up emulators

**From the command line:**

```sh
dart test/scripts/run_complete_test_suite.dart --verbose
```

**From VS Code:**

- Use the Run/Debug sidebar and select:
  - `🧪 Firebase Test Suite (Complete)` (runs the full suite)
  - `Flutter: Run All Unit Tests` (runs only unit tests)
  - `Run All Tests (Complete Suite + Unit)` (runs both in sequence)

---

## Manual Testing Steps

1. **Start Emulators (if not using the suite):**

   ```sh
   firebase emulators:start --only auth,firestore,ui
   # or use the provided scripts if available
   ```

   Emulator UI: [http://localhost:4000](http://localhost:4000)

2. **Generate Test Data:**

   ```sh
   dart test/scripts/generate_test_data.dart
   # Outputs JSON files to test/test_data/
   ```

3. **Import Test Data:**

   ```sh
   dart test/scripts/import_test_data.dart
   # Uses CLI tools and test/test_data/*.json
   ```

4. **Run Tests:**

   ```sh
   flutter test
   # Or run individual test files as needed
   ```

---

## Test Data & Artifacts

- All generated test data and emulator exports are stored in `/test/test_data/`, `/test/emulator_data/`, and `/test/scripts/` (see .gitignore for details).
- These files and folders are ignored by git and safe to delete/regenerate.
- Test users use password: `testpass123`.

---

## Custom Scripts

- `test/scripts/run_complete_test_suite.dart`: Runs the full suite, handles all setup/teardown.
- `test/scripts/generate_test_data.dart`: Generates JSON test data.
- `test/scripts/import_test_data.dart`: Imports test data using CLI tools.
- `test/scripts/create_real_test_users.dart`: (CAUTION) Creates real users in production Firebase.

---

## Best Practices

- Always use the test suite or scripts to reset emulator state before running tests.
- Never commit generated test data or emulator exports.
- Use the VS Code test runner for quick feedback on unit/widget tests.
- For advanced scenarios, see comments in the relevant scripts.

## iOS Connectivity Lifecycle Regression

Crashlytics issue `70aabed98e2aeac09963b50d82990a2e` affected
3.0.10 (42) while backgrounded, including iOS apps running on macOS.
`connectivity_plus` 6.1.5 could deliver an `NWPathMonitor` update to a torn-down
Flutter engine. Keep the dependency at 7.3.0 or newer, which gates native
connectivity events while backgrounded instead of messaging an unavailable engine.

Use an emulator-configured build, not production services:

1. Open the app and verify connectivity changes still trigger offline-session sync.
2. Background the app, change network connectivity, and return to the app.
3. Repeat while closing and reopening the Flutter scene, including on an Apple
   Silicon Mac running the iOS app when available.
4. Confirm there is no `NSInternalInconsistencyException` with
   `Sending a message before the FlutterEngine has been run.`, and verify
   queued sessions sync when connectivity is restored in the foreground.

Flutter unit tests cannot exercise the native engine-teardown race; include
this lifecycle check when validating connectivity dependency changes.

---

## Copilot Rules & Guidelines

1. Use super parameters in constructors wherever possible.
2. After every code change, perform a post-change assessment for code simplicity. This must include:
   - Widget structure: Ensure widgets are organized, minimal, and easy to follow.
   - Separation of concerns: Classes and files should have clear, single responsibilities.
   - Redundant code: Remove unnecessary variables, functions, and repeated logic.
   - External packages: Evaluate and use appropriate pub.dev packages to simplify code and avoid reinventing solutions.
3. Document all refactoring decisions and rationale in code comments or commit messages.
4. Use underscore notation for firestore collections/documents/fields, and camelcase for Flutter variables etc.
5. Always centralize and reuse test utilities and mocks for maintainability.
6. Always add ToDo's for any debug code to remember to remove
7. Prefer concise, readable code over clever or complex solutions.
8. Always enforce DRY principals when possible
9. Review and update these guidelines as new best practices emerge.
10. Never abbreviate changes with "//..existing code" in actual file changes, only in suggestions in the chat

Happy Testing! 🎯

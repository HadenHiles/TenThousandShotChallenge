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

Happy Testing! 🎯

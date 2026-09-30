# Repository Instructions

## Project Map

- Flutter and Dart application code lives in `lib/`; tests live in `test/`.
- Firebase Cloud Functions are TypeScript in `functions/src/`, with compiled output in `functions/lib/`.
- Firebase configuration, security rules, and indexes are maintained at the repository root.
- Follow nearby models, services, widgets, and tests for local architecture and naming. Trace data ownership through its model, storage path, and consumers before changing fields; similarly named values may belong to different features.

## Implementation Preferences

- Prefer clear object-oriented boundaries when they improve domain ownership, reuse, or testability. Keep to the established codebase patterns and avoid broad refactors done only to make code more object-oriented.
- Keep changes focused and readable. Reuse existing test helpers and mocks, and do not include unrelated or generated files in a change.
- When asked to commit, use a concise, imperative commit subject and include only the task-related changes. Do not commit unless asked.

## Validation

- Run focused Flutter tests while iterating, then broaden coverage to match the change: `flutter test` for the Dart suite and `dart test/scripts/run_complete_test_suite.dart --verbose` for emulator-backed integration coverage.
- For Cloud Functions changes, run `cd functions && npm run lint && npm run build`.
- Do not use production services or create real test users for routine validation. The testing runbook documents emulator setup and calls out scripts that affect production.
- See [TESTING.md](TESTING.md) for test setup and safe emulator workflows, and [TEST_ROADMAP.md](TEST_ROADMAP.md) for planned coverage.

## Project References

- [CHALLENGER_ROAD_ROADMAP.md](CHALLENGER_ROAD_ROADMAP.md) documents Challenger Road data architecture and feature decisions.
- [CHALLENGES.md](CHALLENGES.md) describes the existing challenges feature.

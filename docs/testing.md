# Testing strategy

> When to read: before writing tests or changing the test setup.

## Test suite

`flutter_test` (bundled with the SDK) – covers pure Dart unit tests and widget tests in one runner, no extra dependency. Device integration tests (only where hardware behaviour must be proven) use `integration_test` under `tests/integration/`.

## TDD flow (mandatory)

1. Red: write the test, run it, confirm it fails for the expected reason.
2. Green: write the minimal code until it passes.
3. Refactor: clean up, tests stay green.

## Commands

```bash
flutter test tests/                                        # all tests
flutter test tests/recording/engine_test.dart              # one file
flutter test tests/recording/engine_test.dart --plain-name "first step active on start"
flutter test tests/ --coverage                             # coverage to coverage/lcov.info
flutter test tests/integration/<file>_test.dart -d <device-id>   # on device/emulator
```

Note: with an empty `tests/` folder Flutter reports "No test files were passed" – that is expected until the first test exists. Never create `test/`.

## Which tests to run

- Change in `lib/<feature>/` → `flutter test tests/<feature>/`.
- Change in shared code (`lib/core/`, DB schema, l10n, formatters) → full suite.
- Always run the full suite before finishing a task.

## Done criteria

A change is done when all of these hold:

1. `flutter test tests/` passes.
2. `flutter analyze` reports no issues.
3. `dart format --output=none --set-exit-if-changed .` exits with 0.
4. No existing test was changed, deleted or weakened (unless explicitly requested).

## Hard rules

- A failing test means fixing the implementation, not the test.
- At most 3 repair attempts per failing test; then stop and report.
- Changing an existing test requires a stated reason and approval.

## Test structure

- `tests/` mirrors `lib/`: `lib/recording/domain/engine.dart` → `tests/recording/domain/engine_test.dart`.
- Unit tests for all domain logic (engine, statistics, formatters, parsers, export builders). Widget tests for screens with Riverpod `ProviderScope(overrides: [...])`.
- Time is always faked: inject a `FakeClock`; never use real delays or `sleep` in tests.
- Platform interfaces (keys, speech, video, foreground service) are replaced by fakes in `tests/fakes/`.
- Database tests use an in-memory database.
- Hardware behaviour that cannot be automated is checked manually on a device and logged in the task notes.

---
Maintenance: update this file immediately when the test suite or strategy changes.

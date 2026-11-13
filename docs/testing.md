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
- Platform interfaces (keys, speech, video, frame decoding, foreground service) are replaced by fakes in `tests/fakes/` (`FakeFrameSource` returns a valid 1x1 PNG per frame). `fakePlatformOverrides()` also replaces `videoFilesProvider` by `FakeVideoFiles` (records deleted paths; pass `videoFiles:` to inspect them), so tests never delete real files. It also replaces `urlOpenerProvider` by `FakeUrlOpener` (records opened links, `result` sets what it reports; pass `urlOpener:`), so tests never start a browser.
- Database tests use an in-memory database: `openTestDatabase()` from `tests/helpers.dart` (independent instance per call, `singleInstance: false`).
- Widget tests: wrap with `ProviderScope(overrides: [databaseProvider.overrideWithValue(db)])` and `localizedApp(...)`; use `settle(tester)` after actions that hit the database (sqflite ffi needs real async via `runAsync`) and `tapVisible(tester, finder)` for widgets that may be scrolled out of the 800×600 test view.
- Screens with an endless ticker (recording screen): never `pumpAndSettle`; use `pumpFrames(tester)` for animations (tabs, snack bars, expansion tiles) and `usePhoneSize(tester)` for a realistic 392×872 surface.
- Slow real async work (PDF rendering, backup files) can outlast `settle`; wait for its effect with `settleUntil(tester, () => condition)` (bounded, 10 s). Found when CI (GitHub runner) was slower than local machines.
- Forms must not use lazy `ListView`s: off-screen fields would not be validated (found in Task_01).
- Hardware behaviour that cannot be automated is checked manually on a device and logged in the task notes.

## Screenshots

- `tests/screenshots/app_screenshots_test.dart` renders the main screens (EN + DE) with seeded sample data into `screenshots/<lang>/`. It is skipped in normal runs and enabled with `flutter test tests/screenshots --dart-define=SCREENSHOTS=true`.
- Real fonts (Roboto, Material Icons) are loaded from `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts`; shadows are switched on per test (`debugDisableShadows`) and switched off again before the test ends.
- CI: `.github/workflows/screenshots.yml` runs the full suite and the generator on every push to `main` (Ubuntu, Flutter pinned to the local version) and commits changed images. Do not commit locally rendered screenshots; CI is the single source.
- New screens or major UI changes: add a scene to the generator (scenes 08 group, 09 revisions, 10 line analysis, 11 simulation).

---
Maintenance: update this file immediately when the test suite or strategy changes.

# CycleScope

Flutter app (Android first, iOS-capable code) for time and motion studies (REFA/MTM): define work steps, measure cycles live via volume keys or from an imported video, edit recordings, and analyse step times and the real cycle time. Local data only. English-first UI with German translation.

## Top rules

1. **Strict TDD.** Always write a failing test with `flutter_test` first, then the minimal code, then refactor (Red, Green, Refactor). No production code without a previously failing test. Bug fixes start with a test that reproduces the bug.
   - Never change, delete or weaken existing tests to get green. If a test fails, fix the implementation. If the test itself is wrong, explain why and wait for approval.
   - Repair budget: at most 3 attempts per failing test, then stop and report (which tests, what you tried, suspected cause).
   - Run the tests belonging to your change first (`flutter test tests/<path>_test.dart`); run the full suite before finishing and when shared code changed.
2. **Tests live in `tests/`, not `test/`.** Flutter's default `test/` folder must not be used. Always pass the path explicitly.
3. **Keep docs current.** If stack, architecture, conventions, code style or testing change, update the matching file in `docs/` in the same step. A task is only done when `docs/` is correct.
4. **Use only `flutter pub` for dependencies.** Flutter SDK version is pinned by the `environment` section in `pubspec.yaml`. Ask before adding a dependency not named in `docs/architecture.md`.
5. **English everywhere in code**: identifiers, file names, comments, commit messages. User-visible strings only via l10n (ARB files, English is the template), never hard-coded.

## Commands

```bash
flutter pub get
flutter test tests/
flutter test tests/<path>_test.dart
flutter test tests/<path>_test.dart --plain-name "<test name>"
flutter analyze
dart format .
flutter run
flutter build apk --debug
```

## Documentation (load on demand)

Read only what your current work needs:

- [docs/architecture.md](docs/architecture.md) – before structural changes, new components or new dependencies. Stack, layers, platform abstractions.
- [docs/testing.md](docs/testing.md) – before writing tests or changing test setup. Test strategy, fakes, done criteria.
- [docs/code-style.md](docs/code-style.md) – before writing or formatting code. Formatter, linter, style rules.
- [docs/conventions.md](docs/conventions.md) – when naming things, organising files or committing. Naming, folder rules, git.
- [docs/project-brief.md](docs/project-brief.md) – when goal, scope or non-goals are unclear.

## Roadmap

Work on roadmap tasks follows [Roadmap/AGENTS.md](Roadmap/AGENTS.md). Current task files are in `Roadmap/Tasks/`; project-wide memory is `Roadmap/README.md`.

## Boundaries

- No cloud services, accounts or network calls; all data stays on the device (backup only via file export).
- Measurement time comes from a monotonic clock behind an injectable interface – never `DateTime.now()` for durations.
- Platform features (volume keys, microphone, video, foreground service) only behind Dart interfaces with test fakes.
- Do not implement standard time (performance rating, allowances) – explicit non-goal for now.
- Never commit secrets; none are needed. If a key ever becomes necessary, add `.env.example` and document it first.

# Tech stack and architecture

> When to read: before structural changes, new components or new dependencies.

## Tech stack

- Language/runtime: Dart 3.13 / Flutter 3.47 (stable). SDK constraint in `pubspec.yaml`.
- Target: Android first (minSdk see open decisions). Code must stay iOS-capable; iOS-specific features are out of scope.
- State management: **Riverpod** (`flutter_riverpod`) – chosen because providers can be overridden with fakes (clock, keys, speech, video) in unit and widget tests without a widget tree.
- Persistence: local SQLite. Proposed library: **drift** (typed queries, migrations, in-memory DB for tests) – to be confirmed in Task_01.
- Localization: Flutter `gen-l10n` with ARB files; **English is the template/fallback**, German is the translation.
- Further libraries (video player, speech recognition, foreground service, export) are chosen in their roadmap tasks and recorded here with the reason.

## Architecture

- **Feature-first structure** under `lib/`: each feature (e.g. `study`, `recording`, `analysis`, `video`, `export`, `settings`) has `domain/` (pure Dart), `data/` (repositories, DB), `presentation/` (widgets, providers).
- **Domain is pure Dart**: measurement engine, statistics and export table building have no Flutter imports, so they are fully unit-testable.
- **Time source**: the engine reads time through a `Clock` interface (monotonic, e.g. `Stopwatch`-based). Video studies plug in a video-position time source. Durations are stored as integer microseconds; unit conversion (HM, s, mm:ss.SSS, TMU) happens only in formatters.
- **Platform abstractions**: hardware volume keys (Android platform channel), speech recognition, video playback and the foreground service each sit behind a Dart interface with a fake in tests.
- **Data model (core)**: Study (name, description, mode) → StepDefinition (position, name) → Measurement (cycle number, step id, start, end, type `normal | special`, note). Measurements reference steps by id, never by position.
- **Crash safety**: every completed measurement and every engine state change is persisted immediately.

## Environment

- Dependencies only via `flutter pub add` / `flutter pub get`. No `.env` needed (no external services).
- Android application id: `dev.cyclescope.cyclescope`, Dart package name `cyclescope`.

## Open decisions

- Minimum Android version: assumption API 26 (Android 8), not yet confirmed. Currently `flutter.minSdkVersion` in `android/app/build.gradle.kts`.
- Final app display name (working title "CycleScope").

---
Maintenance: update this file immediately when the stack or architecture changes.

# Tech stack and architecture

> When to read: before structural changes, new components or new dependencies.

## Tech stack

- Language/runtime: Dart 3.13 / Flutter 3.47 (stable). SDK constraint in `pubspec.yaml`.
- Target: Android first (minSdk see open decisions). Code must stay iOS-capable; iOS-specific features are out of scope.
- State management: **Riverpod** (`flutter_riverpod`) – chosen because providers can be overridden with fakes (clock, keys, speech, video) in unit and widget tests without a widget tree.
- Persistence: local SQLite via **sqflite** with hand-written SQL. Schema migrations are an append-only list in `lib/core/database.dart` (`migrations[n]` creates version n+1). Chosen over drift to avoid code generation/build_runner; tests use `sqflite_common_ffi` with an in-memory DB.
- Localization: Flutter `gen-l10n` with ARB files in `lib/l10n/` (`l10n.yaml`); **English is the template/fallback**, German is the translation. Generated `app_localizations*.dart` are committed; after editing ARB files run `flutter gen-l10n`.
- `speech_to_text` – push-to-talk dictation of steps (platform recognizer, no own model).
- `wakelock_plus` – keep the screen on while recording.
- `video_player` – video playback (ExoPlayer) for video studies; `file_picker` – choosing videos (and backup files).
- `excel` – .xlsx export; `share_plus` – system share sheet for export/backup files.
- Further libraries (PDF) are chosen in their roadmap tasks and recorded here with the reason.

## Architecture

- **Feature-first structure** under `lib/`: each feature (e.g. `study`, `recording`, `analysis`, `video`, `export`, `settings`) has `domain/` (pure Dart), `data/` (repositories, DB), `presentation/` (widgets, providers).
- **Domain is pure Dart**: measurement engine, statistics and export table building have no Flutter imports, so they are fully unit-testable.
- **Time source**: the engine reads time through a `Clock` interface (monotonic, e.g. `Stopwatch`-based). Video studies plug in a video-position time source. Durations are stored as integer microseconds; unit conversion (HM, s, mm:ss.SSS, TMU) happens only in formatters.
- **Platform abstractions**: hardware volume keys (Android platform channel), speech recognition, video playback and the foreground service each sit behind a Dart interface with a fake in tests.
- **Data model (core)**: Study (name, description, mode) → StepDefinition (position, name) → Measurement (cycle number, step id, start, end, type `normal | special`, note). Measurements reference steps by id, never by position.
- **Crash safety**: every completed measurement and every engine state change is persisted immediately.

## App wiring

- `main()` opens the database and overrides `databaseProvider`; all other providers live in `lib/core/providers.dart` or the feature's `presentation/` folder.
- Lists are `FutureProvider`s that are invalidated after writes (sqflite has no change streams).
- Screens with live state use a `ChangeNotifier` controller (e.g. `RecordingController`) that reads its dependencies from providers once; Riverpod is the DI/override mechanism. Never use `ref` in `dispose()`.
- Platform side effects (haptics, wake lock, later keys/notifications) go through interfaces in `lib/core/platform.dart`, provided via `deviceFeedbackProvider` etc.
- Settings: `settingsProvider` (Riverpod `Notifier`) backed by the `settings` table; loaded in `main()` and injected via `initialSettingsProvider`. Providers that depend on settings (`deviceFeedbackProvider`, `recordingNotifierProvider`) watch it.
- Wall-clock timestamps (created/active) come from `wallClockProvider`, never directly from `DateTime.now()` in widgets.

## Environment

- Dependencies only via `flutter pub add` / `flutter pub get`. No `.env` needed (no external services).
- Android application id: `dev.cyclescope.cyclescope`, Dart package name `cyclescope`.

## Open decisions

- Minimum Android version: API 26 (Android 8) set in `android/app/build.gradle.kts` – assumption, not yet confirmed by the user.
- Final app display name (working title "CycleScope").

---
Maintenance: update this file immediately when the stack or architecture changes.

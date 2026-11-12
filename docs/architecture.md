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
- `pdf` – PDF report (pure Dart, built-in Latin-1 fonts; shared via the share sheet instead of the `printing` plugin).

## Architecture

- **Feature-first structure** under `lib/`: each feature (e.g. `study`, `recording`, `analysis`, `video`, `export`, `settings`) has `domain/` (pure Dart), `data/` (repositories, DB), `presentation/` (widgets, providers).
- **Domain is pure Dart**: measurement engine, statistics and export table building have no Flutter imports, so they are fully unit-testable.
- **Time source**: the engine reads time through a `Clock` interface (monotonic, e.g. `Stopwatch`-based). Video studies plug in a video-position time source. Durations are stored as integer microseconds; unit conversion (HM, s, mm:ss.SSS, TMU) happens only in formatters.
- **Platform abstractions**: hardware volume keys (Android platform channel), speech recognition, video playback, video frame decoding and the foreground service each sit behind a Dart interface with a fake in tests.
- **Frame decoding** (`video/platform/frame_source.dart` → `FrameDecoder.kt`, channel `dev.cyclescope/frames`): `MediaMetadataRetriever.getFramesAtIndex` (API 28+) decodes JPEG frames (longest side 1280 px) on a worker thread. `FrameCache` (pure Dart, `video/domain/frame_cache.dart`) keeps the frames within 8 of the position (forward first) and evicts far ones; `FrameTiming` converts time ↔ frame index with the real frame rate (frame count / duration). Frame stepping shows the cached frame above the player while it seeks; play or any other seek hides it. Without decoder support stepping falls back to 30 fps player seeks.
- **Data model (core)**: Study (name, description, mode) → StepDefinition (position, name) → Measurement (cycle number, step id, start, end, type `normal | special`, note). Measurements reference steps by id, never by position.
- **Crash safety**: every completed measurement and every engine state change is persisted immediately.

## App wiring

- `main()` opens the database and overrides `databaseProvider`; all other providers live in `lib/core/providers.dart` or the feature's `presentation/` folder.
- Lists are `FutureProvider`s that are invalidated after writes (sqflite has no change streams).
- Screens with live state use a `ChangeNotifier` controller (e.g. `RecordingController`) that reads its dependencies from providers once; Riverpod is the DI/override mechanism. Never use `ref` in `dispose()`.
- Platform side effects (haptics, wake lock, later keys/notifications) go through interfaces in `lib/core/platform.dart`, provided via `deviceFeedbackProvider` etc.
- Settings: `settingsProvider` (Riverpod `Notifier`) backed by the `settings` table; loaded in `main()` and injected via `initialSettingsProvider`. Providers that depend on settings (`deviceFeedbackProvider`, `recordingNotifierProvider`) watch it.
- Wall-clock timestamps (created/active) come from `wallClockProvider`, never directly from `DateTime.now()` in widgets.
- Video studies without steps have `study.steps_open = 1` (migration v7): `RecordingController.mark()` appends a step (and rebuilds the engine from its snapshot) while on the last step; `closeCycle()` wraps to the next cycle and clears the flag (`StudyRepository.closeSteps`). With fixed steps `closeCycle()` ends the cycle early via `RecordingEngine.endCycle()` (closes the current step, next cycle starts at step 1). `StudyMode.definesStepsUpfront` says which modes ask for steps on creation. Markers may not lie before the last marker (`canMarkAt`); so that deleted cycles or a new video never block positions, `RecordingController.resetMarkers()` drops the open marker run (engine back to idle, stored times kept). It runs when a video study's deleted cycle contains the marker the open step started at (or is the running cycle) and whenever the video is replaced; replacing a video with recorded cycles first asks whether to delete them (`deleteAllMeasurements()`) or keep them.
- Study notes: `study.notes` (migration v8, `TEXT NOT NULL DEFAULT ''`), edited in the analysis tab via `RecordingController.setNotes()` (which also refreshes `study`, so an export right after typing sees them) and written by the CSV/Excel header block and the PDF report; part of the backup (`notes`, optional on import). The analysis unit chip calls `RecordingController.onAnalysisUnitChosen`, which the screens wire to save `AppSettings.defaultUnit`.
- Dictation (`DictationButton`) queues recognizer calls: a release during start stops once started, a new press waits for the previous session's result. `SystemSpeechInput.stop()` waits (bounded) for the recognizer's "done" status, because Android's recognizer is busy until then.

## Environment

- Dependencies only via `flutter pub add` / `flutter pub get`. No `.env` needed (no external services).
- Release signing: the only secret of the project. `android/app/build.gradle.kts` signs release builds with the key from `android/key.properties` (template: `android/key.properties.example`; the real file, `*.jks` and `*.keystore` are git-ignored). Without the file, release builds use the debug key.
- The release keystore lives outside the repository and must be backed up by the owner: without it no update of an installed app is possible. GitHub secrets used by `.github/workflows/release.yml`: `ANDROID_KEYSTORE_BASE64` (base64 of the `.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- Releases: pushing a tag `vX.Y.Z` runs the tests, builds `flutter build apk --release` (version name from the tag, version code = workflow run number) and publishes the APK as a GitHub release.
- Google Play: application ID `dev.cyclescope.cyclescope` (fixed once published), launcher label `CycleScope`. Upload an app bundle (`flutter build appbundle --release`, signed with the release key above as upload key; Play App Signing holds the app signing key). Store graphics come from `python tool/generate_store_assets.py`, which wraps `screenshots/<lang>/` in 1080 × 1920 frames and writes the icon and feature graphic into the local, git-ignored `store/` folder (listing texts and console answers are kept there by hand).
- Play upload: fastlane in `android/` (`Gemfile`, `fastlane/Fastfile`, lane `internal` with options `track:` and `status:`). It asks Play for the highest version code on all tracks, builds `flutter build appbundle --build-number <max+1>` and uploads the bundle (no metadata or images; the store listing is maintained in the console). CI: `.github/workflows/play.yml`, started by hand (track internal/alpha/beta/production, status draft/completed), runs the tests first. Secrets: the `ANDROID_*` signing secrets (shared composite action `.github/actions/android-signing`, also used by `release.yml`) and `PLAY_SERVICE_ACCOUNT_JSON` (JSON key of a Google Cloud service account invited in the Play Console with release rights for the app). Ruby/fastlane are only needed in CI.
- Privacy policy (required by Google Play): `site/privacy/index.html`, published with the small landing page `site/` by `.github/workflows/pages.yml` (GitHub Pages, source "GitHub Actions") at https://sphaerox.github.io/Serienmessung/privacy/. Keep it in line with the app's permissions and data handling whenever those change.
- Android application id: `dev.cyclescope.cyclescope`, Dart package name `cyclescope`.

## Open decisions

- Minimum Android version: API 26 (Android 8) set in `android/app/build.gradle.kts` – assumption, not yet confirmed by the user.
- Final app display name (working title "CycleScope").

---
Maintenance: update this file immediately when the stack or architecture changes.

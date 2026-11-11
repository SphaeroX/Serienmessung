# CycleScope

Time and motion study stopwatch for Android (Flutter): define work steps, record cycles via volume keys or from video, and analyse step times and the real cycle time.

- Agent / developer rules: [AGENTS.md](AGENTS.md)
- Project brief: [docs/project-brief.md](docs/project-brief.md)
- Roadmap: [Roadmap/README.md](Roadmap/README.md)

```bash
flutter pub get
flutter test tests/
flutter run
```

## Download

Signed APKs are on the [Releases page](https://github.com/SphaeroX/Serienmessung/releases). A release is built by pushing a version tag (`git tag v1.2.0 && git push origin v1.2.0`), see [release.yml](.github/workflows/release.yml).

## Screenshots

Rendered automatically on every push to `main` by the [Screenshots workflow](.github/workflows/screenshots.yml) (`tests/screenshots`). German versions: [screenshots/de](screenshots/de).

| Studies | Live recording | Analysis | Video study |
|---|---|---|---|
| <img src="screenshots/en/01_study_list.png" width="200"> | <img src="screenshots/en/03_recording_live.png" width="200"> | <img src="screenshots/en/05_analysis.png" width="200"> | <img src="screenshots/en/06_video_study.png" width="200"> |

| New study | Cycles | Settings |
|---|---|---|
| <img src="screenshots/en/02_new_study.png" width="200"> | <img src="screenshots/en/04_cycles.png" width="200"> | <img src="screenshots/en/07_settings.png" width="200"> |

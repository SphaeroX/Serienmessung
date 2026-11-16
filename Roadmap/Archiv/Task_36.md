# Task_36: iOS-Unterstützung

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_36.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

CycleScope läuft auch unter iOS (iPhone und iPad) und lässt sich über den App Store verteilen. Alles, was unter iOS geht, funktioniert wie unter Android; was iOS nicht erlaubt (Lautstärketasten, dauerhafte Aufnahme-Benachrichtigung), ist dort ausgeblendet statt kaputt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_35 archiviert (Nutzerwunsch nach Abschluss der Roadmap).
- **Relevantes Vorwissen:** Task_04 (Plattform-Kanal `dev.cyclescope/platform` in `MainActivity.kt`), Task_06 (Uhr-Offset über `elapsedRealtime`, Aufnahme-Benachrichtigung), Task_10 (Einstellungen), Task_12 (Video-Import nach `Documents/videos/`), GitHub-Logo nach Task_35 (`UrlOpener`).

## Umfang

**Gehört dazu:**

- iOS-Projekt unter `ios/` (`flutter create --platforms=ios`, Bundle-ID `com.boundfoxstudios.apps.cyclescope`, ab iOS 15, iPhone und iPad, Anzeigename „CycleScope“, Sprachen Englisch und Deutsch).
- Swift-Seite des Kanals `dev.cyclescope/platform`: `openUrl` (nur https) und `elapsedRealtimeMicros` (monotone Uhr), mit XCTests.
- iOS-App-Icon aus `tool/generate_app_icon.py`.
- Lautstärketasten und Aufnahme-Benachrichtigung nur dort anbieten, wo die Plattform sie hat (`PlatformFeatures`); unter iOS Silent-Implementierungen und ausgeblendete Einstellungen.
- Videopfade relativ zum Documents-Ordner speichern, weil sich der Container-Pfad unter iOS mit jedem App-Update ändert; alte absolute Pfade weiter finden.
- Datenschutzerklärung in den Einstellungen verlinken (App-Store-Pflicht) und auf der Website um iOS ergänzen.
- App-Store-Angaben: Zweckbeschreibungen für Mikrofon und Spracherkennung (EN/DE), `ITSAppUsesNonExemptEncryption`.
- iOS-CI (unsignierter Build, XCTests) und Übergabe grüner `main`-Builds an die App-Store-Pipeline in `BoundfoxStudios/cyclescope-ios`.
- Doku, README, Roadmap.

**Gehört nicht dazu:**

- Lautstärketasten unter iOS (App Review Guideline 2.5.9 verbietet das Umbelegen der Lautstärketasten).
- Dauerhafte Aufnahme-Benachrichtigung unter iOS.
- Frame-Decoder für iOS (Einzelbild-Schritte nutzen den 30-fps-Fallback).
- Signieren, Versionierung und TestFlight-Upload in diesem Repo (passiert in `BoundfoxStudios/cyclescope-ios`).

## Umsetzungsschritte

1. [x] iOS-Projekt anlegen (`.metadata`, `analysis_options.yaml` schließt `ios/**` aus).
2. [x] Swift-Kanal `openUrl`/`elapsedRealtimeMicros` mit XCTests.
3. [x] iOS-App-Icon aus dem Icon-Generator.
4. [x] Lautstärketasten und Aufnahme-Benachrichtigung unter iOS ausblenden (TDD).
5. [x] Videopfade relativ speichern und beim Lesen auflösen (TDD).
6. [x] Datenschutzerklärung in den Einstellungen verlinken (TDD).
7. [x] Datenschutzerklärung der Website um iOS ergänzen.
8. [x] iOS-CI und Übergabe an die App-Store-Pipeline.
9. [x] Doku, README, Roadmap.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`); die nativen iOS-Tests liegen in `ios/RunnerTests/`.

Zu belegende Verhaltensweisen:

- Android bietet Lautstärketasten und Aufnahme-Benachrichtigung, iOS keins von beiden; unter iOS liefern die Provider `SilentHardwareKeys` und `SilentRecordingNotifier`.
- Die Einstellungen blenden unter iOS Lautstärketasten-Schalter, Halteschwelle und Benachrichtigungs-Schalter aus.
- Ein Video wird als `videos/<datei>` gespeichert und beim Lesen in den aktuellen Documents-Ordner aufgelöst; ein fehlender alter absoluter Pfad wird über den Dateinamen im aktuellen Videos-Ordner gefunden; Löschen und Öffnen im Video-Bildschirm nutzen den aufgelösten Pfad.
- Der Eintrag „Datenschutzerklärung“ öffnet den Link, meldet einen Fehlschlag per Snackbar und ist übersetzt.
- Swift-Kanal (XCTest): https-Link öffnen, Fehlschlag, kein https, fehlendes oder falsches Argument, Uhrwert, unbekannte Methode.

Alle Dart-Tests laufen mit `flutter test tests/`; die XCTests nur auf macOS (`xcodebuild test`, iOS-Workflow oder Xcode).

## Akzeptanzkriterien

- [x] Tests grün (550), `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Swift-Code und XCTests ließen sich in der Linux-Umgebung nicht kompilieren; sie werden erst im iOS-Workflow auf macOS gebaut und ausgeführt.
- Die App-Store-Pipeline (`BoundfoxStudios/cyclescope-ios`) und die GitHub App für den Trigger werden außerhalb dieses Repos eingerichtet; bis die Variable `CYCLESCOPE_IOS_TRIGGER_CLIENT_ID` gesetzt ist, überspringt der Workflow die Übergabe.

## Notizen zu diesem Task

- Nach Abschluss der Roadmap ergänzt (iOS-Version für den App Store).
- Version unverändert 1.6.2; die Build-Nummer für iOS vergibt die Pipeline.

## Abschluss-Checkliste

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** iOS-Projekt unter `ios/`; `PlatformChannel` in `ios/Runner/AppDelegate.swift` (Swift-Seite von `dev.cyclescope/platform`, alle anderen Methoden `FlutterMethodNotImplemented`) mit XCTests in `ios/RunnerTests/RunnerTests.swift`; `PlatformFeatures`/`platformFeaturesProvider` (`lib/core/platform_features.dart`); `VideoPaths`/`videoPathsProvider` (`lib/video/platform/video_paths.dart`); Datenschutz-Link im Abschnitt „Über“ der Einstellungen; `.github/workflows/ios.yml`. Kein Frame-Decoder unter iOS, Einzelbild-Schritte nutzen den 30-fps-Fallback.
- **Learnings & Stolpersteine:** `flutter create --platforms=ios` hat in `.metadata` den Android-Eintrag überschrieben (beide Einträge wiederhergestellt) und `pubspec.lock` aktualisiert (zurückgesetzt; danach `flutter pub get --enforce-lockfile`). Neue Swift-Dateien müssen in `project.pbxproj` registriert werden, deshalb liegt der Kanal-Handler in `AppDelegate.swift`. Swift lässt sich in einer Linux-Umgebung nicht kompilieren; geprüft wird auf macOS im iOS-Workflow. Lautstärketasten sind nicht nach iOS portierbar (App Review Guideline 2.5.9).
- **Wichtige Entscheidungen und ihre Gründe:** `elapsedRealtimeMicros` liest `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)` statt `systemUptime`/`mach_absolute_time`, weil diese Required-Reason-APIs sind; so braucht die App kein Privacy-Manifest. Videos werden relativ gespeichert und erst beim Lesen aufgelöst, weil sich der Container-Pfad unter iOS mit jedem App-Update ändert; alte absolute Pfade werden über den Dateinamen gefunden, deshalb keine DB-Migration. Signieren, Versionierung und TestFlight-Upload liegen in `BoundfoxStudios/cyclescope-ios`, damit die Apple-Zertifikate nie in diesem Repo liegen; dieses Repo stößt die Pipeline nach grünem `main`-Build per GitHub App an. Das App-Icon ist ein einzelnes 1024-px-PNG ohne Alphakanal (App-Store-Pflicht), erzeugt von `tool/generate_app_icon.py`.
- **Auswirkungen auf Folge-Tasks:** Neue Plattform-Funktionen brauchen eine iOS-Seite in `AppDelegate.swift` oder einen Eintrag in `PlatformFeatures` mit Silent-Implementierung und ausgeblendeter Einstellung. Neue Berechtigungen brauchen eine Zweckbeschreibung in `ios/Runner/Info.plist` und `ios/Runner/de.lproj/InfoPlist.strings` sowie einen Abgleich der Datenschutzerklärung. Neue Dateipfade im App-Speicher nie absolut in der DB ablegen.
- **Hinweise zu Tests und Befehlen:** `tests/core/platform_features_test.dart`, `tests/settings/settings_test.dart` (iOS simuliert per Override von `platformFeaturesProvider`, denn unter `flutter test` ist die Plattform Android), `tests/video/video_paths_test.dart`, `tests/video/video_files_test.dart`, `tests/video/video_study_screen_test.dart` (`videoPathsProvider` mit Temp-Documents-Ordner). iOS-Build lokal nur auf macOS: `flutter build ios --no-codesign`; XCTests per `xcodebuild test` (siehe `.github/workflows/ios.yml`) oder in Xcode.

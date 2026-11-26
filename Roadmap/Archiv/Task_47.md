# Task_47: Schlafsichere Zeitbasis und sichere Neustart-Erkennung

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_47.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Schrittzeiten stimmen auch dann, wenn das Gerät während einer Aufnahme im Standby war, und ein Geräteneustart wird immer erkannt. Heute fehlt auf Android die Schlafzeit in der gemessenen Schrittzeit, solange die App im Speicher bleibt – der schwerste Befund der Fehlerprüfung vom 2026-11-26, weil er Messwerte still verfälscht. Nebenbei wird die Testsuite auf dem Windows-Rechner des Nutzers wieder grün, damit sie als Beleg taugt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_01 bis Task_46 archiviert. Keine offenen Vorgänger.
- **Herkunft:** Fehlerprüfung vom 2026-11-26 (Befunde 1, 2, 7 und 8; siehe `Roadmap/README.md`, „[Fehlerprüfung 2026-11-26]“). Befunde 2, 7 und 8 wurden mit Tests reproduziert, Befund 1 ist aus dem Code und der Plattform-Dokumentation abgeleitet und am Gerät noch nicht nachgemessen.
- **Relevantes Vorwissen:** README „[Task_06] Wiederherstellung“ (Uhr-Offset = `elapsedRealtime`, Neustart-Regel), „[Task_04] Hardware-Tasten“, `docs/architecture.md` (Abschnitte „Time source“ und „Platform abstractions“), Erkenntnisse von Task_04, Task_06 und Task_36 (iOS-Kanal).
- **Ursache Befund 1:** `MonotonicClock` (`lib/core/clock.dart`) liest die schlafsichere Systemzeit nur einmal beim App-Start (`main.dart`, `readElapsedRealtimeMicros`) und zählt dann mit `Stopwatch` weiter. `Stopwatch` nutzt auf Android `CLOCK_MONOTONIC` und steht im Geräteschlaf still. Am USB-Kabel schläft das Gerät meist nicht, deshalb fällt es beim Entwickeln nicht auf.
- **Ursache Befund 2:** `RecordingController.load()` (`lib/recording/presentation/recording_controller.dart`, um Zeile 162) erkennt einen Neustart nur an „Uhr jetzt < gespeicherte Uhr“. Läuft das Gerät nach dem Neustart schon länger als beim Speichern, wird der offene Schritt mit einer falschen Zeit fortgesetzt. `RunState.savedAt` (Wanduhr) ist gespeichert, wird aber nicht ausgewertet.
- **Betroffener Code:** `lib/core/clock.dart`, `lib/main.dart`, `lib/core/providers.dart`, `lib/recording/platform/hardware_keys.dart`, `lib/recording/platform/recording_notifier.dart`, `lib/recording/presentation/recording_controller.dart`, `lib/recording/presentation/recording_screen.dart`, `lib/recording/data/measurement_repository.dart`, `lib/revision/data/revision_repository.dart`, `lib/video/platform/video_paths.dart`, `android/app/src/main/kotlin/dev/cyclescope/cyclescope/MainActivity.kt`.

## Umfang

**Gehört dazu:**

- **Vorarbeit, Windows-Tests (Befund 7):** `VideoPaths.resolve` liefert für gespeicherte Pfade (`videos/<datei>`) den Pfad mit den Trennzeichen der Plattform. Die beiden bisher unter Windows scheiternden Tests (`tests/video/video_paths_test.dart` „a stored path resolves into the current documents folder“ und `tests/video/video_study_screen_test.dart` „a stored video opens from the current documents folder“) werden grün, ohne dass sie geändert werden.
- **Uhr gleicht sich ab (Befund 1), entschieden: Weg über den Plattform-Kanal, kein `dart:ffi`:**
  - `MonotonicClock` bekommt einen Abgleich mit der Systemzeit der Plattform (µs seit Boot, zählt im Schlaf weiter). Danach gilt `nowMicros()` ≈ Systemzeit. Die Uhr läuft dabei nie rückwärts: ein Abgleich, der sie zurückstellen würde (Jitter), ändert nichts.
  - Die native Android-Seite schickt bei jedem Tasten-Ereignis und bei jeder Benachrichtigungs-Aktion die Systemzeit des Ereignisses mit (`SystemClock.elapsedRealtimeNanos() / 1000`; beim Tasten-Ereignis abzüglich seines Alters, das heute als `ageMicros` kommt). Die Dart-Seite gleicht die Uhr damit ab und verwendet die Ereigniszeit als Zeitstempel der Aktion.
  - Benachrichtigungs-Aktionen („Weiter“, „Stopp/Fortsetzen“) werden mit ihrer Ereigniszeit ausgeführt (`controller.next(at:)`, `controller.startStop(at:)`), nicht mehr mit „jetzt“.
  - Kehrt die App in den Vordergrund zurück (`AppLifecycleState.resumed`), gleicht sie die Uhr über `readElapsedRealtimeMicros()` ab – auf Android und iOS (der iOS-Kanal liefert den Wert bereits).
- **Neustart-Erkennung (Befund 2):** Ein gespeicherter Lauf gilt zusätzlich als durch Neustart unterbrochen, wenn die seit dem Speichern vergangene Zeit auf der monotonen Uhr und auf der Wanduhr (`RunState.savedAt` gegen `wallClock()`) um mehr als eine Toleranz auseinanderliegen. Die bisherige Regel (Uhr kleiner als gespeichert) bleibt. Video-Studien (`detectReboot: false`) bleiben unberührt.
- **Reihenfolge im Schritt-Timer (Befund 8):** Die Zeiten eines Schritt-Timers (alle in Zyklus 0) erscheinen in der Reihenfolge ihrer Aufnahme, auch wenn die Uhr zwischendurch neu begann (Neustart). Das gilt für Live-Liste, Zeiten-Tab, Export und für archivierte Revisionen. Heute sortiert `listForStudy` nach `cycle, end_us, id`, wodurch neue Zeiten nach einem Neustart vor den alten stehen.
- `docs/architecture.md` (Zeitquelle, Tastenkanal, Neustart-Regel) und `Roadmap/README.md` aktualisieren.

**Gehört nicht dazu:**

- Ein Foreground-Service oder Wakelock, der das Gerät wach hält (bewusst nicht: die Benachrichtigung mit Chronometer bleibt, siehe Task_06).
- `dart:ffi` oder eine neue Abhängigkeit (z. B. `system_clock`, `package:ffi`).
- Lautstärketasten oder Benachrichtigung unter iOS (bleiben Android-only).
- Nachträgliche Korrektur bereits gespeicherter, zu kurzer Zeiten.
- Die übrigen Befunde der Fehlerprüfung (Task_48 bis Task_50).

## Umsetzungsschritte

1. [ ] Vorarbeit: `VideoPaths.resolve` so ändern, dass die zwei Windows-Tests grün werden; volle Suite einmal laufen lassen und den Ausgangsstand notieren.
2. [ ] `MonotonicClock`: Abgleich als testbare Logik (TDD). Die Tick-Quelle muss dafür im Test ersetzbar sein; bestehende Aufrufer (`MonotonicClock()`, `MonotonicClock(offsetMicros: …)`) bleiben gültig.
3. [ ] Android nativ (`MainActivity.kt`): Systemzeit des Ereignisses bei Tasten-Ereignissen und Benachrichtigungs-Aktionen mitsenden. Bestehende Felder bleiben, damit die Dart-Seite abwärtskompatibel liest.
4. [ ] Dart-Seite: `AndroidHardwareKeys` und `AndroidRecordingNotifier` gleichen die Uhr ab und liefern die Ereigniszeit; `RecordingScreen` führt Benachrichtigungs-Aktionen mit dieser Zeit aus. Schnittstellen nur additiv erweitern, damit Fakes und bestehende Tests unverändert bleiben.
5. [ ] Abgleich bei `AppLifecycleState.resumed` an einer zentralen Stelle (nicht pro Bildschirm), hinter einem Interface mit Fake.
6. [ ] Neustart-Erkennung um den Wanduhr-Vergleich erweitern (TDD, zuerst der Test, der den Fall aus der Fehlerprüfung reproduziert).
7. [ ] Reihenfolge der Schritt-Timer-Zeiten korrigieren (TDD), inklusive Archivieren und Laden von Revisionen.
8. [ ] Doku, volle Suite, `flutter analyze`, `dart format`; manuelle Geräteprüfung in den Notizen protokollieren oder als offen vermerken.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/core/clock_test.dart`, Ergänzungen in `tests/recording/presentation/recording_controller_test.dart` (nur neue Tests), `tests/recording/platform/` für die Kanal-Seite, `tests/recording/data/measurement_repository_test.dart`.

Zu belegende Verhaltensweisen:

- Uhr: Nach einem Abgleich mit einer um 10 min größeren Systemzeit springt `nowMicros()` um diese 10 min nach vorn und läuft von dort weiter.
- Uhr: Ein Abgleich mit einer kleineren Systemzeit lässt `nowMicros()` nicht kleiner werden als den zuletzt gelieferten Wert.
- Standby-Fall Ende zu Ende mit Fakes: Schritt läuft, die Tick-Quelle bleibt 10 min stehen (Geräteschlaf), danach kommt eine Benachrichtigungs-Aktion „Weiter“ mit der Systemzeit des Ereignisses – die gespeicherte Schrittzeit enthält die 10 min.
- Dasselbe für ein Tasten-Ereignis (Lautstärke hoch) nach dem Schlaf.
- Abgleich bei Rückkehr in den Vordergrund: Nach `resumed` enthält die Anzeige des laufenden Schritts die Schlafzeit.
- Neustart: Lauf gespeichert bei Uhr = 5 min, App zwei Tage später geöffnet bei Uhr = 10 min → `interruptedByReboot` ist wahr, der Lauf ist verworfen, gespeicherte Zeiten bleiben (Fall aus der Fehlerprüfung).
- Kein Fehlalarm: App nach 10 s neu geöffnet bei gleichlaufender Uhr und Wanduhr → Lauf wird fortgesetzt. Die bestehenden Tests („a running recording continues after the app was restarted“, „a device reboot discards the unfinished step“) bleiben unverändert grün; sie nutzen eine feste Wanduhr und kleine Uhr-Sprünge.
- Pausierter Lauf: gleiche Neustart-Regel wie für einen laufenden.
- Schritt-Timer: Zeit A (Ende bei Uhr 9010 s) vor einem Neustart, Zeit B (Ende bei Uhr 60 s) danach → Reihenfolge A, B in `listForStudy`; nach „Neue Messung“ steht die archivierte Revision in derselben Reihenfolge.
- Zeitstudie, Einfach-Modus und Video-Studie liefern dieselbe Reihenfolge wie bisher (bestehende Tests).
- Windows: die zwei Pfad-Tests sind grün.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] `flutter test tests/` läuft auf dem Windows-Rechner ohne Fehlschlag (vorher: 2 Fehlschläge in `tests/video/`).
- [x] `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [x] Verhalten wie unter „Tests“ beschrieben belegt, insbesondere der Standby-Fall und der Neustart-Fall.
- [x] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [x] `flutter build apk --debug` baut (native Änderung in `MainActivity.kt`).
- [x] Keine neue Abhängigkeit in `pubspec.yaml`.
- [x] `docs/architecture.md` und `Roadmap/README.md` aktuell (Zeitquelle, Abgleich, Neustart-Regel, Hinweis auf die Windows-Tests entfernt).
- [x] Geräteprüfung **offen** (kein Gerät am Windows-Rechner angeschlossen): Aufnahme starten, Kabel ab, Bildschirm 5 min aus, über die Benachrichtigung oder in der App „Weiter“ – die Schrittzeit stimmt mit dem Chronometer der Benachrichtigung überein.

## Offene Fragen / Annahmen

- **Annahme, Toleranz der Neustart-Erkennung:** 5 Minuten als benannte Konstante. Kleiner erkennt mehr Fälle, erzeugt aber Fehlalarme, wenn der Nutzer die Geräteuhr verstellt. Weicht der Agent davon ab, begründet er das in den Notizen.
- **Akzeptierte Lücke (vom Nutzer so entschieden):** Ein Tipp auf dem Bildschirm in den ersten Millisekunden nach dem Aufwachen, bevor der Abgleich über den Kanal zurück ist, kann noch die alte Uhr sehen. Das wird in `docs/architecture.md` genannt, nicht gelöst.
- **Annahme:** Vor diesem Task gespeicherte Laufzustände (`run_state`) wurden mit einer Uhr geschrieben, die nach einem Standby nachging. Sie können beim ersten Öffnen nach dem Update fälschlich als Neustart gelten (der Lauf wird verworfen, gespeicherte Zeiten bleiben). Das ist hinnehmbar und wird nicht migriert.
- **Offen:** Verhalten von `Stopwatch` im Geräteschlaf unter iOS ist nicht geprüft. Der Abgleich bei `resumed` deckt beide Fälle ab; der iOS-Teil bleibt ungeprüft, bis auf macOS gebaut wird (wie in Task_36).
- **Offen:** Die Wahl der Sortierung für den Schritt-Timer (z. B. nach `id` innerhalb von Zyklus 0) trifft der Agent. Bedingung: „Rückgängig“ nach dem Löschen (Wiedereinfügen mit alter `id`) stellt die alte Reihenfolge wieder her.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Ausgangsstand (2026-11-26, Windows): 841 bestanden, 2 Fehlschläge (`tests/video/`, Pfadtrenner). Ende: 867 bestanden, 0 Fehlschläge.
- Toleranz der Neustart-Erkennung wie angenommen 5 min (`RecordingController.rebootTolerance`).
- Sortierung Schritt-Timer: Zyklus 0 nach `id` (`measurementOrder`), andere Zyklen weiter nach `end_us`. „Rückgängig“ setzt die alte `id` wieder ein → alte Stelle (Test).
- `flutter build apk --debug` scheiterte zuerst am ReadOnly-Attribut von `lib/l10n` (dem Ordner selbst) und Dateien in `build/`; `attrib -r` auf Ordner **und** Inhalt behebt es (bekannt aus README).
- **Geräteprüfung offen:** Aufnahme starten, Kabel ab, Bildschirm 5 min aus, über die Benachrichtigung oder in der App „Weiter“ – Schrittzeit muss zum Chronometer der Benachrichtigung passen. Ebenso iOS (Abgleich bei `resumed`) ungeprüft.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `VideoPaths.resolve` mit `p.joinAll` (Windows-Tests grün). `MonotonicClock` = `SyncableClock` mit injizierbarer Tick-Quelle (`ticks:`), `syncTo` nie rückwärts, `nowMicros` monoton; `syncClockTo(clock, µs)` ignoriert nicht abgleichbare Uhren. `MainActivity.kt` sendet `realtimeMicros` bei Tasten (neben `ageMicros`) und Benachrichtigungs-Aktionen (jetzt Map `{action, realtimeMicros}`; Dart liest auch noch den reinen String). `AndroidRecordingNotifier(clock)` implementiert zusätzlich `TimedNotificationActions`; `notificationActionsOf()` liefert `NotificationAction(name, atMicros)`, `RecordingScreen` ruft `next(at:)`/`startStop(at:)`. Abgleich bei Rückkehr in den Vordergrund: `ClockResumeSync` (in `CycleScopeApp`) mit `platformTimeProvider` (`PlatformTime`, `ChannelPlatformTime`, `lib/core/platform_time.dart`; `readElapsedRealtimeMicros` ist dorthin umgezogen und wird aus `recording_notifier.dart` re-exportiert). Neustart: zusätzlich Wanduhr-Vergleich. Schritt-Timer-Reihenfolge: `measurementOrder` + `groupCycles` lässt Zyklus 0 unsortiert. Abweichung: Schnittstellen nur additiv (eigenes Interface statt neuem Member), damit `FakeRecordingNotifier`/`FakeClock` unverändert bleiben.
- **Learnings & Stolpersteine:** `MockStreamHandler.inline(onListen: (_, sink) => x = sink)` bricht mit „Invalid argument: MockStreamHandlerEventSink“ – der Rückgabewert wird kodiert; Block-Body nehmen. `fakePlatformOverrides()` und eigene Overrides desselben Providers dürfen nicht zusammen in einem `ProviderScope` stehen.
- **Wichtige Entscheidungen und ihre Gründe:** Abgleich im Dart-Code der Android-Klassen (nicht im Bildschirm), damit jede Stelle, die Tasten/Aktionen liest, automatisch abgleicht. Tasten-Zeit = `realtimeMicros − ageMicros` direkt aus der Plattform (exakt, unabhängig von der Kanal-Latenz).
- **Auswirkungen auf Folge-Tasks:** Task_49 (Benachrichtigung ausblenden) kann `recordingNotifierProvider.hide()` wie bisher nutzen. Neue Tests, die einen Laufzustand über lange Zeit wiederherstellen, müssen Wanduhr und `FakeClock` gemeinsam bewegen, sonst gilt es als Neustart. Task_50: Versionshinweis kann „Schrittzeiten nach Standby korrekt“, „Neustart sicher erkannt“, „Schritt-Timer-Reihenfolge nach Neustart“ nennen; Geräteprüfung steht aus.
- **Hinweise zu Tests und Befehlen:** Neue Tests: `tests/core/clock_test.dart`, `tests/recording/platform/android_channels_test.dart` (echte Android-Klassen über gemockte Kanäle), `tests/recording/presentation/sleep_sync_test.dart` (Standby Ende zu Ende), `tests/recording/presentation/reboot_detection_test.dart`, `tests/recording/data/step_timer_order_test.dart`; Fakes `tests/fakes/fake_platform_time.dart` (`FakeTicks`, `FakePlatformTime`). Unter Windows vor `flutter build apk` ggf. `attrib -r` auf `lib\l10n` und `build\` (Ordner selbst und `\* /s /d`).

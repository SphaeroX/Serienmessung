# Serienmessung (Zeitstudien-App) – Roadmap

Projektübergreifendes Gedächtnis. Agenten lesen diese Datei vor jedem Task und aktualisieren sie, wenn sich etwas ergibt, das über einen einzelnen Task hinausgeht. Regeln für die Arbeit: [AGENTS.md](AGENTS.md).

## Projektziel

Neuentwicklung einer bestehenden Android-App "Zeitstudie Stoppuhr" als bessere Flutter-App für Zeitaufnahmen nach REFA/MTM. Schwerpunkt ist eine einfache, fehlerarme Zeiterfassung im Feld (Bedienung blind über die Lautstärketasten) und eine saubere Auswertung, aus der die reale Taktzeit hervorgeht.

**Was die Software tut:** Man legt eine Studie an und gibt die Arbeitsschritte in eine Textarea ein (eine Zeile = ein Schritt, auch per Spracheingabe mit Push-to-talk). Beim Start ist Schritt 1 sofort aktiv; jeder Druck auf "Weiter" (oder Lautstärke hoch) schließt den aktuellen Schritt ab und startet den nächsten, nach dem letzten Schritt beginnt der nächste Zyklus. Der aktuelle Schritt ist während der Messung immer groß eingeblendet. Lautstärke hoch gedrückt halten erfasst eine Sonderzeit (unvorhergesehene Störung), die nicht in die Taktzeit zählt. Lautstärke runter = Start/Stopp. Alternativ wird ein Video importiert und die Schritte werden bei der Wiedergabe markiert (flüssige Zeitleiste, Tempo, Einzelbild). Nach der Aufnahme lassen sich Zyklen und einzelne Schritt-Messungen löschen und die Schrittdefinition umbenennen/umsortieren. Die Auswertung zeigt pro Schritt und Zyklus Summe, Mittelwert, Median, Min/Max/Streuung sowie die reale Taktzeit nach wählbarer Methode (Mittelwert / Median / IQR-bereinigt). Export als CSV, Excel und PDF; lokale Datenhaltung mit Backup-Datei. Modi: Zeitstudie (feste Abfolge), Video-Studie, Einfach (Stoppuhr + Runden), Schritt-Timer (freie Reihenfolge).

**Zielgruppe:** Arbeitsvorbereiter, Industrial Engineers, REFA-/MTM-Anwender, die in der Produktion Zeitaufnahmen machen, meist mit einem Android-Smartphone in der Hand.

**Nicht-Ziele:** Vorgabezeit/Sollzeit (Leistungsgrad, Zuschläge) – kommt frühestens später. Cloud-Sync und Benutzerkonten. iOS-Build (Code bleibt iOS-fähig, iOS-Spezialfälle wie Hardware-Tasten werden nicht umgesetzt). "Feedback senden" / "App bewerten" der alten App.

## Aktueller Status

Stand: 2026-11-11 – Task_12 erledigt.

| Task | Titel | Status |
|---|---|---|
| 01 | Durchstich: Studie anlegen & Liste | erledigt |
| 02 | Mess-Engine Zeitstudie | erledigt |
| 03 | Live-Messbildschirm mit Schritt-Overlay | erledigt |
| 04 | Hardware-Tasten (Android) | erledigt |
| 05 | Sonderzeit | erledigt |
| 06 | Hintergrundbetrieb & Wiederherstellung | erledigt |
| 07 | Zyklen ansehen & löschen | erledigt |
| 08 | Schrittdefinition nachträglich bearbeiten | erledigt |
| 09 | Auswertung & reale Taktzeit | erledigt |
| 10 | Einstellungen | erledigt |
| 11 | Spracheingabe Push-to-talk | erledigt |
| 12 | Video-Studie: Import & Markieren | erledigt |
| 13 | Video-Zeitleiste flüssig & Marker ziehen | offen |
| 14 | Modus "Einfach" | offen |
| 15 | Modus "Schritt-Timer" | offen |
| 16 | Export CSV + Excel | offen |
| 17 | Export PDF-Bericht | offen |
| 18 | Backup & Wiederherstellen | offen |

Status ist `offen`, `läuft` (Datei trägt das Präfix `RUN_`) oder `erledigt` (Datei liegt in `Archiv/`). Die Tabelle wird beim Archivieren eines Tasks aktualisiert.

## Taskübergreifende Entwicklungsinfos

Globale Informationen, Architekturentscheidungen und Wissen, das für das gesamte Projekt gilt. Wird laufend ergänzt; jeden Eintrag mit dem Task kennzeichnen, aus dem er stammt.

Im Interview festgelegt (vor Task_01):

- **Stack:** Flutter (Dart), Zielplattform zuerst Android; Code soll iOS-fähig bleiben (plattformspezifisches hinter Interfaces kapseln).
- **Sprachen:** Englisch-first: Englisch ist ARB-Template und Fallback, Deutsch die Übersetzung (Flutter `gen-l10n`). Keine hartkodierten UI-Texte. Code, Bezeichner, Dateinamen, Commits auf Englisch.
- **Projekt-Setup (vor Task_01, via project-init):** App-Arbeitstitel "CycleScope", Dart-Paket `cyclescope`, Android-ID `dev.cyclescope.cyclescope`. Git-Repo (`main`), `flutter create` (nur Android) ist erledigt, Beispieltest entfernt; `lib/main.dart` ist noch die Flutter-Demo und wird in Task_01 ersetzt. State-Management: Riverpod. Linter: `flutter_lints`. Details in Root-`AGENTS.md` und `docs/`.
- **Datenhaltung:** nur lokal auf dem Gerät (SQLite), kein Cloud-Sync. Backup über Export/Import einer Datei (Task_18).
- **Tests:** liegen verbindlich in `tests/` (nicht im Flutter-Standardordner `test/`), Ausführung mit `flutter test tests/`.
- **Zeitmessung:** Grundlage ist eine monotone Uhr (z. B. `Stopwatch` / `SystemClock.elapsedRealtime`), nicht die Wanduhr, damit Zeitumstellungen und Uhr-Korrekturen die Messung nicht verfälschen. Die Uhr wird für Tests injizierbar gekapselt.
- **Fachlogik getrennt von UI:** Mess-Engine, Statistik und Export-Aufbereitung sind reine Dart-Logik und vollständig unit-testbar; Hardware (Tasten, Mikrofon, Video, Hintergrunddienst) liegt hinter Interfaces mit Fakes für Tests.
- **Zeiteinheiten:** HM (1/100 min, Standard), Sekunden, mm:ss.SSS, TMU (1 TMU = 0,036 s). Intern werden Zeiten in einer Einheit (z. B. Mikro- oder Millisekunden) gespeichert, Umrechnung nur bei der Anzeige.
- **Tastenbelegung (Messung):** Lautstärke hoch kurz = nächster Schritt; Lautstärke hoch gehalten = Sonderzeit läuft, solange gehalten; Lautstärke runter = Start/Stopp.
- **Reale Taktzeit:** Methode einstellbar: Mittelwert, Median, IQR-bereinigt (Ausreißer über Q3 + 1,5 × IQR verworfen). Sonderzeiten sind immer herausgerechnet.

- **[Task_01] Datenbank:** sqflite mit handgeschriebenem SQL statt drift (keine Codegenerierung). Migrationen: append-only-Liste in `lib/core/database.dart`. Tests nutzen `sqflite_common_ffi` in-memory über `openTestDatabase()`.
- **[Task_01] Navigation:** `StudyListScreen` bekommt Callbacks (`onOpenStudy`, `onOpenSettings`) aus `app.dart`, damit spätere Bildschirme ohne Zirkelimporte angebunden werden.
- **[Task_01] l10n:** generierte Dateien liegen versioniert in `lib/l10n/`; nach ARB-Änderungen `flutter gen-l10n` ausführen.
- **[Task_02] Mess-Semantik:** `RecordingEngine` (reines Dart) mit Zuständen idle/running/paused/special. Start/Stopp = Pause/Fortsetzen; der offene Schritt läuft nach dem Fortsetzen weiter, Pausenzeit zählt nicht. "Zurücksetzen/Beenden" (`discard`) verwirft den unvollendeten Schritt (nur abgeschlossene Schritte sind gültige Zeiten). Ein neuer Lauf beginnt bei `MAX(cycle)+1` mit Schritt 1. Einfach-Modus = `sequence: [null]` (jede Runde ein Zyklus), Schritt-Timer = `freeOrder: true`, Zyklus 0.
- **[Task_02] Zeiten:** Messungen speichern `start_us`/`end_us` in der Zeitbasis der Quelle (monotone Uhr bzw. Videoposition) und `duration_us` explizit (Pausen/Sonderzeiten herausgerechnet). Alle Engine-Aktionen akzeptieren einen Zeitstempel `at` (für Tastendrücke). `EngineSnapshot` (toJson/fromJson) ist für die Persistenz in Task_06 vorbereitet.
- **[Task_03] Bildschirm-Controller:** Pro Bildschirm ein `ChangeNotifier`-Controller (z. B. `RecordingController`), der seine Abhängigkeiten einmalig aus Providern liest (`clockProvider`, `deviceFeedbackProvider`, Repositories). Riverpod dient nur als DI/Override-Mechanismus. `ref` darf nicht in `dispose()` benutzt werden – Listen-Invalidierung passiert nach `Navigator.push` in `openStudy` (`lib/app.dart`).
- **[Task_03] Zeitformat:** `formatTime(micros, TimeUnit, decimals:, locale:)` in `lib/core/time_format.dart` kann bereits HM, s, mm:ss.SSS und TMU (Task_09 muss das nicht mehr bauen). Live-Anzeige: Stoppuhr groß + HM.
- **[Task_03] Plattform:** Haptik und Wakelock hinter `DeviceFeedback` (`lib/core/platform.dart`); Tests nutzen `fakePlatformOverrides()` aus `tests/fakes/fake_platform.dart`.

- **[Task_04] Hardware-Tasten:** eigener Platform Channel in `MainActivity.kt` (`dev.cyclescope/platform` Methoden, `dev.cyclescope/keys` Events). `KeyInterpreter` (reines Dart) setzt kurz/lang um. Erfassung nur auf dem Messbildschirm.
- **[Task_05] Sonderzeit:** Taste halten (rückwirkend ab Key-Down) oder Bildschirm-Button "HALTEN SONDERZEIT". Eigene Zeile `kind = 'special'` mit `cycle`/`step_id` des unterbrochenen Schritts und optionaler Notiz.
- **[Task_06] Wiederherstellung:** `run_state`-Tabelle (Migration v3) hält den Engine-Snapshot jeder laufenden Studie; Uhr-Offset = Android `elapsedRealtime`. Gerätereboot (Uhr kleiner als gespeichert) → Laufzustand verwerfen. Hintergrund: dauerhafte Benachrichtigung mit Chronometer und Aktionen statt Foreground-Service.
- **[Task_07] Zyklen:** `groupCycles()` in `lib/recording/domain/cycles.dart` ist die gemeinsame Grundlage für Zyklen-Ansicht und Auswertung (vollständig = jeder aktuelle Schritt hat eine normale Zeit). Löschen hart + Rückgängig per Wiedereinfügen; Zyklusnummern bleiben stabil.
- **[Task_08] Schritte bearbeiten:** nur im Ruhezustand (Stift-Symbol im Messbildschirm). Schritt löschen entfernt auch dessen Zeiten (mit Warnung). Nach dem Bearbeiten `RecordingController.load()`.
- **[Task_09] Auswertung:** `StudyAnalysis.compute()` (reines Dart) ist die einzige Quelle für Kennzahlen – Export und PDF verwenden sie mit. Quartile wie Excel `QUARTILE.INC`, Standardabweichung n−1, IQR-Filter erst ab 4 Werten. Methode pro Studie in `study.cycle_time_method` (Migration v4), Standard Median.
- **[Task_10] Einstellungen:** in SQLite-Tabelle `settings` (Migration v5), geladen in `main()` → `initialSettingsProvider`, live über `settingsProvider`. Kein shared_preferences mehr. Tests setzen Einstellungen per `initialSettingsProvider.overrideWithValue`.
- **[Task_11] Diktat:** `DictationButton` + `speechInputProvider` (speech_to_text); eine Aufnahme = eine Zeile/ein Schritt.
- **[Task_12] Video:** Zeitbasis = Videoposition (`VideoClock`), Video wird nach `Documents/videos/` kopiert, `study.video_path` (Migration v6). Player/Picker hinter `VideoPlayback`/`VideoPicker`. Gleicher `RecordingController` wie live, mit `detectReboot: false`.

## Auffälligkeiten & Details

Dinge, die global noch zu beachten sind: Besonderheiten, bekannte Einschränkungen, kleinere Details. Wird laufend ergänzt.

- Fachbegriffe im Code (siehe `docs/conventions.md`): Studie = `Study`, Schritt = `StepDefinition`, Zyklus = `Cycle`, Messung = `Measurement`, Sonderzeit = `SpecialTime`, Taktzeit = `CycleTime`.
- Mindest-Android-Version: API 26 gesetzt (Annahme, vom Nutzer nicht bestätigt).
- **Sandbox-Hinweis (nur für die KI-Umgebung, in der die Tasks bisher liefen):** `flutter gen-l10n`/Build-Zeit-Generierung hatte dort keine Schreibrechte auf `lib/l10n`; die Agenten generierten in einem Temp-Ordner und kopierten. Auf normalen Rechnern funktioniert `flutter gen-l10n` direkt.
- Lautstärketasten funktionieren nur bei eingeschaltetem Bildschirm mit geöffnetem Messbildschirm (Task_06).
- Hardware-nahe Funktionen (Lautstärketasten, Mikrofon, Video, Hintergrunddienst) lassen sich nur teilweise automatisiert testen. Logik mit Fakes testen, zusätzlich eine kurze manuelle Geräteprüfung in den Task-Notizen protokollieren.

# Task_10: Einstellungen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_10.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Ein Einstellungsbildschirm bündelt alle globalen Optionen, und die App beachtet sie überall: Design, Standard-Zeiteinheit, Standard-Methode für die reale Taktzeit, Vibration, Hardware-Tasten, Bildschirm aktiv halten, Benachrichtigungen, Sprache.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_09 archiviert.
- **Relevantes Vorwissen:** Vorbild alte App: Einstellungen mit Gruppen "Erscheinungsbild" (Design: System/Hell/Dunkel) und "Allgemein" (Benachrichtigungen, Standard-Zeiteinheit, Vibration, Hardware-Tasten Lautstärke +/-, Bildschirm aktiv halten). Bisher sind diese Werte fest verdrahtet (Task_03–06, 09).

## Umfang

**Gehört dazu:**

- Persistente Einstellungen (z. B. shared_preferences oder DB) mit Standardwerten.
- Design: System / Hell / Dunkel.
- Standard-Zeiteinheit: HM / s / mm:ss.SSS / TMU.
- Standard-Methode reale Taktzeit: Mittelwert / Median / IQR.
- Schalter: Vibration, Hardware-Tasten, Bildschirm aktiv halten, Benachrichtigungen.
- Schwelle für "Taste halten" (Sonderzeit) einstellbar (sinnvoller Bereich, z. B. 250–1000 ms).
- Sprache: System / Deutsch / Englisch.
- Info: App-Version.

**Gehört nicht dazu:**

- Feedback senden / App bewerten (Nicht-Ziel).
- Backup (Task_18).

## Umsetzungsschritte

1. [x] Einstellungs-Service mit Standardwerten und Änderungs-Stream umsetzen.
2. [x] Einstellungsbildschirm umsetzen (Zahnrad auf der Startseite).
3. [x] Alle bisher fest verdrahteten Stellen auf die Einstellungen umstellen.
4. [x] Neue Studien übernehmen die Standard-Methode, bestehende behalten ihre eigene.
5. [x] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Standardwerte bei Erststart.
- Geänderte Einstellung überlebt Neustart (Service-Test).
- Hardware-Tasten aus → Interpreter löst keine Aktionen aus.
- Einheitenwechsel ändert die Anzeige im Messbildschirm (Widget-Test).

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Jede Einstellung hat nachweisbar eine Wirkung (Test oder dokumentierte manuelle Prüfung je Einstellung).

## Offene Fragen / Annahmen

- Keine.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `AppSettings` (Design, Sprache, Standardeinheit, Standardmethode, Vibration, Hardware-Tasten, Haltedauer 250–1000 ms, Bildschirm aktiv halten, Benachrichtigungen), `SettingsRepository`, `settingsProvider` (Riverpod `Notifier`, speichert sofort), `SettingsScreen` (Zahnrad auf der Startseite). Wirkung: `MaterialApp.themeMode/locale`, `deviceFeedbackProvider` (Vibration/Wakelock), `recordingNotifierProvider` (`SilentRecordingNotifier` wenn aus), Messbildschirm (Tasten-Erfassung an/aus, Haltedauer, Anzeigeeinheit für Kacheln/Live-Liste/Zyklen), Auswertung (Starteinheit), neue Studien übernehmen die Standardmethode. Abweichung: Speicherung in der SQLite-Tabelle `settings` (Migration v5) statt shared_preferences – eine Datenquelle weniger, in Tests ohne Plattform-Mock nutzbar; `shared_preferences` wurde entfernt.
- **Learnings & Stolpersteine:** `flutter pub add/remove` löst in der Sandbox die l10n-Generierung aus und scheitert – Hilfsskript blendet `l10n.yaml` dafür kurz aus (nur KI-Umgebung). Dart 3.8+ erlaubt null-aware Map-Einträge (`'key': ?value`).
- **Wichtige Entscheidungen und ihre Gründe:** Einstellungen werden beim Start in `main()` geladen und über `initialSettingsProvider` injiziert (kein asynchroner Ladezustand in der UI). Bestehende Studien ohne eigene Methode nutzen die aktuelle Standardmethode; neue Studien speichern sie fest. App-Version als Konstante (`appVersion`) statt package_info_plus.
- **Auswirkungen auf Folge-Tasks:** Task_11: Spracherkennung nutzt die App-Sprache (`Localizations.localeOf`). Task_12: Video-Bildschirm muss `settings.hardwareKeys`/`holdThresholdMs` genauso beachten. Task_18: Backup-/Wiederherstellen-Einträge direkt im `SettingsScreen` ergänzen; Einstellungen selbst nicht mitsichern (Entscheidung dort treffen).
- **Hinweise zu Tests und Befehlen:** `tests/settings/settings_test.dart` (Standardwerte, Neustart, ungültige Werte, Schalter/Auswahl speichern, Standardmethode, Sprache/Design, Provider-Wirkung) sowie zwei neue Fälle in `recording_screen_test.dart` (Tasten aus, Anzeigeeinheit). Widget-Tests können Einstellungen über `initialSettingsProvider.overrideWithValue(...)` setzen.

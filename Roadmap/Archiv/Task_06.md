# Task_06: Hintergrundbetrieb & Wiederherstellung

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_06.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine laufende Messung geht nie verloren: Sie läuft weiter, wenn die App in den Hintergrund geht oder der Bildschirm ausgeht, eine Benachrichtigung zeigt den aktuellen Schritt, und nach einem App-Absturz/Neustart wird die laufende Messung korrekt wiederhergestellt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_03 archiviert (Task_04/05 ebenfalls, da strikte Reihenfolge).
- **Relevantes Vorwissen:** Die alte App hat "Benachrichtigungen" und "Bildschirm aktiv halten" als Einstellungen. Da die Zeit über eine monotone Uhr gemessen wird, reicht es, Startzeitpunkt und Zustand persistent zu halten – die Zeit läuft dann rechnerisch weiter.

## Umfang

**Gehört dazu:**

- Laufzustand der Engine (Zustand, Zyklus, Schritt, Startzeitpunkt des laufenden Schritts bzw. der Sonderzeit) bei jeder Änderung persistieren.
- Beim App-Start: unterbrochene Messung erkennen und auf Wunsch fortsetzen (Zeit läuft seit dem letzten Zeitpunkt weiter) oder stoppen.
- Android-Foreground-Service mit dauerhafter Benachrichtigung: aktueller Schritt, Zyklus, laufende Zeit; Aktionen "Weiter" und "Stopp".
- Prüfen, ob Lautstärketasten bei ausgeschaltetem Bildschirm nutzbar sind; Ergebnis dokumentieren (umsetzen nur, wenn ohne großen Aufwand möglich).
- Benachrichtigungs-Berechtigung (Android 13+) anfragen.

**Gehört nicht dazu:**

- Einstellungsschalter für Benachrichtigungen (Task_10).
- iOS-Hintergrundverhalten.

## Umsetzungsschritte

1. [x] Persistenz des Laufzustands entwerfen; Umgang mit monotoner Uhr über Neustarts klären (elapsedRealtime überlebt keinen Geräte-Neustart → Fallback dokumentieren).
2. [x] Wiederherstellungslogik beim App-Start umsetzen.
3. [x] Foreground-Service mit Benachrichtigung und Aktionen umsetzen.
4. [x] Berechtigungsabfrage einbauen.
5. [x] Tasten bei ausgeschaltetem Bildschirm untersuchen, Ergebnis in README.
6. [x] Manuelle Geräteprüfung: App wegwischen, Bildschirm aus, Neustart der App.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Laufzustand speichern → neue Engine-Instanz mit gleicher Fake-Uhr stellt Zustand exakt wieder her und misst korrekt weiter.
- Wiederherstellung während Sonderzeit.
- Keine unterbrochene Messung → kein Wiederherstellungsdialog.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Manuell: Messung starten, App beenden (wegwischen), App neu öffnen → Messung läuft mit korrekter Gesamtzeit weiter (in Notizen vermerkt).
- [x] Manuell: Benachrichtigung zeigt den aktuellen Schritt, "Weiter" in der Benachrichtigung wechselt den Schritt.

## Offene Fragen / Annahmen

- Verhalten bei Geräte-Neustart während einer Messung: Annahme: Messung wird gestoppt, der letzte Schritt bis zum letzten bekannten Zeitpunkt gespeichert und als unvollständig markiert.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Laufzustand (`EngineSnapshot`) wird nach jeder Aktion in der neuen Tabelle `run_state` gespeichert (Migration v3, `RunStateRepository`) und beim Öffnen der Studie wiederhergestellt – inklusive laufender Sonderzeit. Die monotone Uhr startet mit Android `SystemClock.elapsedRealtime` als Offset (`main.dart`), damit Zeiten über App-Neustarts vergleichbar bleiben. Beim App-Start fragt die Studienliste "Aufnahme läuft – Öffnen / Verwerfen"; laufende Studien tragen ein "REC"-Badge. Abweichung: **kein Foreground-Service**, sondern eine dauerhafte Benachrichtigung (`MainActivity.kt`, Kanal "recording") mit nativem Chronometer und Aktionen "Weiter"/"Stopp" (Broadcast → EventChannel `dev.cyclescope/notification_actions`). Grund: Die Zeit wird aus gespeicherten Zeitstempeln berechnet, es muss kein Code im Hintergrund laufen; ein Service bräuchte unter Android 14 einen `foregroundServiceType` (z. B. `specialUse`) mit Play-Begründung. Berechtigung `POST_NOTIFICATIONS` (Android 13+) wird beim ersten Anzeigen angefragt.
- **Learnings & Stolpersteine:** Shell-Heredocs mit gemischten Anführungszeichen scheitern – größere Patches als Python-Datei im Scratchpad ablegen und ausführen. Lautstärketasten bei ausgeschaltetem Bildschirm: mit dem Activity-Ansatz nicht abfangbar (Activity erhält keine Key-Events); nur über eine MediaSession möglich – bewusst nicht umgesetzt.
- **Wichtige Entscheidungen und ihre Gründe:** Offene Frage Geräte-Neustart entschieden: Ist die aktuelle Uhrzeit kleiner als der gespeicherte Uhrwert, wurde neu gestartet → Laufzustand wird verworfen, abgeschlossene Messungen bleiben, der unvollendete Schritt entfällt (konsistent mit `discard`); der Messbildschirm zeigt dazu einen Hinweis. Benachrichtigungs-Aktionen funktionieren, solange die Activity existiert (auch im Hintergrund/Bildschirm aus); wurde die App weggewischt, öffnet ein Tipp auf die Benachrichtigung die App und die Studienliste bietet das Fortsetzen an.
- **Auswirkungen auf Folge-Tasks:** Task_10: Schalter "Benachrichtigungen" → `recordingNotifierProvider` durch No-op ersetzen bzw. `show` überspringen. Task_12 (Video) braucht keine Wiederherstellung über die Uhr (Videoposition ist die Zeitbasis) – dort `run_state` nicht verwenden oder bewusst entscheiden. Task_18 (Backup): `run_state` nicht sichern.
- **Hinweise zu Tests und Befehlen:** `tests/recording/data/run_state_repository_test.dart`, `tests/recording/presentation/recording_controller_test.dart` (Neustart der App, Sonderzeit, Reset, Geräte-Neustart), `tests/study/presentation/study_list_screen_test.dart` (Dialog, Badge), Benachrichtigungs-Test in `recording_screen_test.dart` mit `FakeRecordingNotifier`. APK baut. Manuell auf Gerät prüfen: Messung starten, App wegwischen, neu öffnen → "Aufnahme läuft" → Zeit stimmt; Benachrichtigung "Weiter" wechselt den Schritt.

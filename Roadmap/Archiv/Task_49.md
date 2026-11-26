# Task_49: Import, Wiederherstellen und Löschen: Validierung, Gruppenliste und Benachrichtigung

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_49.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine fehlerhafte Import-Datei kann die App nicht mehr unbrauchbar machen und wird immer mit einer Meldung abgelehnt. Nach dem Wiederherstellen stimmt die Gruppenliste, und wer eine Studie mit laufender Aufnahme löscht, behält keine hängende Benachrichtigung zurück.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_47 und Task_48 archiviert. Deren "Erkenntnisse für Folge-Agenten" lesen.
- **Herkunft:** Fehlerprüfung vom 2026-11-26 (Befunde 5, 6 und 10; siehe `Roadmap/README.md`, „[Fehlerprüfung 2026-11-26]“). Befund 6 wurde mit Tests reproduziert, 5 und 10 sind aus dem Code abgeleitet.
- **Relevantes Vorwissen:** README „[Task_18] Backup“, „[Task_23] Backup v2“, „[Task_06] Wiederherstellung“ (Benachrichtigung statt Foreground-Service), „Außerhalb der Roadmap (2026-11-17)“ (Teilen und „Öffnen mit CycleScope“); `docs/architecture.md` Abschnitte „Backup“, „Sharing and importing“ und „Open with CycleScope“. Erkenntnisse von Task_18, Task_23 und Task_39.
- **Ursachen:**
  - Befund 6: `BackupService._parse` (`lib/backup/data/backup_service.dart`) prüft nicht alle Felder. `lastActiveAt` (Studie) sowie `firstRecordedAt`/`lastRecordedAt` (Revision) gehen ungeprüft in INTEGER-Spalten; ein Text darin lässt `StudyRepository.studyFromRow` bzw. `RevisionRepository._load` bei jedem Lesen scheitern – die Studienliste lädt dann dauerhaft nicht mehr. Andere falsche Typen (z. B. `groupPosition` als Text, `notes` als Zahl, `revision` als Text) werfen mitten im Import einen `TypeError`; die Transaktion wird zurückgerollt, aber `importSharedJson` und `BackupTiles._restore` fangen nur `BackupException` – der Nutzer sieht nichts.
  - Befund 10: `BackupTiles._restore` (`lib/backup/presentation/backup_tiles.dart`, um Zeile 99) invalidiert nur `studyListProvider`. `groupListProvider` ist ein gecachter `FutureProvider`; die Gruppenliste zeigt nach „Ersetzen“ gelöschte Gruppen und nach „Zusammenführen“ fehlen neue.
  - Befund 5: Beim Löschen einer Studie aus der Studienliste (`_confirmDelete` in `lib/study/presentation/study_list_screen.dart`, `deleteStudies` in `lib/backup/presentation/share_actions.dart`) und beim Wiederherstellen mit „Ersetzen“ wird `run_state` entfernt, die laufende Benachrichtigung aber nicht. Sie ist „ongoing“ und lässt sich nicht wegwischen. `deleteGroupInteractively` (`lib/group/presentation/group_dialogs.dart`) macht es bereits richtig.
- **Betroffener Code:** `lib/backup/data/backup_service.dart`, `lib/backup/presentation/backup_tiles.dart`, `lib/backup/presentation/share_actions.dart`, `lib/study/presentation/study_list_screen.dart`.

## Umfang

**Gehört dazu:**

- **Validierung vor dem Schreiben (Befund 6):** `_parse` prüft jeden Wert, der beim Import gelesen wird, auf seinen Typ – insbesondere `lastActiveAt`, `groupPosition`, `revision`, `notes`, `description`, `cycleTimeMethod`, `videoPath`, die Puffer- und Bandfelder der Studie, `stepRef` und `note` der Zeiten sowie `firstRecordedAt`, `lastRecordedAt`, `cycleTimeMethod` und `notes` der Revisionen. Fehlende optionale Felder bleiben erlaubt (v1-Dateien und ältere v2-Dateien importieren weiter). Eine ungültige Datei wirft `BackupException(BackupError.invalid)` und ändert nichts.
- **Keine stillen Abbrüche:** Scheitert der Import trotzdem (unerwarteter Fehler in der Transaktion), sieht der Nutzer die Meldung „Datei ungültig“ statt nichts. Das gilt für Import-Knopf, „Öffnen mit CycleScope“ und „Backup wiederherstellen“.
- **Gruppenliste (Befund 10):** Nach „Backup wiederherstellen“ (Ersetzen und Zusammenführen) wird auch `groupListProvider` invalidiert.
- **Benachrichtigung (Befund 5):** Wird eine Studie gelöscht, die gerade eine laufende Aufnahme hat (einzeln, per Mehrfachauswahl), oder werden beim Wiederherstellen mit „Ersetzen“ Laufzustände entfernt, verschwindet die Benachrichtigung (`recordingNotifierProvider.hide()`).
- `docs/architecture.md` (Abschnitt Backup: was validiert wird) und `Roadmap/README.md`.

**Gehört nicht dazu:**

- Neue Format-Version oder neue Felder im Backup.
- Reparatur einer Datenbank, in die bereits ein fehlerhafter Wert importiert wurde.
- Aufräumen von Videodateien nach „Ersetzen“ (verwaiste Kopien bleiben wie bisher liegen).
- Die Schaltflächen der Benachrichtigung, wenn der Messbildschirm geschlossen ist (sie bleiben ohne Wirkung, bis die Studie wieder geöffnet wird).
- Die Befunde zu Zeitbasis, Video und Simulation (Task_47, Task_48, Task_50).

## Umsetzungsschritte

1. [ ] Validierung erweitern (TDD, zuerst die zwei Tests aus der Fehlerprüfung: `lastActiveAt` als Text, `groupPosition` als Text). Für jedes geprüfte Feld mindestens ein Fall „falscher Typ wird abgelehnt“ und die Prüfung, dass die Datenbank danach unverändert ist.
2. [ ] Sicherstellen, dass gültige Dateien weiter importieren: v1-Datei, v2-Datei ohne die optionalen Felder, Datei mit Bereichen (bestehende Tests bleiben grün).
3. [ ] Fehlerbehandlung in `importSharedJson` und `BackupTiles._restore`: jeder Fehler führt zur Meldung.
4. [ ] `groupListProvider` nach dem Wiederherstellen invalidieren (Widget-Test).
5. [ ] Benachrichtigung beim Löschen einer laufenden Studie und beim Ersetzen entfernen (Widget-Tests mit `FakeRecordingNotifier`).
6. [ ] Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/backup/backup_validation_test.dart`, Ergänzungen in `tests/backup/backup_tiles_test.dart` und `tests/study/presentation/study_list_screen_test.dart` (nur neue Tests).

Zu belegende Verhaltensweisen:

- Import einer Datei mit `lastActiveAt: "yesterday"` → `BackupException(invalid)`, keine Studie angelegt, `listStudies()` funktioniert weiter.
- Import einer Datei mit `groupPosition: "3"` bei gesetztem `groupRef` → `BackupException(invalid)` statt `TypeError`, keine Gruppe und keine Studie angelegt.
- Revision mit `lastRecordedAt` als Text → abgelehnt.
- Je ein Fall mit falschem Typ für die übrigen geprüften Felder (Tabelle von Fällen in einem Test genügt).
- Eine Datei ohne die optionalen Felder (Stand v1 und früher v2-Stand) importiert vollständig.
- Export und Wiederimport einer vollen Datenbank (Demo-Daten) liefert dieselben Studien, Gruppen, Revisionen und Sonderzyklen – die Validierung lehnt nichts ab, was der eigene Export schreibt.
- Oberfläche: Import einer ungültigen Datei über den Import-Knopf zeigt die Meldung „ungültig“; ein unerwarteter Fehler ebenso.
- Wiederherstellen (Ersetzen): Gruppenliste vorher geöffnet, danach Backup mit anderen Gruppen eingespielt → die Gruppenliste zeigt die Gruppen des Backups.
- Löschen einer Studie mit Laufzustand aus der Studienliste (einzeln und per Mehrfachauswahl) → `FakeRecordingNotifier` wurde ausgeblendet; ohne Laufzustand wird nichts ausgeblendet.
- Wiederherstellen mit „Ersetzen“ bei vorhandenem Laufzustand → Benachrichtigung ausgeblendet.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [x] Verhalten wie unter „Tests“ beschrieben belegt, insbesondere: Kein Import kann die Studienliste unlesbar machen.
- [x] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [x] Backup-Format unverändert (`backupVersion` bleibt 2); eine mit Version 1.9.1 exportierte Datei importiert.
- [x] `docs/architecture.md` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- **Annahme:** Für die Meldung bei unerwarteten Fehlern reichen die vorhandenen Texte (`importInvalid`, `restoreInvalid`); es sind keine neuen ARB-Einträge nötig. Braucht der Agent doch einen, kommt er in beide ARB-Dateien.
- **Annahme:** Zahlen, die als Gleitkommazahl ohne Nachkommaanteil kommen (z. B. `1.0`), gelten als falscher Typ – der eigene Export schreibt nur Ganzzahlen.
- **Offen:** Ob die Benachrichtigung nur verschwindet, wenn genau die gelöschte Studie die laufende ist, oder immer dann, wenn danach kein Laufzustand mehr existiert, entscheidet der Agent. Bedingung: Läuft noch eine andere Aufnahme, darf deren Benachrichtigung nicht verschwinden, solange sich das mit den vorhandenen Mitteln unterscheiden lässt; sonst die Grenze in den Notizen festhalten.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Volle Suite danach: 919 bestanden, 0 Fehlschläge (Windows).
- Entscheidung Benachrichtigung: Sie verschwindet, wenn eine gelöschte Studie der zuletzt gespeicherte Laufzustand ist (`activeRuns().first`, sortiert nach `saved_at DESC` – das ist die Studie, deren Messbildschirm die Benachrichtigung zuletzt gesetzt hat). Grenze: Wurde danach eine andere Studie geöffnet, ohne dass dort ein Laufzustand gespeichert wurde, kann die Zuordnung abweichen; mit den vorhandenen Mitteln (kein Studienbezug in der Benachrichtigung) nicht genauer.
- Zusätzlich geprüft (über den Plan hinaus): `revision` ≥ 1, Gruppe `description`, Sonderzyklus `name`.
- Keine neuen ARB-Texte nötig (`importInvalid`, `restoreInvalid`). `backupVersion` bleibt 2.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `_parse` prüft alle gelesenen Felder (Hilfen `optInt`, `optText`, `optAmount`); `importSharedJson` und `BackupTiles._restore` melden jeden Fehler; nach dem Wiederherstellen auch `groupListProvider` invalidiert; „Ersetzen“ mit Laufzustand blendet die Benachrichtigung aus; `deleteStudies` blendet sie aus, wenn die zuletzt gespeicherte laufende Studie gelöscht wird; `_confirmDelete` der Studienkarte nutzt jetzt `deleteStudies`.
- **Learnings & Stolpersteine:** `StudySummary` hat `study.name`/`study.id` (nicht direkt). `Override` kommt aus `package:flutter_riverpod/misc.dart`.
- **Wichtige Entscheidungen und ihre Gründe:** Gleitkommazahlen gelten als falscher Typ (eigener Export schreibt Ganzzahlen). Benachrichtigung siehe Notizen.
- **Auswirkungen auf Folge-Tasks:** Task_50: Versionshinweis kann „fehlerhafte Import-Dateien werden abgelehnt“, „Gruppenliste nach Wiederherstellen aktuell“, „keine hängende Benachrichtigung nach dem Löschen“ nennen.
- **Hinweise zu Tests und Befehlen:** Neue Tests: `tests/backup/backup_validation_test.dart` (Fall-Tabellen, Demo-Daten-Rundlauf), `tests/backup/restore_and_delete_test.dart` (Oberfläche: Fehler per SQLite-Trigger, Gruppenliste, Benachrichtigung).

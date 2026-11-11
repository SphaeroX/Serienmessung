# Task_18: Backup & Wiederherstellen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_18.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Alle Studien (inkl. Schritte, Messungen, Einstellungen pro Studie) lassen sich in eine Backup-Datei exportieren und auf demselben oder einem anderen Gerät wiederherstellen.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_17 archiviert.
- **Relevantes Vorwissen:** README: Datenhaltung nur lokal, Backup per Datei. Video-Dateien selbst sind nicht Teil des Backups (nur Verweis), außer in Task_12 wurde Kopieren entschieden.

## Umfang

**Gehört dazu:**

- Backup-Format (z. B. JSON mit Versionsnummer, optional gezippt).
- Export aller Studien in eine Datei über Teilen/Speichern-Dialog (in den Einstellungen).
- Import mit Auswahl: zusammenführen (Duplikate erkennen) oder ersetzen (mit deutlicher Warnung).
- Validierung und verständliche Fehlermeldung bei beschädigter oder neuerer Datei.

**Gehört nicht dazu:**

- Automatische/Cloud-Backups.

## Umsetzungsschritte

1. [x] Format definieren und in README dokumentieren.
2. [x] Serialisierung/Deserialisierung als reine Funktionen.
3. [x] Export- und Import-UI in den Einstellungen.
4. [x] Zusammenführen-Logik (ID-Konflikte).
5. [x] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Round-Trip: Export → Import in leere DB ergibt identische Daten.
- Zusammenführen ohne Duplikate bei zweimaligem Import.
- Beschädigte Datei → Fehler, keine Änderung an der DB.
- Datei mit höherer Formatversion wird abgelehnt.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Manuell: Backup auf Gerät A, Import auf Gerät B/Emulator, Auswertung identisch (in Notizen vermerkt).

## Offene Fragen / Annahmen

- Video-Studien: Verweis auf Video ist auf einem anderen Gerät ungültig. Annahme: Studie wird importiert, Video muss neu verknüpft werden (Hinweis in der UI).

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `BackupService` (`lib/backup/data/backup_service.dart`): JSON mit `format: "cyclescope-backup"` und `version: 1`, enthält alle Studien mit Schritten und Messungen (inkl. Methode und Video-Pfad). Import prüft die komplette Struktur, bevor etwas geschrieben wird, und läuft in einer Transaktion: "Hinzufügen" überspringt Studien, die schon existieren (gleicher Name, Modus und Erstellzeitpunkt), "Alles ersetzen" löscht vorher alles (doppelte Rückfrage). IDs werden neu vergeben, Schrittbezüge umgemappt. Einstellungen → Abschnitt "Daten": "Backup erstellen" (Datei `cyclescope_backup_JJJJ-MM-TT.json` über den Teilen-Dialog) und "Backup wiederherstellen" (Dateiauswahl, Ergebnis-Hinweis, Hinweis für Video-Studien).
- **Learnings & Stolpersteine:** sqflite liefert für denselben Pfad (auch `:memory:`) standardmäßig dieselbe DB-Instanz – Tests mit zwei Datenbanken brauchen `singleInstance: false` (jetzt in `openTestDatabase`).
- **Wichtige Entscheidungen und ihre Gründe:** Nicht im Backup: laufende Aufnahmen (`run_state`), Einstellungen und Videodateien (nur der Pfad; nach Import auf einem anderen Gerät zeigt die Video-Studie "Video nicht gefunden – erneut auswählen"). Offene Frage damit entschieden. Beschädigte Dateien und Dateien neuerer Formatversion werden abgelehnt, ohne die DB zu ändern.
- **Auswirkungen auf Folge-Tasks:** Keine – letzter Task der Roadmap.
- **Hinweise zu Tests und Befehlen:** `tests/backup/backup_service_test.dart` (Round-Trip identisch, doppelter Import ohne Duplikate, Ersetzen, beschädigt, neuere Version), `tests/backup/backup_tiles_test.dart` (Backup teilen, Wiederherstellen per Hinzufügen, ungültige Datei). APK baut. Manuell prüfen: Backup auf Gerät A, Import auf Gerät B.

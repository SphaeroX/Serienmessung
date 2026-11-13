# Task_23: Backup v2, Screenshots & Doku

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_23.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Das Backup enthält Gruppen, Reihenfolge, Revisionen und Messzeitpunkte; alte Backups (v1) bleiben importierbar. Screenshot-Generator und Dokumentation kennen die neuen Bildschirme.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_22 archiviert.
- **Relevantes Vorwissen:** Task_18 (Backup-Format v1).

## Umfang

**Gehört dazu:**

- Backup-Format v2: `groups`, pro Studie Gruppenbezug/Position, `revision`, `recordedAt` je Messung, `revisions` mit Schritten und Messungen. Import von v1 und v2.
- Ersetzen löscht auch Gruppen und Revisionen.
- Szenen für Gruppen- und Revisions-Bildschirm im Screenshot-Generator.
- Doku (`docs/`, README) aktuell.

**Gehört nicht dazu:**

- Videodateien im Backup.

## Umsetzungsschritte

1. [ ] Export/Import v2 (TDD), v1-Import weiter grün.
2. [ ] Screenshot-Szenen.
3. [ ] Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Round-Trip v2 identisch inkl. Gruppen, Reihenfolge, Revisionen, Zeitstempeln.
- v1-Datei wird weiterhin importiert.
- Doppelter Import erzeugt keine doppelten Gruppen.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Gruppen werden beim Zusammenführen über den Namen wiederverwendet.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `backupVersion = 2`; Export von `groups`, `groupRef`, `groupPosition`, `revision`, `recordedAt`, `revisions` (Schritte + Zeiten); Import/Validierung für v1 und v2; Ersetzen löscht Gruppen und Revisionen mit. Screenshot-Szenen `08_group` und `09_revisions`. Doku (`docs/architecture.md`, `docs/testing.md`, README) aktualisiert. Zusätzlich: Revisionsvergleich zeigt eine Nachkommastelle mehr als die Live-Anzeige (sonst erschien "+0 HM" rot) – gefunden bei der Sichtprüfung der Screenshots.
- **Learnings & Stolpersteine:** Lokal erzeugte Screenshots nicht committen (`git checkout -- screenshots`), CI erzeugt sie.
- **Wichtige Entscheidungen und ihre Gründe:** Gruppen werden beim Zusammenführen über den exakten Namen wiederverwendet; importierte Studien kommen mit ihrer relativen Reihenfolge hinter die vorhandenen. Schritt-Bezüge gelöschter Schritte in Revisionen bekommen negative IDs (keine Kollision mit echten Schritten).
- **Auswirkungen auf Folge-Tasks:** Keine – letzter Task.
- **Hinweise zu Tests und Befehlen:** `tests/backup/backup_v2_test.dart` (Version, Round-Trip inkl. Gruppen/Reihenfolge/Revisionen/Zeitstempel, doppelter Import, Zusammenführen in bestehende Gruppe, Ersetzen, v1-Import, defekte Revision). Screenshots: `flutter test tests/screenshots --dart-define=SCREENSHOTS=true`. Manuell offen: Geräteprüfung von Gruppen-Report (Teilen-Dialog, Öffnen in Excel/PDF-Viewer) und Revisions-Ablauf.

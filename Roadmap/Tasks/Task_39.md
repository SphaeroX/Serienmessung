# Task_39: Verschachtelte Gruppen in Backup, Teilen und Import

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_39.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Die Verschachtelung aus Task_38 geht bei Backup, Wiederherstellen, Teilen und Import nicht verloren. Damit funktioniert auch der Hauptanwendungsfall über mehrere Geräte: Jeder misst seinen Bereich als eigene Gruppe, teilt ihn als Datei, und auf einem Gerät werden die Bereiche zur Gesamtanlage zusammengefügt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_38 archiviert. Dessen "Erkenntnisse für Folge-Agenten" lesen.
- **Relevantes Vorwissen:** Task_18 und Task_23 (Backup v1/v2), README "Außerhalb der Roadmap (2026-11-17)" (Teilen einzelner Studien und Gruppen, Import immer als Zusammenführen), `docs/architecture.md` Abschnitte "Backup" und "Sharing and importing studies/groups".
- **Betroffener Code:** `lib/backup/data/backup_service.dart` (`exportJson`, `importJson`, `_parse`, `ExportSelection`), `lib/backup/presentation/share_actions.dart`.

## Umfang

**Gehört dazu:**

- **Export:** jede Gruppe in `groups[]` bekommt `parentRef` (nur gesetzt, wenn die Obergruppe ebenfalls in der Datei steht) und `parentPosition`. Beide Felder sind optional; die Format-Version bleibt 2, wie bei allen bisherigen optionalen Feldern.
- **Auswahl (`ExportSelection`):** Eine ausgewählte Gruppe nimmt ihren ganzen Teilbaum mit, also alle Bereiche darunter und deren Studien. Ein einzeln geteilter Bereich verlässt das Gerät ohne `parentRef` und kommt beim Empfänger als Gruppe der obersten Ebene an.
- **Import:**
  - Gruppen werden in einer Reihenfolge angelegt, in der die Obergruppe vor ihren Bereichen steht, unabhängig von der Reihenfolge in der Datei.
  - Zusammenführen: Eine Gruppe **mit** `parentRef` wird wiederverwendet, wenn unter der aufgelösten Obergruppe schon eine Gruppe gleichen Namens liegt. Eine Gruppe **ohne** `parentRef` wird wiederverwendet, wenn es eine Gruppe gleichen Namens auf der obersten Ebene gibt; gibt es dort keine, aber im ganzen Bestand genau eine Gruppe dieses Namens (z. B. ein Bereich, der schon in einer Anlage liegt), wird diese verwendet. Sonst entsteht eine neue Gruppe der obersten Ebene.
  - Neue Bereiche einer bestehenden Obergruppe werden hinter deren vorhandene Mitglieder gehängt; die Reihenfolge untereinander bleibt erhalten. Studien und Bereiche teilen sich dabei denselben Versatz.
  - Die Stationsregel aus Task_38 gilt auch nach dem Import: Eine Studie direkt hinter einem Bereich ist nicht parallel und kein Lader.
  - Ersetzen (`replace: true`) stellt den Baum exakt wieder her.
- **Validierung vor dem Schreiben** (`_parse`): `parentRef` zeigt auf eine Gruppe der Datei, kein Kreis, `parentPosition` ist eine Zahl. Sonst `BackupError.invalid`, und nichts wird geändert.
- Alte Dateien ohne die Felder (v1 und v2) laden wie bisher.
- `docs/architecture.md` (Backup, Teilen) und `Roadmap/README.md`.

**Gehört nicht dazu:**

- Oberfläche für das Teilen (die bestehenden Knöpfe reichen; die Gruppenliste wird in Task_41 angepasst).
- Die Verbindungsfelder zwischen Bereichen (Puffer, Band): kommen in Task_42 samt Backup-Feldern.
- Eine Auswahl beim Import, in welche Obergruppe eine empfangene Gruppe gelegt wird. Das Einsortieren macht der Nutzer danach im Gruppen-Bildschirm (Task_41).

## Umsetzungsschritte

1. [ ] Export mit `parentRef`/`parentPosition`, Auswahl mit Teilbaum (TDD).
2. [ ] Validierung (unbekannter Verweis, Kreis).
3. [ ] Import: Anlegen in Eltern-vor-Kind-Reihenfolge, Zusammenführen nach den Regeln oben, Positionen.
4. [ ] Rundreise-Tests und alte Dateien.
5. [ ] Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/backup/nested_groups_backup_test.dart`, `tests/backup/nested_groups_share_test.dart`.

Zu belegende Verhaltensweisen:

- Rundreise: Anlage mit zwei Bereichen, einer davon mit eigenem Unterbereich, dazu direkte Studien dazwischen. Export, Ersetzen-Import in eine leere Datenbank: gleicher Baum, gleiche Mitgliederreihenfolge, gleiche Stationen.
- Dieselbe Datei zweimal zusammenführen fügt beim zweiten Mal nichts hinzu (keine doppelten Gruppen, keine doppelten Studien).
- Teilen der Obergruppe enthält alle Bereiche und alle ihre Studien. Teilen eines Bereichs allein enthält nur ihn, ohne `parentRef`.
- Ein empfangener Bereich ohne `parentRef` landet in dem gleichnamigen Bereich, der lokal schon in einer Anlage liegt, wenn es keinen gleichnamigen auf oberster Ebene und nur diesen einen gibt; bei zwei gleichnamigen Bereichen in verschiedenen Anlagen entsteht eine neue Gruppe der obersten Ebene.
- Zwei Anlagen mit je einem Bereich „Montage“ bleiben nach Export und Zusammenführen zwei getrennte Bereiche.
- Eine Datei mit `parentRef` auf eine unbekannte Gruppe oder mit einem Kreis wird als ungültig abgelehnt; die Datenbank ist danach unverändert.
- Eine v2-Datei ohne die neuen Felder und eine v1-Datei laden wie vor diesem Task.
- Die bestehenden Tests in `tests/backup/` laufen unverändert.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.
- [ ] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [ ] `docs/architecture.md` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- Annahme: Die Format-Version bleibt 2. Eine ältere App-Version liest eine neue Datei und legt alle Gruppen flach nebeneinander an; es gehen keine Studien verloren. Soll das verhindert werden, müsste die Version auf 3 steigen (dann lehnen ältere Apps die Datei ab). Vor der Umsetzung nicht nötig zu klären, aber in den Erkenntnissen festhalten.
- Annahme: Die Regel „genau eine gleichnamige Gruppe irgendwo“ für empfangene Bereiche ist gewollt, damit ein Kollege einen Bereich nachliefern kann, der lokal schon in der Anlage liegt. Bisher wurden Gruppen einfach über den Namen wiederverwendet (es gab nur eine Ebene).

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

(Beim Abschluss ausfüllen.)

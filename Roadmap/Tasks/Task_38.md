# Task_38: Verschachtelte Gruppen – Datenmodell und Repository

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_38.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine Gruppe kann neben Studien auch **ganze Gruppen** enthalten. So lässt sich eine große Anlage in Bereiche aufteilen, die jeweils eine eigene Gruppe sind und einzeln gemessen und ausgewertet werden; die Obergruppe fügt sie später zur Gesamtanlage zusammen. Dieser Task legt nur das Fundament: Schema, Domain-Modell und Repository. Es gibt noch keine neue Oberfläche.

Der Gesamtentwurf der Erweiterung (Task_38–46) steht in `Roadmap/README.md` unter "[Erweiterung 6, geplant 2026-11-25]". Lies ihn vor diesem Task.

## Begriffe

- **Obergruppe:** Gruppe, die mindestens eine andere Gruppe enthält (die Gesamtanlage).
- **Bereich:** Gruppe, die in einer Obergruppe liegt. Im Code `subgroup` bzw. `parentId`; ein Bereich bleibt eine vollwertige Gruppe (`study_group`).
- **Mitglied:** Eintrag einer Gruppe in ihrer Reihenfolge: eine Studie oder ein Bereich.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_37 archiviert (Stand `main`, Version 1.8.0, Migration v16).
- **Relevantes Vorwissen:** Task_19 (Gruppen), Task_26/27 (parallele Maschinen, `stationGroups`), README-Einträge "[Review nach Task_35]" (Stationen bleiben zusammen: `handOverStation`, `reorder(..., moved:)`, `parallelAfterMove`), "[Nach Task_36, 2026-11-19]" (`tidyStations`, `wait_for_slowest`) und "[Task_37]" (Lader hängen über `parallel` an ihrer Station).
- **Betroffener Code:** `lib/core/database.dart`, `lib/group/domain/study_group.dart`, `lib/group/domain/stations.dart`, `lib/group/data/group_repository.dart`, `lib/study/data/study_repository.dart` (`nextGroupPosition`, `handOverStation`, `tidyStations`).

## Umfang

**Gehört dazu:**

- **Migration v17** (anhängen, bestehende Migrationen nicht ändern):
  - `study_group.parent_id INTEGER REFERENCES study_group(id) ON DELETE SET NULL` (NULL = Gruppe der obersten Ebene).
  - `study_group.parent_position INTEGER NOT NULL DEFAULT 0`.
  - Studien (`study.group_position`) und Bereiche (`study_group.parent_position`) teilen sich **einen** Positionsraum innerhalb ihrer Gruppe.
- **Domain:**
  - `StudyGroup.parentId` und `StudyGroup.parentPosition`.
  - `GroupMember` als versiegelte Klasse (Studie oder Bereich) in `lib/group/domain/`.
  - `GroupSummary` zusätzlich mit Anzahl der direkten Bereiche und Anzahl aller Studien im Teilbaum. `studyCount` bleibt die Anzahl der direkten Studien.
- **Regeln (im Repository erzwungen, nicht nur in der UI):**
  - Eine Gruppe hat höchstens eine Obergruppe (wie eine Studie höchstens eine Gruppe hat).
  - Kein Kreis: Eine Gruppe kann weder in sich selbst noch in einen ihrer Nachfahren gelegt werden. Der Versuch wird mit einem klaren Fehler abgelehnt und ändert nichts.
  - Die Tiefe ist nicht begrenzt (Bereich im Bereich ist erlaubt).
  - **Ein Bereich ist immer eine Stationsgrenze.** Eine Studie direkt hinter einem Bereich ist nie parallel und nie Lader, denn „parallel“ heißt „parallel zum Mitglied davor“, und das wäre ein Bereich.
- **Repository (`GroupRepository`, alles transaktional):**
  - `listMembers(groupId)`: Studien und Bereiche gemischt in Gruppenreihenfolge.
  - Bereich in eine Obergruppe legen bzw. herauslösen (ans Ende angehängt; `null` = oberste Ebene).
  - `ancestors(groupId)` und alle Nachfahren einer Gruppe (für Kreisprüfung, Pfadanzeige und Löschen).
  - Reihenfolge gemischter Mitglieder setzen, mit `moved` wie heute. Die bestehende Methode `reorder(groupId, studyIds, moved:)` behält Signatur und Verhalten für Gruppen ohne Bereiche; die bestehenden Tests dafür bleiben unverändert.
  - `StudyRepository.nextGroupPosition` zählt Bereiche mit, damit neue Studien, Kopien, Maschinen und importierte Studien hinter dem letzten Mitglied landen.
- **Stationen bleiben zusammen, auch mit Bereichen:**
  - `stations.dart` (reines Dart) so erweitern, dass ein Bereich in der Mitgliederliste als Grenze zählt: `stationGroups`/`parallelAfterMove` bzw. eine neue Variante mit einer Liste „ist Bereich“.
  - Wird ein Bereich **in eine Station hinein** verschoben (zwischen erste Maschine und parallele Maschine), wird die Maschine dahinter zur ersten Maschine einer eigenen Station: `parallel = 0`, `cell_loader = 0`. Puffer und Band bleiben bei der Station davor, die Option „auf langsamste warten“ gilt für beide Teile weiter, soweit `tidyStations` sie nicht entfernt.
  - `handOverStation`, `tidyStations` und `_stationOf` lesen die gemischte Reihenfolge. Die Regel „vor der ersten Station steht nichts“ bezieht sich auf das erste **Mitglied**: eine Studie direkt hinter einem Bereich darf Puffer und Band haben.
- **Löschen:**
  - `deleteGroup(id)`: Studien bleiben ohne Gruppe (wie heute), direkte Bereiche werden zu Gruppen der obersten Ebene.
  - `deleteGroup(id, withStudies: true)`: löscht den ganzen Teilbaum, also alle Bereiche darunter samt ihren Studien. Der Aufrufer bekommt vorher die Studien des Teilbaums geliefert (für das Aufräumen der Videos über `deleteUnusedVideo`).
- `docs/architecture.md` (Abschnitt "Groups") und `Roadmap/README.md`.

**Gehört nicht dazu:**

- Oberfläche (Task_41), Backup und Teilen (Task_39), Linienanalyse über Bereiche hinweg (Task_40), Puffer und Bänder zwischen Bereichen (Task_42).
- Eine Gruppe in mehreren Obergruppen gleichzeitig, das Kopieren ganzer Gruppen und parallele Bereiche (zwei Bereiche, die in eine Station zusammenlaufen).

## Umsetzungsschritte

1. [ ] Stationsregeln mit Bereichen als reine Domain-Funktionen (TDD, `tests/group/domain/`).
2. [ ] Migration v17 und Modell (`StudyGroup`, `GroupMember`, `GroupSummary`), Test mit einer v16-Datenbank, die hochgezogen wird.
3. [ ] `listMembers`, Bereich hinein- und herauslegen, Kreisprüfung, Vor- und Nachfahren.
4. [ ] Gemischte Reihenfolge mit `moved`; `nextGroupPosition`, `handOverStation`, `tidyStations`, `_stationOf` auf die gemischte Reihenfolge umstellen.
5. [ ] Löschen mit und ohne Studien.
6. [ ] Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/group/domain/nested_stations_test.dart`, `tests/group/data/nested_groups_test.dart`, `tests/group/data/nested_station_integrity_test.dart`.

Zu belegende Verhaltensweisen:

- Eine Datenbank der Version 16 mit Gruppen und Studien lässt sich hochziehen; alle Gruppen sind danach oberste Ebene, Reihenfolge und Stationen unverändert.
- `listMembers` liefert Studien und Bereiche in der gespeicherten Reihenfolge; ein neu hineingelegter Bereich steht am Ende, eine danach hinzugefügte Studie dahinter.
- Eine Gruppe in sich selbst, in ein Kind oder in einen Enkel legen wird abgelehnt und ändert nichts.
- Ein Bereich, der in eine andere Obergruppe gelegt wird, verschwindet aus der alten.
- Studie direkt hinter einem Bereich: `setParallel(true)` und `setCellLoader(true)` bleiben ohne Wirkung.
- Bereich wird zwischen die erste und die zweite Maschine einer Parallelstation geschoben: die zweite Maschine ist danach eine eigene Station ohne Lader-Rolle; Puffer und Band stehen weiter vor der ersten.
- Erste Maschine einer Station direkt hinter einem Bereich verlässt die Gruppe: die nächste Maschine übernimmt Station, Puffer, Band und Warte-Option.
- Verschieben einer Studie über einen Bereich hinweg hält alle anderen Stationen zusammen.
- Löschen ohne Studien: Studien ohne Gruppe, Bereiche oberste Ebene. Löschen mit Studien: der ganze Teilbaum ist weg, Studien anderer Gruppen bleiben.
- Alle bestehenden Tests in `tests/group/` laufen unverändert.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.
- [ ] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [ ] `docs/architecture.md` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- Annahme (aus der Planung, vom Nutzer noch nicht bestätigt): Eine Gruppe hat höchstens eine Obergruppe; „in mehreren Anlagen“ ginge wie bei Studien nur über eine Kopie, und das Kopieren ganzer Gruppen ist nicht Teil dieser Erweiterung.
- Annahme: Die Tiefe ist frei. Sollte der Nutzer nur eine Ebene wollen, ist das eine reine Sperre im Repository (Bereich mit eigenen Bereichen ablehnen); das Schema bleibt gleich.
- Bestätigt (Nutzer, 2026-11-25): Bereiche stehen in der Obergruppe immer in Reihe. Parallele Bereiche werden nicht gebraucht.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- SQLite erlaubt `ALTER TABLE ... ADD COLUMN ... REFERENCES` nur mit Standardwert NULL; das passt hier (wie in Migration v9).
- `study_group.parent_position` und `study.group_position` können bei Altdaten nicht kollidieren, weil es vor v17 keine Bereiche gibt.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

(Beim Abschluss ausfüllen.)

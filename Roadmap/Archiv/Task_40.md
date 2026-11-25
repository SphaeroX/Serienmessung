# Task_40: Gesamtlinie – Bereiche abflachen, Linienanalyse und Bereichsübersicht

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_40.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine Obergruppe wird als **eine durchgehende Linie** betrachtet: Die Stationen ihrer Bereiche stehen in Gruppenreihenfolge hintereinander, gemischt mit den direkten Studien der Obergruppe. Die Linienanalyse zeigt Taktzeit, Engpass, Abstimmung und Ausbringung der Gesamtanlage und zusätzlich je Bereich, wie schnell er allein wäre und ob der Engpass in ihm liegt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_38 und Task_39 archiviert. Deren "Erkenntnisse für Folge-Agenten" lesen.
- **Relevantes Vorwissen:** Task_24 (`LineAnalysis`, `LineScreen`, `loadGroupReport`), Task_27 (`line.stations` ist nicht 1:1 zu den Mitgliedern), Task_37 (Laderzelle = eine Maschine in `LineStation.machines`), README "[Nach Task_36, 2026-11-19]" (wartende Stationen).
- **Betroffener Code:** `lib/group/domain/` (neu: Baum und Abflachen, Bereichsauswertung), `lib/study/domain/study.dart`, `lib/export/presentation/export_menu.dart` (`loadGroupReport`), `lib/export/domain/group_report.dart` (`GroupReportInput`), `lib/group/presentation/line_screen.dart`.

## Entwurf

- **Abflachen (reines Dart):** Aus dem Baum einer Gruppe entsteht die Liste der Studien in Linienreihenfolge (Tiefensuche). Jede Studie trägt den Pfad ihrer Bereiche. Dabei entstehen *wirksame* Studien:
  - Die erste Studie jedes Bereichs und die erste Studie hinter einem Bereich sind nicht parallel und kein Lader (Stationsgrenze, siehe Task_38). Das Repository garantiert das bereits; das Abflachen erzwingt es trotzdem, damit ein Altbestand oder ein Import die Linie nie verfälscht.
  - Ein leerer Bereich trägt nichts bei.
  - Ein Kreis im Baum (dürfte nie vorkommen) führt zu einem klaren Fehler statt zu einer Endlosschleife.
- **Wirksame Studie statt neuer Eingabetyp:** `Study` bekommt ein `copyWith` für die Linienfelder. Die abgeflachte Liste besteht aus normalen `Study`-Objekten mit den wirksamen Werten. Dadurch arbeiten `GroupReportInput.line`, die Simulation, das Ausfallrisiko und das Excel-Linienblatt (das `stationGroups` über `study.parallel` der Einträge bildet) ohne eigene Sonderfälle.
- **`loadGroupReport`** lädt den Baum und liefert `entries` in abgeflachter Reihenfolge; die Signatur bleibt.
- **Bereiche in `GroupReportInput`:** neue Liste der direkten Bereiche der geöffneten Gruppe mit Name, erstem und letztem Eintrag. Direkte Studien der Obergruppe gehören zu keinem Bereich. Tiefere Ebenen sieht man, wenn man den Bereich selbst öffnet.
- **Bereichsauswertung (reines Dart):** je Bereich Stationen von–bis (durchlaufende Nummern der Gesamtlinie), Taktzeit des Bereichs (seine langsamste gemessene Station), Summe und Durchlaufzeit, Ausbringung pro Stunde, wenn er allein liefe, Wartezeit gegenüber dem Linientakt und ob der Engpass der Gesamtlinie in ihm liegt.

## Umfang

**Gehört dazu:**

- Baum laden (`GroupRepository`) und Abflachen (Domain) wie im Entwurf.
- `Study.copyWith` für die Linienfelder.
- `loadGroupReport` und `GroupReportInput` mit Bereichen.
- Bereichsauswertung als reine Domain-Funktion.
- `LineScreen`:
  - Stationsnummern laufen über die ganze Anlage durch.
  - Karte „Bereiche“ mit einer Zeile je Bereich (Name, Stationen von–bis, Taktzeit, Ausbringung allein, Markierung des Engpass-Bereichs). Antippen öffnet die Linienanalyse dieses Bereichs.
  - Im Yamazumi-Diagramm Trennlinien und Namen der Bereiche; in der Stationsliste Zwischenüberschriften.
  - Ohne Bereiche sieht der Bildschirm aus wie heute.
- Ausfallrisiko und Simulationsbildschirm müssen mit einer Obergruppe ohne Fehler laufen (Feinschliff in Task_43).
- Texte EN/DE, `docs/architecture.md`, `Roadmap/README.md`.

**Gehört nicht dazu:**

- Gruppen-Bildschirm und Gruppenliste (Task_41). Bis dahin entstehen verschachtelte Gruppen nur über Repository und Import; die Tests legen sie über das Repository an.
- Puffer und Bänder **zwischen** Bereichen (Task_42). Puffer und Bänder innerhalb eines Bereichs und vor direkten Studien wirken schon jetzt.
- Reports (Task_44).

## Umsetzungsschritte

1. [x] Abflachen als reine Funktion mit allen Regeln (TDD).
2. [x] `Study.copyWith`, Baum laden, `loadGroupReport` mit abgeflachten Einträgen und Bereichen.
3. [x] Bereichsauswertung (TDD), inklusive der Invariante unten.
4. [x] `LineScreen`: Bereichskarte, Diagramm, Stationsliste (Widget-Tests).
5. [x] Ausfallrisiko und Simulationsbildschirm mit Obergruppe gegenprüfen.
6. [x] Texte, Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/group/domain/group_tree_test.dart`, `tests/group/domain/area_analysis_test.dart`, `tests/group/data/group_tree_load_test.dart`, `tests/group/presentation/line_areas_screen_test.dart`.

Zu belegende Verhaltensweisen:

- Abflachen: Reihenfolge bei „Studie, Bereich, Studie“, bei Bereich im Bereich und bei leerem Bereich. Jede Studie trägt den richtigen Bereichspfad.
- Eine als parallel gespeicherte Studie am Anfang eines Bereichs oder direkt hinter einem Bereich bildet in der Gesamtlinie eine eigene Station.
- Ein Kreis im Baum führt zu einem Fehler, nicht zu einer Endlosschleife.
- **Invariante:** Die Taktzeit eines Bereichs in der Gesamtlinie ist gleich der Linientaktzeit desselben Bereichs, wenn man ihn allein analysiert. Die Linientaktzeit der Anlage ist das Maximum der Bereichstaktzeiten und der direkten Stationen.
- Der Engpass-Bereich ist der Bereich, der die Engpass-Station enthält; liegt der Engpass in einer direkten Studie, ist kein Bereich markiert.
- Parallelstation, wartende Station und Laderzelle innerhalb eines Bereichs rechnen in der Gesamtlinie wie im Bereich allein.
- Ein Bereich ohne gemessene Station wird aufgeführt, zählt aber nicht (wie heute Stationen ohne Zeiten).
- `LineScreen` einer Obergruppe zeigt die Bereichskarte, durchlaufende Stationsnummern und die Zwischenüberschriften; eine Gruppe ohne Bereiche zeigt keine Bereichskarte.
- Alle bestehenden Tests zu Linie, Simulation und Reports laufen unverändert.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.
- [x] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [x] `docs/architecture.md` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- Annahme: Die Bereichskarte zeigt nur die direkten Bereiche der geöffneten Gruppe. Unterbereiche erscheinen, wenn man den Bereich öffnet. So bleibt die Karte auch bei einem Werk mit vielen Ebenen lesbar.
- Annahme: Einheit und Methode kommen wie heute aus den Einstellungen bzw. der Studie; es gibt keine eigene Einstellung je Bereich.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- `loadGroupReport` lädt alle Zeiten aller Studien der Anlage. Bei einer Anlage mit etwa 100 Studien die Ladezeit einmal messen und hier festhalten.
- Das Yamazumi-Diagramm muss bei vielen Stationen bedienbar bleiben (waagerecht scrollen oder Mindestbreite je Balken); mit 40 Stationen im Widget-Test und in einer Screenshot-Szene prüfen.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Bausteine:** `GroupRepository.loadTree(id)` → `Map<int, List<GroupMember>>`; `flattenGroup(id, tree)` → `FlatLine(entries: [FlatEntry(study, path)], areas: [LineArea(group, start, end)])` in `lib/group/domain/group_tree.dart`; `analyseAreas(line, parallel, areas)` → `AreaFigures` in `lib/group/domain/area_analysis.dart`; `GroupReportInput.areas` / `.areaFigures`. Stationen eines Bereichs = Stationen, deren erster Eintrag in `[start, end)` liegt (ein Bereich ist immer Stationsgrenze, daher eindeutig).
- **`loadGroupReport` liefert die abgeflachten Studien** – auch die Gruppen-Reports (PDF/Excel) einer Anlage enthalten damit schon jetzt alle Studien aller Bereiche als Einträge, nur noch ohne Bereichs-Zwischenüberschriften (Task_44).
- **Wirksame Studien:** Die erste Studie eines Bereichs und die erste hinter einem Bereich bekommen in der flachen Liste `parallel = false`, `cellLoader = false`. Puffer und Bänder bleiben, wie sie gespeichert sind (Task_42 legt die Verbindung zwischen Bereichen auf die erste Station des Bereichs; dafür `Study.copyWith(bufferCapacity: …)` usw. nutzen).
- **Yamazumi:** waagerechtes Scrollen nur, wenn `Stationen × YamazumiPainter.minSlot (28 px)` breiter ist als der Platz. Bewusst so: Ein zweiter `Scrollable` würde `scrollUntilVisible` ohne `scrollable:` in bestehenden Widget-Tests mehrdeutig machen. Neue Tests mit vielen Stationen müssen beim Scrollen den senkrechten Scrollable angeben (siehe `line_areas_screen_test.dart`).
- **Ladezeit:** Anlage mit 10 Bereichen × 10 Studien (100 Studien) öffnete die Linienanalyse im Widget-Test (sqflite ffi, Windows-Desktop) in rund 0,6 s inklusive Wartezyklen der Test-Hilfen. Auf dem Gerät nicht gemessen.
- **Screenshot-Szene** mit 40 Stationen ist nicht angelegt; das passt zu Task_46 (Screenshots). Der Widget-Test mit 40 Stationen prüft Breite und Scrollbarkeit.
- `lib/` und `lib/l10n` trugen wieder das ReadOnly-Attribut; `attrib -R lib\l10n /S /D` (PowerShell) vor `flutter gen-l10n`.

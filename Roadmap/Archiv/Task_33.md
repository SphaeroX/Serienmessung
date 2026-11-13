# Task_33: Transportbänder zwischen Stationen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_33.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Zwischen zwei Stationen lässt sich ein Transportband angeben – so einfach wie möglich: gemessene Transportzeit eines Teils von A nach B und Anzahl Teile, die sich darauf stauen können. Das Band wirkt wie ein kostenloser kleiner Puffer. Ein Puffer an derselben Stelle ist mit dem Band verknüpft: Er lagert erst ein, wenn das Band voll ist, und lagert aus, sobald auf dem Band Platz ist.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_32 archiviert.
- **Relevantes Vorwissen:** Task_29 (Puffer am ersten Mitglied der Station), Task_30 (Simulation), Task_32 (Puffertabelle im Report).

## Umfang

**Gehört dazu:**

- Migration: `study.conveyor_capacity` (0 = kein Band), `study.conveyor_transport_us` am ersten Mitglied der Station (wie der Puffer); Parallel schalten/Verschieben/Kopieren entfernt es; Backup-Felder optional.
- Gruppen-Bildschirm: Menüpunkt "Transportband davor", Karte über der Station (antippen = bearbeiten/entfernen).
- Linienanalyse: Band je Station; Durchlaufzeit eines Teils enthält die Transportzeiten.
- Simulation: Band = Warteschlange mit Kapazität (zählt auch fahrende Teile); ein Teil verlässt die Maschine, solange Platz ist, und ist nach der Transportzeit an der nächsten Station. Mit Band lagert der Puffer ein, wenn das Band voll ist, und lagert aufs Band aus, sobald Platz ist. Max. Belegung des Bands im Ergebnis.
- Linien-/Simulationsbildschirm und Reports (Spalten in der Verbindungstabelle) zeigen das Band.
- Texte DE/EN, Doku, README, Version 1.2.0.

**Gehört nicht dazu:**

- Mindestabstand/Durchsatzgrenze des Bands (bewusst weggelassen – so einfach wie möglich).

## Umsetzungsschritte

1. [ ] Daten, Backup (TDD).
2. [ ] Simulation und Linienanalyse (TDD).
3. [ ] UI Gruppe, Linie, Simulation (Widget-Tests).
4. [ ] Reports (TDD).
5. [ ] Doku, README, Version; main + interner Play-Test.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Band wird gespeichert, angezeigt, bearbeitet, entfernt; Backup erhält es.
- Transportzeit verzögert die Teile, ändert den Takt nicht; Durchlaufzeit enthält sie.
- Band mit Plätzen fängt einen Ausfall dahinter ab, bis es voll ist.
- Puffer am Band lagert erst bei vollem Band ein; ohne Stau nie.
- Report zeigt Transportzeit und Plätze des Bands.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Ein ausgelagertes Teil wird vorne am Band (vor der Station) abgesetzt.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Migration v13, `Study.conveyorCapacity/conveyorTransportMicros/hasConveyor`, `GroupRepository.setConveyor/removeConveyor`, Backup; `LineConveyor`, Durchlaufzeit mit Transportzeiten; `SimConveyor`/`SimConveyorStats`, Band-Logik in `LineSimulation` (Puffer am Band); UI: "Transportband davor einfügen", Karten in Gruppe/Linie/Simulation; Report: Verbindungstabelle (früher "Puffer") mit Band-Spalten. Version 1.2.0 und Freigabe folgen nach Task_34 (Sonderzyklen, vom Nutzer während der Arbeit ergänzt).
- **Learnings & Stolpersteine:** Beim Einfügen eines Elements in eine `for`-Collection-Schleife mit nur einem Element wird der Rest aus der Schleife herausgelöst – mehrere Elemente pro Durchlauf immer als `...[ ]` schreiben.
- **Wichtige Entscheidungen und ihre Gründe:** So einfach wie möglich (Nutzerwunsch): nur Transportzeit und Plätze, kein Mindestabstand. Ausgelagertes Teil wird vorne am Band abgesetzt (sofort an der Station verfügbar).
- **Auswirkungen auf Folge-Tasks:** Task_34 (Sonderzyklen) erweitert die Maschinen der Simulation.
- **Hinweise zu Tests und Befehlen:** `tests/group/data/conveyor_test.dart`, `tests/group/domain/conveyor_simulation_test.dart`, `tests/group/presentation/conveyor_screen_test.dart`, `tests/export/group_report_conveyor_test.dart`.

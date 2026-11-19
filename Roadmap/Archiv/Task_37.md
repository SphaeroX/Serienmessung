# Task_37: Laderzelle – mehrere Maschinen, bedient von Ladern auf einer Schiene

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_37.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine Gruppe kann eine **Laderzelle** enthalten: n gleiche Maschinen, die der Reihe nach von mehreren Ladern auf einer gemeinsamen Schiene bedient werden. Die App berechnet daraus die Taktzeit der Zelle, den Engpass (welcher Lader oder die Maschinen), die Wartezeiten und zeigt, ab welcher Maschinenanzahl eine weitere Maschine nichts mehr bringt. In der Linie zählt die Zelle als eine Station.

## Praxisfall (Vorlage des Nutzers)

Laderschiene mit drei Ladern, 1 bis 4 gleiche Maschinen:

- **Lader 1** (Doppelgreifer): nimmt ein Rohteil vom Eingangsband → fährt zu Maschine i → entnimmt das Fertigteil und setzt das Rohteil ein (Wechsel) → fährt zum Ausgangsband und legt das Fertigteil ab → **wartet, bis Lader 2 die Maschine fertig bestückt hat und wegfährt** (gemeinsame Schiene, kein Überholen) → nächste Maschine i+1, immer reihum.
- **Lader 2**: bestückt Maschine i mit weiteren Teilen, während Lader 1 zum Band fährt. Er nimmt die Teile aus einem Magazin.
- **Lader 3**: legt Teile im Magazin bereit, damit Lader 2 sie direkt greifen kann. Durch das Magazin ist er von Lader 2 entkoppelt; er muss im Mittel nur schnell genug nachlegen.
- **Maschine i**: Wechsel (L1) → Bestücken (L2) → Bearbeiten → wartet auf den nächsten Wechsel.

## Modell

Jede beteiligte Ressource wird als eigene Studie gemessen, über ihren **ganzen Zyklus einschließlich Wartezeiten**. Schritte, in denen die Ressource nur auf Nachschub wartet, werden markiert („Wartezeit, zählt nicht“) und herausgerechnet:

- **Lader k:** H_k = Zykluszeit pro Teil − markierte Warteschritte (z. B. „Warten auf Maschine“, „Warten auf Magazin“). Wartezeiten wegen der gemeinsamen Schiene („Warten auf Lader 2“) sind **nicht** markiert. Sie gehören zum Ablauf und bleiben in H_k.
- **Maschine:** M = Zykluszeit − markierte Warteschritte („Warten auf Lader“), also Wechsel + Bestücken + Bearbeiten.
- **Taktzeit der Zelle:** T = max(H_1, …, H_k, M ÷ n). Ein Lader, der nicht jedes Teil anfasst, bekommt einen Faktor „Teile pro Zyklus“ (Standard 1) und geht mit Zykluszeit ÷ Faktor ein.
- **Engpass:** die Ressource mit dem größten Wert. **Auslastung** einer Ressource = eigener Wert ÷ T, Wartezeit pro Teil = T − eigener Wert.
- **Sinnvolle Maschinenanzahl:** n* = ⌈M ÷ max(H_k)⌉. Ab dieser Anzahl bringt eine weitere Maschine nichts mehr. Tabelle für n = 1…6.

Beispiel (muss als Test belegt werden): H_1 = 32 s, H_2 = 20 s, H_3 = 15 s, M = 88 s
→ n = 1: 88 s · n = 2: 44 s · n = 3: 32 s (Engpass Lader 1) · n = 4: 32 s; n* = 3.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_36 archiviert.
- **Relevantes Vorwissen:** Task_19 (Gruppen), Task_24/27 (`LineAnalysis`, Stationen, `stationGroups`), Task_26 (parallele Maschinen = Lastteilung 1/Σ(1/t); das ist **etwas anderes** als die Laderzelle), Task_29–33 (Puffer, Simulation, Bänder), Task_34 (Sonderzyklen: wirksame Taktzeit der Maschine).

## Umfang

**Gehört dazu:**

- Datenmodell und Migration:
  - Je Schrittdefinition ein Merker „Wartezeit, zählt nicht“, ausschließlich für die Laderzelle; die Auswertung der einzelnen Studie bleibt unverändert, zeigt den Merker aber an.
  - Je Gruppenmitglied eine Rolle in der Zelle (Maschine / Lader), „Teile pro Zyklus“ bei Ladern und die Maschinenanzahl n bei der Maschine. Die Zelle ist eine Station; ihre Mitglieder werden wie heute über die Gruppenreihenfolge zusammengehalten (an `stationGroups` anlehnen, keine zweite Gruppierungslogik).
  - Kopie und Backup übernehmen alle neuen Felder; alte Backups bleiben lesbar.
- Reine Domain-Funktion für die Zelle (H_k, M, T, Engpass, Auslastung, Wartezeit, n*, Tabelle n = 1…6).
- Linienanalyse: die Zelle ist eine Station mit Taktzeit T und Durchlaufzeit M; Engpass, Abstimmung und Ausbringung rechnen damit. Sonderzyklen der Maschine wirken über die wirksame Taktzeit auf M.
- Simulation: die Zelle als Station mit Taktzeit T (deterministisch wie eine Maschine). Puffer und Bänder davor und dahinter funktionieren unverändert.
- UI:
  - In der Gruppe ein Mitglied als „Laderzelle“ kennzeichnen (Maschine plus Lader); Felder für n und „Teile pro Zyklus“.
  - Im Schritt-Editor der Merker „Wartezeit, zählt nicht“.
  - Zellenansicht mit Taktzeit, Engpass, Auslastung und Wartezeit je Ressource sowie der Tabelle 1…6 Maschinen mit hervorgehobenem n*.
  - Hinweis in der Zellenansicht: „Jede Ressource über den ganzen Zyklus messen, Wartezeiten als eigene Schritte.“
- Reports (PDF, Excel): Kapitel bzw. Blatt zur Laderzelle mit denselben Werten.
- Texte DE/EN, `docs/` (architecture, project-brief), `Roadmap/README.md`, Demo-Daten um eine Laderzelle ergänzen.

**Gehört nicht dazu:**

- Ereignisgenaue Simulation der Schienenverriegelung („wer wartet auf wen“) für Was-wäre-wenn-Fragen. Die gemessenen Wartezeiten bilden die Verriegelung ab. Wird ein Lader schneller, ändert sich seine Wartezeit; das bildet das Modell nicht nach. Das wäre ein eigener Folge-Task.
- Ungleiche Maschinen in einer Zelle (alle n Maschinen haben dieselbe Belegungszeit M).
- Ausfälle einzelner Maschinen der Zelle in der Simulation (die Zelle fällt als Ganzes aus wie eine Maschine).

## Umsetzungsschritte

1. [x] Domain-Funktion der Zelle mit dem Beispiel oben (TDD).
2. [x] Datenmodell, Migration, Kopie, Backup (TDD).
3. [x] Linienanalyse und Simulation (TDD).
4. [x] UI: Merker im Schritt-Editor, Zelle in der Gruppe, Zellenansicht (Widget-Tests).
5. [x] Reports (TDD).
6. [x] Demo-Daten, Doku, README, Version (1.7.0).

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Beispiel oben: T je n und n* = 3; Engpass wechselt von „Maschinen“ (n ≤ 2) zu „Lader 1“ (n ≥ 3).
- Markierte Warteschritte werden aus H_k bzw. M herausgerechnet, unmarkierte (Schienen-Warten) nicht.
- „Teile pro Zyklus“ = 2 halbiert den Wert des Laders.
- Lader 3 (Magazin) wird Engpass, wenn sein Wert über allen anderen liegt.
- Eine Zelle ohne gemessene Maschine oder ohne gemessenen Lader gilt als nicht gemessen (wie heute bei Stationen).
- Linienanalyse und Simulation nutzen T der Zelle; Puffer und Bänder davor und dahinter arbeiten unverändert.
- Merker, Rolle, n und Faktor werden gespeichert, kopiert, gesichert und wiederhergestellt; ein altes Backup ohne die Felder lädt.
- UI und Reports zeigen die Werte.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.
- [x] `docs/` und `Roadmap/README.md` aktuell.
- [x] Demo-Daten zeigen eine Laderzelle (zweite Demo-Gruppe).
- [x] 621 Tests grün (14 übersprungen: Screenshot-Generatoren), `flutter analyze` ohne Befunde, `dart format` sauber (2026-11-19).

## Offene Fragen / Annahmen

- Bestätigt (Nutzer, 2026-11-19): Lader 2 bestückt die Maschinen reihum, jeweils nachdem Lader 1 dort das neue Rohteil eingelegt hat.
- Bestätigt: Lader 3 fährt auf derselben Schiene und kann Lader 2 behindern. Das zeigt sich als (unmarkiertes) Schienen-Warten in der Studie von Lader 2 und bleibt in H_2.
- Bestätigt: Die Maschinen einer Zelle sind „in der Regel“ gleich schnell. Ungleiche Maschinen bleiben außerhalb dieses Tasks; das Datenmodell soll eine spätere Erweiterung (eigene Maschinenstudie je Maschine) aber nicht verbauen.
- Annahme: Das Magazin ist groß genug, dass Schwankungen von Lader 3 nicht durchschlagen; nur der Mittelwert zählt.
- Entschieden (Nutzer, 2026-11-19, "Anpassen und Tasks beenden"): Die Demo-Daten bekommen eine zweite Gruppe "Demo: Laderzelle" neben der Gehäuselinie. Dafür wurden – mit Freigabe – die Zähler in drei bestehenden Tests angepasst (`tests/demo/demo_data_service_test.dart`: 2 statt 1 Gruppe je Laden, 14 statt 10 Studien je Laden; `tests/demo/demo_data_tile_test.dart`: beide Gruppennamen statt genau einer Gruppe). Die Gehäuselinie und ihre 1000 Teile in 24 h sind unverändert.
- Entschieden: Version 1.7.0 (`pubspec.yaml`, `appVersion`, README). Merge nach `main`, Tag und Play-/TestFlight-Lauf macht der Nutzer; entwickelt wurde auf dem Branch `ccr-e4e8e596-qd8qyd`.
- Umgesetzt ohne weitere Rückfrage: Bezeichnung „Laderzelle“ / „Loader cell“; der Merker ist ein Sanduhr-Schalter an jedem Schritt im Schritt-Editor.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Umsetzung (2026-11-19), Entwurfsentscheidungen:
  - Lader hängen über das vorhandene `parallel`-Flag an der Station der Maschine; `cell_loader` macht aus dem parallelen Mitglied einen Lader. So halten `stationGroups`, `parallelAfterMove` und `handOverStation` die Zelle ohne zweite Gruppierungslogik zusammen.
  - Ein paralleles Mitglied ohne Lader-Rolle in einer Zelle zählt als weitere Maschinenart (Kapazitäten addieren sich). Damit gibt es keinen ungültigen Zustand, und ungleiche Maschinen sind im Rechenkern schon möglich; nur die Tabelle 1…6 und n* gibt es dann nicht.
  - Die Zelle steht in `LineStation.machines` als **eine** Maschine mit der Zellen-Taktzeit. Ausfallrisiko, Simulation und Reports brauchten dadurch keine Sonderfälle; Sonderzyklen der Mitglieder stecken schon in den Arbeitszeiten.
  - Der Merker "Wartezeit" wird in archivierten Revisionen nicht gespeichert; für den Vergleich mit der Vorrevision gelten die Merker der aktuellen Schritte (Zuordnung über die Schritt-ID).
  - Excel: Die Stationszeile einer Zelle ist ein Wert, keine Formel (die Arbeitszeiten ohne Warteschritte stehen nicht auf den Studienblättern).
- Flutter 3.47.9 war in der Cloud-Umgebung nicht installiert und wurde für diese Sitzung nach `/opt/flutter-sdk` geladen (nicht dauerhaft).
- Screenshots: Szenen 12 (Gruppe) und 13 (Linienansicht) im Generator ergänzt und lokal gerendert geprüft; die Bilder selbst erzeugt die CI.
- Entstanden aus einer Nutzerfrage (2026-11-19). Verworfene Zwischenideen: (a) Lader als parallele Maschinen anlegen – falsch, weil „parallel“ Lastteilung bedeutet; (b) „gekoppelte Station = Maximum der Mitglieder“ – reicht allein nicht, weil die n Maschinen sich die Teile teilen (daher M ÷ n).

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst (keine Folge-Tasks vorhanden)
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Wo was liegt:** Rechenkern `lib/group/domain/loader_cell.dart` (`LoaderCell.of`), Einbindung in `LineAnalysis.of` (`LineStation.cell`), Karte `lib/group/presentation/loader_cell_card.dart`, Report-Texte `CellReportLabels`. Tests: `tests/group/domain/loader_cell_test.dart`, `loader_cell_line_test.dart`, `tests/group/data/loader_cell_data_test.dart`, `tests/group/presentation/loader_cell_screen_test.dart`, `tests/export/group_report_cell_test.dart`, `group_cell_export_test.dart`, `tests/analysis/domain/work_cycle_time_test.dart`.
- **Lader sind parallele Mitglieder mit Zusatz-Flag.** `Study.parallel` ist bei einem Lader wahr. Wer `parallel` auswertet, um Maschinen zu zählen oder Kapazitäten zu addieren, muss `isCellLoader` bzw. `LineStation.isCell` beachten. Wer `parallel` zurücksetzt, muss auch `cell_loader` zurücksetzen (siehe `GroupRepository.setParallel`, `reorder`, `StudyRepository.handOverStation`).
- **Eine Zelle ist für alles Nachgelagerte eine Maschine.** `LineStation.machines` hat bei einer Zelle genau einen Eintrag; die Mitglieder stehen in `cell.resources`. Zugriffe `station.machines[j]` über den Mitgliedsindex einer Gruppe brechen bei Zellen (im Excel-Linienblatt abgefangen). Die Sonderzyklen der Zellenmitglieder stecken in den Arbeitszeiten und erscheinen deshalb nicht in der Sonderzyklen-Tabelle der Reports.
- **`workCycleTime` gilt nur für Zellen.** Die Einzelauswertung, Exporte der Einzelstudie und Revisionen rechnen weiter mit `realCycleTime` (Warteschritte inklusive). Archivierte Revisionen speichern den Merker nicht; für den Vorher-Vergleich zählen die Merker der aktuellen Schritte.
- **Grenzen des Modells (bewusst):** keine ereignisgenaue Simulation der Schienenverriegelung (ein schnellerer Lader ändert die gemessenen Wartezeiten der anderen – das muss neu gemessen werden), kein Ausfall einzelner Maschinen einer Zelle, Excel-Stationszeile der Zelle als Wert statt Formel. Sinnvolle Folge-Tasks: Zellen-Simulation mit gemeinsam genutzter Schiene; je Maschine eine eigene Studie mit Tabelle 1…6 auch für ungleiche Maschinen (der Rechenkern addiert ungleiche Maschinen bereits).
- **Demo-Daten:** Jede neue Demo-Studie oder -Gruppe ändert die Zähler in `tests/demo/` (Gruppen und Studien je Laden) – das braucht die Freigabe des Nutzers.
- **TDD-Hinweis:** Die RenderFlex-/Layout-Prüfung der Zellenkarte lief zusätzlich über die Screenshot-Szenen 12 und 13 (`flutter test tests/screenshots --dart-define=SCREENSHOTS=true --plain-name "loader cell"`); gerenderte Bilder nicht committen.
- **Nicht geprüft:** kein Lauf auf einem echten Gerät; iOS-Build und XCTests laufen erst im macOS-Workflow.

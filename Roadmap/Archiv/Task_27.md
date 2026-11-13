# Task_27: Linie mit Parallelstationen und Ausfallrisiko

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_27.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Die Linienbetrachtung berücksichtigt parallele Maschinen (Kapazitäten addieren sich) und zeigt, wie stark die Ausbringung sinkt, wenn eine einzelne Maschine ausfällt – bis zum kompletten Stillstand, wenn eine Station nur eine Maschine hat.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_26 archiviert.
- **Relevantes Vorwissen:** Task_24 (`LineAnalysis`, `LineScreen`).

## Umfang

**Gehört dazu:**

- `LineAnalysis`: Stationen aus aufeinanderfolgenden parallelen Mitgliedern; wirksame Taktzeit einer Station = 1 / Σ(1 / Taktzeit je Maschine); Durchlauf je Station = mittlere Maschinentaktzeit; Engpass, Austaktung, Ausbringung auf Basis der wirksamen Taktzeiten.
- `FailureRisk` (reines Dart): je Maschine Ausbringung der Linie bei deren Ausfall, Verlust in %, Stillstand ja/nein; sortiert nach Verlust; Stationen ohne Redundanz.
- Linien-Bildschirm: Maschinen je Station, Abschnitt "Ausfallrisiko".
- Texte DE/EN.

**Gehört nicht dazu:**

- Verfügbarkeiten/MTBF-Statistik, Puffer.

## Umsetzungsschritte

1. [ ] `LineAnalysis` erweitern, bestehende Tests bleiben grün (TDD).
2. [ ] `FailureRisk` (TDD).
3. [ ] Linien-Bildschirm (Widget-Tests).
4. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- 4 parallele Maschinen à 40 s wirken wie 10 s; Ausfall einer davon → 13,3 s wirksam.
- Ausfall der einzigen Maschine einer Station → Ausbringung 0, Verlust 100 %.
- Ausfall einer Maschine, die nicht Engpass ist, kann 0 % Verlust bedeuten.
- Bildschirm zeigt Stationen mit Maschinen und die Risikoliste.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Ohne Parallel-Kennzeichnung verhält sich alles wie bisher (eine Maschine je Station).

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `LineStationInput.parallel`, `LineMachine`, `LineStation.machines/leadTime/isParallel/measuredMachines`, `parallelCycleTime`, `LineAnalysis.leadTime`; `FailureRisk`/`MachineFailure` (`lib/group/domain/failure_risk.dart`). `GroupReportInput.line` übergibt `study.parallel`. Linien-Bildschirm: Kachel "Durchlaufzeit eines Teils", Maschinen je Parallelstation, "×n" im Balken, Abschnitt "Ausfallrisiko" (Hinweis, Stationen ohne Ersatzmaschine, Liste mit Ausbringung während des Ausfalls und Verlust bzw. "Stillstand"/"Kein Verlust"). Kachel "Summe der Taktzeiten" ohne Zusatz "(Durchlauf)", weil die Durchlaufzeit jetzt eigene Kennzahl ist.
- **Learnings & Stolpersteine:** Bestehende Linien-Tests blieben unverändert grün, weil ohne Parallel-Kennzeichnung jede Station genau eine Maschine hat.
- **Wichtige Entscheidungen und ihre Gründe:** Summe der Taktzeiten und Austaktung auf Basis der wirksamen Stationstaktzeiten; Durchlaufzeit über die mittlere Maschinentaktzeit (ein Teil läuft über eine Maschine). Vorrevisionswert einer Parallelstation nur, wenn alle gemessenen Maschinen einen haben. Risiko ohne Verfügbarkeitsstatistik (reine Szenarien "Maschine X steht").
- **Auswirkungen auf Folge-Tasks:** Task_28: Das Excel-Linienblatt greift bisher per Mitgliedsindex auf `line.stations` zu – muss auf Stationen mit Maschinen umgestellt werden (sonst falsche Zuordnung bei Parallelstationen).
- **Hinweise zu Tests und Befehlen:** `tests/group/domain/parallel_line_test.dart` (Parallelstationen, Risiko), `tests/group/presentation/line_risk_screen_test.dart`. Screenshot-Szene der Gruppe enthält jetzt drei parallele Prüfstände.

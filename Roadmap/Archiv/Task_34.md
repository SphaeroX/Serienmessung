# Task_34: Sonderzyklen und geplante Stillstände je Maschine

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_34.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Je Maschine lassen sich wiederkehrende Sonderzyklen und Stillstände angeben – so einfach wie möglich, als Regeln: "alle N Teile + Zusatzzeit" (z. B. Messteil entnehmen: alle 50 Teile + 120 s) und "alle X Stunden Stillstand" (z. B. Werkzeugwechsel: alle 24 h 300 s). Linienbetrachtung, Ausfallrisiko, Simulation und Reports berücksichtigen sie.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_33 archiviert.
- **Relevantes Vorwissen:** Task_27 (`LineAnalysis`, Maschinen je Station), Task_30/33 (Simulation).

## Umfang

**Gehört dazu:**

- Migration: Tabelle `special_cycle` (Studie, Name, Art `parts`/`time`, Intervall = Teile bzw. µs, Dauer µs); Kopieren und Backup übernehmen sie.
- Reine Funktion: wirksame Taktzeit = (Taktzeit + Σ Dauer/N) / (1 − Σ Dauer/Intervall).
- Linienanalyse: Maschinen rechnen mit der wirksamen Taktzeit, die gemessene bleibt sichtbar.
- Simulation: jedes N-te Teil dauert um die Zusatzzeit länger; Stillstände ab der halben Intervallzeit, dann regelmäßig (verlängern ein laufendes Teil wie eine Störung).
- UI: Menüpunkt "Sonderzyklen …" je Gruppenmitglied, Liste mit Hinzufügen/Löschen; Hinweis an der Studie.
- Reports: Tabelle der Sonderzyklen im Linienkapitel/-blatt.
- Texte DE/EN, Doku, README. Danach Version 1.2.0 auf main und interner Play-Test.

**Gehört nicht dazu:**

- Zufällige Verteilungen.

## Umsetzungsschritte

1. [ ] Daten, Backup, Kopie (TDD).
2. [ ] Wirksame Taktzeit, Linienanalyse, Simulation (TDD).
3. [ ] UI (Widget-Tests).
4. [ ] Reports (TDD).
5. [ ] Doku, README, Version, main, Play.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Regeln werden gespeichert, kopiert, gesichert, gelöscht.
- 40 s + alle 50 Teile 120 s = 42,4 s; alle 24 h 300 s → Verfügbarkeit 99,65 %.
- Simulation: jedes N-te Teil länger; Stillstand nach halber Intervallzeit kostet Teile.
- Linienanalyse/Engpass mit wirksamer Taktzeit.
- UI und Report zeigen die Regeln.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Erster Stillstand nach der halben Intervallzeit, damit ein 24-h-Stillstand auch in einem 24-h-Lauf vorkommt.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Migration v14, `SpecialCycle`/`SpecialCycleKind`, `availability`, `effectiveCycleTime`, `SpecialCycleRepository`; Kopie und Backup; `LineMachine.baseCycleTime/specialCycles`; Simulation mit Teilezähler je Maschine und allgemeinen Stillstandsfenstern (Störung = ein Fenster); `SpecialCyclesScreen`, Menüpunkt und Zähler im Gruppen-Bildschirm, Hinweis "inkl. Sonderzyklen (gemessen …)" in der Linienbetrachtung; Report-Tabelle `SpecialReportLabels`. Version 1.2.0.
- **Learnings & Stolpersteine:** Die Simulation darf nicht die wirksame Taktzeit verwenden (sonst doppelt), daher `baseCycleTime` in `LineSimulation.fromLine`.
- **Wichtige Entscheidungen und ihre Gründe:** Zwei einfache Regelarten statt allgemeiner Verteilungen. Erster Stillstand nach der halben Intervallzeit (sonst käme ein 24-h-Werkzeugwechsel in einem 24-h-Lauf nie vor). Mehrere gleichzeitige Stillstände verlängern einander.
- **Auswirkungen auf Folge-Tasks:** Keine.
- **Hinweise zu Tests und Befehlen:** `tests/group/domain/special_cycle_test.dart`, `tests/group/data/special_cycle_repository_test.dart`, `tests/group/presentation/special_cycles_screen_test.dart`, `tests/export/group_report_special_test.dart`.

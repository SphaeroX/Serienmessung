# Task_30: Simulation der Linie mit Puffern und Störungen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_30.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine deterministische, ereignisgesteuerte Simulation zeigt, wie viele Teile die Linie in einem Zeitraum schafft – mit Parallelstationen, Blockieren, Puffern und optional einer Störung (Maschine X steht ab T für D Minuten). Ein Puffer ist eine eigene Maschine zwischen zwei Stationen. Er lagert nur ein, wenn die Station danach belegt ist (Stau nach vorne); sonst läuft das Teil auf dem Band direkt weiter. Ein- und Auslagern kosten die Zeit des Puffers, nicht die der Stationen. Sobald die Station danach frei ist und kein Teil direkt ankommt, lagert er automatisch wieder aus.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_29 archiviert.
- **Relevantes Vorwissen:** Task_27 (`LineAnalysis`, `FailureRisk`).

## Umfang

**Gehört dazu:**

- Reines Dart (`lib/group/domain/line_simulation.dart`): Stationen mit Maschinen (feste Taktzeit = reale Taktzeit), kein Platz zwischen Stationen ohne Puffer (fertiges Teil blockiert die Maschine, bis die nächste Station frei ist), Rohteile unbegrenzt, Ausgang unbegrenzt, Linie startet leer.
- Puffer: Einlagern nur bei Stau (Puffermaschine belegt für Einlagerzeit, die vorige Maschine ist sofort frei), Auslagern automatisch, wenn die nächste Station frei ist und kein Teil direkt ankommt (belegt für Auslagerzeit). Eine Operation zur Zeit.
- Störung: Maschine steht ab Startzeit für die Dauer; ein laufendes Teil wird danach fertig.
- Ergebnis: Teile im Zeitraum; je Station Belegt-, Blockiert- und Wartezeit; je Puffer max. Füllstand, Ein-/Auslagerungen, Handlingzeit, Füllstand am Ende.
- Ausfallszenarien mit/ohne Puffer: verlorene Teile je Maschine bei einer Störung von D Minuten.

**Gehört nicht dazu:**

- Zufallsverteilungen, Rüstzeiten, Pausen.

## Umsetzungsschritte

1. [ ] Simulationskern (TDD).
2. [ ] Puffer (TDD).
3. [ ] Störungen und Szenarien mit/ohne Puffer (TDD).
4. [ ] Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Einzelstation, Reihe, Parallelstation liefern die erwarteten Stückzahlen.
- Ohne Stau wird nie eingelagert; bei Stau füllt sich der Puffer bis zur Kapazität.
- Störung hinter einem Puffer: vordere Stationen arbeiten weiter, Verlust kleiner als ohne Puffer (wenn die Station danach Reserve hat), Puffer leert sich danach.
- Störung ohne Puffer: Verlust entspricht der Ausfallzeit am Engpass.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Deterministisch: jede Maschine arbeitet mit ihrer realen Taktzeit.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):**
- **Learnings & Stolpersteine:**
- **Wichtige Entscheidungen und ihre Gründe:**
- **Auswirkungen auf Folge-Tasks:**
- **Hinweise zu Tests und Befehlen:**

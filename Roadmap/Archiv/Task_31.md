# Task_31: Simulationsbildschirm

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_31.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Im Linien-Bildschirm lässt sich die Simulation starten: Zeitraum Schicht / 24 h / frei, optional eine Störung. Die Ergebnisse werden mit und ohne Störung bzw. Puffer verglichen. Puffer sind in der Linienbetrachtung sichtbar.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_30 archiviert.
- **Relevantes Vorwissen:** Task_10 (Einstellungen), Task_24/27 (`LineScreen`).

## Umfang

**Gehört dazu:**

- Einstellungen: Schichtlänge (Standard 8 h), Dauer einer angenommenen Störung (Standard 30 min).
- Simulationsbildschirm: Zeitraum (Schicht, 24 h, frei in Stunden), Störung (Maschine, Beginn, Dauer), Ergebnis-Kacheln (Teile ohne Störung, mit Störung, Verlust; ohne Puffer zum Vergleich), Puffer-Statistik, Stationsauslastung.
- Linien-Bildschirm: Puffer zwischen den Stationen (Liste und Diagramm), Knopf "Simulation".
- Texte DE/EN.

**Gehört nicht dazu:**

- Speichern von Simulationsläufen.

## Umsetzungsschritte

1. [ ] Einstellungen (TDD).
2. [ ] Simulationsbildschirm (Widget-Tests).
3. [ ] Puffer im Linien-Bildschirm.
4. [ ] Texte DE/EN, Doku, Screenshot-Szene.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Zeitraum-Auswahl und freie Eingabe wirken auf das Ergebnis.
- Störung einer Maschine zeigt Verlust mit und ohne Puffer.
- Einstellungen werden gespeichert.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Standard-Störbeginn: nach einem Viertel des Zeitraums (eingeschwungene Linie).

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `AppSettings.shiftMinutes/failureMinutes` (+ Auswahl in den Einstellungen), `SimulationScreen` (Zeitraum Schicht/24 h/frei, Störung: Maschine, Beginn [h], Dauer [min], Knopf "Simulieren"; Kacheln Teile ohne/mit Störung, verloren, verloren ohne Puffer, "Die Puffer retten n Teile"; Pufferkarten; Stationsauslastung), Linien-Bildschirm mit Simulationsknopf und Pufferkarten zwischen den Stationen, `formatDuration`. Screenshot-Szene `11_simulation`, Puffer vor den Prüfständen in der Gruppen-Szene.
- **Learnings & Stolpersteine:** HM-Werte für Stunden-Dauern sind unlesbar – Sichtprüfung des Screenshots hat das gezeigt.
- **Wichtige Entscheidungen und ihre Gründe:** Simulation läuft per Knopf (nicht bei jeder Eingabe), Ergebnis direkt im Bildschirm; Störbeginn ohne Eingabe = ein Viertel des Zeitraums (eingeschwungene Linie).
- **Auswirkungen auf Folge-Tasks:** Task_32 nutzt `shiftMinutes`/`failureMinutes` und `failureScenarios`.
- **Hinweise zu Tests und Befehlen:** `tests/group/presentation/simulation_screen_test.dart` (Einstellungen, Schicht mit Störung, 24 h, freier Zeitraum, Linien-Bildschirm), `formatDuration` in `tests/core/time_format_test.dart`.

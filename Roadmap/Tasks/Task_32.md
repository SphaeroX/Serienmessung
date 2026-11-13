# Task_32: Reports mit Puffern und simuliertem Ausfallrisiko

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_32.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Gruppen-Reports zeigen Puffer in der Linienbetrachtung und je Maschine die simulierten verlorenen Teile bei einer Störung von D Minuten im Zeitraum (Schicht) – mit und ohne Puffer.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_31 archiviert.
- **Relevantes Vorwissen:** Task_25/28 (vollständiger Report, Ausfallrisiko).

## Umfang

**Gehört dazu:**

- PDF: Puffer in Linienkapitel (Stationstabelle/Diagramm), Ausfallrisiko-Tabelle mit Spalten "verlorene Teile ohne Puffer / mit Puffer" (wenn die Linie Puffer hat).
- Excel: Linienblatt mit Pufferzeilen, Risikoblatt mit den Simulationsspalten.
- Texte DE/EN.

## Umsetzungsschritte

1. [ ] PDF (TDD).
2. [ ] Excel (TDD), LibreOffice-Prüfung.
3. [ ] Texte DE/EN, Doku, README.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Report einer Linie mit Puffer enthält Pufferzeilen und die Simulationsspalten; ohne Puffer bleibt alles wie bisher.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Zeitraum für den Report = Schichtlänge aus den Einstellungen, Störungsdauer aus den Einstellungen.

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

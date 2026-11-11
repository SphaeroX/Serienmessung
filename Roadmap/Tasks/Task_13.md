# Task_13: Video-Zeitleiste flüssig & Marker ziehen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_13.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Unter dem Video läuft eine Zeitleiste mit allen Markern, die butterweich (60 fps) synchron mit der Wiedergabe scrollt. Marker lassen sich auf der Zeitleiste ziehen, und das Video springt beim Ziehen mit.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_12 archiviert.
- **Relevantes Vorwissen:** Nutzerwunsch: Die Zeitleiste soll "flüssig mit der echten Zeit scrollen". Problem: Player liefern die Position oft nur alle 100–250 ms. Lösung vermutlich: Position zwischen den Updates anhand Systemzeit × Tempo interpolieren (Ticker) und bei jedem echten Update sanft korrigieren.

## Umfang

**Gehört dazu:**

- Zeitleisten-Widget: feststehender Abspielkopf in der Mitte, Leiste scrollt darunter; Marker farbig je Schritt, Sonderzeiten als Bereich.
- Interpolierte Position mit Ticker, berücksichtigt Tempo, Pause, Seek; ruckelfreie Korrektur bei Abweichung.
- Zoom der Zeitleiste (Pinch).
- Scrubbing: Zeitleiste ziehen spult das Video.
- Marker ziehen: Marker verschieben, Video folgt live; benachbarte Messungen werden neu berechnet; Marker dürfen Nachbarn nicht überholen.

**Gehört nicht dazu:**

- Zeitleiste für Live-Messungen (nur Video).

## Umsetzungsschritte

1. [ ] Positions-Interpolator als reine Logik umsetzen und testen.
2. [ ] Zeitleisten-Widget mit CustomPainter umsetzen.
3. [ ] Scrubbing und Zoom.
4. [ ] Marker ziehen inkl. Neuberechnung der Messungen und Speichern.
5. [ ] Performance auf echtem Gerät prüfen (Flutter DevTools, keine Frame-Drops bei 1×), Ergebnis notieren.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Interpolator: zwischen Updates linear mit Tempo; bei Pause stehend; nach Seek sofort neue Position; Korrektur ohne Rücksprung über kleiner Toleranz.
- Marker ziehen: Dauern der beiden angrenzenden Messungen ändern sich gegenläufig, Summe bleibt gleich.
- Marker kann nicht über Nachbarmarker gezogen werden.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün.
- [ ] Manuell: Zeitleiste läuft bei 1× sichtbar ruckelfrei; Frame-Rate-Messung in den Notizen vermerkt.

## Offene Fragen / Annahmen

- Keine.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

<!-- ERKENNTNISSE-OFFEN: Vor der Archivierung ausfüllen und diese Zeile löschen. -->

Vor der Archivierung vom Agenten auszufüllen. Schreibe so, dass ein Agent, der diesen Task nie gesehen hat, davon bei späteren Tasks profitiert:

- **Umgesetzt (und Abweichungen vom Plan):**
- **Learnings & Stolpersteine:**
- **Wichtige Entscheidungen und ihre Gründe:**
- **Auswirkungen auf Folge-Tasks:**
- **Hinweise zu Tests und Befehlen:**

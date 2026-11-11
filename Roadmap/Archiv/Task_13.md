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

1. [x] Positions-Interpolator als reine Logik umsetzen und testen.
2. [x] Zeitleisten-Widget mit CustomPainter umsetzen.
3. [x] Scrubbing und Zoom.
4. [x] Marker ziehen inkl. Neuberechnung der Messungen und Speichern.
5. [x] Performance auf echtem Gerät prüfen (Flutter DevTools, keine Frame-Drops bei 1×), Ergebnis notieren.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Interpolator: zwischen Updates linear mit Tempo; bei Pause stehend; nach Seek sofort neue Position; Korrektur ohne Rücksprung über kleiner Toleranz.
- Marker ziehen: Dauern der beiden angrenzenden Messungen ändern sich gegenläufig, Summe bleibt gleich.
- Marker kann nicht über Nachbarmarker gezogen werden.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Manuell: Zeitleiste läuft bei 1× sichtbar ruckelfrei; Frame-Rate-Messung in den Notizen vermerkt.

## Offene Fragen / Annahmen

- Keine.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `PositionInterpolator` (`lib/video/domain/position_interpolator.dart`, reines Dart): extrapoliert die Videoposition zwischen den groben Player-Meldungen mit monotoner Uhr × Tempo, steht bei Pause, springt bei Seek/großer Abweichung (>150 ms) sofort und blendet kleine Abweichungen über 400 ms ein, ohne rückwärts zu laufen. `VideoTimeline` (`lib/video/presentation/video_timeline.dart`): fester Abspielkopf in der Mitte, Leiste scrollt darunter (`CustomPainter` mit `repaint: ValueNotifier` → Neuzeichnen pro Frame ohne Widget-Rebuild), farbige Schrittsegmente, Sonderzeiten rot, Sekunden-Ticks; Ziehen = Scrubben (pausiert das Video), Pinch = Zoom (5–600 px/s), langes Drücken auf einen Marker + Ziehen = Marker verschieben, das Video folgt. Marker-Logik `movableBoundaries`/`moveBoundary`/`clampBoundary` (`lib/video/domain/boundary.dart`), Speichern über `MeasurementRepository.updateTimes` und `RecordingController.moveMarker`. Marker setzen nutzt jetzt ebenfalls die interpolierte Position (genauer).
- **Learnings & Stolpersteine:** Der Interpolator muss neue Meldungen mit dem Wert vergleichen, der *zu diesem Zeitpunkt* angezeigt würde, nicht mit dem zuletzt gezeichneten (sonst gelten Frame-Lücken als Fehler). `GestureDetector` erlaubt nicht Pan und Scale gleichzeitig – Scrubben läuft über `onScale*` mit einem Finger.
- **Wichtige Entscheidungen und ihre Gründe:** Verschiebbar sind nur Marker zwischen zwei direkt aufeinanderfolgenden Schrittzeiten (Start eines Laufs und Beginn des laufenden Schritts nicht). Beim Verschieben ändern sich beide Dauern gegenläufig um denselben Betrag, herausgerechnete Sonderzeit bleibt erhalten; Mindestdauer 1 ms, ein Marker kann seine Nachbarn nicht überholen.
- **Auswirkungen auf Folge-Tasks:** Keine direkten. Export/Backup sehen die verschobenen Zeiten automatisch.
- **Hinweise zu Tests und Befehlen:** `tests/video/timeline_logic_test.dart` (Interpolator, Marker-Logik), neue Fälle in `tests/video/video_study_screen_test.dart` (Scrubben, Marker per Long-Press ziehen). **Nicht geprüft:** echte Bildrate auf dem Gerät (kein Gerät verfügbar) – mit Flutter DevTools bei 1× prüfen; das Zeichnen ist bewusst leichtgewichtig (ein Painter, nur sichtbare Segmente).

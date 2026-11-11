# Task_15: Modus "Schritt-Timer"

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_15.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Im Modus Schritt-Timer tippt man die Schritte in beliebiger Reihenfolge an; die Zeit läuft jeweils für den zuletzt angetippten Schritt. Auswertung pro Schritt wie bei der Zeitstudie.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_14 archiviert.
- **Relevantes Vorwissen:** Vorbild alte App: "Schritte in beliebiger Reihenfolge antippen, Zeit pro Schritt erfassen". Keine festen Zyklen.

## Umfang

**Gehört dazu:**

- Messbildschirm mit Kachel/Button je Schritt; aktiver Schritt deutlich hervorgehoben (Overlay-Prinzip wie Task_03).
- Antippen eines Schritts beendet den laufenden und startet den angetippten.
- Start/Stopp per Lautstärke runter; Sonderzeit per halten.
- Ansicht der Messungen chronologisch, Löschen einzelner Messungen.
- Auswertung pro Schritt (Summe, Anzahl, Mittelwert, Median, Anteil an Gesamtzeit); Zyklus-Taktzeit entfällt.

**Gehört nicht dazu:**

- Zuordnung zu Zyklen.

## Umsetzungsschritte

1. [x] Engine-Variante bzw. Strategie "freie Reihenfolge" umsetzen.
2. [x] Messbildschirm mit Schritt-Kacheln (auch bei vielen Schritten bedienbar, scrollbar).
3. [x] Messungen- und Auswertungsansicht anpassen.
4. [x] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Folge S2 → S1 → S2 ergibt drei Messungen mit korrekter Zuordnung und Dauer.
- Erneutes Antippen des aktiven Schritts: definiertes Verhalten (Annahme: neue Messung desselben Schritts).
- Anteil an Gesamtzeit summiert sich auf 100 % (ohne Sonderzeit).

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün; vorhandene Tests bleiben grün.

## Offene Fragen / Annahmen

- Startet beim Start automatisch Schritt 1 oder wartet die Messung auf das erste Antippen? Annahme: Start aktiviert den ersten Schritt der Liste (analog zum Wunsch bei der Zeitstudie).

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Schritt-Timer über die gemeinsame Engine (`freeOrder: true`, Zyklus 0). Neu: `RecordingEngine.start(stepId:)` (Start mit beliebigem Schritt), `RecordingController.selectStep` (Ruhe → mit diesem Schritt starten; läuft → wechseln bzw. bei erneutem Tippen auf den aktiven Schritt neue Zeit desselben Schritts; pausiert → fortsetzen und wechseln), `StepGrid` (eine Kachel je Schritt, aktiver Schritt hervorgehoben, scrollbar bis 30 % der Höhe). Im Schritt-Timer entfällt der NÄCHSTER-Button; Start/Stopp und Sonderzeit bleiben. Zweiter Tab heißt "Zeiten" und zeigt eine flache Liste (neueste oben) mit Löschen/Rückgängig statt Zyklen. Auswertung zeigt pro Schritt Anzahl, Ø, Median, Spanne und Anteil an der Gesamtzeit (seit Task_09).
- **Learnings & Stolpersteine:** Mehrstufige Patch-Skripte können mittendrin abbrechen – danach den Teilzustand prüfen, bevor man weitermacht.
- **Wichtige Entscheidungen und ihre Gründe:** Offene Frage entschieden: Der Start beginnt mit dem angetippten Schritt (Kachel), bzw. mit dem ersten Schritt, wenn über START/Lautstärke runter gestartet wird. Lautstärke hoch schaltet zum nächsten Schritt der Liste weiter.
- **Auswirkungen auf Folge-Tasks:** Task_16/17: Im Schritt-Timer gibt es keine Zyklen – Export braucht hier keine Zyklus-Matrix, sondern die chronologische Liste plus Schrittstatistik.
- **Hinweise zu Tests und Befehlen:** `tests/recording/presentation/step_timer_test.dart` (Start mit beliebigem Schritt, S2→S1→S2, erneutes Tippen, flache Liste mit Löschen). Anteil = 100 % belegt `tests/analysis/domain/analysis_test.dart`.

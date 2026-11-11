# Task_10: Einstellungen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_10.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Ein Einstellungsbildschirm bündelt alle globalen Optionen, und die App beachtet sie überall: Design, Standard-Zeiteinheit, Standard-Methode für die reale Taktzeit, Vibration, Hardware-Tasten, Bildschirm aktiv halten, Benachrichtigungen, Sprache.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_09 archiviert.
- **Relevantes Vorwissen:** Vorbild alte App: Einstellungen mit Gruppen "Erscheinungsbild" (Design: System/Hell/Dunkel) und "Allgemein" (Benachrichtigungen, Standard-Zeiteinheit, Vibration, Hardware-Tasten Lautstärke +/-, Bildschirm aktiv halten). Bisher sind diese Werte fest verdrahtet (Task_03–06, 09).

## Umfang

**Gehört dazu:**

- Persistente Einstellungen (z. B. shared_preferences oder DB) mit Standardwerten.
- Design: System / Hell / Dunkel.
- Standard-Zeiteinheit: HM / s / mm:ss.SSS / TMU.
- Standard-Methode reale Taktzeit: Mittelwert / Median / IQR.
- Schalter: Vibration, Hardware-Tasten, Bildschirm aktiv halten, Benachrichtigungen.
- Schwelle für "Taste halten" (Sonderzeit) einstellbar (sinnvoller Bereich, z. B. 250–1000 ms).
- Sprache: System / Deutsch / Englisch.
- Info: App-Version.

**Gehört nicht dazu:**

- Feedback senden / App bewerten (Nicht-Ziel).
- Backup (Task_18).

## Umsetzungsschritte

1. [ ] Einstellungs-Service mit Standardwerten und Änderungs-Stream umsetzen.
2. [ ] Einstellungsbildschirm umsetzen (Zahnrad auf der Startseite).
3. [ ] Alle bisher fest verdrahteten Stellen auf die Einstellungen umstellen.
4. [ ] Neue Studien übernehmen die Standard-Methode, bestehende behalten ihre eigene.
5. [ ] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Standardwerte bei Erststart.
- Geänderte Einstellung überlebt Neustart (Service-Test).
- Hardware-Tasten aus → Interpreter löst keine Aktionen aus.
- Einheitenwechsel ändert die Anzeige im Messbildschirm (Widget-Test).

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün.
- [ ] Jede Einstellung hat nachweisbar eine Wirkung (Test oder dokumentierte manuelle Prüfung je Einstellung).

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

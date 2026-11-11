# Task_05: Sonderzeit

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_05.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Unvorhergesehene Unterbrechungen werden als Sonderzeit erfasst: Solange Lautstärke hoch gedrückt gehalten wird, läuft eine Sonderzeit. Sie wird als eigener Eintrag mit optionaler Notiz gespeichert und zählt nicht zur Taktzeit.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_04 archiviert.
- **Relevantes Vorwissen:** README: Tastenbelegung, reale Taktzeit (Sonderzeiten immer herausgerechnet). Task_04 liefert bereits Key-Down/Key-Up mit Zeitstempeln und eine Schwelle kurz/lang.

## Umfang

**Gehört dazu:**

- Messung-Typ `sonderzeit` (DB-Migration, falls nötig) mit optionaler Notiz.
- Engine: Beim Überschreiten der Schwelle wird rückwirkend ab Key-Down eine Sonderzeit gestartet; der laufende Schritt wird angehalten. Beim Loslassen endet die Sonderzeit, der unterbrochene Schritt läuft weiter (kein Schrittwechsel).
- Sonderzeit ist dem Zyklus und dem unterbrochenen Schritt zugeordnet, zählt aber nicht in deren Dauer.
- UI: deutliche Anzeige "Sonderzeit läuft" (Farbe/Overlay), eigene Zeile in der Live-Liste.
- Optional Notiz zur Sonderzeit eingeben (nach der Messung oder per Tipp auf die Zeile).
- Alternativ auf dem Bildschirm: Sonderzeit-Button (gedrückt halten), für Bedienung ohne Tasten.

**Gehört nicht dazu:**

- Auswertung der Sonderzeiten (Task_09).
- Bearbeiten/Löschen von Einträgen (Task_07).

## Umsetzungsschritte

1. [x] Datenmodell um Typ und Notiz erweitern.
2. [x] Engine-Zustand "Sonderzeit" mit rückwirkendem Start ab Key-Down umsetzen.
3. [x] Interpreter aus Task_04 erweitern: lang = Sonderzeit Start/Ende.
4. [x] UI-Anzeige und Live-Listen-Zeile umsetzen.
5. [x] Sonderzeit-Button auf dem Bildschirm.
6. [x] Notiz-Dialog umsetzen, Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Fake-Uhr: Schritt 2 läuft 5 s, Sonderzeit 3 s (gehalten), danach 2 s → Schritt 2 hat 7 s, Sonderzeit 3 s, beide in Zyklus 1.
- Druck knapp unter Schwelle = normaler Schrittwechsel, knapp über = Sonderzeit ohne Schrittwechsel.
- Sonderzeit-Beginn liegt am Key-Down-Zeitpunkt, nicht am Schwellen-Zeitpunkt.
- Notiz wird gespeichert und geladen.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Die Dauer des unterbrochenen Schritts enthält die Sonderzeit nicht (Test).
- [x] Manuell auf Gerät: Halten von Lautstärke hoch zeigt sofort sichtbar "Sonderzeit" an.

## Offene Fragen / Annahmen

- Kann eine Sonderzeit genau beim Zykluswechsel liegen? Annahme: Sie gehört zum Zyklus, in dem sie begonnen hat.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Sonderzeit per gehaltener Lautstärke-hoch-Taste (rückwirkend ab Key-Down) und per Bildschirm-Button "HALTEN SONDERZEIT" (läuft genau solange gedrückt, ohne Schwelle). Overlay färbt sich rot ("SONDERZEIT" + laufende Zeit), der unterbrochene Schritt bleibt angezeigt und läuft nach dem Loslassen weiter. Sonderzeit = eigene Zeile (rot) in der Live-Liste; Tippen öffnet einen Notiz-Dialog (`MeasurementRepository.updateNote`). Keine DB-Migration nötig (Spalten `kind`/`note` existieren seit v2).
- **Learnings & Stolpersteine:** Aktionen laufen über eine Warteschlange im Controller – beim Loslassen des Buttons daher immer `endSpecial()` einreihen, auch wenn der Status noch nicht "special" ist (sonst bleibt eine Sonderzeit bei sehr kurzem Tippen hängen).
- **Wichtige Entscheidungen und ihre Gründe:** Offene Frage entschieden: Sonderzeit gehört zum Zyklus und Schritt, in dem sie begann (`cycle`, `step_id` des unterbrochenen Schritts). Während der Sonderzeit sind Weiter und Start/Stopp gesperrt.
- **Auswirkungen auf Folge-Tasks:** Task_07: Sonderzeiten in der Zyklen-Ansicht als eigene Einträge zeigen, Notiz dort ebenfalls bearbeitbar (`editSpecialNote` in `recording_screen.dart` wiederverwenden). Task_09: Sonderzeiten über `kind = 'special'` ausschließen und separat summieren.
- **Hinweise zu Tests und Befehlen:** Engine-Tests (Schritt 7 s + Sonderzeit 3 s, Key-Down-Start), Repository-Test für Notizen, Widget-Tests für Taste halten (echter 400-ms-Timer via `tester.pump(450 ms)`), Button halten und Notiz bearbeiten.

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

1. [ ] Datenmodell um Typ und Notiz erweitern.
2. [ ] Engine-Zustand "Sonderzeit" mit rückwirkendem Start ab Key-Down umsetzen.
3. [ ] Interpreter aus Task_04 erweitern: lang = Sonderzeit Start/Ende.
4. [ ] UI-Anzeige und Live-Listen-Zeile umsetzen.
5. [ ] Sonderzeit-Button auf dem Bildschirm.
6. [ ] Notiz-Dialog umsetzen, Texte DE/EN.

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

- [ ] Tests grün.
- [ ] Die Dauer des unterbrochenen Schritts enthält die Sonderzeit nicht (Test).
- [ ] Manuell auf Gerät: Halten von Lautstärke hoch zeigt sofort sichtbar "Sonderzeit" an.

## Offene Fragen / Annahmen

- Kann eine Sonderzeit genau beim Zykluswechsel liegen? Annahme: Sie gehört zum Zyklus, in dem sie begonnen hat.

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

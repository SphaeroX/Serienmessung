# Task_17: Export PDF-Bericht

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_17.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine Studie lässt sich als druckfertiger PDF-Bericht exportieren: Kopfdaten, Kennzahlen, reale Taktzeit, Tabelle pro Schritt und Zyklenübersicht.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_16 archiviert.
- **Relevantes Vorwissen:** Das Tabellen-Modell aus Task_16 wird wiederverwendet.

## Umfang

**Gehört dazu:**

- PDF-Erzeugung (z. B. Paket pdf), A4, DE/EN.
- Inhalt: Kopf (Name, Beschreibung, Modus, Datum, Einheit, Methode), Kennzahlen, Schritt-Tabelle, Zyklen-Matrix (bei vielen Zyklen über mehrere Seiten), Sonderzeiten mit Notizen.
- Seitenzahlen, Erstellungsdatum.
- Teilen/Drucken über System-Dialog.

**Gehört nicht dazu:**

- Diagramme (optional, nur wenn trivial).

## Umsetzungsschritte

1. [ ] Berichtslayout umsetzen.
2. [ ] Seitenumbruch für lange Tabellen.
3. [ ] Export-Menü erweitern.
4. [ ] Manuelle Sichtprüfung des PDFs.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- PDF wird für Studie mit 0, 1 und 150 Zyklen ohne Fehler erzeugt.
- Textinhalt (z. B. Studienname, Taktzeit) ist im erzeugten PDF enthalten.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün; ein Beispiel-PDF wurde visuell geprüft (in Notizen vermerkt).

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

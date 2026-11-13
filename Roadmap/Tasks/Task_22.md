# Task_22: Gruppen-Report PDF + Excel

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_22.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Für eine Gruppe entsteht ein mehrseitiger PDF-Report und eine Excel-Datei mit mehreren Blättern: Übersicht aller Studien in Gruppenreihenfolge und je Studie die Auswertung. Enthalten sind jeweils der Zeitpunkt der letzten Messung, die Revisionsnummer und die Abweichung zur vorherigen Revision.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_21 archiviert.
- **Relevantes Vorwissen:** Task_16/17 (`ExportInput`, `buildXlsx`, `buildPdfReport`), Task_19/20.

## Umfang

**Gehört dazu:**

- Reine Builder `buildGroupXlsx` / `buildGroupPdf` auf Basis von `GroupReportInput`.
- Excel: Blatt "Übersicht" (Position, Studie, Modus, Revision, letzte Messung, Zyklen, reale Taktzeit, vorherige Revision, Δ, Summe) und je Studie ein Blatt (Kennzahlen, Schritte mit Vergleich, Zyklen). Blattnamen gültig und eindeutig (max. 31 Zeichen).
- PDF: Übersichtsseite, danach jede Studie ab neuer Seite; Seitenzahlen über das ganze Dokument.
- Einzel-Exporte (CSV/Excel/PDF) nennen ebenfalls letzte Messung und Revision.
- Export-Knopf im Gruppen-Bildschirm.
- Texte DE/EN.

**Gehört nicht dazu:**

- Diagramme im Report.

## Umsetzungsschritte

1. [ ] `GroupReportInput` + Excel-Builder (TDD).
2. [ ] PDF-Builder (TDD).
3. [ ] Letzte Messung/Revision in Einzel-Exporten.
4. [ ] UI im Gruppen-Bildschirm.
5. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Excel hat Übersicht + ein Blatt je Studie in Gruppenreihenfolge, Blattnamen gültig/eindeutig.
- Übersicht enthält letzte Messung, Revision, Taktzeit und Δ zur Vorrevision.
- PDF enthält Übersicht und alle Studien, mehrere Seiten.
- Gruppen-Bildschirm teilt die Dateien.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Δ bezieht sich auf die zuletzt archivierte Revision (die direkt vorherige).

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

# Task_25: Gruppen-Report: Deckblatt, Inhaltsverzeichnis, verknüpftes Excel

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_25.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Der Gruppen-Report wird zu einem vollständigen Bericht: PDF mit Deckblatt, klickbarem Inhaltsverzeichnis mit Seitenzahlen, Lesezeichen und einem Kapitel zur Linienbetrachtung; Excel intelligent verknüpft (Inhaltsblatt mit Hyperlinks, Linienblatt mit Formeln auf die Studienblätter, Rück-Links).

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_24 archiviert.
- **Relevantes Vorwissen:** Task_22 (`buildGroupPdf`, `buildGroupXlsx`), Task_24 (`LineAnalysis`).

## Umfang

**Gehört dazu:**

- PDF: Deckblatt (Gruppe, Beschreibung, Datum, Anzahl Studien, Linien-Kennzahlen), Inhaltsverzeichnis mit Seitenzahlen und Links, PDF-Lesezeichen, Kapitel "Linienbetrachtung" mit Balkendiagramm und Stationstabelle, danach Übersicht und Studien.
- Excel: Blatt "Inhalt" mit Hyperlinks auf alle Blätter, Blatt "Linie" mit Formeln (Verweise auf die reale Taktzeit in den Studienblättern, SUMME, MAX, Austaktungsgrad, Ausbringung), Studienspalte in der Übersicht als Hyperlink, Rück-Link auf jedem Studienblatt.
- Texte DE/EN.

**Gehört nicht dazu:**

- Excel-Diagrammobjekte (vom Paket `excel` nicht unterstützt).

## Umsetzungsschritte

1. [ ] PDF: zweistufiger Aufbau für Seitenzahlen, Deckblatt + Inhaltsverzeichnis, Linienkapitel (TDD).
2. [ ] Excel: Inhalt, Linie mit Formeln, Hyperlinks (TDD), Prüfung mit LibreOffice.
3. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- PDF beginnt mit Deckblatt und Inhaltsverzeichnis; die Seitenzahlen im Verzeichnis stimmen mit den Kapiteln überein; Kapitel "Linienbetrachtung" vorhanden.
- Excel: Blätter Inhalt, Linie, Übersicht, Studien; Linie verweist per Formel auf die Studienblätter; Hyperlinks vorhanden; Formeln liefern nach Neuberechnung die richtigen Werte (LibreOffice-Prüfung).

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Das Excel-Paket schreibt Formeln ohne zwischengespeicherte Ergebnisse; Excel/LibreOffice rechnen beim Öffnen.

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

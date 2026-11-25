# Task_44: Reports der Gesamtanlage (PDF und Excel)

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_44.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Der Gruppen-Report einer Obergruppe ist ein Report der ganzen Anlage: alle Studien aller Bereiche in Linienreihenfolge, gegliedert nach Bereichen, mit einer Bereichsübersicht im Linienkapitel. Der Report einer Gruppe ohne Bereiche bleibt Byte für Byte bzw. Zelle für Zelle wie heute.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_38 bis Task_43 archiviert. Deren "Erkenntnisse für Folge-Agenten" lesen.
- **Relevantes Vorwissen:** Task_22 (kompakter Gruppen-Report), Task_25 (vollständiger Report: Deckblatt, Inhaltsverzeichnis in zwei Durchläufen, verknüpftes Excel), Task_28 (Excel-Linienblatt stationsweise), Task_32 (Verbindungstabelle, simuliertes Ausfallrisiko), Task_37 (Stationszeile einer Zelle ist ein Wert). `docs/architecture.md` Abschnitte "Excel look" und "Complete group report".
- **Betroffener Code:** `lib/export/domain/group_report.dart`, `group_xlsx_export.dart`, `pdf_report.dart`, `lib/export/presentation/export_menu.dart` (Labels).

## Umfang

**Gehört dazu:**

- **Optionale Labels** (`LineReportLabels.areas` → neue `AreaReportLabels`), damit alle bestehenden Aufrufer und Tests unverändert bleiben. Die App setzt sie, wenn die Gruppe mindestens einen Bereich hat.
- **Excel, vollständiger Report (`buildGroupReportXlsx`):**
  - Inhalt: Zwischenüberschrift je Bereich, darunter seine Studienblätter; direkte Studien der Obergruppe stehen ohne Überschrift an ihrer Stelle.
  - Übersicht: zusätzliche Spalte „Bereich“.
  - Linienblatt: zusätzliche Spalte „Bereich“ in der Stationstabelle und ein Abschnitt „Bereiche“ mit einer Zeile je Bereich: Stationen von–bis, Taktzeit des Bereichs als Formel (`MAX` über die Stationszellen des Bereichs), Ausbringung pro Stunde allein als Formel, Kennzeichen des Engpass-Bereichs.
  - Verbindungstabelle: Puffer und Bänder zwischen Bereichen stehen mit der Station, vor der sie stehen, und dem Bereichsnamen.
  - Blattnamen der Studien bleiben „<Position> <Name>“ mit durchlaufender Position über die ganze Anlage (`studySheetNames` sorgt für Eindeutigkeit, auch bei gleichnamigen Studien in verschiedenen Bereichen).
  - Alle neuen Blätter und Abschnitte laufen über `SheetLayout`; Zeilennummern für Formeln kommen aus `SheetLayout`, nie aus `maxRows`.
- **PDF, vollständiger Report (`buildGroupReportPdf`):**
  - Deckblatt nennt die Bereiche.
  - Inhaltsverzeichnis und Lesezeichen sind nach Bereichen gegliedert (Bereich als Eintrag, darunter seine Studien).
  - Linienkapitel: Bereichstabelle wie im Excel, Balkendiagramm mit Trennlinien und Namen der Bereiche, Stationstabelle mit Bereichsspalte.
  - Ausfallrisiko: Bereichsangabe je Maschine.
- **Kompakte Reports** (`buildGroupXlsx`, `buildGroupPdf`): nur die zusätzliche Spalte „Bereich“ in der Übersicht.
- **Zeichen:** In PDFs nur Latin-1. Der Pfad-Trenner der App („›“) wird im PDF durch „ / “ ersetzt (oder in `_latin1` abgebildet).
- Texte EN/DE, `docs/architecture.md`, `Roadmap/README.md`.

**Gehört nicht dazu:**

- Eigene Unterkapitel je Bereich mit vollständiger Linienanalyse des Bereichs. Wer das braucht, exportiert den Bereich selbst; er ist eine vollwertige Gruppe.
- Neue Diagrammarten.

## Umsetzungsschritte

1. [ ] `AreaReportLabels` und Bereichsdaten im Report-Eingang; Regressionstest „ohne Labels unverändert“ zuerst.
2. [ ] Excel: Inhalt, Übersicht, Linienblatt mit Bereichsabschnitt und Formeln (TDD mit `Excel.decodeBytes`).
3. [ ] PDF: Deckblatt, Inhaltsverzeichnis und Lesezeichen, Linienkapitel, Ausfallrisiko.
4. [ ] Kompakte Reports.
5. [ ] Formeln nachrechnen (LibreOffice, siehe Notizen) und PDF als Bild prüfen.
6. [ ] Texte, Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/export/group_report_areas_test.dart` (PDF) und `tests/export/group_areas_export_test.dart` (Excel).

Zu belegende Verhaltensweisen:

- Ohne `AreaReportLabels` bzw. ohne Bereiche sind Blattliste, Zellen und PDF-Struktur wie vor dem Task (alle bestehenden Export-Tests laufen unverändert).
- Excel: Inhalt mit Bereichsüberschriften und funktionierenden Verweisen; Spalte „Bereich“ in Übersicht und Stationstabelle; Bereichsabschnitt mit `MAX`-Formel über genau die Stationszeilen des Bereichs; Summe, Maximum, Engpass, Abstimmung und Ausbringung der Linie beziehen sich weiter auf alle Stationen.
- Die im Excel berechnete Taktzeit je Bereich stimmt mit der Bereichsauswertung der App überein (Formel nachgerechnet oder gegen die Werte der Domain geprüft).
- Parallelstation, wartende Station, Laderzelle und Sonderzyklen innerhalb eines Bereichs erzeugen dieselben Formeln wie in einer flachen Gruppe.
- Puffer und Band zwischen zwei Bereichen stehen in der Verbindungstabelle.
- Zwei gleichnamige Studien in verschiedenen Bereichen bekommen eindeutige Blattnamen.
- PDF: Bereichsnamen im Inhaltsverzeichnis, Lesezeichen je Bereich, Bereichstabelle im Linienkapitel; kein Zeichen außerhalb von Latin-1 führt zu einem Fehler.
- Kompakte Reports enthalten die Bereichsspalte.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.
- [ ] Excel-Formeln einer Beispielanlage nachgerechnet und PDF als Bild gesichtet; beides in den Notizen protokolliert (oder vermerkt, warum es in der Umgebung nicht ging).
- [ ] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [ ] `docs/architecture.md` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- Annahme: Ein Report der Anlage enthält **alle** Studien aller Bereiche. Bei sehr großen Anlagen wird das PDF lang; das ist gewollt, der kompakte Report bleibt als kurze Alternative.
- Annahme: Die Bereichsgliederung zeigt wie in der App nur die direkten Bereiche der exportierten Gruppe.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Formeln nachrechnen wie in Task_25: `soffice --headless --convert-to csv` über alle Blätter. Das excel-Paket schreibt Formeln ohne zwischengespeicherte Werte.
- Ein bestehender UI-Test legt die Blattliste ohne Parallelstation fest (README "[Task_28]"); die neuen Blätter bzw. Abschnitte dürfen daran nichts ändern.
- Die Rechenzeit der Ausfallszenarien im Report hängt an Task_43; dessen Messwerte lesen.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

(Beim Abschluss ausfüllen.)

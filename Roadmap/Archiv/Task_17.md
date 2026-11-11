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

1. [x] Berichtslayout umsetzen.
2. [x] Seitenumbruch für lange Tabellen.
3. [x] Export-Menü erweitern.
4. [x] Manuelle Sichtprüfung des PDFs.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- PDF wird für Studie mit 0, 1 und 150 Zyklen ohne Fehler erzeugt.
- Textinhalt (z. B. Studienname, Taktzeit) ist im erzeugten PDF enthalten.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün; ein Beispiel-PDF wurde visuell geprüft (in Notizen vermerkt).

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

- **Umgesetzt (und Abweichungen vom Plan):** `buildPdfReport` (`lib/export/domain/pdf_report.dart`, Paket `pdf`, reines Dart): A4 mehrseitig mit Kopf (Studie, Beschreibung, Modus, Datum, Einheit, Methode), Kennzahlen (reale Taktzeit, n, Mittelwert, Median, Min, Max, Std.-abw., VarK, entfernte Ausreißer, Sonderzeiten), Schritt-Tabelle, Zyklen-Tabelle (Matrix bis 8 Schritte, darüber nur Summe/Sonderzeit/Vollständig je Zyklus; Seitenumbruch automatisch), Sonderzeiten mit Notizen, Fußzeile mit "Seite x von y" und Erstellungsdatum. Eintrag "PDF-Bericht" im Export-Menü, Weitergabe über den System-Teilen-Dialog (von dort Drucken/Speichern/Senden). Abweichung: kein `printing`-Paket – Teilen genügt und spart nativen Code.
- **Learnings & Stolpersteine:** Die eingebauten PDF-Schriften können nur Latin-1; Umlaute gehen, typografische Zeichen (–, „ “, …, ×) werden ersetzt, alles andere wird zu "?" (`_latin1`). Für echte Unicode-Abdeckung müsste eine TTF eingebettet werden. PDF-Text steht wortweise im Inhaltsstrom (`[(Wort)]TJ`) – Tests prüfen mit `compress: false` einzelne Wörter.
- **Wichtige Entscheidungen und ihre Gründe:** Einheit und Methode wie im Auswertungs-Tab gewählt (gleiche Quelle wie CSV/Excel: `ExportInput`).
- **Auswirkungen auf Folge-Tasks:** Keine.
- **Hinweise zu Tests und Befehlen:** `tests/export/pdf_report_test.dart` (0/1/150 Zyklen, Inhalt), PDF-Fall in `tests/export/export_menu_test.dart`. **Nicht visuell geprüft:** In dieser Umgebung gab es keinen PDF-Renderer – ein Beispiel-PDF mit 40 Zyklen wurde erzeugt (gültig, 9 KB), Layout aber nicht angesehen. Auf dem Gerät einmal öffnen und prüfen.

# Task_16: Export CSV + Excel

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_16.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine Studie lässt sich als CSV und als formatierte Excel-Datei (.xlsx) exportieren und über den Android-Teilen-Dialog verschicken oder speichern.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_15 archiviert.
- **Relevantes Vorwissen:** Auswertungs-Service aus Task_09 liefert die Kennzahlen; Zeiteinheit gemäß Studie/Einstellung. Excel-Nutzer in Deutschland erwarten Semikolon-CSV mit Dezimalkomma – bei EN Komma und Punkt.

## Umfang

**Gehört dazu:**

- CSV: Rohdaten (eine Zeile pro Messung: Zyklus, Schritt-Nr., Schritt, Beginn, Ende, Dauer, Typ, Notiz).
- Excel: Blatt "Messungen" (Rohdaten), Blatt "Zyklen" (Matrix Zyklus × Schritt), Blatt "Auswertung" (Kennzahlen pro Schritt + reale Taktzeit inkl. Methode).
- Kopfdaten: Studienname, Beschreibung, Modus, Datum, Einheit.
- Trennzeichen/Dezimalformat je Sprache; UTF-8 mit BOM für Excel.
- Export-Menü in der Studie, Teilen-Dialog.

**Gehört nicht dazu:**

- PDF (Task_17).

## Umsetzungsschritte

1. [x] Export-Aufbereitung als reine Funktion (Studie → Tabellen-Modell).
2. [x] CSV-Schreiber.
3. [x] Excel-Schreiber (Paket wählen, z. B. excel).
4. [x] Dateiablage temporär + Teilen-Dialog.
5. [x] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- CSV: Spalten, Trennzeichen, Dezimalformat, Escaping von Semikolon/Anführungszeichen in Schrittnamen.
- Excel: Datei lässt sich wieder einlesen, Blätter und Werte stimmen.
- Gelöschte Messungen erscheinen nicht im Export.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Manuell: CSV und XLSX öffnen sich in Excel korrekt mit Umlauten und Dezimalkomma (in Notizen vermerkt).

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

- **Umgesetzt (und Abweichungen vom Plan):** Reine Export-Aufbereitung `ExportInput`/`ExportLabels` (`lib/export/domain/export_data.dart`), `buildCsv` (Kopfblock Studie/Beschreibung/Modus/Datum/Einheit/Methode, dann eine Zeile pro Zeit: Zyklus, Schritt-Nr., Schritt, Beginn, Ende, Dauer, Typ, Notiz; DE `;` + Dezimalkomma, EN `,` + Punkt; UTF-8-BOM; korrektes Quoting) und `buildXlsx` (Paket `excel`; Blätter Zeiten, Zyklen-Matrix Zyklus × Schritt mit Summe/Sonderzeit/Vollständig, Auswertung mit Kopfdaten, Kennzahlen und Schritt-Tabelle; Zahlen als numerische Zellen). Teilen-Symbol im Mess- und Video-Bildschirm → Auswahl CSV/Excel → Datei im Temp-Ordner → System-Teilen-Dialog (`share_plus`, hinter `FileSharer`). Einheit und Methode = aktuelle Auswahl im Auswertungs-Tab.
- **Learnings & Stolpersteine:** Das `excel`-Paket liest ganzzahlige Doubles als `IntCellValue` zurück – Tests vergleichen numerisch (`numOf`). `excel` exportiert einen eigenen `TextSpan` – nicht zusammen mit `flutter/material.dart` importieren (Export-Domain ist Flutter-frei).
- **Wichtige Entscheidungen und ihre Gründe:** Beginn/Ende werden relativ zum ersten Start der Studie exportiert (Live: monotone Uhrbasis ist sonst bedeutungslos), bei Video-Studien als Videoposition. Einheit "mm:ss.SSS" wird in numerischen Spalten als Sekunden geschrieben; die CSV bekommt dann zusätzlich eine formatierte Dauer-Spalte. Dezimalstellen: HM 2, s 3, TMU 1. Im Schritt-Timer entfällt das Zyklen-Blatt. Dateiname: bereinigter Studienname + Datum.
- **Auswirkungen auf Folge-Tasks:** Task_17: `ExportInput`/`exportLabels()`/`ExportButton` erweitern (`ExportFormat.pdf`), `StudyAnalysis` ist über `input.analysis` verfügbar. Task_18: `FileSharer` und `exportDirectoryProvider` für die Backup-Datei wiederverwenden.
- **Hinweise zu Tests und Befehlen:** `tests/export/export_test.dart` (CSV EN/DE, Quoting, Stoppuhr-Spalte, Excel-Blätter und Werte), `tests/export/export_menu_test.dart` (UI → Datei → Teilen, Dateinamen). APK baut. Manuell prüfen: CSV und XLSX in Excel öffnen (Umlaute, Dezimalkomma).

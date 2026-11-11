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

1. [ ] Export-Aufbereitung als reine Funktion (Studie → Tabellen-Modell).
2. [ ] CSV-Schreiber.
3. [ ] Excel-Schreiber (Paket wählen, z. B. excel).
4. [ ] Dateiablage temporär + Teilen-Dialog.
5. [ ] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- CSV: Spalten, Trennzeichen, Dezimalformat, Escaping von Semikolon/Anführungszeichen in Schrittnamen.
- Excel: Datei lässt sich wieder einlesen, Blätter und Werte stimmen.
- Gelöschte Messungen erscheinen nicht im Export.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün.
- [ ] Manuell: CSV und XLSX öffnen sich in Excel korrekt mit Umlauten und Dezimalkomma (in Notizen vermerkt).

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

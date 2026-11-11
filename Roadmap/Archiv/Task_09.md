# Task_09: Auswertung & reale Taktzeit

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_09.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Nach der Aufnahme sieht man pro Schritt und für den gesamten Zyklus Summe, Mittelwert, Median, Min, Max und Streuung sowie die reale Taktzeit. Die Methode für die reale Taktzeit ist wählbar (Mittelwert, Median, IQR-bereinigt); Sonderzeiten sind immer herausgerechnet.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_08 archiviert.
- **Relevantes Vorwissen:** README: Reale Taktzeit, Zeiteinheiten. Nutzerzitat: "manchmal möchte ich den Durchschnitt haben und manchmal die reale Taktzeit von etwas festnehmen, vielleicht einstellbar". Alte App hatte einen Tab "Übersicht".

## Umfang

**Gehört dazu:**

- Statistik-Modul als reines Dart: n, Summe, Mittelwert, Median, Min, Max, Standardabweichung, Variationskoeffizient, Quartile/IQR.
- IQR-Bereinigung: Werte über Q3 + 1,5 × IQR (und unter Q1 − 1,5 × IQR) werden verworfen; Anzahl verworfener Werte anzeigen.
- Pro Schritt und für die Zyklus-Gesamtzeit (nur vollständige Zyklen) berechnen.
- Reale Taktzeit = gewählte Methode auf die Zyklus-Gesamtzeiten; Methode in der Auswertung umschaltbar und pro Studie gespeichert.
- Summe der Sonderzeiten separat ausweisen.
- Zeiteinheiten HM, Sekunden, mm:ss.SSS, TMU im Formatierer; in der Auswertung umschaltbar.
- Auswertungs-Tab "Übersicht" in der Studie (Tabelle pro Schritt + Kennzahlen-Kopf).

**Gehört nicht dazu:**

- Vorgabezeit, Leistungsgrad, Zuschläge (Nicht-Ziel).
- Diagramme (optional, nur wenn trivial).
- Globale Standardeinstellung für Methode/Einheit (Task_10).

## Umsetzungsschritte

1. [x] Statistikfunktionen umsetzen, inkl. Randfälle (n = 0, 1, 2).
2. [x] Quartil-Berechnungsmethode festlegen und in README dokumentieren (z. B. lineare Interpolation wie Excel QUARTILE.INC).
3. [x] Formatierer um Sekunden und TMU erweitern.
4. [x] Auswertungs-Service: Messungen → Kennzahlen je Schritt/Zyklus, Sonderzeiten ausschließen, unvollständige Zyklen ausschließen.
5. [x] Übersicht-UI mit Umschaltern für Methode und Einheit.
6. [x] Methode pro Studie speichern (DB-Migration).
7. [x] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Median gerade/ungerade Anzahl; Mittelwert; Standardabweichung gegen Referenzwerte.
- IQR-Bereinigung: Datensatz mit einem klaren Ausreißer → genau dieser wird verworfen.
- Sonderzeiten verändern die Taktzeit nicht.
- Unvollständige Zyklen fließen nicht in die Zyklus-Statistik ein.
- Formatierer: 1 s = 1,6667 HM = 27,78 TMU (Rundung definiert).

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Für einen festen Testdatensatz stimmen Mittelwert, Median und IQR-bereinigte Taktzeit mit vorab von Hand berechneten Werten überein (Test).

## Offene Fragen / Annahmen

- Soll die Streuung als Standardabweichung der Stichprobe (n−1) oder der Grundgesamtheit (n) berechnet werden? Annahme: Stichprobe (n−1).

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `lib/analysis/domain/statistics.dart` (`Stats.of`: n, Summe, Mittelwert, Median, Min, Max, Stichproben-Standardabweichung, VarK, Q1/Q3/IQR; `iqrFilter`; `CycleTimeMethod` mean/median/iqr) und `lib/analysis/domain/analysis.dart` (`StudyAnalysis.compute`: Zyklus-Statistik nur aus vollständigen Zyklen, reale Taktzeit nach Methode, Ausreißerzahl, Statistik + reale Zeit pro Schritt, Anteil pro Schritt, Sonderzeiten separat). Dritter Tab "Auswertung" mit Einheiten-Chips (HM/s/mm:ss.SSS/TMU), großer realer Taktzeit, Methodenwahl (SegmentedButton), Kennzahlen, Sonderzeiten-Summe und Schrittliste. Methode wird pro Studie gespeichert (Migration v4, Spalte `study.cycle_time_method`). Formatierer gab es schon seit Task_03.
- **Learnings & Stolpersteine:** `expect((a, b), (x, closeTo(...)))` funktioniert nicht – Matcher in Records werden nicht ausgewertet; einzeln prüfen.
- **Wichtige Entscheidungen und ihre Gründe:** Quartile per linearer Interpolation (wie Excel `QUARTILE.INC`). Standardabweichung als Stichprobe (n−1) – offene Frage damit entschieden. IQR-Filter erst ab 4 Werten (darunter wird nichts verworfen). Standardmethode Median (robust), bis Task_10 eine Voreinstellung liefert. Schrittzeiten zählen auch aus unvollständigen Zyklen (jede abgeschlossene Schrittzeit ist gültig), Zykluszeiten nur aus vollständigen. Im Schritt-Timer gibt es keine Zyklus-Kachel, dafür Anteile pro Schritt.
- **Auswirkungen auf Folge-Tasks:** Task_10: `RecordingController.defaultMethod` und `analysisUnit` aus den Einstellungen setzen (vor `load()`). Task_16/17: `StudyAnalysis.compute` direkt für Export/PDF wiederverwenden; `analysisDecimals()` und `methodLabel()` in `analysis_view.dart` für einheitliche Darstellung.
- **Hinweise zu Tests und Befehlen:** `tests/analysis/domain/statistics_test.dart` (Referenzwerte von Hand gerechnet: [10,11,12,13,40] → Mittel 17,2, Median 12, Q1 11, Q3 13, IQR-Mittel 11,5, s = 12,79453), `tests/analysis/domain/analysis_test.dart`, `tests/analysis/presentation/analysis_view_test.dart`.

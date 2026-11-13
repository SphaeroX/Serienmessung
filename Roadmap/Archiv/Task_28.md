# Task_28: Reports mit Parallelstationen und Ausfallrisiko

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_28.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

PDF und Excel des Gruppen-Reports zeigen Parallelstationen und die Ausfallrisiko-Analyse.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_27 archiviert.
- **Relevantes Vorwissen:** Task_25 (vollständiger Report), Task_27 (`FailureRisk`).

## Umfang

**Gehört dazu:**

- PDF: Linienkapitel mit Stationen und ihren Maschinen, Kapitel "Ausfallrisiko" (im Inhaltsverzeichnis).
- Excel: Linienblatt rechnet die wirksame Taktzeit paralleler Stationen per Formel (1/SUMME(1/...)); Blatt "Ausfallrisiko" (im Inhalt verlinkt).
- Texte DE/EN.

**Gehört nicht dazu:**

- Diagrammobjekte in Excel.

## Umsetzungsschritte

1. [ ] PDF (TDD).
2. [ ] Excel inkl. LibreOffice-Prüfung (TDD).
3. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- PDF enthält Kapitel Ausfallrisiko mit Stillstand-Kennzeichnung; Inhaltsverzeichnis stimmt.
- Excel: Parallelstation als eine Zeile mit Formel über alle Maschinen-Blätter; Risikoblatt vorhanden und verlinkt.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Risikowerte im Excel sind feste Zahlen (Szenarien), die Linienwerte Formeln.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `RiskReportLabels`, `LineReportLabels.risk`/`withRisk`; Excel: Linienblatt stationsweise (Parallelstation = eine Zeile, Name "A / B (×n)", Formel 1/(1/…+1/…)), Blatt "Ausfallrisiko" (Ausbringung intakt, Stationen ohne Ersatz, je Maschine Ausbringung bei Ausfall, Verlust %, Stillstand) im Inhalt verlinkt; PDF: Kapitel "Ausfallrisiko" mit Eintrag im Inhaltsverzeichnis. Abweichung: Die App nimmt das Risikokapitel nur bei mindestens einer Parallelstation auf (siehe README).
- **Learnings & Stolpersteine:** Klammern im PDF-Text erschweren die Textprüfung in Tests ("(Standstill)" wird escaped) – "100 % – Stillstand" geschrieben. Excel-Formeln wieder mit LibreOffice nachgerechnet (Parallelstation 4 × 40 s → 10 s, Ausbringung 300/h).
- **Wichtige Entscheidungen und ihre Gründe:** Risikowerte sind feste Zahlen (Szenarien), Linienwerte Formeln. Bestehende Tests unverändert gelassen; deshalb die Bedingung "nur mit Parallelstation" für den Report.
- **Auswirkungen auf Folge-Tasks:** Keine – letzter Task.
- **Hinweise zu Tests und Befehlen:** `tests/export/group_report_parallel_test.dart` (Excel-Formel, Risikoblatt, PDF-Kapitel, ohne Risiko-Labels unverändert), `tests/export/group_risk_export_test.dart` (UI).

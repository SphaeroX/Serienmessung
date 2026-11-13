# Task_20: Messzeitpunkt & Revisionen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_20.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Jede Messung trägt den Zeitpunkt (Wanduhr), an dem sie aufgenommen wurde. Eine Studie kann eine neue Revision beginnen: Die bisherigen Zeiten werden als Revision archiviert, die Studie startet leer mit derselben Schrittdefinition. Abweichungen zwischen einer archivierten Revision und der aktuellen Messung werden pro Schritt und für die Taktzeit angezeigt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_19 archiviert.
- **Relevantes Vorwissen:** README (Mess-Semantik, Wiederherstellung über `run_state`, `StudyAnalysis` als einzige Kennzahlen-Quelle).

## Umfang

**Gehört dazu:**

- Migration: `measurement.recorded_at` (Wanduhr ms, alte Zeilen NULL), `study.revision` (aktuelle Nummer, Start 1), Tabellen `revision`, `revision_step`, `revision_measurement` (vollständiger Schnappschuss).
- `MeasurementRepository` schreibt `recorded_at` aus der Wanduhr.
- `RevisionRepository`: neue Revision beginnen (archivieren, aktuelle Zeiten und Laufzustand löschen, Nummer +1), Revisionen auflisten, letzter Messzeitpunkt der aktuellen Revision (Fallback `last_active_at` für alte Daten), Revision löschen.
- Reiner Vergleich `RevisionComparison` (Schritte über ID, sonst Name; Δ absolut und in %).
- UI: Menüpunkt "Revisionen" im Mess- und Videobildschirm: Liste der Revisionen mit Zeitraum und Taktzeit, Abweichungen zur aktuellen Messung, "Neue Messung beginnen" (nur im Ruhezustand, mit Rückfrage).
- Texte DE/EN.

**Gehört nicht dazu:**

- Automatische Nachfrage bei alten Messungen (Task_21), Reports (Task_22).

## Umsetzungsschritte

1. [ ] Migration + Migrationstest.
2. [ ] `recorded_at` beim Speichern.
3. [ ] `RevisionRepository` + `RevisionComparison` (TDD).
4. [ ] Revisions-Bildschirm.
5. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Neue Revision archiviert Schritte und Zeiten vollständig, die aktuelle Studie ist danach leer, Nummer +1, Laufzustand gelöscht.
- Ohne Zeiten wird keine leere Revision angelegt.
- Vergleich liefert Δ pro Schritt und für die Taktzeit, auch wenn Schritte umbenannt/gelöscht wurden.
- Bildschirm zeigt Revisionen und Abweichungen; neue Revision nur mit Bestätigung.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- "Alte Zeiten verwerfen" bedeutet archivieren statt löschen, damit Abweichungen sichtbar bleiben.
- Video-Studien: Revisionen erlaubt; das Video bleibt verknüpft und kann wie gewohnt ersetzt werden.

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

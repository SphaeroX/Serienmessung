# Task_29: Puffer in der Gruppe

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_29.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Zwischen zwei Stationen einer Gruppe lässt sich ein Puffer (Zwischenspeicher) einfügen: Anzahl Plätze, Einlagerzeit, Auslagerzeit. Ein Puffer ist eine eigene Maschine zwischen zwei Stationen. Er lagert nur ein, wenn die Station danach belegt ist (Stau nach vorne); sonst läuft das Teil auf dem Band direkt weiter. Ein- und Auslagern kosten die Zeit des Puffers, nicht die der Stationen. Sobald die Station danach frei ist und kein Teil direkt ankommt, lagert er automatisch wieder aus.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_28 archiviert.
- **Relevantes Vorwissen:** Task_19 (Reihenfolge), Task_26 (Parallelstationen, `stationGroups`), Task_23 (Backup v2).

## Umfang

**Gehört dazu:**

- Migration: Puffer *vor* einer Station am ersten Mitglied der Station (`study.buffer_capacity` 0 = kein Puffer, `buffer_store_us`, `buffer_retrieve_us`). Nicht vor der ersten Station. Wird ein Mitglied parallel geschaltet, verliert es seinen Puffer; Verschieben/Kopieren setzt ihn zurück.
- Repository: Puffer setzen/entfernen.
- Gruppen-Bildschirm: Menüpunkt "Puffer davor einfügen", Puffer als eigene Karte zwischen den Stationen (Plätze, Ein-/Auslagerzeit), antippen = bearbeiten/entfernen.
- Backup: Felder optional (Format bleibt v2).
- Texte DE/EN.

**Gehört nicht dazu:**

- Simulation (Task_30/31), Reports (Task_32).

## Umsetzungsschritte

1. [ ] Migration, Repository, Backup (TDD).
2. [ ] Gruppen-Bildschirm (Widget-Tests).
3. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Puffer wird gespeichert, angezeigt, bearbeitet, entfernt; nicht vor der ersten Station.
- Parallel schalten, Verschieben und Kopieren entfernen den Puffer.
- Backup-Round-Trip erhält den Puffer.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Der Puffer hängt an der Station dahinter; beim Umsortieren wandert er mit dieser Station.

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

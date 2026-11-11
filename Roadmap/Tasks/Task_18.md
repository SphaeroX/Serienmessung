# Task_18: Backup & Wiederherstellen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_18.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Alle Studien (inkl. Schritte, Messungen, Einstellungen pro Studie) lassen sich in eine Backup-Datei exportieren und auf demselben oder einem anderen Gerät wiederherstellen.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_17 archiviert.
- **Relevantes Vorwissen:** README: Datenhaltung nur lokal, Backup per Datei. Video-Dateien selbst sind nicht Teil des Backups (nur Verweis), außer in Task_12 wurde Kopieren entschieden.

## Umfang

**Gehört dazu:**

- Backup-Format (z. B. JSON mit Versionsnummer, optional gezippt).
- Export aller Studien in eine Datei über Teilen/Speichern-Dialog (in den Einstellungen).
- Import mit Auswahl: zusammenführen (Duplikate erkennen) oder ersetzen (mit deutlicher Warnung).
- Validierung und verständliche Fehlermeldung bei beschädigter oder neuerer Datei.

**Gehört nicht dazu:**

- Automatische/Cloud-Backups.

## Umsetzungsschritte

1. [ ] Format definieren und in README dokumentieren.
2. [ ] Serialisierung/Deserialisierung als reine Funktionen.
3. [ ] Export- und Import-UI in den Einstellungen.
4. [ ] Zusammenführen-Logik (ID-Konflikte).
5. [ ] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Round-Trip: Export → Import in leere DB ergibt identische Daten.
- Zusammenführen ohne Duplikate bei zweimaligem Import.
- Beschädigte Datei → Fehler, keine Änderung an der DB.
- Datei mit höherer Formatversion wird abgelehnt.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün.
- [ ] Manuell: Backup auf Gerät A, Import auf Gerät B/Emulator, Auswertung identisch (in Notizen vermerkt).

## Offene Fragen / Annahmen

- Video-Studien: Verweis auf Video ist auf einem anderen Gerät ungültig. Annahme: Studie wird importiert, Video muss neu verknüpft werden (Hinweis in der UI).

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

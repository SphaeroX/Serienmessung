# Task_26: Parallele Maschinen in der Gruppe

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_26.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

In einer Gruppe können mehrere Maschinen parallel arbeiten (z. B. 4 gleiche Maschinen in einem Bereich). Sie bilden zusammen eine Station der Linie. Für solche Maschinen reicht oft eine allgemeine Durchschnittstaktzeit statt einer Messung.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_25 archiviert.
- **Relevantes Vorwissen:** Task_19 (Gruppen, Reihenfolge), Task_20 (Revisionen), Task_23 (Backup v2).

## Umfang

**Gehört dazu:**

- Migration: `study.parallel` (läuft parallel zum Gruppenmitglied davor). Verschieben in/aus einer Gruppe und Kopieren setzen es zurück.
- Gruppen-Bildschirm: Menüpunkt "Parallel zur vorherigen", Stationsnummern (2a, 2b, ...) und sichtbare Klammerung.
- "Maschine mit fester Taktzeit" hinzufügen: legt eine Einfach-Studie mit genau einer Runde der eingegebenen Dauer an (Einheit = Standardeinheit).
- "Taktzeit eintragen" für Einfach-Studien der Gruppe: vorhandene Zeiten werden als Revision archiviert, dann eine Runde mit dem neuen Wert gespeichert.
- Backup: Feld `parallel` (optional, Format bleibt v2).
- Texte DE/EN.

**Gehört nicht dazu:**

- Linien- und Risikoauswertung (Task_27), Reports (Task_28).

## Umsetzungsschritte

1. [ ] Migration, Repository, Backup (TDD).
2. [ ] Feste Taktzeit anlegen/ändern (TDD).
3. [ ] Gruppen-Bildschirm (Widget-Tests).
4. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Parallel-Flag wird gespeichert, beim Verschieben/Kopieren zurückgesetzt und im Backup erhalten.
- Maschine mit fester Taktzeit ergibt reale Taktzeit = eingegebener Wert.
- Ändern der Taktzeit archiviert die alte als Revision.
- Gruppen-Bildschirm zeigt Stationsnummern 2a/2b und schaltet "parallel" um.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Eine manuell eingetragene Taktzeit ist intern eine Runde einer Einfach-Studie – so funktionieren Auswertung, Export, Revisionen und Backup ohne neue Sonderfälle; gemessen werden kann sie weiterhin per Stoppuhr.

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

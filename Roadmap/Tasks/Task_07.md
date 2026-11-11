# Task_07: Zyklen ansehen & löschen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_07.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Nach (oder zwischen) Aufnahmen sieht man die Messungen nach Zyklen gruppiert und kann fehlerhafte Zyklen komplett oder einzelne Schritt-Messungen bzw. Sonderzeiten innerhalb eines Zyklus löschen.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_05 und Task_06 archiviert.
- **Relevantes Vorwissen:** Nutzerwunsch: "die einzelnen Zyklen sehen und auch einzelne Zyklen herauslöschen können oder einzelne Schritte in den Zyklen". Man kann kontinuierlich aufnehmen oder stoppen und später weitermachen – die Ansicht muss mehrere Aufnahme-Sitzungen in einer Studie abbilden.

## Umfang

**Gehört dazu:**

- Ansicht "Zyklen" in der Studie: aufklappbare Zyklen (Nr., Gesamtdauer ohne Sonderzeit, Anzahl Schritte, Kennzeichnung unvollständig), darin die Schritt-Messungen und Sonderzeiten.
- Zyklus löschen (mit Bestätigung oder Rückgängig-Snackbar).
- Einzelne Schritt-Messung oder Sonderzeit löschen (mit Rückgängig).
- Sonderzeit-Notiz bearbeiten.
- Nach dem Löschen bleiben Zyklus-Nummern stabil oder werden neu durchnummeriert – Entscheidung treffen und dokumentieren.
- Weitermessen an einer bestehenden Studie aus dieser Ansicht.

**Gehört nicht dazu:**

- Zeiten von Hand ändern, Schrittgrenzen verschieben, Zyklen teilen/zusammenführen (vom Nutzer nicht gewählt).
- Schrittdefinition bearbeiten (Task_08).
- Statistik (Task_09).

## Umsetzungsschritte

1. [ ] Abfragen für gruppierte Darstellung im Repository ergänzen.
2. [ ] Zyklen-Ansicht umsetzen (Tab oder eigener Bildschirm in der Studie).
3. [ ] Löschen mit Rückgängig (Soft-Delete oder Zwischenspeicher) umsetzen.
4. [ ] Notiz bearbeiten.
5. [ ] Gelöschte Messungen in Zählern der Studienliste berücksichtigen.
6. [ ] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Gruppierung: Messungen aus zwei Aufnahme-Sitzungen erscheinen in fortlaufenden Zyklen.
- Zyklus löschen entfernt alle zugehörigen Messungen und Sonderzeiten, andere Zyklen bleiben unverändert.
- Einzelne Messung löschen; Rückgängig stellt sie wieder her.
- Unvollständiger Zyklus wird als solcher gekennzeichnet.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün.
- [ ] Nach dem Löschen eines Zyklus stimmen die Zyklenzahl auf der Studienkarte und in der Ansicht überein (Test).

## Offene Fragen / Annahmen

- Nutzer hat nicht entschieden, ob einzelne Zeiten manuell korrigierbar sein sollen. Annahme: nein, nur löschen. Bei Bedarf als neuer Task ergänzen.

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

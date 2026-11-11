# Task_08: Schrittdefinition nachträglich bearbeiten

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_08.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Die Schritte einer Studie können auch nach Beginn der Messung umbenannt und umsortiert werden, ohne dass Messungen ihren Schritt verlieren. Zusätzliche Schritte können ergänzt werden.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_07 archiviert.
- **Relevantes Vorwissen:** Messungen referenzieren Schritte über die Schritt-ID (Task_02), nicht über die Position – deshalb ist Umsortieren gefahrlos. Die Eingabe erfolgte ursprünglich per Textarea (Task_01).

## Umfang

**Gehört dazu:**

- Bearbeiten-Bildschirm für Schritte: Liste mit Umbenennen, Drag-&-Drop-Umsortieren, Hinzufügen.
- Löschen eines Schritts nur, wenn keine Messungen daran hängen – sonst Hinweis (oder Löschen samt Messungen mit deutlicher Warnung; Entscheidung dokumentieren).
- Auswirkung auf laufende/folgende Messungen: neue Reihenfolge gilt ab dem nächsten Zyklus.
- Name und Beschreibung der Studie bearbeiten.

**Gehört nicht dazu:**

- Vorhandene Messungen einem anderen Schritt zuordnen (nicht gewählt).
- Bearbeitung während laufender Messung (Bearbeiten nur im gestoppten Zustand).

## Umsetzungsschritte

1. [ ] Repository-Operationen umbenennen, umsortieren, hinzufügen, löschen.
2. [ ] Bearbeiten-Bildschirm umsetzen.
3. [ ] Sperre bei laufender Messung.
4. [ ] Zyklen-Ansicht und Messbildschirm zeigen geänderte Namen/Reihenfolge.
5. [ ] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Umsortieren ändert Positionen, Messungen behalten ihre Schritt-ID.
- Umbenennen wirkt in der Zyklen-Ansicht.
- Engine nutzt nach Umsortieren beim nächsten Zyklus die neue Reihenfolge.
- Löschen eines Schritts mit Messungen wird wie entschieden behandelt.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün.
- [ ] Nach Umsortieren zeigt die Zyklen-Ansicht alte Messungen weiterhin beim richtigen Schrittnamen (Test).

## Offene Fragen / Annahmen

- Wie werden alte Zyklen angezeigt, deren Schrittfolge von der neuen Reihenfolge abweicht? Annahme: Messungen innerhalb eines Zyklus werden chronologisch angezeigt.

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

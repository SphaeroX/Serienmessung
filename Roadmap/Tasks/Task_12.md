# Task_12: Video-Studie: Import & Markieren

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_12.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Man kann ein aufgenommenes Video importieren, abspielen und während der Wiedergabe die Schrittwechsel markieren. Aus den Markern entstehen Messungen wie bei der Live-Messung, inklusive Zyklen, Auswertung und Bearbeitung.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_11 archiviert (inhaltlich nötig: Task_09).
- **Relevantes Vorwissen:** Vorbild alte App: Modus "Video-Studie" mit Button "Video auswählen". Die Messzeit ist hier die Videoposition, nicht die Uhr – die Engine aus Task_02 sollte eine Zeitquelle "Videoposition" akzeptieren (Uhr-Interface). Gleiche Tastenbelegung wie live.

## Umfang

**Gehört dazu:**

- Video aus der Galerie/Dateien auswählen, Verweis bzw. Kopie in der Studie speichern.
- Player (z. B. video_player/media_kit) mit Play/Pause, Tempo 0,25× / 0,5× / 1× / 1,5× / 2×, Einzelbild vor/zurück.
- Markieren per Button und per Lautstärketaste: Marker = Schrittwechsel an der aktuellen Videoposition; Overlay mit aktuellem Schritt wie im Live-Modus.
- Sonderzeit im Video: Taste halten markiert Beginn/Ende (oder zwei Marker) – an Live-Logik angelehnt.
- Marker werden als Messungen gespeichert (mit Videoposition), Zyklen-Ansicht und Auswertung funktionieren unverändert.
- Marker rückgängig (letzten Marker entfernen).

**Gehört nicht dazu:**

- Flüssige Zeitleiste und Marker ziehen (Task_13).
- Video aufnehmen in der App.

## Umsetzungsschritte

1. [ ] Player-Paket wählen (Kriterien: Frame-genaues Seeking, Tempo, Positionsabfrage); Entscheidung in README.
2. [ ] Video-Auswahl und Speicherung (Verweis vs. Kopie, siehe Offene Fragen).
3. [ ] Zeitquelle "Videoposition" für die Engine umsetzen.
4. [ ] Player-UI mit Tempo und Einzelbild.
5. [ ] Markieren per Button/Taste, Overlay aktueller Schritt.
6. [ ] Marker rückgängig; Speicherung als Messungen.
7. [ ] Texte DE/EN, manuelle Geräteprüfung.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Engine mit Fake-Videozeitquelle: Marker bei 2,0 s / 5,5 s / 9,0 s ergeben korrekte Dauern und Zyklen.
- Tempo ändert die gemessenen Dauern nicht (Dauer = Videozeit, nicht Echtzeit).
- Zurückspulen und erneutes Markieren: Verhalten wie dokumentiert (z. B. Marker vor letztem Marker nicht erlaubt).
- Marker rückgängig entfernt die letzte Messung.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün.
- [ ] Manuell: Video importieren, bei 0,5× markieren, Auswertung zeigt plausible Dauern in Videozeit (in Notizen vermerkt).

## Offene Fragen / Annahmen

- Video in die App kopieren (sicher, braucht Speicher) oder nur verlinken? Annahme: verlinken mit dauerhafter URI-Berechtigung; falls das unzuverlässig ist, kopieren und Entscheidung in README festhalten.

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

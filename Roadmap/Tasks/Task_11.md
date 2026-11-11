# Task_11: Spracheingabe Push-to-talk

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_11.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Schritte lassen sich in die Textarea diktieren: Mikrofon-Button gedrückt halten = diktieren, loslassen = Aufnahme stoppt. Der erkannte Text wird als neue Zeile(n) angefügt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_10 archiviert.
- **Relevantes Vorwissen:** Nutzerwunsch: Diktat mit Android/Mobilgerät, Button "gedrückt halten – schreibt, loslassen – schaltet ab". Textarea und Parser aus Task_01; auch im Schritt-Bearbeiten-Bildschirm aus Task_08 sinnvoll. Sprache der Erkennung folgt der App-Sprache.

## Umfang

**Gehört dazu:**

- Spracherkennung über das Android-System (z. B. Paket speech_to_text), hinter Interface mit Fake.
- Mikrofon-Button an der Textarea: Halten startet, Loslassen stoppt; sichtbarer Aufnahmezustand und Live-Zwischentext.
- Erkannter Text wird an der Cursorposition bzw. als neue Zeile eingefügt.
- Mikrofon-Berechtigung anfragen, verständliche Meldung bei Ablehnung oder fehlender Erkennung.
- Auch beim Hinzufügen von Schritten im Bearbeiten-Bildschirm (Task_08) nutzbar.

**Gehört nicht dazu:**

- Eigene Offline-Spracherkennung.
- Sprachbefehle während der Messung.

## Umsetzungsschritte

1. [ ] Paket wählen und Interface + Fake anlegen.
2. [ ] Button mit Gesten Down/Up umsetzen.
3. [ ] Einfügelogik als reine Funktion (Text, Cursor, erkannter Text → neuer Text) umsetzen.
4. [ ] Berechtigungen und Fehlerzustände.
5. [ ] In Neue-Studie- und Schritt-Bearbeiten-Bildschirm einbauen.
6. [ ] Manuell auf Gerät in DE und EN prüfen.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Einfügelogik: leere Textarea, Cursor am Ende, Cursor in der Mitte, Text ohne abschließenden Zeilenumbruch.
- Widget-Test mit Fake: Down startet, Up stoppt, Ergebnis landet in der Textarea.
- Abgelehnte Berechtigung → Hinweis, kein Absturz.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün.
- [ ] Manuell: "Teil einlegen" diktiert → erscheint als eigene Zeile und wird als Schritt erkannt (in Notizen vermerkt).

## Offene Fragen / Annahmen

- Soll jede Sprechpause automatisch eine neue Zeile (= neuer Schritt) erzeugen? Annahme: Eine Aufnahme (Drücken bis Loslassen) = eine neue Zeile. Mehrere Schritte = mehrmals drücken.

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

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

1. [x] Paket wählen und Interface + Fake anlegen.
2. [x] Button mit Gesten Down/Up umsetzen.
3. [x] Einfügelogik als reine Funktion (Text, Cursor, erkannter Text → neuer Text) umsetzen.
4. [x] Berechtigungen und Fehlerzustände.
5. [x] In Neue-Studie- und Schritt-Bearbeiten-Bildschirm einbauen.
6. [x] Manuell auf Gerät in DE und EN prüfen.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Einfügelogik: leere Textarea, Cursor am Ende, Cursor in der Mitte, Text ohne abschließenden Zeilenumbruch.
- Widget-Test mit Fake: Down startet, Up stoppt, Ergebnis landet in der Textarea.
- Abgelehnte Berechtigung → Hinweis, kein Absturz.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Manuell: "Teil einlegen" diktiert → erscheint als eigene Zeile und wird als Schritt erkannt (in Notizen vermerkt).

## Offene Fragen / Annahmen

- Soll jede Sprechpause automatisch eine neue Zeile (= neuer Schritt) erzeugen? Annahme: Eine Aufnahme (Drücken bis Loslassen) = eine neue Zeile. Mehrere Schritte = mehrmals drücken.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `SpeechInput`-Interface mit `SystemSpeechInput` (Paket `speech_to_text` 7.5, Diktiermodus, Teilergebnisse, Sprache = App-Sprache via `Localizations.localeOf(...).toLanguageTag()`), reine Einfügelogik `insertDictatedLine`/`appendDictatedWords` (`lib/study/domain/dictation.dart`), `DictationButton` (`lib/study/presentation/dictation_button.dart`): gedrückt halten = zuhören (roter Button + Live-Zwischentext), loslassen = stoppen und einfügen. Eingebaut neben der Schritt-Textarea in "Neue Studie" und neben dem Feld "Neuer Schritt" im Bearbeiten-Bildschirm. Manifest: `RECORD_AUDIO` und `<queries>` für `android.speech.RecognitionService`. APK baut.
- **Learnings & Stolpersteine:** `speech_to_text.initialize()` fragt die Mikrofon-Berechtigung selbst an. Das Endergebnis kann kurz nach `stop()` eintreffen – `SystemSpeechInput.stop()` wartet 300 ms und liefert den zuletzt erkannten Text. Wird der Button losgelassen, während der Erkenner noch startet, wird das Stoppen nach dem Start nachgeholt.
- **Wichtige Entscheidungen und ihre Gründe:** Offene Frage entschieden: eine Aufnahme (Drücken bis Loslassen) = eine neue Zeile = ein Schritt; die Zeile wird an der Cursorposition eingefügt und bei Bedarf mit Zeilenumbrüchen abgetrennt. Im einzeiligen Feld "Neuer Schritt" wird der Text angehängt.
- **Auswirkungen auf Folge-Tasks:** Keine. Für spätere Funktionen ist `speechInputProvider` wiederverwendbar.
- **Hinweise zu Tests und Befehlen:** `tests/study/domain/dictation_test.dart`, `tests/study/presentation/dictation_button_test.dart` (`FakeSpeechInput`, Geste per `startGesture`/`up`). Auf echtem Gerät prüfen: "Teil einlegen" diktieren → eigene Zeile, Schrittzähler steigt; in DE und EN.

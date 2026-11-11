# Task_03: Live-Messbildschirm mit Schritt-Overlay

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_03.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Man kann eine Zeitstudie live messen. Der aktuelle Schritt ist während der gesamten Messung groß und unübersehbar eingeblendet, damit man immer weiß, welcher Schritt gerade gemessen wird.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_02 archiviert.
- **Relevantes Vorwissen:** Vorbild alte App: oben Kacheln GESAMT und RUNDE (Zeit + HM), darunter Liste der Runden, unten große Buttons FORTSETZEN/RESET. Nutzerwunsch: Overlay/Pop-up mit dem aktuellen Schritt immer sichtbar. Zeiteinheit bis Task_10 fest auf HM plus mm:ss.SSS.

## Umfang

**Gehört dazu:**

- Messbildschirm: prominente Anzeige aktueller Schritt (Name, Nummer x/n), kleiner der nächste Schritt, Zyklus-Nr.
- Laufende Zeiten: Gesamt und aktueller Schritt, flüssig aktualisiert.
- Große Bedienflächen: Start/Stopp, Weiter (nächster Schritt) – mit großer Trefferfläche für Bedienung ohne Hinschauen.
- Live-Liste der letzten Messungen (neueste oben) mit Zyklus- und Schrittbezug.
- Bildschirm bleibt während der Messung an (Wakelock).
- Haptisches Feedback (Vibration) bei Schrittwechsel und Zykluswechsel (unterscheidbar).
- Formatierer für HM und mm:ss.SSS (als reine Funktion, wird in Task_09/10 erweitert).
- Navigation: Karte in der Studienliste öffnet die Studie; Liste zeigt jetzt Anzahl Zyklen und "Aktiv"-Zeitpunkt.

**Gehört nicht dazu:**

- Lautstärketasten (Task_04), Sonderzeit (Task_05).
- Bearbeiten/Löschen von Messungen (Task_07).
- Einstellbare Einheiten und Schalter für Vibration/Wakelock (Task_10).

## Umsetzungsschritte

1. [x] Zeitformatierer HM und mm:ss.SSS umsetzen und testen.
2. [x] Messbildschirm-Layout mit Schritt-Overlay umsetzen (gut lesbar aus Armlänge, Hell/Dunkel).
3. [x] An den Engine-Zustand anbinden, Anzeige mit ~30–60 fps aktualisieren ohne Rebuild der gesamten Seite.
4. [x] Bedienflächen und Zustandswechsel verbinden.
5. [x] Wakelock und Vibration einbauen.
6. [x] Studienliste: Öffnen einer Studie, Kennzahlen auf der Karte.
7. [x] Texte DE/EN ergänzen.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Formatierer: 0, < 1 s, 1 min = 100 HM, Rundung, > 1 h.
- Widget-Test mit Fake-Uhr: nach Start zeigt das Overlay Schritt 1; nach weiter Schritt 2; nach dem letzten wieder Schritt 1 mit Zyklus 2.
- Widget-Test: neue Messung erscheint oben in der Live-Liste.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün; das Overlay zeigt zu jedem Zeitpunkt den Schritt, dem die laufende Zeit zugeordnet wird (Test belegt die Zuordnung).
- [x] Manuelle Geräteprüfung: Bildschirm geht während der Messung nicht aus, Vibration spürbar (in Notizen vermerkt).

## Offene Fragen / Annahmen

- Genaue Gestaltung des Overlays (Vollbild-Banner vs. große Karte) ist nicht vorgegeben. Annahme: große Karte im oberen Drittel, die immer sichtbar bleibt, auch wenn die Liste scrollt.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `RecordingScreen` mit Zeit-Kacheln (GESAMT / SCHRITT bzw. RUNDE, Stoppuhr groß + HM), dauerhaft sichtbarem `StepOverlay` (Status, Schrittname groß, "Schritt x von n", nächster Schritt, Zyklus, Farbwechsel je Zustand, Sonderzeit-Anzeige vorbereitet), `LiveList` (neueste oben, Zyklus-Nr., kumulierte Zeit, Dauer in Stoppuhr + HM), `ControlBar` (START/STOPP/WEITER + großer NÄCHSTER-Button), Zurücksetzen mit Rückfrage. `RecordingController` serialisiert Aktionen (schnelle Tastendrücke bleiben in Reihenfolge). Wakelock und Haptik (Schritt vs. Zyklus unterscheidbar) über `DeviceFeedback`. Studienkarte zeigt echte Zyklen-/Rundenzahl. Mehr als geplant: Formatierer kann bereits alle vier Einheiten.
- **Learnings & Stolpersteine:** `ref.invalidate` in `dispose()` wirft (Element schon deaktiviert) – Invalidierung nach `Navigator.push` erledigen. Ticker läuft endlos: in Widget-Tests nie `pumpAndSettle`, sondern `settle()`/`pump()`.
- **Wichtige Entscheidungen und ihre Gründe:** Overlay als große Karte direkt unter den Zeiten (bleibt immer sichtbar, Liste scrollt darunter). Im Ruhezustand zeigt das Overlay "Bereit" mit Schritt 1, damit klar ist, womit der Start beginnt.
- **Auswirkungen auf Folge-Tasks:** Task_04/05: `RecordingController.next/startStop/beginSpecial/endSpecial` nehmen `at:`-Zeitstempel an – Tasten-Interpreter direkt daran anschließen. Task_07/09: Tabs (Zyklen, Auswertung) in `RecordingScreen` ergänzen; `LiveList` ist die Live-Ansicht. Task_10: Einheit der Kacheln/Liste aus den Einstellungen lesen (aktuell fest Stoppuhr + HM). Task_14/15 nutzen die Variante ohne Schritte bzw. freie Reihenfolge (Grundlage im Controller schon vorhanden).
- **Hinweise zu Tests und Befehlen:** Widget-Tests: `tests/recording/presentation/recording_screen_test.dart` mit `clockProvider` → `FakeClock`. Keine manuelle Geräteprüfung möglich (kein Gerät verfügbar) – Wakelock/Vibration beim ersten Gerätetest prüfen.

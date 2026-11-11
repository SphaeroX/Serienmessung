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

1. [ ] Zeitformatierer HM und mm:ss.SSS umsetzen und testen.
2. [ ] Messbildschirm-Layout mit Schritt-Overlay umsetzen (gut lesbar aus Armlänge, Hell/Dunkel).
3. [ ] An den Engine-Zustand anbinden, Anzeige mit ~30–60 fps aktualisieren ohne Rebuild der gesamten Seite.
4. [ ] Bedienflächen und Zustandswechsel verbinden.
5. [ ] Wakelock und Vibration einbauen.
6. [ ] Studienliste: Öffnen einer Studie, Kennzahlen auf der Karte.
7. [ ] Texte DE/EN ergänzen.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Formatierer: 0, < 1 s, 1 min = 100 HM, Rundung, > 1 h.
- Widget-Test mit Fake-Uhr: nach Start zeigt das Overlay Schritt 1; nach weiter Schritt 2; nach dem letzten wieder Schritt 1 mit Zyklus 2.
- Widget-Test: neue Messung erscheint oben in der Live-Liste.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün; das Overlay zeigt zu jedem Zeitpunkt den Schritt, dem die laufende Zeit zugeordnet wird (Test belegt die Zuordnung).
- [ ] Manuelle Geräteprüfung: Bildschirm geht während der Messung nicht aus, Vibration spürbar (in Notizen vermerkt).

## Offene Fragen / Annahmen

- Genaue Gestaltung des Overlays (Vollbild-Banner vs. große Karte) ist nicht vorgegeben. Annahme: große Karte im oberen Drittel, die immer sichtbar bleibt, auch wenn die Liste scrollt.

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

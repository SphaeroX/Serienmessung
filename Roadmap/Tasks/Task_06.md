# Task_06: Hintergrundbetrieb & Wiederherstellung

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_06.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine laufende Messung geht nie verloren: Sie läuft weiter, wenn die App in den Hintergrund geht oder der Bildschirm ausgeht, eine Benachrichtigung zeigt den aktuellen Schritt, und nach einem App-Absturz/Neustart wird die laufende Messung korrekt wiederhergestellt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_03 archiviert (Task_04/05 ebenfalls, da strikte Reihenfolge).
- **Relevantes Vorwissen:** Die alte App hat "Benachrichtigungen" und "Bildschirm aktiv halten" als Einstellungen. Da die Zeit über eine monotone Uhr gemessen wird, reicht es, Startzeitpunkt und Zustand persistent zu halten – die Zeit läuft dann rechnerisch weiter.

## Umfang

**Gehört dazu:**

- Laufzustand der Engine (Zustand, Zyklus, Schritt, Startzeitpunkt des laufenden Schritts bzw. der Sonderzeit) bei jeder Änderung persistieren.
- Beim App-Start: unterbrochene Messung erkennen und auf Wunsch fortsetzen (Zeit läuft seit dem letzten Zeitpunkt weiter) oder stoppen.
- Android-Foreground-Service mit dauerhafter Benachrichtigung: aktueller Schritt, Zyklus, laufende Zeit; Aktionen "Weiter" und "Stopp".
- Prüfen, ob Lautstärketasten bei ausgeschaltetem Bildschirm nutzbar sind; Ergebnis dokumentieren (umsetzen nur, wenn ohne großen Aufwand möglich).
- Benachrichtigungs-Berechtigung (Android 13+) anfragen.

**Gehört nicht dazu:**

- Einstellungsschalter für Benachrichtigungen (Task_10).
- iOS-Hintergrundverhalten.

## Umsetzungsschritte

1. [ ] Persistenz des Laufzustands entwerfen; Umgang mit monotoner Uhr über Neustarts klären (elapsedRealtime überlebt keinen Geräte-Neustart → Fallback dokumentieren).
2. [ ] Wiederherstellungslogik beim App-Start umsetzen.
3. [ ] Foreground-Service mit Benachrichtigung und Aktionen umsetzen.
4. [ ] Berechtigungsabfrage einbauen.
5. [ ] Tasten bei ausgeschaltetem Bildschirm untersuchen, Ergebnis in README.
6. [ ] Manuelle Geräteprüfung: App wegwischen, Bildschirm aus, Neustart der App.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Laufzustand speichern → neue Engine-Instanz mit gleicher Fake-Uhr stellt Zustand exakt wieder her und misst korrekt weiter.
- Wiederherstellung während Sonderzeit.
- Keine unterbrochene Messung → kein Wiederherstellungsdialog.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün.
- [ ] Manuell: Messung starten, App beenden (wegwischen), App neu öffnen → Messung läuft mit korrekter Gesamtzeit weiter (in Notizen vermerkt).
- [ ] Manuell: Benachrichtigung zeigt den aktuellen Schritt, "Weiter" in der Benachrichtigung wechselt den Schritt.

## Offene Fragen / Annahmen

- Verhalten bei Geräte-Neustart während einer Messung: Annahme: Messung wird gestoppt, der letzte Schritt bis zum letzten bekannten Zeitpunkt gespeichert und als unvollständig markiert.

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

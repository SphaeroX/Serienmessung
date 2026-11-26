# Task_50: Simulationsbildschirm absichern und Version 1.9.2

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_50.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Der Simulationsbildschirm kann die App nicht mehr einfrieren oder in einer endlosen Fortschrittsanzeige hängen lassen: Der frei eingegebene Zeitraum hat eine Obergrenze, und ein Fehler der Berechnung wird angezeigt. Damit sind alle Befunde der Fehlerprüfung vom 2026-11-26 erledigt, und die Fehlerbehebungen aus Task_47 bis Task_50 gehen als Version 1.9.2 heraus.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_47, Task_48 und Task_49 archiviert. Deren "Erkenntnisse für Folge-Agenten" lesen (für die Versionshinweise und die Doku).
- **Herkunft:** Fehlerprüfung vom 2026-11-26 (Befund 13; siehe `Roadmap/README.md`, „[Fehlerprüfung 2026-11-26]“). Aus dem Code abgeleitet, nicht mit einem Test reproduziert.
- **Relevantes Vorwissen:** README „[Task_31] Simulationsbildschirm“ und „[Task_43] Simulation der Gesamtanlage“ (Laufzeit: Linien mit mehr als `offThreadMachines` = 30 Maschinen rechnen in einem Hintergrund-Isolate, kleinere direkt im UI-Thread); `docs/architecture.md` Abschnitte „Simulation screen“ und „Simulation of a plant“. Erkenntnisse von Task_31, Task_43 und Task_46 (Stellen der Versionsnummer).
- **Ursachen:**
  - `_horizonMicros` in `lib/group/presentation/simulation_screen.dart` akzeptiert jede positive Stundenzahl. Kleine Linien rechnen im UI-Thread; 24 h dauern weit unter einer Sekunde, 100 000 h aber Minuten.
  - `_simulate()` ruft `runSimulation(...).then(...)` ohne Fehlerbehandlung: Scheitert das Isolate, bleibt `_busy` gesetzt. `simulateRun` im UI-Thread kann einen `ArgumentError` werfen (Maschine mit Taktzeit ≤ 0), der nicht gefangen wird.
- **Betroffener Code:** `lib/group/presentation/simulation_screen.dart`, `lib/group/domain/simulation_runner.dart`, ARB-Dateien in `lib/l10n/`, `pubspec.yaml`, `lib/settings/presentation/settings_screen.dart` (`appVersion`), Root-`README.md`.

## Umfang

**Gehört dazu:**

- **Obergrenze:** Der freie Zeitraum ist auf höchstens 720 Stunden (30 Tage) begrenzt. Eine größere Eingabe wird nicht simuliert; eine Meldung nennt die Grenze.
- **Fehler anzeigen:** Scheitert die Berechnung (im UI-Thread oder im Isolate), endet die Fortschrittsanzeige und der Bildschirm zeigt eine Fehlermeldung statt der Ergebnisse. Eine neue Eingabe kann danach wieder simuliert werden.
- **Version 1.9.2:** `pubspec.yaml`, `appVersion` und Root-`README.md`; in `Roadmap/README.md` der Status mit einer Zusammenfassung der behobenen Befunde (Task_47 bis Task_50).
- **Doku-Abgleich:** `docs/architecture.md` einmal gegen die Änderungen von Task_47 bis Task_50 lesen und Lücken schließen. Die Website (`site/index.html`, `site/privacy/index.html`) nur anfassen, wenn sich dort beschriebenes Verhalten geändert hat.

**Gehört nicht dazu:**

- Änderungen an der Simulations-Engine (`lib/group/domain/line_simulation.dart`) oder an ihren Ergebnissen. Die Demo-Linie liefert weiter 1000 Teile in 24 h, die Demo-Anlage 998.
- Obergrenzen für andere Eingaben (Ausfalldauer, Anzahl Maschinen einer Zelle, Teile je Zyklus).
- Abbrechen einer laufenden Simulation.
- Commit, Merge, Tag und Upload in den Play-Test (macht der Nutzer).

## Umsetzungsschritte

1. [ ] Obergrenze für den freien Zeitraum als benannte Konstante (TDD: Widget-Test mit zu großer Eingabe).
2. [ ] Fehlerbehandlung für beide Rechenwege, sodass `_busy` immer endet (TDD: Widget-Test mit einer Simulation, die wirft).
3. [ ] Texte EN/DE für Obergrenze und Rechenfehler, `flutter gen-l10n`.
4. [ ] Version auf 1.9.2 setzen (alle drei Stellen), Versionshinweis in der Root-`README.md` nach dem Muster der bisherigen Versionen.
5. [ ] `docs/architecture.md` und `Roadmap/README.md` abgleichen; den Eintrag „[Fehlerprüfung 2026-11-26]“ auf „alle Befunde erledigt“ setzen.
6. [ ] Volle Suite, `flutter analyze`, `dart format`, `flutter build apk --debug`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: Ergänzungen in `tests/group/presentation/simulation_screen_test.dart` (nur neue Tests) oder eine neue Datei `tests/group/presentation/simulation_limits_test.dart`.

Zu belegende Verhaltensweisen:

- Freier Zeitraum 720 h wird simuliert; 721 h und 100000 h werden nicht simuliert, die Meldung mit der Grenze erscheint, die vorherigen Ergebnisse bleiben oder verschwinden einheitlich (in den Notizen festhalten, was gewählt wurde).
- Eingabe mit Komma (`7,5`) funktioniert weiter; `0`, negative Werte und leere Eingabe werden wie bisher abgelehnt (bestehende Tests).
- Eine Berechnung, die wirft: Die Fortschrittsanzeige (`simBusy`) verschwindet, eine Fehlermeldung erscheint, eine anschließende gültige Simulation zeigt wieder Ergebnisse.
- Schicht und 24 h liefern dieselben Zahlen wie vor dem Task (bestehende Tests, inklusive Demo-Linie 1000 Teile in 24 h).
- Die Einstellungen zeigen Version 1.9.2.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [x] Verhalten wie unter „Tests“ beschrieben belegt.
- [x] Kein bestehender Test geändert, gelöscht oder abgeschwächt. Ausnahme mit Begründung in den Notizen: ein Test, der die Versionsnummer 1.9.1 fest erwartet.
- [x] `grep -rn "1\.9\.1" pubspec.yaml lib/settings README.md` findet nichts mehr außer in Versionshistorien.
- [x] `flutter build apk --debug` baut.
- [x] `docs/architecture.md`, Root-`README.md` und `Roadmap/README.md` aktuell; in `Roadmap/Tasks/` liegt danach kein Task mehr und der Status in `Roadmap/README.md` sagt das.

## Offene Fragen / Annahmen

- **Annahme:** 720 Stunden als Obergrenze. Eine kleine Linie braucht dafür im UI-Thread grob 30-mal so lange wie für 24 h, also wenige Sekunden auf einem langsamen Gerät. Misst der Agent deutlich mehr, senkt er die Grenze oder lässt lange Zeiträume auch für kleine Linien im Isolate rechnen und begründet das in den Notizen.
- **Annahme:** Die Fehlermeldung ist ein allgemeiner Text („Die Simulation konnte nicht berechnet werden“), ohne technische Details.
- **Offen, hängt von Task_47 bis Task_49 ab:** Welche Punkte in den Versionshinweis kommen. Grundlage sind deren „Erkenntnisse für Folge-Agenten“; nicht umgesetzte oder verschobene Befunde werden dort genannt statt verschwiegen.
- **Offen:** Ob ein vorhandener Test die Versionsnummer fest prüft, ist nicht bekannt. Falls ja, ist das Anpassen dieser einen Erwartung erlaubt (siehe Akzeptanzkriterien).

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Gemessen (Windows, Debug-Testlauf): kleine Linie (2 Maschinen, Puffer, ein Ausfall → 4 Läufe) 24 h ≈ 63 ms, 720 h ≈ 528 ms. Grenze 720 h bleibt.
- Gewählt bei zu großem Zeitraum: die vorherigen Ergebnisse bleiben stehen (wie bei einer ungültigen Zeit), nur die Meldung erscheint. Bei einem Rechenfehler verschwinden die Ergebnisse, die Meldung „konnte nicht berechnet werden“ erscheint.
- Fehler testbar über `simulationRunnerProvider` (`SimulationRunner`, im Test `_FailingRunner` für beide Rechenwege).
- Kein bestehender Test prüfte die Versionsnummer; neuer Test `tests/settings/app_version_test.dart`. Root-README enthält nur die Tag-Zeile als Versionsangabe (Muster der bisherigen Versionen), Versionshinweise stehen in `Roadmap/README.md`.
- Website unverändert (kein dort beschriebenes Verhalten geändert).
- Endstand: 925 Tests bestanden, `flutter analyze` sauber, `dart format` sauber, `flutter build apk --debug` baut.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `maxHorizonHours` = 720 mit Meldung `simHorizonTooLong`; Rechenfehler auf beiden Wegen → `simFailed`, `_busy` endet, Ergebnisse weg. Dafür `SimulationRunner` + `simulationRunnerProvider` (additiv, `runSimulation`/`simulateRun` unverändert). Version 1.9.2 (`pubspec.yaml`, `appVersion`, Tag-Zeile im Root-README). Doku-Abgleich in `docs/architecture.md`.
- **Learnings & Stolpersteine:** Kleine Linien rechnen synchron im UI-Thread; bestehende Tests erwarten das Ergebnis nach `pumpAndSettle` – der direkte Weg muss synchron bleiben.
- **Wichtige Entscheidungen und ihre Gründe:** Bei zu großem Zeitraum bleiben die alten Ergebnisse (einheitlich mit „ungültige Zeit“).
- **Auswirkungen auf Folge-Tasks:** Keine; die Roadmap ist abgeschlossen. Offen bleiben die Geräteprüfungen aus Task_47 und Task_48.
- **Hinweise zu Tests und Befehlen:** `tests/group/presentation/simulation_limits_test.dart`, `tests/settings/app_version_test.dart`. Unter Windows vor `flutter gen-l10n`/`flutter build apk` ggf. `attrib -r` auf `lib\l10n` und `build` (Ordner und Inhalt).

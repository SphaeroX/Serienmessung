# Task_21: Nachfrage bei veralteter Messung

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_21.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Ist die letzte Messung einer Studie älter als X Tage (Einstellung, Standard 10, 0 = aus), fragt die App beim Öffnen der Studie, ob eine neue Messung (neue Revision) begonnen oder mit den bisherigen Zeiten weitergemacht werden soll.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_20 archiviert.
- **Relevantes Vorwissen:** Task_20 (`RevisionRepository`, letzter Messzeitpunkt), Task_10 (Einstellungen).

## Umfang

**Gehört dazu:**

- Einstellung `staleDays` (Standard 10, 0 = nie fragen) im Einstellungsbildschirm.
- Reine Funktion "ist veraltet" (Tage seit letzter Messung).
- Dialog in `openStudy` (gilt für Startseite und Gruppen): "Neue Messung beginnen" / "Bisherige fortsetzen". Nicht bei laufender Aufnahme und nicht bei Video-Studien.
- Texte DE/EN.

**Gehört nicht dazu:**

- Erinnerungen/Benachrichtigungen außerhalb der App.

## Umsetzungsschritte

1. [ ] Einstellung + Test.
2. [ ] Domain-Funktion + Test.
3. [ ] Dialog beim Öffnen + Widget-Test.
4. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Älter als Schwelle → Dialog; "Neue Messung" startet eine Revision, "Fortsetzen" ändert nichts.
- Jünger, ohne Zeiten, Schwelle 0, laufende Aufnahme oder Video-Studie → kein Dialog.
- Einstellung wird gespeichert und geladen.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Video-Studien werden ausgenommen: dort bestimmt das Video die Messung, nicht das Öffnungsdatum.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `AppSettings.staleDays` (+ `staleDayChoices`), Einstellungs-Kachel "Neue Messung vorschlagen"; `isMeasurementStale`/`daysSince` (`lib/revision/domain/staleness.dart`); `offerNewRevisionIfStale` (`lib/revision/presentation/stale_prompt.dart`), aufgerufen in `openStudy`. Dialog "Messung ist N Tage alt" mit "Fortsetzen" / "Neue Messung" (nicht wegklickbar).
- **Learnings & Stolpersteine:** Für Widget-Tests von `openStudy` reicht ein `Builder` mit Knopf; `RecordingScreen` braucht `usePhoneSize` und `pumpFrames` statt `pumpAndSettle`.
- **Wichtige Entscheidungen und ihre Gründe:** "Älter als X Tage" streng (genau X Tage → keine Frage). Keine Frage bei Video-Studien, laufender Aufnahme oder ohne Zeiten. "Neue Messung" archiviert die Zeiten als Revision (siehe Task_20) statt sie zu löschen.
- **Auswirkungen auf Folge-Tasks:** Keine. Einstellung `staleDays` ist bewusst nicht Teil des Backups (Einstellungen generell nicht).
- **Hinweise zu Tests und Befehlen:** `tests/revision/domain/staleness_test.dart`, `tests/revision/presentation/stale_prompt_test.dart`, `tests/settings/stale_days_setting_test.dart`.

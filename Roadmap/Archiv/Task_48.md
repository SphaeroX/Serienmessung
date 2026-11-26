# Task_48: Video-Studie: Marker-Undo, Video ersetzen und Player absichern

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_48.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Fünf Fehler der Video-Studie sind behoben: Ein zurückgenommener Marker hinterlässt keinen überzähligen Schritt mehr, ein nicht abspielbares neues Video kostet nicht das alte, ein Doppeltipp erzeugt keinen Schritt mit 0 Dauer, der alte Player wird beim Ersetzen freigegeben und eine abgebrochene Geste lässt keine Sonderzeit weiterlaufen.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_47 archiviert (grüne Suite unter Windows). Dessen "Erkenntnisse für Folge-Agenten" lesen.
- **Herkunft:** Fehlerprüfung vom 2026-11-26 (Befunde 3, 4, 9, 11 und 12; siehe `Roadmap/README.md`, „[Fehlerprüfung 2026-11-26]“). Befunde 3 und 9 wurden mit Tests reproduziert, 4, 11 und 12 sind aus dem Code abgeleitet.
- **Relevantes Vorwissen:** README „[Nach Task_18] Feedback-Runde 1“ (`study.steps_open`: Marker im ersten Zyklus legen Schritte an), „[Task_12] Video“, „[Task_13] Zeitleiste“, „[Review nach Task_35]“ Punkte 5 und 8; `docs/architecture.md` Abschnitte zu `steps_open`, „Video files“ und „Undo of a marker with special times“. Erkenntnisse von Task_12 und Task_13.
- **Ursachen:**
  - Befund 3: `RecordingController.mark()` legt bei offenen Schritten per `_appendStep()` einen Schritt an; `undoLastMarker()` löscht nur die Zeit und spult zurück. `closeCycle()` verlangt dann `engine.stepIndex == steps.length - 1` und lehnt ab.
  - Befund 4: `_chooseVideo()` in `lib/video/presentation/video_study_screen.dart` speichert den neuen Pfad, ruft `_open()` (kehrt bei einem Fehler normal zurück) und löscht danach das alte Video.
  - Befund 9: `canMarkAt()` erlaubt `at >= segmentStartMicros`, also auch dieselbe Position.
  - Befund 11: `PluginVideoPlayback.open()` (`lib/video/platform/video_playback.dart`) ersetzt `_c`, ohne den alten `VideoPlayerController` freizugeben; `dispose()` gibt nur den letzten frei.
  - Befund 12: Die Sonderzeit-Taste in `_MarkBar` hat `onPointerDown`/`onPointerUp`, aber kein `onPointerCancel` (der Live-Bildschirm hat es).
- **Betroffener Code:** `lib/recording/presentation/recording_controller.dart`, `lib/study/data/study_repository.dart`, `lib/video/presentation/video_study_screen.dart`, `lib/video/platform/video_playback.dart`, `tests/fakes/fake_video.dart`.

## Umfang

**Gehört dazu:**

- **Marker zurücknehmen (Befund 3):** Solange die Schritte offen sind (`stepsOpen`), entfernt „Marker rückgängig“ auch den Schritt, den der zurückgenommene Marker angelegt hat – sofern dieser Schritt keine Zeiten hat. Danach ist der vorherige Schritt wieder der letzte, und „Zyklus fertig“ wird angenommen. Das gilt auch für das Zurücknehmen des Startmarkers (zurück in den Ruhezustand ohne Schritte). Bei festen Schritten (`stepsOpen` aus) ändert sich nichts.
- **Video ersetzen (Befund 4):** Lässt sich das neue Video nicht öffnen, bleiben der gespeicherte Pfad, das alte Video und seine Datei erhalten; die Kopie des neuen Videos wird gelöscht (`deleteUnusedVideo`) und eine Meldung erklärt es. Die Frage „Zyklen behalten oder löschen?“ wirkt erst, wenn das neue Video geöffnet ist – Zeiten werden nicht für ein Video gelöscht, das dann nicht kommt.
- **Doppelter Marker (Befund 9):** Ein Marker an genau der Position des letzten Markers wird abgelehnt und legt keinen Schritt an. Der Hinweis für den Nutzer nennt den Grund.
- **Player freigeben (Befund 11):** `PluginVideoPlayback.open()` gibt einen vorher geöffneten Controller frei (Listener entfernen, `dispose`), auch wenn das Öffnen des neuen scheitert.
- **Sonderzeit-Taste (Befund 12):** `onPointerCancel` beendet die Sonderzeit wie `onPointerUp`.
- Texte EN/DE für neue Meldungen, `docs/architecture.md`, `Roadmap/README.md`.

**Gehört nicht dazu:**

- Umbau des Marker-Modells (z. B. Marker einzeln löschen, Schritte während der Aufnahme umbenennen).
- Mindestabstand zwischen Markern über „nicht dieselbe Position“ hinaus.
- Vorschau oder Formatprüfung von Videos vor dem Kopieren.
- Schlafsichere Zeitbasis (Task_47) und die Befunde zu Import, Löschen und Simulation (Task_49, Task_50).

## Umsetzungsschritte

1. [ ] Marker zurücknehmen bei offenen Schritten (TDD, zuerst der Test aus der Fehlerprüfung: Start, zwei Marker, einer zu viel, rückgängig, „Zyklus fertig“).
2. [ ] Doppelten Marker an derselben Position ablehnen (TDD), Hinweistext prüfen.
3. [ ] Video ersetzen: Reihenfolge so ändern, dass erst das erfolgreiche Öffnen den Pfad, das Löschen der Zeiten und das Löschen der alten Datei auslöst (Widget-Test mit einem Fake-Player, der das Öffnen verweigert).
4. [ ] `PluginVideoPlayback.open()`: alten Controller freigeben.
5. [ ] `onPointerCancel` an der Sonderzeit-Taste der Video-Studie (Widget-Test).
6. [ ] Texte, Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: Ergänzungen in `tests/video/open_steps_test.dart`, `tests/video/video_marking_test.dart` und `tests/video/video_study_screen_test.dart` (nur neue Tests) sowie `tests/video/video_replace_test.dart`.

Zu belegende Verhaltensweisen:

- Offene Schritte: Start bei 1 s, Marker bei 2 s und 3 s, den Marker bei 3 s zurücknehmen → es gibt wieder genau zwei Schritte, Schritt 2 läuft, „Zyklus fertig“ bei 4 s wird angenommen und der Zyklus ist vollständig.
- Offene Schritte: Alle Marker bis zum Start zurücknehmen → Ruhezustand, keine Schritte, keine Zeiten.
- Offene Schritte: Ein Schritt, der schon Zeiten hat, wird beim Zurücknehmen nicht gelöscht.
- Feste Schritte: „Marker rückgängig“ verhält sich wie bisher (bestehende Tests bleiben grün, inklusive Sonderzeiten).
- Zwei Marker an derselben Position: Der zweite wird abgelehnt, es entsteht keine Zeit mit 0 Dauer und kein neuer Schritt.
- Video ersetzen mit einem nicht abspielbaren Video: `study.video_path` ist unverändert, die alte Datei wurde nicht gelöscht (`FakeVideoFiles`), die Kopie des neuen wurde gelöscht, das alte Video ist weiter geöffnet, eine Meldung erscheint.
- Video ersetzen mit „Zyklen löschen“ und nicht abspielbarem Video: Die Zyklen sind noch da.
- Video ersetzen mit einem abspielbaren Video: Verhalten wie bisher (bestehende Tests).
- Sonderzeit-Taste: Zeiger gedrückt, dann abgebrochen → die Sonderzeit ist beendet und gespeichert.

Der Player-Wechsel in `PluginVideoPlayback` hängt am echten Plugin und ist nicht automatisiert testbar; er wird am Gerät geprüft (siehe Akzeptanzkriterien).

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [x] Verhalten wie unter „Tests“ beschrieben belegt.
- [x] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [x] Neue Texte in beiden ARB-Dateien, `flutter gen-l10n` gelaufen, keine hartkodierten Texte.
- [x] `docs/architecture.md` und `Roadmap/README.md` aktuell.
- [x] Geräteprüfung **offen** (kein Gerät angeschlossen): Video dreimal ersetzen, danach spielt das letzte Video flüssig; ein nicht abspielbares Video ablehnen lassen.

## Offene Fragen / Annahmen

- **Annahme:** Ein beim Zurücknehmen entfernter Schritt wird wirklich gelöscht (nicht nur ausgeblendet). `StudyRepository.deleteStep` löscht auch Zeiten des Schritts; es darf nur für Schritte ohne Zeiten aufgerufen werden.
- **Annahme:** Schlägt das Öffnen des neuen Videos fehl und es war vorher kein Video vorhanden, bleibt der Bildschirm „Noch kein Video“ mit der Meldung.
- **Offen:** Ob `PluginVideoPlayback.open()` den alten Controller vor oder nach dem erfolgreichen Öffnen des neuen freigibt, entscheidet der Agent. Bedingung: Nach einem gescheiterten Ersetzen spielt das alte Video weiter (siehe Tests), und es bleibt kein Controller ungenutzt offen.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Volle Suite danach: 878 bestanden, 0 Fehlschläge (Windows).
- Entscheidung `PluginVideoPlayback.open()`: alten Controller **nach** dem erfolgreichen Initialisieren des neuen freigeben; scheitert das Initialisieren, wird der neue freigegeben und der alte bleibt offen (spielt weiter).
- Meldung bei nicht abspielbarem Video: allgemein „…ließ sich nicht öffnen. Es wurde nichts geändert.“ (passt auch, wenn vorher kein Video da war).
- **Geräteprüfung offen:** Video dreimal ersetzen, danach spielt das letzte flüssig; ein nicht abspielbares Video (z. B. umbenannte Textdatei) ablehnen lassen.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Alle fünf Befunde wie geplant. `undoLastMarker` = `_undoLastMarker` + bei `stepsOpen` `_dropUnusedTrailingSteps` (löscht Schritte hinter dem aktuellen ohne Zeiten – bei offenen Schritten sind alle Schritte von Markern angelegt, deshalb sicher). `canMarkAt` strikt größer. `_chooseVideo`: Frage zuerst, dann `playback.open` des neuen Pfads, erst bei Erfolg Zeiten löschen/Marker zurücksetzen/Pfad speichern/alte Datei löschen; `_open` aufgeteilt in `_open` + `_showOpened`. Neue Texte `markerAtLast`, `videoNotPlayable`.
- **Learnings & Stolpersteine:** `lib/l10n` trägt unter Windows wieder das ReadOnly-Attribut; vor `flutter gen-l10n` `attrib -r lib\l10n` (Ordner) und `attrib -r lib\l10n\* /s`.
- **Wichtige Entscheidungen und ihre Gründe:** Der Player hält das alte Video, bis das neue initialisiert ist – so braucht der Bildschirm nach einem Fehlschlag nichts neu zu öffnen. Auch beim allerersten Video wird die Kopie bei einem Fehlschlag gelöscht und der Bildschirm bleibt „Noch kein Video“.
- **Auswirkungen auf Folge-Tasks:** Keine für Task_49. Task_50: Versionshinweis kann „Marker rückgängig bei neuer Video-Studie“, „kein Marker an derselben Stelle“, „nicht abspielbares Video ersetzt das alte nicht mehr“ nennen.
- **Hinweise zu Tests und Befehlen:** Neue Tests: `tests/video/marker_undo_open_steps_test.dart`, `tests/video/video_replace_test.dart` (inkl. Sonderzeit-Taste mit `gesture.cancel()` und Hinweis bei gleicher Position). `PluginVideoPlayback` ist nicht automatisiert getestet (echtes Plugin).

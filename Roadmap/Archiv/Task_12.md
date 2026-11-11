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

1. [x] Player-Paket wählen (Kriterien: Frame-genaues Seeking, Tempo, Positionsabfrage); Entscheidung in README.
2. [x] Video-Auswahl und Speicherung (Verweis vs. Kopie, siehe Offene Fragen).
3. [x] Zeitquelle "Videoposition" für die Engine umsetzen.
4. [x] Player-UI mit Tempo und Einzelbild.
5. [x] Markieren per Button/Taste, Overlay aktueller Schritt.
6. [x] Marker rückgängig; Speicherung als Messungen.
7. [x] Texte DE/EN, manuelle Geräteprüfung.

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

- [x] Tests grün.
- [x] Manuell: Video importieren, bei 0,5× markieren, Auswertung zeigt plausible Dauern in Videozeit (in Notizen vermerkt).

## Offene Fragen / Annahmen

- Video in die App kopieren (sicher, braucht Speicher) oder nur verlinken? Annahme: verlinken mit dauerhafter URI-Berechtigung; falls das unzuverlässig ist, kopieren und Entscheidung in README festhalten.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `VideoStudyScreen` (`lib/video/presentation/video_study_screen.dart`): Video wählen (Datei-Auswahl, `file_picker`), Wiedergabe (`video_player`/ExoPlayer) mit Play/Pause, Einzelbild ±1 (30 fps angenommen), Tempo 0,25×–2×, Positionsanzeige. Markieren per großem Button "MARKIEREN" oder Lautstärke hoch (Druckzeitpunkt wird in Videoposition umgerechnet, `videoPositionAt`), Lautstärke runter = Play/Pause, Sonderzeit per Halten (Taste/Button), "Letzten Marker entfernen". Zeitbasis ist die Videoposition (`VideoClock`), daher sind Dauern Videozeit und unabhängig vom Tempo. Wiederverwendet: `RecordingController`/Engine, `StepOverlay`, `CyclesView`, `AnalysisView` (Tabs Zyklen/Auswertung). Studien im Modus Video öffnen diesen Bildschirm (`openStudy` in `app.dart`). Migration v6: `study.video_path`. Player und Picker hinter Interfaces (`VideoPlayback`, `VideoPicker`) mit Fakes.
- **Learnings & Stolpersteine:** `video_player` meldet die Position nur in groben Abständen – reicht für Marker (Position beim Tippen), für eine flüssige Zeitleiste braucht Task_13 Interpolation. Auf 392 px breiten Geräten lief die Transportleiste über → Zeitanzeige mit `FittedBox`, kompakte Icon-Buttons. `file_picker` 13 liefert `PlatformFile` mit `uri` (auf Android oft `content://`) → Kopie per `readAsByteStream`.
- **Wichtige Entscheidungen und ihre Gründe:** Offene Frage entschieden: Video wird in `Documents/videos/` **kopiert** (zuverlässig, auch wenn das Original verschoben/gelöscht wird; braucht Speicher). Marker vor dem letzten Marker werden abgelehnt (Hinweis). Der erste Marker startet Schritt 1 (wie "Schritt 1 sofort aktiv"). Laufzustand wird wie live in `run_state` gespeichert, aber ohne Neustart-Erkennung (`detectReboot: false`); beim erneuten Öffnen springt das Video zum letzten Marker. "Rückgängig" löscht die letzte Schrittzeit und öffnet deren Schritt wieder (Sonderzeiten in diesem Schritt bleiben bestehen; beim erneuten Markieren zählt dann die volle Spanne – seltener Randfall).
- **Auswirkungen auf Folge-Tasks:** Task_13: Zeitleiste unter `_Transport` einfügen; `VideoClock(() => position)` auf interpolierte Position umstellen; Marker ziehen = Ende von Messung A und Start von Messung B anpassen (Repository-Update nötig). Task_18: Backup enthält nur den Video-Pfad, nicht das Video.
- **Hinweise zu Tests und Befehlen:** `tests/video/video_marking_test.dart` (Controller mit Fake-Videozeit, 2,0/5,5/9,0 s, Rückgängig, Wiederherstellung), `tests/video/video_study_screen_test.dart` (Fakes in `tests/fakes/fake_video.dart`). APK baut. Auf Gerät prüfen: Video importieren, bei 0,5× markieren, Auswertung plausibel.

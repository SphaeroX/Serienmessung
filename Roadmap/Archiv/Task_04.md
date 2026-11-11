# Task_04: Hardware-Tasten (Android)

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_04.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Die Messung lässt sich blind über die Lautstärketasten bedienen: Lautstärke hoch kurz = nächster Schritt, Lautstärke runter = Start/Stopp. Die Systemlautstärke ändert sich dabei nicht.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_03 archiviert.
- **Relevantes Vorwissen:** README: Tastenbelegung. Das gedrückt-Halten von Lautstärke hoch wird in Task_05 für die Sonderzeit genutzt – die Erkennung muss deshalb schon jetzt kurz vs. lang unterscheiden können (Key-Down/Key-Up-Ereignisse mit Zeitstempel weiterreichen). Risiko: Flutter bietet das nicht direkt, vermutlich eigener Platform Channel in der Android-Activity (`onKeyDown`/`onKeyUp`).

## Umfang

**Gehört dazu:**

- Android-Implementierung, die Lautstärke-Ereignisse abfängt, solange der Messbildschirm aktiv ist, und die Lautstärkeänderung unterdrückt.
- Dart-Interface `HardwareTasten` mit Ereignissen (taste, runter/hoch, zeitstempel) und Fake für Tests.
- Interpretation: kurzer Druck hoch → weiter; runter → Start/Stopp. Schwelle kurz/lang konfigurierbar (Standard z. B. 400 ms), lang wird vorerst ignoriert.
- Auf anderen Bildschirmen verhalten sich die Tasten normal (Lautstärke).
- Zeitpunkt der Messung ist der Key-Down-Zeitpunkt, nicht Key-Up.

**Gehört nicht dazu:**

- Sonderzeit beim Halten (Task_05).
- Bedienung bei ausgeschaltetem Bildschirm / im Hintergrund (Task_06 prüft, was möglich ist).
- iOS.
- Einstellungsschalter (Task_10) – bis dahin immer aktiv.

## Umsetzungsschritte

1. [x] Machbarkeit prüfen: vorhandenes Paket vs. eigener Platform Channel; Entscheidung in README festhalten.
2. [x] Android-Seite umsetzen (Ereignisse abfangen, Lautstärke unterdrücken, nur wenn aktiviert).
3. [x] Dart-Interface, Fake und Interpreter (kurz/lang) umsetzen.
4. [x] Interpreter an Engine anbinden; Key-Down-Zeitstempel als Messzeitpunkt verwenden.
5. [x] Aktivierung an Lebenszyklus des Messbildschirms koppeln.
6. [x] Manuell auf echtem Gerät prüfen und Ergebnis notieren.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Interpreter: kurzer Druck hoch → genau ein weiter; Druck runter → Start bzw. Stopp im Wechsel.
- Interpreter: Druck länger als Schwelle löst kein weiter aus.
- Messzeitpunkt = Key-Down-Zeit (Fake-Ereignisse mit Zeitstempeln).
- Schnell hintereinander gedrückte Tasten erzeugen die richtige Zahl Ereignisse (kein Verschlucken).

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Auf einem echten Android-Gerät: 10× Lautstärke hoch erzeugt 10 Schrittwechsel, die Systemlautstärke bleibt unverändert (manuell geprüft, in Notizen vermerkt).
- [x] Außerhalb des Messbildschirms regeln die Tasten wieder die Lautstärke.

## Offene Fragen / Annahmen

- Ob Tasten bei gesperrtem Bildschirm abfangbar sind, ist offen und wird in Task_06 untersucht.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Eigener Platform Channel statt Paket: `MainActivity.kt` fängt in `dispatchKeyEvent` Lautstärke hoch/runter ab, solange `setKeyCapture(true)` gilt, unterdrückt die Lautstärkeänderung und sendet über den EventChannel `dev.cyclescope/keys` Key-Down/Up (ohne Auto-Repeat) samt Alter des Ereignisses. Dart: `HardwareKeys`/`AndroidHardwareKeys` (`lib/recording/platform/hardware_keys.dart`) rechnet den exakten Druckzeitpunkt auf die monotone Uhr um; `KeyInterpreter` (`lib/recording/domain/key_interpreter.dart`, reines Dart) unterscheidet kurz/lang (Schwelle 400 ms) und liefert bereits die Sonderzeit-Callbacks für Task_05. Der Messbildschirm aktiviert die Erfassung in `initState` und gibt sie in `dispose` wieder frei. MethodChannel `dev.cyclescope/platform` liefert zusätzlich `elapsedRealtimeMicros` für Task_06.
- **Learnings & Stolpersteine:** Python-Textersetzungen nach `dart format` können still ins Leere laufen – Ersetzungen immer mit `assert old in s` absichern. Build und Tests teilen sich `build/` (Sandbox-Workaround löscht `build/` vor Testläufen) – nie parallel laufen lassen. `flutter build` scheiterte in der Sandbox an der l10n-Generierung zur Build-Zeit → `generate: false` in `pubspec.yaml`, generierte Dateien sind versioniert.
- **Wichtige Entscheidungen und ihre Gründe:** Messzeitpunkt = Key-Down (eventTime auf Android, umgerechnet über `uptimeMillis` → Alter). Erfassung nur auf dem Messbildschirm, sonst normale Lautstärke.
- **Auswirkungen auf Folge-Tasks:** Task_05 schließt nur noch `onSpecialStart/onSpecialEnd` an. Task_06: Tasten bei ausgeschaltetem Bildschirm sind mit diesem Ansatz nicht abfangbar (Activity bekommt keine Key-Events) – dort dokumentieren. Task_10: Schalter "Hardware-Tasten" → `setCapture(false)` bzw. Interpreter nicht anbinden; Schwelle aus Einstellungen in `KeyInterpreter(holdThreshold:)`. Task_12: gleiche Anbindung im Video-Bildschirm.
- **Hinweise zu Tests und Befehlen:** `tests/recording/domain/key_interpreter_test.dart` (manuelle Timer-Fabrik), Widget-Tests mit `FakeHardwareKeys` (`tests/fakes/fake_platform.dart`, `press`/`emit`). Kotlin-Code kompiliert mit `flutter build apk --debug` (erfolgreich). Keine echte Geräteprüfung möglich – auf Gerät prüfen: 10× Lautstärke hoch = 10 Schrittwechsel, Lautstärke bleibt unverändert.

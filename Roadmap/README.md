# Serienmessung (Zeitstudien-App) – Roadmap

Projektübergreifendes Gedächtnis. Agenten lesen diese Datei vor jedem Task und aktualisieren sie, wenn sich etwas ergibt, das über einen einzelnen Task hinausgeht. Regeln für die Arbeit: [AGENTS.md](AGENTS.md).

## Projektziel

Neuentwicklung einer bestehenden Android-App "Zeitstudie Stoppuhr" als bessere Flutter-App für Zeitaufnahmen nach REFA/MTM. Schwerpunkt ist eine einfache, fehlerarme Zeiterfassung im Feld (Bedienung blind über die Lautstärketasten) und eine saubere Auswertung, aus der die reale Taktzeit hervorgeht.

**Was die Software tut:** Man legt eine Studie an und gibt die Arbeitsschritte in eine Textarea ein (eine Zeile = ein Schritt, auch per Spracheingabe mit Push-to-talk). Beim Start ist Schritt 1 sofort aktiv; jeder Druck auf "Weiter" (oder Lautstärke hoch) schließt den aktuellen Schritt ab und startet den nächsten, nach dem letzten Schritt beginnt der nächste Zyklus. Der aktuelle Schritt ist während der Messung immer groß eingeblendet. Lautstärke hoch gedrückt halten erfasst eine Sonderzeit (unvorhergesehene Störung), die nicht in die Taktzeit zählt. Lautstärke runter = Start/Stopp. Alternativ wird ein Video importiert und die Schritte werden bei der Wiedergabe markiert (flüssige Zeitleiste, Tempo, Einzelbild). Nach der Aufnahme lassen sich Zyklen und einzelne Schritt-Messungen löschen und die Schrittdefinition umbenennen/umsortieren. Die Auswertung zeigt pro Schritt und Zyklus Summe, Mittelwert, Median, Min/Max/Streuung sowie die reale Taktzeit nach wählbarer Methode (Mittelwert / Median / IQR-bereinigt). Export als CSV, Excel und PDF; lokale Datenhaltung mit Backup-Datei. Modi: Zeitstudie (feste Abfolge), Video-Studie, Einfach (Stoppuhr + Runden), Schritt-Timer (freie Reihenfolge).

**Zielgruppe:** Arbeitsvorbereiter, Industrial Engineers, REFA-/MTM-Anwender, die in der Produktion Zeitaufnahmen machen, meist mit einem Android-Smartphone in der Hand.

**Nicht-Ziele:** Vorgabezeit/Sollzeit (Leistungsgrad, Zuschläge) – kommt frühestens später. Cloud-Sync und Benutzerkonten. iOS-Build (Code bleibt iOS-fähig, iOS-Spezialfälle wie Hardware-Tasten werden nicht umgesetzt). "Feedback senden" / "App bewerten" der alten App.

## Aktueller Status

Stand: 2026-11-11 – Roadmap angelegt, Projekt-Setup erledigt, noch kein Task begonnen.

| Task | Titel | Status |
|---|---|---|
| 01 | Durchstich: Studie anlegen & Liste | offen |
| 02 | Mess-Engine Zeitstudie | offen |
| 03 | Live-Messbildschirm mit Schritt-Overlay | offen |
| 04 | Hardware-Tasten (Android) | offen |
| 05 | Sonderzeit | offen |
| 06 | Hintergrundbetrieb & Wiederherstellung | offen |
| 07 | Zyklen ansehen & löschen | offen |
| 08 | Schrittdefinition nachträglich bearbeiten | offen |
| 09 | Auswertung & reale Taktzeit | offen |
| 10 | Einstellungen | offen |
| 11 | Spracheingabe Push-to-talk | offen |
| 12 | Video-Studie: Import & Markieren | offen |
| 13 | Video-Zeitleiste flüssig & Marker ziehen | offen |
| 14 | Modus "Einfach" | offen |
| 15 | Modus "Schritt-Timer" | offen |
| 16 | Export CSV + Excel | offen |
| 17 | Export PDF-Bericht | offen |
| 18 | Backup & Wiederherstellen | offen |

Status ist `offen`, `läuft` (Datei trägt das Präfix `RUN_`) oder `erledigt` (Datei liegt in `Archiv/`). Die Tabelle wird beim Archivieren eines Tasks aktualisiert.

## Taskübergreifende Entwicklungsinfos

Globale Informationen, Architekturentscheidungen und Wissen, das für das gesamte Projekt gilt. Wird laufend ergänzt; jeden Eintrag mit dem Task kennzeichnen, aus dem er stammt.

Im Interview festgelegt (vor Task_01):

- **Stack:** Flutter (Dart), Zielplattform zuerst Android; Code soll iOS-fähig bleiben (plattformspezifisches hinter Interfaces kapseln).
- **Sprachen:** Englisch-first: Englisch ist ARB-Template und Fallback, Deutsch die Übersetzung (Flutter `gen-l10n`). Keine hartkodierten UI-Texte. Code, Bezeichner, Dateinamen, Commits auf Englisch.
- **Projekt-Setup (vor Task_01, via project-init):** App-Arbeitstitel "CycleScope", Dart-Paket `cyclescope`, Android-ID `dev.cyclescope.cyclescope`. Git-Repo (`main`), `flutter create` (nur Android) ist erledigt, Beispieltest entfernt; `lib/main.dart` ist noch die Flutter-Demo und wird in Task_01 ersetzt. State-Management: Riverpod. Linter: `flutter_lints`. Details in Root-`AGENTS.md` und `docs/`.
- **Datenhaltung:** nur lokal auf dem Gerät (SQLite), kein Cloud-Sync. Backup über Export/Import einer Datei (Task_18).
- **Tests:** liegen verbindlich in `tests/` (nicht im Flutter-Standardordner `test/`), Ausführung mit `flutter test tests/`.
- **Zeitmessung:** Grundlage ist eine monotone Uhr (z. B. `Stopwatch` / `SystemClock.elapsedRealtime`), nicht die Wanduhr, damit Zeitumstellungen und Uhr-Korrekturen die Messung nicht verfälschen. Die Uhr wird für Tests injizierbar gekapselt.
- **Fachlogik getrennt von UI:** Mess-Engine, Statistik und Export-Aufbereitung sind reine Dart-Logik und vollständig unit-testbar; Hardware (Tasten, Mikrofon, Video, Hintergrunddienst) liegt hinter Interfaces mit Fakes für Tests.
- **Zeiteinheiten:** HM (1/100 min, Standard), Sekunden, mm:ss.SSS, TMU (1 TMU = 0,036 s). Intern werden Zeiten in einer Einheit (z. B. Mikro- oder Millisekunden) gespeichert, Umrechnung nur bei der Anzeige.
- **Tastenbelegung (Messung):** Lautstärke hoch kurz = nächster Schritt; Lautstärke hoch gehalten = Sonderzeit läuft, solange gehalten; Lautstärke runter = Start/Stopp.
- **Reale Taktzeit:** Methode einstellbar: Mittelwert, Median, IQR-bereinigt (Ausreißer über Q3 + 1,5 × IQR verworfen). Sonderzeiten sind immer herausgerechnet.

## Auffälligkeiten & Details

Dinge, die global noch zu beachten sind: Besonderheiten, bekannte Einschränkungen, kleinere Details. Wird laufend ergänzt.

- Fachbegriffe im Code (siehe `docs/conventions.md`): Studie = `Study`, Schritt = `StepDefinition`, Zyklus = `Cycle`, Messung = `Measurement`, Sonderzeit = `SpecialTime`, Taktzeit = `CycleTime`.
- Mindest-Android-Version ist noch nicht festgelegt (Annahme: API 26 / Android 8), siehe Task_01.
- Hardware-nahe Funktionen (Lautstärketasten, Mikrofon, Video, Hintergrunddienst) lassen sich nur teilweise automatisiert testen. Logik mit Fakes testen, zusätzlich eine kurze manuelle Geräteprüfung in den Task-Notizen protokollieren.

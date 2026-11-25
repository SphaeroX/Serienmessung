# Task_46: Demo-Daten, Screenshots, Doku und Version 1.9.0

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_46.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Die Erweiterung „Bereiche“ ist rund: Die Demo-Daten zeigen eine Anlage aus Bereichen, die Screenshots und die Dokumentation sind aktuell, und die Version 1.9.0 ist zum Mergen bereit.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_38 bis Task_45 archiviert. Deren "Erkenntnisse für Folge-Agenten" lesen.
- **Relevantes Vorwissen:** Task_35 (`DemoDataService`, nur über die normalen Repositories), README "[Demo-Daten 2026-11-14]" (1000 Teile in 24 h hängen an der Simulation), "[Nach Task_37, 2026-11-19] Demo-Daten in einer Linie" und die Erkenntnis aus Task_37: Jede neue Demo-Studie oder -Gruppe ändert die Zähler in `tests/demo/`, und das braucht die Freigabe des Nutzers.
- **Betroffener Code:** `lib/demo/`, `tests/demo/`, `tests/screenshots/`, `docs/`, Root-`README.md`, `site/index.html`, `pubspec.yaml`, `lib/settings/presentation/settings_screen.dart` (`appVersion`).

## Umfang

**Gehört dazu:**

- **Demo-Daten** (erst nach Freigabe, siehe "Offene Fragen"): Vorschlag ist eine Obergruppe „Demo: Werk“ mit zwei Bereichen:
  - „Demo: Gehäuselinie“ unverändert als Bereich 1 (15 Mitglieder, 8 Stationen; allein weiter genau 1000 Teile in 24 h).
  - Ein kleiner zweiter Bereich „Demo: Versand“ mit zwei bis drei Maschinen mit fester Taktzeit, deutlich schneller als der Linientakt, mit einem Transportband als Verbindung vor dem Bereich.
  - Die Anlage zeigt damit: Bereich hinzufügen, Verbindung zwischen Bereichen, Bereichsübersicht mit Engpass im ersten Bereich.
  - Texte über l10n (`demoTextsOf`), keine eigene SQL, keine Migration.
- **Screenshots:** neue Szenen im Generator `tests/screenshots/app_screenshots_test.dart` (Anlage im Gruppen-Bildschirm mit Bereichskarten, Linienanalyse mit Bereichsübersicht); Szenenliste in `docs/testing.md` ergänzen. Lokal gerenderte Bilder nicht committen, die CI erzeugt sie.
- **Dokumentation:**
  - `docs/architecture.md`: Abschnitt zu verschachtelten Gruppen auf Vollständigkeit prüfen (Datenmodell, Stationsregel, Abflachen, Verbindung, Backup-Felder, Reports) und die Demo-Beschreibung anpassen.
  - `docs/project-brief.md`: Bereiche im Funktionsumfang.
  - Root-`README.md` und Landingpage `site/index.html` (EN im HTML, DE im Wörterbuch des Skripts): Funktionsbeschreibung um Bereiche ergänzen.
  - `Roadmap/README.md`: Status, Tabelle, taskübergreifende Erkenntnisse.
- **Version 1.9.0:** `pubspec.yaml`, `appVersion`, Root-`README.md`.
- **Abschlussprüfung der ganzen Erweiterung:** volle Suite, `flutter analyze`, `dart format`, `flutter build apk --debug`.
- **Manuelle Geräteprüfung** (protokollieren oder als offen vermerken): Anlage aus zwei Bereichen anlegen, Bereich öffnen und messen, Linienanalyse und Simulation der Anlage, Report teilen, Anlage teilen und auf einem zweiten Gerät importieren.

**Gehört nicht dazu:**

- Merge nach `main`, Tag, Play- und TestFlight-Lauf: macht der Nutzer.
- Store-Grafiken (`store/`, `tool/generate_store_assets.py`): nur auf ausdrücklichen Wunsch.

## Umsetzungsschritte

1. [x] Freigabe des Nutzers für die Demo-Erweiterung und die dafür nötigen Zähler-Änderungen in `tests/demo/` einholen. Ohne Freigabe diesen Punkt überspringen und in den Erkenntnissen vermerken.
2. [x] Demo-Daten (TDD; neue Tests für die Anlage, freigegebene Anpassung der Zähler).
3. [x] Screenshot-Szenen, lokal gerendert geprüft.
4. [x] Dokumentation, Landingpage, Root-README.
5. [x] Version 1.9.0.
6. [x] Volle Suite, `flutter analyze`, `dart format`, Debug-Build; manuelle Prüfung protokollieren.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Nach dem Laden der Demo gibt es die Obergruppe mit ihren Bereichen in der richtigen Reihenfolge; die Gehäuselinie allein ergibt in der 24-h-Simulation weiter genau 1000 Teile.
- Die Anlage hat eine Verbindung zwischen den Bereichen, und die Bereichsübersicht nennt die Gehäuselinie als Engpass-Bereich.
- Die Ausbringung der ganzen Anlage in 24 h ist festgelegt und per Test gesichert (der Wert ergibt sich beim Abstimmen; er darf wegen des leeren Starts knapp unter 1000 liegen).
- Zweimaliges Laden legt zwei unabhängige Anlagen an (wie heute: jedes Laden fügt eine Kopie hinzu).
- Die Screenshot-Szenen rendern ohne Überlauf-Fehler (`flutter test tests/screenshots --dart-define=SCREENSHOTS=true`).
- Die volle Suite läuft grün.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber, `flutter build apk --debug` erfolgreich.
- [x] Demo-Daten zeigen eine Anlage aus Bereichen (oder: Freigabe nicht erteilt, vermerkt).
- [x] Bestehende Tests nur dort geändert, wo der Nutzer es ausdrücklich freigegeben hat (Zähler in `tests/demo/`); die Änderungen sind in den Notizen aufgelistet.
- [x] `docs/`, Root-`README.md`, Landingpage und `Roadmap/README.md` aktuell; Version 1.9.0 an allen drei Stellen.
- [x] Manuelle Geräteprüfung protokolliert oder als offen vermerkt.

## Offene Fragen / Annahmen

- **Offen (Freigabe nötig):** Die Demo-Erweiterung ändert die Zähler in `tests/demo/demo_data_service_test.dart` und `tests/demo/demo_data_tile_test.dart` (Gruppen und Studien je Laden, Gruppennamen). Nach den Projektregeln dürfen bestehende Tests nur mit Begründung und Freigabe geändert werden. Vor Schritt 2 beim Nutzer nachfragen.
- Annahme: Die Gehäuselinie bleibt als Ganzes ein Bereich. Die Alternative, sie selbst in Bereiche (z. B. Zerspanung, Montage, Prüfung) aufzuteilen, würde zusätzlich die Mitglieds- und Stationsindizes der bestehenden Demo-Tests verschieben.
- Annahme: Version 1.9.0 (neue Funktion, keine Inkompatibilität).

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Unter Windows können `lib/l10n` und Ordner in `build/` schreibgeschützt sein (`attrib -r` hilft, siehe `Roadmap/README.md`).
- **Freigabe:** Der Nutzer hat am 2026-11-25 die Demo-Erweiterung samt Anpassung der Demo-Tests freigegeben. Geänderte bestehende Tests: `tests/demo/demo_data_service_test.dart` (Gruppenzahl 1 → 3 und die Gehäuselinie per Id statt `.single`; bei zweimal Laden Gruppen 2 → 6, Studien 1 + 2·16 → 1 + 2·18), `tests/demo/demo_data_tile_test.dart` (Snackbar nennt „Demo: plant“; Gehäuselinie per Name statt `.single`, 15 Studien unverändert; deutsche Namen als Menge mit Werk/Gehäuselinie/Versand). Zusätzlich musste `tests/screenshots/store_screenshots_test.dart` die fünf neuen `DemoTexts`-Felder durchreichen (reine Kompilierkorrektur, keine Prüfung geändert).
- **Abschlussprüfung (2026-11-25, Windows):** `flutter test tests/` 840 bestanden, 20 übersprungen (Screenshot-Generatoren), 2 fehlgeschlagen – die vorbestehenden Pfadtrenner-Fehler in `tests/video/` (siehe Task_38). `flutter analyze` ohne Befunde, `dart format` sauber, `flutter build apk --debug` erfolgreich (nach `attrib -R build\* /S /D` und Löschen von `build/unit_test_assets`).
- **Screenshots:** Szenen 14 (Anlage im Gruppen-Bildschirm) und 15 (Linienanalyse der Anlage mit Bereichskarte) lokal gerendert und gesichtet; dabei überlappte der Bereichsname im Diagramm den Wert des Engpassbalkens → `YamazumiPainter` reserviert bei Bereichen ein eigenes Band oben. Bilder nicht committet (CI erzeugt sie); Root-README und Landingpage verweisen deshalb noch nicht auf sie.
- **Manuelle Geräteprüfung: offen.** Anlage aus zwei Bereichen anlegen, Bereich öffnen und messen, Linienanalyse und Simulation, Report teilen, Anlage teilen und auf einem zweiten Gerät importieren – auf einem echten Gerät noch nicht geprüft.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst (letzter Task der Erweiterung: Status der Roadmap auf "abgeschlossen" setzen)
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- `DemoDataService.load` gibt weiter die Id der **Gehäuselinie** zurück (nicht der Anlage); die Obergruppe ist `getGroup(id).parentId`. So blieben die meisten Demo-Tests unverändert. Wer die Demo erweitert: Gehäuselinie allein = 1000 Teile, ganze Anlage = 998 Teile in 24 h; beide Werte hängen an der Simulation.
- Das Snackbar-Ziel nach dem Laden ist jetzt die Anlage („Demo: Werk“), weil sie oben in der Gruppenliste steht.
- Nach dem Merge: Release-Tag `v1.9.0`, Screenshots kommen per CI; danach Szenen 14/15 bei Bedarf in Root-README und `site/index.html` (Galerie) aufnehmen.

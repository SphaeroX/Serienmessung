# Task_01: Durchstich: Studie anlegen & Liste

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_01.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Man kann eine Studie (Name, optionale Beschreibung, Modus) mit Schritten aus einer Textarea anlegen. Sie wird lokal gespeichert und erscheint in der Studienliste. Damit sind Riverpod, Datenbank, Mehrsprachigkeit und Testing einmal Ende zu Ende verdrahtet.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Keine (erster Task). Projekt-Setup ist erledigt: Git-Repo, `flutter create` (Paket `cyclescope`, Android), Root-`AGENTS.md` und `docs/` existieren.
- **Relevantes Vorwissen:** `Roadmap/README.md` (Taskübergreifende Entwicklungsinfos: Stack, Sprachen, Datenhaltung, Tests). Vorbild ist die alte App: Startbildschirm "Zeitstudie Stoppuhr" mit Karten (Name, Modus-Badge, Erstellt/Aktiv, Anzahl Runden) und FAB "Zeitstudie erstellen"; Bildschirm "Neue Zeitstudie" mit Name (Vorschlag "Zeitstudie #NNNN", max. 100 Zeichen), Beschreibung (optional, max. 500 Zeichen) und Modusauswahl mit "So funktioniert es"-Infodialog.

## Umfang

**Gehört dazu:**

- Flutter-Demo in `lib/main.dart` durch die echte App-Struktur ersetzen (Feature-Ordner laut `docs/architecture.md`, `ProviderScope`).
- Abhängigkeiten ergänzen: `flutter_riverpod`, Datenbank (Vorschlag drift), `flutter_localizations`/`intl`.
- Mehrsprachigkeit über `gen-l10n` einrichten: Englisch als Template/Fallback, Deutsch als Übersetzung; Gerätesprache wird verwendet.
- Lokale SQLite-Datenbank mit Schema-Versionierung/Migrationen; Tabellen für Studie und Schrittdefinition (Messungen folgen in Task_02).
- Parser Textarea → Schrittliste: eine Zeile = ein Schritt, Leerzeilen und führende/folgende Leerzeichen ignorieren.
- Bildschirm "Neue Studie": Name, Beschreibung, Modusauswahl (alle vier Modi sichtbar, Infodialog je Modus), Textarea für Schritte (nur bei Modi mit Schritten: Zeitstudie, Schritt-Timer, Video), Live-Anzeige der erkannten Schrittanzahl.
- Studienliste als Startbildschirm mit Karten (Name, Modus, Erstellt, Anzahl Zyklen/Runden = 0) und leerem Zustand.
- Dunkles und helles Theme (Systemeinstellung folgen), Gestaltung angelehnt an die alte App.

**Gehört nicht dazu:**

- Zeitmessung jeglicher Art (Task_02/03).
- Spracheingabe in der Textarea (Task_11).
- Bearbeiten/Löschen von Studien über die Liste hinaus (Löschen einer Studie per Langdruck ist optional erlaubt).
- Einstellungsbildschirm (Task_10).

## Umsetzungsschritte

1. [x] Demo-Code entfernen, App-Gerüst mit `ProviderScope` und Feature-Ordnern anlegen; `flutter analyze` und `flutter test tests/` lauffähig halten.
2. [x] Datenbank-Bibliothek wählen (Vorschlag: drift) und Entscheidung in `Roadmap/README.md` festhalten.
3. [x] Datenmodell Studie (id, name, beschreibung, modus, erstelltAm, zuletztAktivAm) und Schrittdefinition (id, studieId, position, name) mit Repository-Schicht umsetzen.
4. [x] Textarea-Parser als reine Funktion umsetzen und testen.
5. [x] l10n einrichten, alle Texte dieses Tasks in EN (Template) und DE anlegen.
6. [x] Bildschirm "Neue Studie" inkl. Validierung (Name Pflicht, Modi mit Schritten brauchen mindestens 1 Schritt).
7. [x] Studienliste mit Karten und Navigation zu "Neue Studie" umsetzen.
8. [x] Projektstruktur (Ordneraufteilung) und Befehle in `Roadmap/README.md` dokumentieren.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Parser: normale Eingabe, Leerzeilen, Leerzeichen, Windows-Zeilenumbrüche, leere Eingabe → leere Liste.
- Repository (mit In-Memory-DB): Studie mit Schritten speichern und in richtiger Reihenfolge wieder laden.
- Widget-Test: Formular verhindert Speichern ohne Name bzw. ohne Schritte im Modus Zeitstudie.
- Widget-Test: nach dem Anlegen erscheint die Studie in der Liste mit korrektem Modus-Badge.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] `flutter test tests/` läuft grün, `flutter analyze` meldet keine Fehler.
- [x] Eine Studie mit 3 Zeilen in der Textarea wird mit genau 3 Schritten in richtiger Reihenfolge gespeichert (Test belegt das).
- [x] Die App startet auf einem Android-Gerät/Emulator, zeigt die Liste und übersteht einen Neustart ohne Datenverlust (manuell geprüft, in den Notizen vermerkt).
- [x] Alle sichtbaren Texte existieren in DE und EN.

## Offene Fragen / Annahmen

- Mindest-Android-Version: Annahme API 26 (Android 8), in `android/app/build.gradle.kts` setzen. Vom Nutzer noch nicht bestätigt – im Zweifel nachfragen.
- Endgültiger App-Anzeigename noch offen (Arbeitstitel "CycleScope").

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Studienliste (Karten mit Modus-Badge, Erstellt/Aktiv, Zähler), Bildschirm "Neue Studie" (Name mit Vorschlag, Beschreibung, 4 Modi mit Info-Dialog, Textarea mit Live-Schrittzähler, Validierung), Repository + DB-Schema v1, Textarea-Parser, l10n EN/DE, Light/Dark-Theme. Löschen einer Studie per Langdruck mit Rückfrage. Abweichung: sqflite statt drift (keine Codegenerierung nötig). minSdk 26 gesetzt.
- **Learnings & Stolpersteine:** Formulare nicht in `ListView` bauen – Felder außerhalb des Sichtbereichs werden nicht gebaut und damit nicht validiert (jetzt `SingleChildScrollView`). In Widget-Tests scrollt ein fokussiertes Textfeld sich selbst wieder in den Sichtbereich; `tapVisible` hebt deshalb zuerst den Fokus auf. sqflite-ffi braucht in Widget-Tests echte Asynchronität (`settle()` mit `runAsync`).
- **Wichtige Entscheidungen und ihre Gründe:** Listen als `FutureProvider` + `ref.invalidate` nach Schreibzugriffen (sqflite hat keine Streams). `StudyRepository.countCycles` liefert vorerst 0 und wird mit den Messungen (Task_02/07) echt.
- **Auswirkungen auf Folge-Tasks:** `StudyListScreen.onOpenStudy` ist noch nicht verdrahtet (in `app.dart` null) – Task_03 bindet den Studien-/Messbildschirm an. Nach dem Anlegen wird die Studie automatisch geöffnet, sobald `onOpenStudy` gesetzt ist. `Study` hat schon optionale Felder `cycleTimeMethod` und `videoPath` (Spalten kommen per Migration in Task_09/12).
- **Hinweise zu Tests und Befehlen:** `flutter test tests/`. Helfer in `tests/helpers.dart`: `openTestDatabase()`, `localizedApp()`, `settle()`, `tapVisible()`. Keine manuelle Geräteprüfung möglich (kein Gerät in dieser Umgebung) – beim ersten Gerätetest nachholen.

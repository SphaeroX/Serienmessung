# Task_35: Demo-Daten über die Einstellungen laden

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_35.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

In den Einstellungen lassen sich mit einem Tipp Demo-Daten laden: eine kleine, vollständige Produktionslinie als Gruppe, die alle Möglichkeiten der App zeigt, damit man Linienbetrachtung, Simulation, Reports, Revisionen usw. sofort ausprobieren kann. Eigene Daten bleiben unberührt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_34 archiviert (Nutzerwunsch nach Abschluss der Roadmap).
- **Relevantes Vorwissen:** Task_19 (Gruppen), Task_20 (Revisionen), Task_26 (Maschinen mit fester Taktzeit, parallel), Task_29 (Puffer), Task_33 (Transportbänder), Task_34 (Sonderzyklen).

## Umfang

**Gehört dazu:**

- Feature-Ordner `lib/demo/`: `DemoTexts` (alle Namen der Demo-Daten, aus l10n), `DemoDataService.load()` legt über die bestehenden Repositories an:
  - Gruppe „Demo: Gehäuselinie“ mit 6 Stationen / 9 Gruppenmitgliedern: Säge (feste Taktzeit, Stillstand Sägeblattwechsel), 2 Bearbeitungszentren parallel (Zeitstudie mit Schritten, Sonderzeit, Revision, Sonderzyklen Messteil + Werkzeugwechsel; Puffer davor), Waschanlage (Transportband davor), Montage (Zeitstudie mit Ausreißer, Sonderzeit, Revision), 3 Prüfstände parallel (Puffer davor, Kalibrierung alle N Teile), Verpacken (Einfach-Modus mit Runden, Transportband davor).
  - Eine Schritt-Timer-Studie „Rüsten“ außerhalb der Gruppe.
  - Deterministische Zeiten (kein Zufall), Zeitstempel relativ zur Wanduhr; aktuelle Messungen jünger als 10 Tage (keine Nachfrage „veraltete Messung“).
- Einstellungen, Abschnitt „Daten“: Eintrag „Demo-Daten laden“ mit Bestätigungsdialog und Snackbar; Listen werden aktualisiert.
- Texte DE/EN, Doku, README.

**Gehört nicht dazu:**

- Video-Studie (bräuchte eine Videodatei).
- Demo-Daten wieder entfernen (normales Löschen der Gruppe/Studien reicht).

## Umsetzungsschritte

1. [x] Daten-Service (TDD).
2. [x] Einstellungs-Eintrag (Widget-Test).
3. [x] Doku, README.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Gruppe mit Mitgliedern in der richtigen Reihenfolge, Parallelmaschinen, Puffer, Transportbänder, Sonderzyklen, Revisionen, Sonderzeiten, Studie außerhalb der Gruppe.
- Linienanalyse und Simulation der Demo-Linie laufen (Engpass = Bearbeitungszentren).
- Bestehende Daten bleiben erhalten; zweimal laden legt eine zweite Gruppe an.
- Einstellungs-Eintrag lädt nach Bestätigung, Abbrechen lädt nichts.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Version wird auf 1.3.0 angehoben (neue Funktion).
- Die Namen der Demo-Daten folgen der App-Sprache zum Zeitpunkt des Ladens.

## Notizen zu diesem Task

- Kein eigener Task-Plan des Nutzers: Wunsch kam nach Abschluss der Roadmap ("Demo-Daten über die Einstellungen laden, ruhig etwas komplexer"). Der Play-Upload von 1.2.0 (Version Code 4, internal) lief parallel und enthält die Demo-Daten noch nicht.
- Windows: `build/unit_test_assets` und `lib/l10n` trugen das Attribut "Schreibgeschützt"; `flutter test` bzw. `flutter gen-l10n` brachen ab. Mit `attrib -R` behoben (siehe README-Auffälligkeiten).

## Abschluss-Checkliste

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** `lib/demo/` mit `DemoTexts` (domain), `DemoDataService` (data) und `DemoDataTile` + `demoTextsOf` (presentation); Eintrag in den Einstellungen unter „Daten“. Linie mit 6 Stationen / 9 Mitgliedern statt der zuerst notierten 7/10. Version 1.3.0.
- **Learnings & Stolpersteine:** `GroupRepository.moveToGroup` setzt Puffer und Band zurück – Puffer/Band erst *nach* dem Einsortieren setzen. Die Stationszahl ist nicht die Mitgliederzahl (Parallelmaschinen).
- **Wichtige Entscheidungen und ihre Gründe:** Nur über die bestehenden Repositories (`MachineService`, `GroupRepository`, `SpecialCycleRepository`, `RevisionRepository`) – neue Tabellen/Spalten erscheinen so nicht automatisch in den Demo-Daten, sondern müssen dort bewusst ergänzt werden. Deterministische Zeiten statt Zufall (gleiche Daten bei jedem Laden, testbar). Keine Video-Studie (bräuchte eine Videodatei). Jedes Laden legt eine weitere Kopie an, nichts wird ersetzt.
- **Auswirkungen auf Folge-Tasks:** Neue Funktionen (z. B. neue Gruppen-Eigenschaften) sollten in `DemoDataService` mit aufgenommen werden, damit die Demo „alle Möglichkeiten“ zeigt.
- **Hinweise zu Tests und Befehlen:** `tests/demo/demo_data_service_test.dart` (Daten, Linienanalyse, Simulation), `tests/demo/demo_data_tile_test.dart` (Einstellungen, Sprache).

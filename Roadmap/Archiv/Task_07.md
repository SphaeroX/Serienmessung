# Task_07: Zyklen ansehen & löschen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_07.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Nach (oder zwischen) Aufnahmen sieht man die Messungen nach Zyklen gruppiert und kann fehlerhafte Zyklen komplett oder einzelne Schritt-Messungen bzw. Sonderzeiten innerhalb eines Zyklus löschen.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_05 und Task_06 archiviert.
- **Relevantes Vorwissen:** Nutzerwunsch: "die einzelnen Zyklen sehen und auch einzelne Zyklen herauslöschen können oder einzelne Schritte in den Zyklen". Man kann kontinuierlich aufnehmen oder stoppen und später weitermachen – die Ansicht muss mehrere Aufnahme-Sitzungen in einer Studie abbilden.

## Umfang

**Gehört dazu:**

- Ansicht "Zyklen" in der Studie: aufklappbare Zyklen (Nr., Gesamtdauer ohne Sonderzeit, Anzahl Schritte, Kennzeichnung unvollständig), darin die Schritt-Messungen und Sonderzeiten.
- Zyklus löschen (mit Bestätigung oder Rückgängig-Snackbar).
- Einzelne Schritt-Messung oder Sonderzeit löschen (mit Rückgängig).
- Sonderzeit-Notiz bearbeiten.
- Nach dem Löschen bleiben Zyklus-Nummern stabil oder werden neu durchnummeriert – Entscheidung treffen und dokumentieren.
- Weitermessen an einer bestehenden Studie aus dieser Ansicht.

**Gehört nicht dazu:**

- Zeiten von Hand ändern, Schrittgrenzen verschieben, Zyklen teilen/zusammenführen (vom Nutzer nicht gewählt).
- Schrittdefinition bearbeiten (Task_08).
- Statistik (Task_09).

## Umsetzungsschritte

1. [x] Abfragen für gruppierte Darstellung im Repository ergänzen.
2. [x] Zyklen-Ansicht umsetzen (Tab oder eigener Bildschirm in der Studie).
3. [x] Löschen mit Rückgängig (Soft-Delete oder Zwischenspeicher) umsetzen.
4. [x] Notiz bearbeiten.
5. [x] Gelöschte Messungen in Zählern der Studienliste berücksichtigen.
6. [x] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Gruppierung: Messungen aus zwei Aufnahme-Sitzungen erscheinen in fortlaufenden Zyklen.
- Zyklus löschen entfernt alle zugehörigen Messungen und Sonderzeiten, andere Zyklen bleiben unverändert.
- Einzelne Messung löschen; Rückgängig stellt sie wieder her.
- Unvollständiger Zyklus wird als solcher gekennzeichnet.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün.
- [x] Nach dem Löschen eines Zyklus stimmen die Zyklenzahl auf der Studienkarte und in der Ansicht überein (Test).

## Offene Fragen / Annahmen

- Nutzer hat nicht entschieden, ob einzelne Zeiten manuell korrigierbar sein sollen. Annahme: nein, nur löschen. Bei Bedarf als neuer Task ergänzen.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Tabs "Live" und "Zyklen" (im Einfach-Modus "Runden") im Messbildschirm. `CyclesView` zeigt aufklappbare Zyklen (neueste oben) mit Zykluszeit ohne Sonderzeit, Sonderzeit-Summe und Kennzeichnung "unvollständig"; darin Schrittzeiten und Sonderzeiten (Notiz per Tipp bearbeitbar). Löschen eines ganzen Zyklus oder einer einzelnen Zeit mit "Rückgängig"-Snackbar. Domänenfunktion `groupCycles` (`lib/recording/domain/cycles.dart`) mit `normalTotal`, `specialTotal`, `isComplete`. Weitermessen geht direkt über den Start-Button im selben Bildschirm.
- **Learnings & Stolpersteine:** Der Phone-Größen-Test deckte einen echten Layout-Fehler auf: Button-Beschriftungen brachen auf schmalen Geräten um und überliefen – jetzt `FittedBox`. In Widget-Tests mit Dauer-Ticker brauchen Tab-Wechsel, Snackbars und ExpansionTiles echte Frame-Zeit: `pumpFrames()`; Bildschirmgröße mit `usePhoneSize()` realistisch setzen.
- **Wichtige Entscheidungen und ihre Gründe:** Hartes Löschen + Rückgängig durch Wiedereinfügen mit Original-IDs (kein Soft-Delete, keine Migration nötig). Zyklusnummern bleiben nach dem Löschen stabil (keine Neunummerierung), damit Notizen/Video-Bezüge stimmen. Ein Zyklus ist vollständig, wenn jeder aktuell definierte Schritt eine normale Zeit hat; unvollständige Zyklen zählen nicht zur Zyklus-Statistik (Task_09).
- **Auswirkungen auf Folge-Tasks:** Task_08: nach Schrittänderungen `RecordingController.load()` neu ausführen (Sequenz + Vollständigkeit hängen an den aktuellen Schritt-IDs). Task_09: `groupCycles(...).where((g) => g.isComplete)` für die Zyklus-Statistik verwenden; dritter Tab "Auswertung" an `DefaultTabController(length: 2)` anhängen.
- **Hinweise zu Tests und Befehlen:** `tests/recording/domain/cycles_test.dart`, `tests/recording/presentation/cycles_view_test.dart`. Neue Helfer in `tests/helpers.dart`: `usePhoneSize`, `pumpFrames`.

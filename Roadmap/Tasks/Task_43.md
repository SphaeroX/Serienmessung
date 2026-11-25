# Task_43: Simulation und Ausfallrisiko der Gesamtanlage

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_43.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Die Simulation und das Ausfallrisiko sind auch für eine große Anlage aus vielen Bereichen lesbar und schnell genug: Stationen und Maschinen sind nach Bereichen gegliedert, je Bereich gibt es eine Zusammenfassung, und die Rechenzeit einer Anlage mit vielen Stationen ist gemessen und friert die Oberfläche nicht ein.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_38 bis Task_42 archiviert. Deren "Erkenntnisse für Folge-Agenten" lesen.
- **Relevantes Vorwissen:** Task_30/31 (`LineSimulation`, Simulationsbildschirm), Task_27 (`FailureRisk`), README "[Nach Task_35] Mehrere Störungen in der Simulation", "[Review Simulation 2026-11-14]" (Invarianten, Zufallslinien) und "[Demo-Daten 2026-11-14]" (die Demo-Linie hängt an den Simulationsregeln).
- **Wichtig:** Die Simulations-Engine und ihre Regeln werden in diesem Task **nicht** geändert. Nach Task_40 und Task_42 läuft sie bereits über die abgeflachte Linie. Hier geht es um Darstellung, Zusammenfassung je Bereich und Laufzeit.

## Umfang

**Gehört dazu:**

- **Zusammenfassung je Bereich (reines Dart):** aus `SimResult` und den Bereichen der Linie je Bereich Auslastung (Arbeitszeit aller Maschinen des Bereichs im Verhältnis zur verfügbaren Zeit), blockierte Zeit, Stillstandszeit und der Füllstand der Puffer im Bereich. Daran erkennt man, welcher Bereich wartet und welcher staut.
- **Simulationsbildschirm:**
  - Karte „Bereiche“ mit einer Zeile je Bereich (Auslastung, blockiert, Stillstand).
  - Stationsliste mit Zwischenüberschriften je Bereich und durchlaufenden Stationsnummern (wie in der Linienanalyse).
  - Die Maschinenauswahl der Störungszeilen nennt den Bereich („Montage · Prüfstand 2“), damit gleichnamige Maschinen in verschiedenen Bereichen unterscheidbar sind.
  - Puffer und Bänder zwischen Bereichen sind als solche beschriftet („vor Bereich Montage“).
  - Ohne Bereiche sieht der Bildschirm aus wie heute.
- **Ausfallrisiko im Linienbildschirm:** jede Zeile nennt den Bereich der Maschine.
- **Laufzeit:**
  - Eine künstliche Anlage mit 60 Stationen und etwa 100 Maschinen, mit Puffern, Bändern, Parallelstationen und einer wartenden Station, über 24 h simulieren und die Zeit messen. Ebenso `failureScenarios` (jede Maschine, mit und ohne Puffer), das der Report aufruft.
  - Ergebnis in den Notizen festhalten. Dauert ein Lauf im Simulationsbildschirm oder im Report auf einem Mittelklasse-Gerät erkennbar lang (Richtwert über 1 s), wird er aus dem UI-Thread herausgenommen (`compute`/Isolate) und ein Fortschrittsanzeiger gezeigt. Dafür ist keine neue Abhängigkeit nötig.
  - Ein Schutztest mit großzügiger Grenze sichert ab, dass die Laufzeit nicht unbemerkt um Größenordnungen wächst.
- Texte EN/DE, `docs/architecture.md`, `Roadmap/README.md`.

**Gehört nicht dazu:**

- Änderungen an den Regeln der Engine (Pufferregel, Bänder, Verbund wartender Stationen).
- Ausfall eines ganzen Bereichs als eigenes Szenario und zufällige Störungen.
- Reports (Task_44).

## Umsetzungsschritte

1. [ ] Zusammenfassung je Bereich als reine Funktion (TDD).
2. [ ] Simulationsbildschirm: Bereichskarte, Zwischenüberschriften, Maschinenauswahl, Beschriftung der Verbindungen (Widget-Tests).
3. [ ] Ausfallrisiko mit Bereichsangabe.
4. [ ] Laufzeit messen, bei Bedarf auslagern, Schutztest.
5. [ ] Texte, Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/group/domain/area_simulation_test.dart`, `tests/group/domain/large_plant_simulation_test.dart`, `tests/group/presentation/simulation_areas_screen_test.dart`.

Zu belegende Verhaltensweisen:

- Die Zeiten je Bereich sind die Summen seiner Stationen; Arbeit, Blockade und Stillstand eines Bereichs überschreiten zusammen nie die verfügbare Zeit seiner Maschinen.
- Liegt der Engpass im hinteren Bereich, zeigt der vordere Bereich Blockadezeit; liegt er im vorderen, zeigt der hintere geringe Auslastung.
- Eine Störung in einem Bereich erscheint als Stillstand nur in diesem Bereich.
- Die Ausbringung einer Anlage aus Bereichen ist gleich der Ausbringung derselben Studien in einer flachen Gruppe (Engine unverändert).
- Große Anlage: Die Simulation endet, das Ergebnis erfüllt die bekannten Invarianten (nie mehr als der Engpass hergibt, mit Puffer nie nennenswert weniger als ohne), und die Laufzeit bleibt unter der Schutzgrenze.
- Simulationsbildschirm: Bereichskarte und Zwischenüberschriften bei einer Obergruppe, keine bei einer Gruppe ohne Bereiche; die Maschinenauswahl unterscheidet gleichnamige Maschinen verschiedener Bereiche.
- Die Demo-Linie ergibt weiter genau 1000 Teile in 24 h (`tests/demo/demo_data_service_test.dart` läuft unverändert).
- Alle bestehenden Simulations-Tests laufen unverändert.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.
- [ ] Gemessene Laufzeiten (Simulation 24 h, alle Ausfallszenarien) stehen in den Notizen.
- [ ] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [ ] `docs/architecture.md` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- Annahme: 60 Stationen / 100 Maschinen ist eine realistische Obergrenze für „sehr große Anlagen“. Nennt der Nutzer eine andere Größe, den Schutztest anpassen.
- Annahme: Die Ausbringung je Bereich wird nicht getrennt ausgewiesen, weil in einer Linie in Reihe jeder Bereich dieselbe Stückzahl liefert; aussagekräftig sind Auslastung, Blockade und Stillstand.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Laufzeit-Tests mit echter Uhr schwanken auf CI-Rechnern. Die Schutzgrenze deshalb großzügig wählen (Faktor 10 über dem lokal gemessenen Wert) und die genauen Messwerte hier notieren statt im Test.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

(Beim Abschluss ausfüllen.)

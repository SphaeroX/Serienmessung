# Task_42: Puffer und Transportbänder zwischen Bereichen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_42.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Zwischen zwei Bereichen einer Anlage kann ein Puffer und ein Transportband stehen, genau wie heute zwischen zwei Stationen. Die Verbindung gehört zur Zusammenstellung der Anlage, nicht zum Bereich: Ein Bereich bleibt für sich allein unverändert auswertbar.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_38 bis Task_41 archiviert. Deren "Erkenntnisse für Folge-Agenten" lesen.
- **Relevantes Vorwissen:** Task_29 (Puffer liegt am ersten Mitglied der Station *dahinter*), Task_33 (Bänder), README "[Review Simulation 2026-11-14]" (Pufferregel, Band und Puffer an derselben Stelle).
- **Warum ein eigener Task:** In einem Bereich allein steht vor der ersten Station nichts (`bufferBefore`/`conveyorBefore` sind bei Station 0 immer leer, das Menü bietet beides beim ersten Mitglied nicht an). In der Gesamtlinie ist die erste Station eines Bereichs aber eine Station mitten in der Linie.

## Entwurf

- Die Verbindung wird **am Bereich** gespeichert, als „was steht in der Obergruppe vor diesem Bereich“.
- **Migration v18** (anhängen): `study_group.buffer_capacity`, `buffer_store_us`, `buffer_retrieve_us`, `conveyor_capacity`, `conveyor_transport_us`, alle `INTEGER NOT NULL DEFAULT 0` (0 = keine).
- Beim Abflachen (Task_40) bekommt die erste wirksame Studie des Bereichs diese Werte. Eigene Puffer- und Bandwerte dieser Studie werden dabei überschrieben (im Bereich allein hätten sie ohnehin keine Wirkung).
- Verschachtelung: Beginnt ein Bereich mit einem Unterbereich und haben beide eine Verbindung, gewinnt die äußerste Ebene, die eine gesetzt hat.
- Steht der Bereich als erstes Mitglied der obersten Linie, wirkt die Verbindung nicht (vor der ersten Station steht nichts). Sie bleibt gespeichert und wirkt wieder, sobald etwas davor steht.
- Verlässt der Bereich seine Obergruppe (herauslösen, in andere Gruppe verschieben, Obergruppe wird gelöscht), wird die Verbindung zurückgesetzt. Umsortieren innerhalb der Obergruppe behält sie.
- Puffer und Band vor einer **Studie** direkt hinter einem Bereich funktionieren schon über die bestehenden Felder der Studie.

## Umfang

**Gehört dazu:**

- Migration v18, `StudyGroup` mit den Verbindungsfeldern.
- `GroupRepository`: Puffer und Band vor einem Bereich setzen und entfernen; Zurücksetzen beim Verlassen der Obergruppe.
- Abflachen wendet die Verbindung an (Regeln oben).
- Gruppen-Bildschirm: Menüpunkte „Puffer davor einfügen“ und „Transportband davor einfügen“ an der Bereichskarte (nicht beim ersten Mitglied), Puffer- und Bandkarte über der Bereichskarte wie bei Stationen, Antippen bearbeitet oder entfernt. Die bestehenden Dialoge `showBufferDialog` und `showConveyorDialog` werden wiederverwendet.
- Linienanalyse, Simulation und Simulationsbildschirm zeigen und rechnen die Verbindung über `LineStation.bufferBefore`/`conveyorBefore` der ersten Station des Bereichs. Das ist per Test zu belegen, nicht anzunehmen.
- Backup und Teilen: optionale Felder `bufferCapacity`, `bufferStore`, `bufferRetrieve`, `conveyorCapacity`, `conveyorTransport` je Gruppe; nur übernommen, wenn die Gruppe beim Import in einer Obergruppe landet. Format-Version bleibt 2.
- Texte EN/DE, `docs/architecture.md`, `Roadmap/README.md`.

**Gehört nicht dazu:**

- Neue Simulationsregeln. Die Engine bleibt unverändert; sie sieht nur Stationen mit Puffer und Band.
- Reports (Task_44); die Verbindungstabelle der Reports sollte die neuen Verbindungen aber schon jetzt automatisch aufführen, weil sie stationsweise arbeitet. Das in Task_44 prüfen.

## Umsetzungsschritte

1. [ ] Abflachen mit Bereichsverbindung als reine Funktion (TDD, alle Regeln aus dem Entwurf).
2. [ ] Migration v18, Modell, Repository-Methoden, Zurücksetzen beim Verlassen.
3. [ ] Gruppen-Bildschirm: Menüpunkte und Karten (Widget-Tests).
4. [ ] Linienanalyse und Simulation mit Verbindung zwischen Bereichen belegen.
5. [ ] Backup-Felder, Rundreise.
6. [ ] Texte, Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/group/domain/area_link_test.dart`, `tests/group/data/area_link_data_test.dart`, `tests/group/presentation/area_link_screen_test.dart`, `tests/backup/area_link_backup_test.dart`.

Zu belegende Verhaltensweisen:

- Puffer vor Bereich B: In der Gesamtlinie hat die erste Station von B diesen Puffer; in der Linienanalyse von B allein hat sie keinen.
- Band vor einem Bereich: Die Durchlaufzeit der Anlage enthält die Transportzeit, die des Bereichs allein nicht.
- Äußere Verbindung gewinnt gegen die eines Unterbereichs an derselben Stelle; ohne äußere wirkt die innere.
- Bereich als erstes Mitglied: Verbindung wirkt nicht, bleibt aber gespeichert und wirkt, sobald ein Mitglied davor steht.
- Herauslösen, Verschieben in eine andere Gruppe und Löschen der Obergruppe setzen die Verbindung zurück; Umsortieren nicht.
- Simulation: Eine Anlage mit Puffer zwischen zwei Bereichen liefert nie nennenswert weniger als dieselbe Anlage ohne Puffer (Invariante wie in `tests/group/domain/buffer_rule_test.dart`), und bei einer Störung im hinteren Bereich läuft der vordere weiter, bis der Puffer voll ist.
- Eine Anlage aus zwei Bereichen rechnet in Linienanalyse und Simulation genau wie dieselben Studien in **einer** flachen Gruppe mit denselben Puffern und Bändern.
- Gruppen-Bildschirm: Menüpunkte fehlen beim ersten Mitglied; Karten erscheinen, lassen sich bearbeiten und entfernen.
- Backup-Rundreise erhält die Verbindung; eine alte Datei ohne die Felder lädt.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.
- [ ] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [ ] `docs/architecture.md` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- Annahme: Die Verbindung gehört zur Anlage (am Bereich in seiner Obergruppe gespeichert) und nicht zum Bereich selbst. Wer denselben Bereich später in eine andere Anlage hängt, legt die Verbindung dort neu fest.
- Annahme: Eine Verbindung am Ende eines Bereichs („hinter dem Bereich“) gibt es nicht; sie steht immer vor dem nächsten Mitglied, wie bei Stationen.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

(Beim Abschluss ausfüllen.)

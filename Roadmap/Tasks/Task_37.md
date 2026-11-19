# Task_37: Laderzelle – mehrere Maschinen, bedient von Ladern auf einer Schiene

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_37.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine Gruppe kann eine **Laderzelle** enthalten: n gleiche Maschinen, die der Reihe nach von mehreren Ladern auf einer gemeinsamen Schiene bedient werden. Die App berechnet daraus die Taktzeit der Zelle, den Engpass (welcher Lader oder die Maschinen), die Wartezeiten und zeigt, ab welcher Maschinenanzahl eine weitere Maschine nichts mehr bringt. In der Linie zählt die Zelle als eine Station.

## Praxisfall (Vorlage des Nutzers)

Laderschiene mit drei Ladern, 1 bis 4 gleiche Maschinen:

- **Lader 1** (Doppelgreifer): nimmt ein Rohteil vom Eingangsband → fährt zu Maschine i → entnimmt das Fertigteil und setzt das Rohteil ein (Wechsel) → fährt zum Ausgangsband und legt das Fertigteil ab → **wartet, bis Lader 2 die Maschine fertig bestückt hat und wegfährt** (gemeinsame Schiene, kein Überholen) → nächste Maschine i+1, immer reihum.
- **Lader 2**: bestückt Maschine i mit weiteren Teilen, während Lader 1 zum Band fährt. Er nimmt die Teile aus einem Magazin.
- **Lader 3**: legt Teile im Magazin bereit, damit Lader 2 sie direkt greifen kann. Durch das Magazin ist er von Lader 2 entkoppelt; er muss im Mittel nur schnell genug nachlegen.
- **Maschine i**: Wechsel (L1) → Bestücken (L2) → Bearbeiten → wartet auf den nächsten Wechsel.

## Modell

Jede beteiligte Ressource wird als eigene Studie gemessen, über ihren **ganzen Zyklus einschließlich Wartezeiten**. Schritte, in denen die Ressource nur auf Nachschub wartet, werden markiert („Wartezeit, zählt nicht“) und herausgerechnet:

- **Lader k:** H_k = Zykluszeit pro Teil − markierte Warteschritte (z. B. „Warten auf Maschine“, „Warten auf Magazin“). Wartezeiten wegen der gemeinsamen Schiene („Warten auf Lader 2“) sind **nicht** markiert. Sie gehören zum Ablauf und bleiben in H_k.
- **Maschine:** M = Zykluszeit − markierte Warteschritte („Warten auf Lader“), also Wechsel + Bestücken + Bearbeiten.
- **Taktzeit der Zelle:** T = max(H_1, …, H_k, M ÷ n). Ein Lader, der nicht jedes Teil anfasst, bekommt einen Faktor „Teile pro Zyklus“ (Standard 1) und geht mit Zykluszeit ÷ Faktor ein.
- **Engpass:** die Ressource mit dem größten Wert. **Auslastung** einer Ressource = eigener Wert ÷ T, Wartezeit pro Teil = T − eigener Wert.
- **Sinnvolle Maschinenanzahl:** n* = ⌈M ÷ max(H_k)⌉. Ab dieser Anzahl bringt eine weitere Maschine nichts mehr. Tabelle für n = 1…6.

Beispiel (muss als Test belegt werden): H_1 = 32 s, H_2 = 20 s, H_3 = 15 s, M = 88 s
→ n = 1: 88 s · n = 2: 44 s · n = 3: 32 s (Engpass Lader 1) · n = 4: 32 s; n* = 3.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_36 archiviert.
- **Relevantes Vorwissen:** Task_19 (Gruppen), Task_24/27 (`LineAnalysis`, Stationen, `stationGroups`), Task_26 (parallele Maschinen = Lastteilung 1/Σ(1/t); das ist **etwas anderes** als die Laderzelle), Task_29–33 (Puffer, Simulation, Bänder), Task_34 (Sonderzyklen: wirksame Taktzeit der Maschine).

## Umfang

**Gehört dazu:**

- Datenmodell und Migration:
  - Je Schrittdefinition ein Merker „Wartezeit, zählt nicht“, ausschließlich für die Laderzelle; die Auswertung der einzelnen Studie bleibt unverändert, zeigt den Merker aber an.
  - Je Gruppenmitglied eine Rolle in der Zelle (Maschine / Lader), „Teile pro Zyklus“ bei Ladern und die Maschinenanzahl n bei der Maschine. Die Zelle ist eine Station; ihre Mitglieder werden wie heute über die Gruppenreihenfolge zusammengehalten (an `stationGroups` anlehnen, keine zweite Gruppierungslogik).
  - Kopie und Backup übernehmen alle neuen Felder; alte Backups bleiben lesbar.
- Reine Domain-Funktion für die Zelle (H_k, M, T, Engpass, Auslastung, Wartezeit, n*, Tabelle n = 1…6).
- Linienanalyse: die Zelle ist eine Station mit Taktzeit T und Durchlaufzeit M; Engpass, Abstimmung und Ausbringung rechnen damit. Sonderzyklen der Maschine wirken über die wirksame Taktzeit auf M.
- Simulation: die Zelle als Station mit Taktzeit T (deterministisch wie eine Maschine). Puffer und Bänder davor und dahinter funktionieren unverändert.
- UI:
  - In der Gruppe ein Mitglied als „Laderzelle“ kennzeichnen (Maschine plus Lader); Felder für n und „Teile pro Zyklus“.
  - Im Schritt-Editor der Merker „Wartezeit, zählt nicht“.
  - Zellenansicht mit Taktzeit, Engpass, Auslastung und Wartezeit je Ressource sowie der Tabelle 1…6 Maschinen mit hervorgehobenem n*.
  - Hinweis in der Zellenansicht: „Jede Ressource über den ganzen Zyklus messen, Wartezeiten als eigene Schritte.“
- Reports (PDF, Excel): Kapitel bzw. Blatt zur Laderzelle mit denselben Werten.
- Texte DE/EN, `docs/` (architecture, project-brief), `Roadmap/README.md`, Demo-Daten um eine Laderzelle ergänzen.

**Gehört nicht dazu:**

- Ereignisgenaue Simulation der Schienenverriegelung („wer wartet auf wen“) für Was-wäre-wenn-Fragen. Die gemessenen Wartezeiten bilden die Verriegelung ab. Wird ein Lader schneller, ändert sich seine Wartezeit; das bildet das Modell nicht nach. Das wäre ein eigener Folge-Task.
- Ungleiche Maschinen in einer Zelle (alle n Maschinen haben dieselbe Belegungszeit M).
- Ausfälle einzelner Maschinen der Zelle in der Simulation (die Zelle fällt als Ganzes aus wie eine Maschine).

## Umsetzungsschritte

1. [ ] Domain-Funktion der Zelle mit dem Beispiel oben (TDD).
2. [ ] Datenmodell, Migration, Kopie, Backup (TDD).
3. [ ] Linienanalyse und Simulation (TDD).
4. [ ] UI: Merker im Schritt-Editor, Zelle in der Gruppe, Zellenansicht (Widget-Tests).
5. [ ] Reports (TDD).
6. [ ] Demo-Daten, Doku, README, Version.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Beispiel oben: T je n und n* = 3; Engpass wechselt von „Maschinen“ (n ≤ 2) zu „Lader 1“ (n ≥ 3).
- Markierte Warteschritte werden aus H_k bzw. M herausgerechnet, unmarkierte (Schienen-Warten) nicht.
- „Teile pro Zyklus“ = 2 halbiert den Wert des Laders.
- Lader 3 (Magazin) wird Engpass, wenn sein Wert über allen anderen liegt.
- Eine Zelle ohne gemessene Maschine oder ohne gemessenen Lader gilt als nicht gemessen (wie heute bei Stationen).
- Linienanalyse und Simulation nutzen T der Zelle; Puffer und Bänder davor und dahinter arbeiten unverändert.
- Merker, Rolle, n und Faktor werden gespeichert, kopiert, gesichert und wiederhergestellt; ein altes Backup ohne die Felder lädt.
- UI und Reports zeigen die Werte.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.
- [ ] `docs/` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- Annahme: Lader 2 bedient alle Maschinen reihum wie Lader 1 (nicht ausdrücklich bestätigt). Bedient ein Lader nur einen Teil der Maschinen, deckt das der Faktor „Teile pro Zyklus“ nicht ab, dann nachfragen.
- Annahme: Lader 3 fährt ebenfalls auf der Schiene. Behindert er Lader 2, zeigt sich das als (unmarkiertes) Schienen-Warten in der Studie von Lader 2.
- Annahme: Das Magazin ist groß genug, dass Schwankungen von Lader 3 nicht durchschlagen; nur der Mittelwert zählt.
- Offen: genaue Bezeichnung in der UI („Laderzelle“ / „Loader cell“) und wo der Merker im Schritt-Editor sitzt – mit dem Nutzer abstimmen, falls unklar.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Entstanden aus einer Nutzerfrage (2026-11-19). Verworfene Zwischenideen: (a) Lader als parallele Maschinen anlegen – falsch, weil „parallel“ Lastteilung bedeutet; (b) „gekoppelte Station = Maximum der Mitglieder“ – reicht allein nicht, weil die n Maschinen sich die Teile teilen (daher M ÷ n).

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

_Wird beim Abschluss ausgefüllt._

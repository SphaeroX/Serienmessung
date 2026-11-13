# Task_24: Linienbetrachtung der Gruppe

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_24.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Die Studien einer Gruppe werden als Linie (Stationen in Gruppenreihenfolge) gemeinsam betrachtet: Wie läuft ein Teil durch, wo ist der Engpass, wie gut ist die Linie ausgetaktet, und wie hat sich das gegenüber der Vorrevision verändert.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_23 archiviert.
- **Relevantes Vorwissen:** Task_19 (Gruppen, Reihenfolge), Task_20 (Revisionen, `RevisionComparison`), Task_22 (`GroupReportInput`, Laden der Gruppendaten im `GroupExportButton`).

## Umfang

**Gehört dazu:**

- Reine Domain `LineAnalysis` (`lib/group/domain/`): je Station reale Taktzeit, Anteil, Wartezeit gegenüber dem Engpass, Schrittanteile (für das gestapelte Diagramm); Linie: Summe der Taktzeiten (Durchlauf ohne Puffer), Linientakt = Engpass (Maximum), Austaktungsgrad = Summe / (Stationen × Engpass), Ausbringung pro Stunde = 1 h / Engpass; Vergleich zur Vorrevision.
- Bildschirm "Linienbetrachtung" (Knopf im Gruppen-Bildschirm): Kennzahlen, gestapeltes Balkendiagramm (Yamazumi) in Gruppenreihenfolge mit Engpass-Linie, Stationsliste.
- Gemeinsames Laden der Gruppendaten für Report und Linienbetrachtung.
- Texte DE/EN.

**Gehört nicht dazu:**

- Simulation von Puffern/Warteschlangen, Sollzeiten (Nicht-Ziel).

## Umsetzungsschritte

1. [ ] `LineAnalysis` (TDD).
2. [ ] Laden der Gruppendaten auslagern.
3. [ ] Linien-Bildschirm mit Diagramm (Widget-Tests).
4. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Summe, Engpass, Austaktungsgrad, Ausbringung, Wartezeit und Anteile stimmen.
- Stationen ohne Zyklen (Schritt-Timer, ohne Zeiten) zählen nicht, werden aber angezeigt.
- Vergleich zur Vorrevision nur, wenn alle gemessenen Stationen eine Vorrevision haben.
- Bildschirm zeigt Kennzahlen, Engpass und Stationen in Reihenfolge.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Die Summe der Taktzeiten ist die reine Bearbeitungs-Durchlaufzeit eines Teils (ohne Puffer/Transport).
- Die Schrittanteile im Diagramm werden so skaliert, dass der Balken der realen Taktzeit der Station entspricht.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):**
- **Learnings & Stolpersteine:**
- **Wichtige Entscheidungen und ihre Gründe:**
- **Auswirkungen auf Folge-Tasks:**
- **Hinweise zu Tests und Befehlen:**

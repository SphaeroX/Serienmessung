# Task_15: Modus "Schritt-Timer"

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_15.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Im Modus Schritt-Timer tippt man die Schritte in beliebiger Reihenfolge an; die Zeit läuft jeweils für den zuletzt angetippten Schritt. Auswertung pro Schritt wie bei der Zeitstudie.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_14 archiviert.
- **Relevantes Vorwissen:** Vorbild alte App: "Schritte in beliebiger Reihenfolge antippen, Zeit pro Schritt erfassen". Keine festen Zyklen.

## Umfang

**Gehört dazu:**

- Messbildschirm mit Kachel/Button je Schritt; aktiver Schritt deutlich hervorgehoben (Overlay-Prinzip wie Task_03).
- Antippen eines Schritts beendet den laufenden und startet den angetippten.
- Start/Stopp per Lautstärke runter; Sonderzeit per halten.
- Ansicht der Messungen chronologisch, Löschen einzelner Messungen.
- Auswertung pro Schritt (Summe, Anzahl, Mittelwert, Median, Anteil an Gesamtzeit); Zyklus-Taktzeit entfällt.

**Gehört nicht dazu:**

- Zuordnung zu Zyklen.

## Umsetzungsschritte

1. [ ] Engine-Variante bzw. Strategie "freie Reihenfolge" umsetzen.
2. [ ] Messbildschirm mit Schritt-Kacheln (auch bei vielen Schritten bedienbar, scrollbar).
3. [ ] Messungen- und Auswertungsansicht anpassen.
4. [ ] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Folge S2 → S1 → S2 ergibt drei Messungen mit korrekter Zuordnung und Dauer.
- Erneutes Antippen des aktiven Schritts: definiertes Verhalten (Annahme: neue Messung desselben Schritts).
- Anteil an Gesamtzeit summiert sich auf 100 % (ohne Sonderzeit).

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün; vorhandene Tests bleiben grün.

## Offene Fragen / Annahmen

- Startet beim Start automatisch Schritt 1 oder wartet die Messung auf das erste Antippen? Annahme: Start aktiviert den ersten Schritt der Liste (analog zum Wunsch bei der Zeitstudie).

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

<!-- ERKENNTNISSE-OFFEN: Vor der Archivierung ausfüllen und diese Zeile löschen. -->

Vor der Archivierung vom Agenten auszufüllen. Schreibe so, dass ein Agent, der diesen Task nie gesehen hat, davon bei späteren Tasks profitiert:

- **Umgesetzt (und Abweichungen vom Plan):**
- **Learnings & Stolpersteine:**
- **Wichtige Entscheidungen und ihre Gründe:**
- **Auswirkungen auf Folge-Tasks:**
- **Hinweise zu Tests und Befehlen:**

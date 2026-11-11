# Task_14: Modus "Einfach"

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_14.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Der Modus Einfach funktioniert als klassische Stoppuhr mit Runden (ohne Schrittdefinition), inkl. Hardware-Tasten, Sonderzeit, Hintergrundbetrieb, Bearbeitung, Auswertung.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_13 archiviert (inhaltlich nötig: Task_03–09).
- **Relevantes Vorwissen:** Vorbild alte App: GESAMT/RUNDE oben, Liste mit ID, Gesamt, Runde. Technisch kann "Einfach" als Zeitstudie mit genau einem impliziten Schritt "Runde" abgebildet werden – prüfen, ob das Engine, Zyklen-Ansicht und Auswertung ohne Sonderfälle wiederverwendet.

## Umfang

**Gehört dazu:**

- Anlegen ohne Textarea (bereits in Task_01 vorbereitet).
- Messbildschirm-Variante: Runde statt Schritt, Rundenliste mit Gesamt- und Rundenzeit.
- Lautstärke hoch = Runde, halten = Sonderzeit, runter = Start/Stopp.
- Runden löschen, Auswertung über Runden (Mittelwert, Median, IQR-Taktzeit).

**Gehört nicht dazu:**

- Neue Statistikfunktionen.

## Umsetzungsschritte

1. [ ] Abbildung auf bestehende Engine entscheiden und dokumentieren.
2. [ ] Messbildschirm-Variante umsetzen.
3. [ ] Zyklen-Ansicht und Auswertung für den Modus anpassen (Begriffe "Runde").
4. [ ] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Engine im Modus Einfach: 5× weiter → 5 Runden mit korrekten Dauern.
- Sonderzeit in Runde wird herausgerechnet.
- Widget-Test: Rundenliste zeigt Gesamt- und Rundenzeit.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün; vorhandene Tests der Zeitstudie bleiben grün.

## Offene Fragen / Annahmen

- Keine.

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

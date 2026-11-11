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

1. [x] Abbildung auf bestehende Engine entscheiden und dokumentieren.
2. [x] Messbildschirm-Variante umsetzen.
3. [x] Zyklen-Ansicht und Auswertung für den Modus anpassen (Begriffe "Runde").
4. [x] Texte DE/EN.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Engine im Modus Einfach: 5× weiter → 5 Runden mit korrekten Dauern.
- Sonderzeit in Runde wird herausgerechnet.
- Widget-Test: Rundenliste zeigt Gesamt- und Rundenzeit.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [x] Tests grün; vorhandene Tests der Zeitstudie bleiben grün.

## Offene Fragen / Annahmen

- Keine.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Keine Produktivcode-Änderung nötig: Der Modus "Einfach" läuft seit Task_02/03 über die gemeinsame Engine mit `sequence: [null]` (jede Runde = ein Zyklus). Messbildschirm zeigt "Runde n" im Overlay, Kacheln GESAMT/RUNDE, Rundenliste mit kumulierter Gesamtzeit und Rundenzeit, Tab "Runden" mit Löschen/Rückgängig, Auswertung "Reale Rundenzeit". Lautstärke hoch = Runde, halten = Sonderzeit, runter = Start/Stopp. Dieser Task hat das Verhalten mit Tests abgesichert.
- **Learnings & Stolpersteine:** Keine – die Entscheidung in Task_02, alle Modi über eine Engine abzubilden, hat sich ausgezahlt.
- **Wichtige Entscheidungen und ihre Gründe:** Abbildung auf die bestehende Engine bestätigt (kein Sonderfall in Engine, Zyklen-Ansicht oder Auswertung).
- **Auswirkungen auf Folge-Tasks:** Task_15 kann denselben Weg gehen (`freeOrder: true`), braucht aber eigene UI (Schritt-Kacheln) und eine flache Zeitenliste statt Zyklen.
- **Hinweise zu Tests und Befehlen:** `tests/recording/presentation/simple_mode_test.dart` (Engine 5 Runden, Rundenliste, Tasten inkl. Sonderzeit + Auswertung). Alle bestehenden Zeitstudien-Tests bleiben grün.

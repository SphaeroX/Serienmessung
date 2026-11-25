# Task_45: Bestehende Gruppe in Bereiche aufteilen und Bereiche auflösen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_45.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Wer schon eine große Gruppe hat, kann sie nachträglich in Bereiche aufteilen, ohne Studien einzeln zu verschieben: mehrere aufeinanderfolgende Mitglieder markieren und zu einem Bereich zusammenfassen. Umgekehrt lässt sich ein Bereich auflösen; seine Mitglieder rücken an seine Stelle in die Obergruppe. Beides ändert die Gesamtlinie nicht.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_38 bis Task_44 archiviert. Deren "Erkenntnisse für Folge-Agenten" lesen.
- **Relevantes Vorwissen:** Task_38 (Stationsregeln mit Bereichen), Task_42 (Verbindung vor einem Bereich), README "Außerhalb der Roadmap (2026-11-17)" (Mehrfachauswahl mit langem Druck, `SelectionAppBar`).
- **Betroffener Code:** `lib/group/data/group_repository.dart`, `lib/group/domain/` (Auswahlregeln), `lib/group/presentation/group_screen.dart`.

## Umfang

**Gehört dazu:**

- **Zusammenfassen:**
  - Im Gruppen-Bildschirm startet ein langer Druck auf ein Mitglied die Auswahl (wie in Studien- und Gruppenliste). Die Auswahlleiste bietet „Als Bereich zusammenfassen“.
  - Die Auswahl wird auf **ganze Stationen** erweitert (wer eine Maschine einer Parallelstation oder einen Lader markiert, nimmt die ganze Station mit) und muss zusammenhängend sein. Bei einer Auswahl mit Lücke ist die Aktion gesperrt, und ein Hinweis erklärt warum.
  - Nach der Eingabe eines Namens entsteht an der Stelle des ersten markierten Mitglieds ein neuer Bereich mit den Mitgliedern in unveränderter Reihenfolge. Parallel-Flags, Lader-Rollen, Warte-Option, Sonderzyklen, Puffer und Bänder **innerhalb** der Auswahl bleiben.
  - Puffer und Band vor der ersten markierten Station werden zur Verbindung vor dem neuen Bereich (Task_42). Steht die Auswahl am Anfang der Gruppe, gibt es nichts zu übernehmen.
  - Bereiche in der Auswahl werden zu Unterbereichen des neuen Bereichs.
- **Auflösen:**
  - Menüpunkt „Bereich auflösen“ an der Bereichskarte, mit Rückfrage.
  - Die Mitglieder des Bereichs rücken in ihrer Reihenfolge an seine Stelle in die Obergruppe, Unterbereiche eine Ebene nach oben. Die Verbindung vor dem Bereich geht an seine erste Station (Studie) bzw. an seinen ersten Unterbereich. Die leere Gruppe wird gelöscht.
  - Ein Bereich der obersten Ebene hat keine Obergruppe und bietet den Menüpunkt nicht an.
- Beide Aktionen laufen in **einer** Transaktion im Repository.
- **Invariante als Test:** Die abgeflachte Linie (Reihenfolge, wirksame Parallel-Flags, Puffer, Bänder, Warte-Optionen) ist vor und nach Zusammenfassen bzw. Auflösen gleich; Zusammenfassen und anschließendes Auflösen stellt die ursprünglichen Mitglieder wieder her.
- Texte EN/DE, `docs/architecture.md`, `Roadmap/README.md`.

**Gehört nicht dazu:**

- Löschen oder Teilen mehrerer Mitglieder über die neue Auswahl im Gruppen-Bildschirm (gibt es in den Listen der Startseite und der Gruppenliste).
- Automatische Vorschläge, wo eine Linie sinnvoll zu teilen wäre.

## Umsetzungsschritte

1. [ ] Auswahlregeln als reine Funktion: Erweitern auf ganze Stationen, Prüfung auf Zusammenhang (TDD).
2. [ ] Repository: Zusammenfassen und Auflösen, jeweils transaktional, mit Invarianten-Test.
3. [ ] Gruppen-Bildschirm: Auswahlmodus, Aktion mit Namensdialog, Hinweis bei Lücke.
4. [ ] Menüpunkt „Bereich auflösen“ mit Rückfrage.
5. [ ] Texte, Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/group/domain/area_selection_test.dart`, `tests/group/data/group_into_area_test.dart`, `tests/group/presentation/group_into_area_screen_test.dart`.

Zu belegende Verhaltensweisen:

- Auswahl einer einzelnen Maschine einer Parallelstation wird auf die ganze Station erweitert; Auswahl eines Laders auf die ganze Zelle.
- Eine Auswahl mit Lücke kann nicht zusammengefasst werden.
- Zusammenfassen von Station 3 bis 5 einer Linie mit acht Stationen: Die Obergruppe hat danach die Mitglieder 1, 2, Bereich, 6, 7, 8; die Linienanalyse (Taktzeit, Engpass, Abstimmung, Ausbringung) und die Simulation über 24 h liefern dieselben Werte wie vorher.
- Puffer vor Station 3 steht danach als Verbindung vor dem Bereich; Puffer vor Station 4 bleibt an Station 4.
- Zusammenfassen am Anfang der Gruppe funktioniert ohne Verbindung.
- Auflösen stellt die ursprünglichen Mitglieder, Reihenfolge, Stationen, Puffer und Bänder wieder her; die leere Gruppe ist gelöscht.
- Auflösen eines Bereichs mit Unterbereich hebt den Unterbereich eine Ebene an.
- Gruppen-Bildschirm: langer Druck startet die Auswahl, Zurück beendet sie, die Aktion legt den Bereich an und zeigt ihn an der richtigen Stelle.
- Die Demo-Linie, in Bereiche aufgeteilt, ergibt weiter 1000 Teile in 24 h.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt, insbesondere die Invariante „Linie unverändert“.
- [ ] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [ ] `docs/architecture.md` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- Annahme: Der lange Druck im Gruppen-Bildschirm ist frei; heute startet er dort nichts. Das Ziehen zum Umsortieren läuft über den Griff rechts und kollidiert nicht. Vor der Umsetzung im Code prüfen.
- Annahme: Die Auswahl wird stillschweigend auf ganze Stationen erweitert und die Erweiterung sofort sichtbar markiert, statt den Nutzer mit einer Fehlermeldung zu stoppen.

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

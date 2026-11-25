# Task_41: Gruppen-Bildschirm und Gruppenliste mit Bereichen

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_41.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Der Nutzer kann in der App eine Gruppe aus Studien **und Gruppen** zusammenstellen: eine bestehende Gruppe als Bereich hinzufügen, einen neuen Bereich anlegen, Bereiche zwischen den Studien anordnen, öffnen, herauslösen und löschen. Die Gruppenliste zeigt, welche Gruppe in welcher liegt.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_38 bis Task_40 archiviert. Deren "Erkenntnisse für Folge-Agenten" lesen.
- **Relevantes Vorwissen:** Task_19 (Gruppen-UI), `docs/architecture.md` Abschnitt "Groups UI", README "Außerhalb der Roadmap (2026-11-17)" (Mehrfachauswahl, `SelectionAppBar`) und "[Nach Task_37, 2026-11-19] Gruppe samt Studien löschen".
- **Betroffener Code:** `lib/group/presentation/group_screen.dart`, `group_list_screen.dart`, `group_dialogs.dart` (`pickGroup`), `lib/study/presentation/study_list_screen.dart` (Gruppenname auf der Studienkarte), `lib/l10n/app_en.arb`, `app_de.arb`.

## Umfang

**Gehört dazu:**

- **Gruppen-Bildschirm (`GroupScreen`):**
  - Lädt die gemischten Mitglieder (`listMembers`).
  - Bereichskarte mit Ordner-Symbol, Name, Anzahl Stationen und Studien im Bereich und, falls gemessen, der Taktzeit des Bereichs. Antippen öffnet den Gruppen-Bildschirm des Bereichs; nach der Rückkehr wird neu geladen.
  - Stationsnummern laufen über Bereiche hinweg durch: Ein Bereich trägt den Bereich seiner Stationen („3–7“), die Studie dahinter die nächste Nummer („8“). Grundlage ist das Abflachen aus Task_40, damit Gruppen-Bildschirm und Linienanalyse dieselben Nummern zeigen.
  - Hinzufügen (Blatt hinter dem „+“): zusätzlich „Bestehende Gruppe hinzufügen“ und „Neuer Bereich“. Zur Auswahl stehen Gruppen der obersten Ebene, ohne die Gruppe selbst und ihre Vorfahren. Ein neuer Bereich wird angelegt und sofort geöffnet.
  - Menü der Bereichskarte: nach oben, nach unten, in andere Gruppe verschieben, aus der Gruppe lösen (wird Gruppe der obersten Ebene), löschen (derselbe Dialog wie beim Löschen einer Gruppe).
  - Ziehen zum Umsortieren funktioniert mit Studien und Bereichen gemischt.
  - Bei einer Studie direkt hinter einem Bereich fehlen die Menüpunkte „parallel“ und „Lader der Maschine darüber“ (wie beim ersten Mitglied).
  - Liegt die geöffnete Gruppe selbst in einer Obergruppe, zeigt die Kopfzeile den Pfad („Werk 1 › Halle 2“), und das Gruppenmenü bietet „Aus Obergruppe lösen“.
- **Löschen einer Gruppe mit Bereichen:** Das Häkchen nennt Studien und Bereiche („Auch die N Studien und M Bereiche dieser Gruppe löschen“) und zählt den ganzen Teilbaum. Ohne Häkchen bleiben Studien und Bereiche erhalten (Bereiche als Gruppen der obersten Ebene).
- **Gruppenliste (`GroupListScreen`):**
  - Baumdarstellung: Bereiche stehen eingerückt unter ihrer Obergruppe. Der Untertitel nennt Bereiche und Studien („3 Bereiche · 12 Studien“).
  - Mehrfachauswahl: Teilen einer Obergruppe nimmt den Teilbaum mit (Task_39). Löschen fragt wie heute „Studien behalten“ oder „mit Studien“ und wendet die Regeln aus Task_38 an.
- **`pickGroup`:** zeigt den Pfad jeder Gruppe; beim Verschieben einer Gruppe fehlen die Gruppe selbst und ihre Nachfahren.
- **Studienkarte der Startseite:** zeigt den Pfad der Gruppe statt nur des Namens.
- Texte EN/DE über ARB, `flutter gen-l10n`.
- `docs/architecture.md` (Groups UI), `Roadmap/README.md`.

**Gehört nicht dazu:**

- Puffer und Bänder vor einem Bereich (Task_42).
- Mehrere Mitglieder zu einem Bereich zusammenfassen und Bereiche auflösen (Task_45).
- Kopieren einer ganzen Gruppe.

## Umsetzungsschritte

1. [ ] Gemischte Mitgliederliste mit Bereichskarte und durchlaufenden Stationsnummern (Widget-Tests zuerst).
2. [ ] Hinzufügen: bestehende Gruppe, neuer Bereich.
3. [ ] Menü der Bereichskarte, Umsortieren per Ziehen und per Menü.
4. [ ] Pfad in der Kopfzeile, „Aus Obergruppe lösen“, Löschdialog.
5. [ ] Gruppenliste als Baum, Mehrfachauswahl.
6. [ ] `pickGroup` mit Pfad und Sperren, Studienkarte mit Pfad.
7. [ ] Texte, Doku, volle Suite, `flutter analyze`, `dart format`.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`). Vorschlag: `tests/group/presentation/nested_group_screen_test.dart`, `nested_group_list_test.dart`, `nested_group_dialogs_test.dart`.

Zu belegende Verhaltensweisen:

- „Bestehende Gruppe hinzufügen“ bietet weder die Gruppe selbst noch ihre Vorfahren an; nach der Auswahl steht der Bereich am Ende der Mitglieder.
- „Neuer Bereich“ legt eine Gruppe in der Obergruppe an und öffnet sie.
- Antippen der Bereichskarte öffnet den Bereich; eine dort hinzugefügte Studie ändert nach der Rückkehr Anzahl und Stationsnummern in der Obergruppe.
- Stationsnummern: Studie „1“, Bereich mit drei Stationen „2–4“, Studie dahinter „5“.
- Nach oben, nach unten und Ziehen ordnen Studien und Bereiche gemischt um; die Stationen der Studien bleiben zusammen.
- „Aus der Gruppe lösen“ macht den Bereich zur Gruppe der obersten Ebene; seine Studien bleiben in ihm.
- Löschen mit Häkchen entfernt den Teilbaum samt Studien, ohne Häkchen bleiben Bereiche und Studien erhalten.
- Die Gruppenliste zeigt den Bereich eingerückt unter der Obergruppe mit den richtigen Zahlen.
- Die Studienkarte der Startseite zeigt den Pfad der Gruppe.
- Texte in Englisch und Deutsch vorhanden.
- Alle bestehenden Tests in `tests/group/presentation/` laufen unverändert (die bestehenden Keys bleiben).

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format --output=none --set-exit-if-changed .` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.
- [ ] Kein bestehender Test geändert, gelöscht oder abgeschwächt.
- [ ] Keine hartkodierten UI-Texte; `docs/architecture.md` und `Roadmap/README.md` aktuell.

## Offene Fragen / Annahmen

- Annahme: Der sichtbare Begriff ist „Bereich“ (EN „Area“) für eine Gruppe in einer Gruppe; die Obergruppe heißt weiter „Gruppe“. Der Nutzer hat in seiner Anfrage von „Bereichen“ gesprochen.
- Annahme: Zum Hinzufügen werden nur Gruppen der obersten Ebene angeboten. Ein Bereich, der schon in einer anderen Anlage liegt, wird dort über „In andere Gruppe verschieben“ umgehängt. So verschwindet nie unbemerkt ein Bereich aus einer anderen Anlage.
- Annahme: Die Gruppenliste zeigt alle Gruppen als Baum (Bereiche eingerückt), damit man einen Bereich auch direkt öffnen kann, ohne über die Anlage zu gehen.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

- Der Pfad-Trenner „›“ ist kein Latin-1-Zeichen. In der App ist das unkritisch; in PDFs (Task_44) muss ein anderes Zeichen stehen.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [ ] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [ ] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [ ] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [ ] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

(Beim Abschluss ausfüllen.)

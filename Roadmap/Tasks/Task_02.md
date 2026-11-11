# Task_02: Mess-Engine Zeitstudie

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_02.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Eine reine Dart-Mess-Engine für den Modus Zeitstudie (feste Abfolge) existiert und ist vollständig getestet: Beim Start ist Schritt 1 sofort aktiv, jedes "Weiter" schließt den aktuellen Schritt ab und aktiviert den nächsten, nach dem letzten Schritt beginnt ein neuer Zyklus. Jede abgeschlossene Messung wird sofort gespeichert.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Task_01 archiviert.
- **Relevantes Vorwissen:** README: monotone Uhr, Fachlogik getrennt von UI, interne Zeiteinheit. Kernwunsch des Nutzers: Der erste Schritt muss beim Start bereits aktiv sein – nicht erst nach dem ersten Rundendruck.

## Umfang

**Gehört dazu:**

- Zustandsmodell: gestoppt / läuft / pausiert; aktueller Zyklus-Index, aktueller Schritt-Index, Startzeit des laufenden Schritts.
- Aktionen: start, weiter (nächster Schritt), pause/stopp, fortsetzen.
- Messung-Datensatz: studieId, zyklusNr, schrittId, beginn, ende, dauer, typ (normal; Sonderzeit folgt in Task_05).
- Persistenz jeder abgeschlossenen Messung direkt bei "weiter" (Tabelle Messung + Migration).
- Verhalten bei Pause: laufende Schrittzeit wird angehalten und beim Fortsetzen weitergezählt (Pausenzeit zählt nicht).
- Injizierbare Uhr für deterministische Tests.
- Laufende Werte als Stream/Notifier: Gesamtzeit, Zeit aktueller Schritt, aktueller Schritt, nächster Schritt, Zyklus-Nr.

**Gehört nicht dazu:**

- Benutzeroberfläche (Task_03).
- Sonderzeit (Task_05), Hardware-Tasten (Task_04), Hintergrunddienst (Task_06).
- Statistik (Task_09).

## Umsetzungsschritte

1. [ ] Uhr-Interface und Fake-Uhr anlegen.
2. [ ] Zustandsautomat der Engine umsetzen, ungültige Übergänge (z. B. weiter im gestoppten Zustand) definiert behandeln.
3. [ ] Messung-Tabelle und Repository ergänzen (DB-Migration von Schema 1 auf 2).
4. [ ] Engine schreibt jede abgeschlossene Messung sofort ins Repository.
5. [ ] Fortsetzen einer bestehenden Studie: Engine setzt beim nächsten Zyklus nach dem letzten gespeicherten an (Entscheidung dokumentieren).
6. [ ] Beobachtbaren Zustand für die UI bereitstellen.
7. [ ] Entscheidungen (Zeiteinheit intern, Verhalten bei Fortsetzen) in README festhalten.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Start → Schritt 1 sofort aktiv, Zyklus 1.
- 3 Schritte, 7× weiter → Messungen in richtiger Zuordnung (Zyklus 1: S1–S3, Zyklus 2: S1–S3, Zyklus 3: S1) mit korrekten Dauern aus der Fake-Uhr.
- Pause/Fortsetzen: Pausenzeit fließt nicht in die Schrittdauer ein.
- Studie mit nur 1 Schritt: jedes weiter erzeugt einen neuen Zyklus.
- Messungen sind nach jedem weiter in der DB vorhanden (Repository-Test).
- Migration von Schema 1 auf 2 erhält bestehende Studien.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Alle oben genannten Tests liegen in `tests/` und laufen grün.
- [ ] Die Engine hat keine Abhängigkeit zu Flutter-Widgets (reines Dart, per Import-Prüfung oder Code-Review belegt).
- [ ] Die Dauer eines Schritts entspricht exakt der Differenz der Fake-Uhr-Zeitpunkte (Test).

## Offene Fragen / Annahmen

- Was passiert beim Stoppen mitten in einem Zyklus: Wird der laufende Schritt als Messung abgeschlossen oder verworfen? Annahme: beim Stopp wird der laufende Schritt abgeschlossen und gespeichert, der Zyklus bleibt unvollständig und ist so markiert.

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

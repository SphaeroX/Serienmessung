# Task_19: Gruppen: Datenmodell & Verwaltung

> ## ⚠️ PFLICHT – BEVOR DU IRGENDETWAS ANDERES TUST
>
> 1. **Lies als Allererstes die Datei `AGENTS.md` im übergeordneten Ordner `Roadmap/`** (von hier: `../AGENTS.md`) und befolge sie strikt.
> 2. **Deine allererste Aktion** ist, diese Datei in `RUN_Task_19.md` umzubenennen, um den Task als laufend zu markieren. Das passiert **noch bevor irgendein Code geschrieben** wird.

## Ziel

Studien lassen sich optional in Gruppen (z. B. eine Fertigungslinie) zusammenfassen und innerhalb der Gruppe in eine feste Reihenfolge bringen (erst Maschine A, dann B, ...). Bestehende oder einzelne Studien können beliebig in eine Gruppe verschoben oder kopiert werden.

## Kontext & Abhängigkeiten

- **Voraussetzung:** Roadmap 01–18 archiviert.
- **Relevantes Vorwissen:** README (Datenbank, Migrationen append-only, Navigation über Callbacks in `app.dart`).

## Umfang

**Gehört dazu:**

- Migration: Tabelle `study_group` (Name, Beschreibung, Erstellzeit), `study.group_id` (optional, `ON DELETE SET NULL`) und `study.group_position`.
- `GroupRepository`: anlegen, umbenennen, löschen (Studien bleiben erhalten, nur ohne Gruppe), Gruppen auflisten (mit Anzahl Studien), Studien einer Gruppe in Reihenfolge, Studie in Gruppe verschieben (ans Ende), aus Gruppe entfernen, Reihenfolge setzen.
- Studie kopieren (Schritte, Messungen; optional direkt in eine Gruppe).
- UI: Gruppen-Liste (App-Leiste der Startseite), Gruppen-Bildschirm mit per Ziehen sortierbarer Studienliste, Studien hinzufügen (neu anlegen oder vorhandene auswählen), Menü pro Studie (Verschieben, Kopieren, Aus Gruppe entfernen). Studienkarte der Startseite zeigt die Gruppe und bietet Verschieben/Kopieren.
- Texte DE/EN.

**Gehört nicht dazu:**

- Gruppen-Report (Task_22), Revisionen (Task_20).

## Umsetzungsschritte

1. [ ] Migration + Migrationstest.
2. [ ] `GroupRepository` + Kopieren im `StudyRepository` (TDD).
3. [ ] Gruppen-Liste und Gruppen-Bildschirm (Widget-Tests).
4. [ ] Verschieben/Kopieren auf der Startseite.
5. [ ] Texte DE/EN, Doku.

## Tests

Alle Tests dieses Tasks werden permanent in `tests/` im Hauptverzeichnis des Projekts abgelegt (siehe `AGENTS.md`).

Zu belegende Verhaltensweisen:

- Gruppe anlegen, umbenennen, löschen (Studien bleiben ohne Gruppe erhalten).
- Verschieben hängt die Studie ans Ende der Zielgruppe; Reihenfolge lässt sich setzen und bleibt erhalten.
- Kopie enthält Schritte und Messungen mit umgemappten Schritt-IDs; Original unverändert.
- Gruppen-Bildschirm zeigt Studien in Reihenfolge; Hinzufügen/Entfernen/Verschieben/Kopieren über die UI.

Alle Tests laufen mit `flutter test tests/`.

## Akzeptanzkriterien

Der Task gilt erst als fertig, wenn alle Punkte erfüllt und durch Tests oder einen konkreten Befehl belegt sind:

- [ ] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [ ] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Eine Studie gehört zu höchstens einer Gruppe; "in mehrere Gruppen" geht über Kopieren.
- Gruppe löschen löscht keine Studien.

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

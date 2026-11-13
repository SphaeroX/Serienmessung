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

- [x] Tests grün, `flutter analyze` ohne Befunde, `dart format` sauber.
- [x] Verhalten wie unter "Tests" beschrieben belegt.

## Offene Fragen / Annahmen

- Eine Studie gehört zu höchstens einer Gruppe; "in mehrere Gruppen" geht über Kopieren.
- Gruppe löschen löscht keine Studien.

## Notizen zu diesem Task

Taskspezifische Informationen während der Arbeit hier festhalten. Taskübergreifendes gehört in `Roadmap/README.md`.

## Abschluss-Checkliste

Reihenfolge und Details stehen in `AGENTS.md`, Abschnitt "Abschluss- und Archivierungs-Workflow".

- [x] Alle Akzeptanzkriterien erfüllt, Tests liegen permanent in `tests/` und laufen grün
- [x] Abschnitt "Erkenntnisse für Folge-Agenten" unten ausgefüllt
- [x] Folge-Tasks und `Roadmap/README.md` geprüft und bei Bedarf angepasst
- [x] Datei ohne `RUN_` nach `Roadmap/Archiv/` verschoben

## Erkenntnisse für Folge-Agenten

- **Umgesetzt (und Abweichungen vom Plan):** Migration v9; `GroupRepository` (`lib/group/data/`), `StudyGroup`/`GroupSummary` (`lib/group/domain/`); `StudyRepository.listStudies(groupId:)`, `copyStudy`, `nextGroupPosition`; `StudySummary.groupName`. UI: `GroupListScreen`, `GroupScreen` (Ziehen am Griff + "Nach oben/unten" im Menü, Hinzufügen neu/vorhanden, Verschieben, Kopieren, Entfernen, Gruppe bearbeiten/löschen), `group_dialogs.dart`; Startseite: Ordner-Knopf (`onOpenGroups`), Kartenmenü statt Chevron, Gruppen-Label. Beim Verschieben/Kopieren kann direkt eine neue Gruppe angelegt werden.
- **Learnings & Stolpersteine:** `ReorderableListView.onReorder` ist ab Flutter 3.41 veraltet → `onReorderItem` (Index bereits um das entfernte Element korrigiert). UI-Nachladen nach mehreren sqflite-Schreibvorgängen dauert in Widget-Tests länger als `settle` – `settleUntil` mit Bedingung verwenden.
- **Wichtige Entscheidungen und ihre Gründe:** Höchstens eine Gruppe pro Studie (einfache Reihenfolge je Gruppe); Gruppe löschen löscht keine Studien; "Vorhandene hinzufügen" bietet auch Studien anderer Gruppen an (werden verschoben). Kopie heißt "<Name> (Kopie)", bekommt das aktuelle Datum und landet am Ende der Zielgruppe.
- **Auswirkungen auf Folge-Tasks:** Task_20 muss Revisionen in `copyStudy` mitkopieren. Task_22 nutzt `listStudies(groupId:)` für die Reihenfolge. Task_23 muss Gruppen ins Backup aufnehmen.
- **Hinweise zu Tests und Befehlen:** `tests/group/data/group_repository_test.dart` (Repository, Kopie, Migration v9), `tests/group/presentation/group_screens_test.dart` (Anlegen, Liste, Reihenfolge per Menü und Ziehen, Hinzufügen, Entfernen, Kopieren, Bearbeiten/Löschen, Startseiten-Menü).

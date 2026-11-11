# Project brief

> When to read: when goal, scope or non-goals of the project are unclear.

## Goal and audience

Rebuild an existing Android "time study stopwatch" app as a better Flutter app for industrial engineers and REFA/MTM practitioners doing time studies on the shop floor, usually one-handed with a phone. Focus: fast, low-error recording (blind operation via volume keys) and a clean analysis yielding the real cycle time.

## Core features

- Create a study: name, optional description, mode; steps entered in a text area, one line per step, with push-to-talk dictation (hold = dictate, release = stop).
- Modes: Time study (fixed step sequence, cycles), Video study, Simple (stopwatch with laps), Step timer (free order).
- Recording: on start, step 1 is immediately active; "next" closes the current step and starts the next; after the last step a new cycle begins. The current step is always shown prominently.
- Volume keys: up short = next step, up held = special time (interruption, separate entry with optional note, excluded from cycle time), down = start/stop.
- Recording continues in background / with screen off and survives app crashes.
- Edit afterwards: view cycles, delete whole cycles or single measurements, rename and reorder step definitions.
- Analysis per step and cycle: sum, mean, median, min, max, spread; real cycle time with selectable method (mean, median, IQR-cleaned); special times always excluded. Units: HM, seconds, mm:ss.SSS, TMU.
- Video study: import video, play with speed 0.25×–2× and frame stepping, mark steps via button or volume key, smooth 60 fps timeline, drag markers.
- Export CSV, Excel (.xlsx), PDF report; backup/restore file.
- Settings: theme, default unit, cycle-time method, vibration, hardware keys, keep screen on, notifications, language.

## Non-goals

- Standard time (performance rating, allowances) – later at the earliest.
- Cloud sync, accounts, any backend.
- iOS build for now.
- "Send feedback" / "Rate app".

## Constraints

- Android first; code iOS-capable.
- Offline only, all data on device.
- English-first UI with German translation; code and identifiers in English.

## Open decisions

- Manual correction of single times (currently: delete only).
- Dictation: one recording = one new line (assumption).
- Video: link vs. copy into app storage (assumption: link with persistent URI permission).
- Minimum Android version (assumption: API 26).

---
Maintenance: update this file when goals or scope change.

# Code style and formatting

> When to read: before writing, changing or formatting code.

## Tools

- Formatter: `dart format .` (default 80 columns).
- Linter: `flutter_lints` via `analysis_options.yaml` – rules there are authoritative and not repeated here. Check with `flutter analyze`.

## Mandatory

- Format before every commit; `flutter analyze` must report no issues.
- No `print`; use `debugPrint` or a logger only where needed.
- All user-visible text through `AppLocalizations` (ARB keys in English, lowerCamelCase).
- Domain classes are immutable (final fields, `copyWith` where needed).
- Prefer `const` constructors for widgets.
- Durations in code are `Duration` or integer microseconds – never `double` seconds.

## Recommendation

- Small widgets: extract when a `build` method exceeds ~80 lines.
- Use trailing commas so the formatter produces readable widget trees.

---
Maintenance: update this file immediately when style or tool rules change.

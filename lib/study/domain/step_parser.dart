/// Turns the step text area into a list of step names.
///
/// One non-empty line is one step; surrounding whitespace is ignored.
List<String> parseSteps(String text) => text
    .split(RegExp(r'\r?\n'))
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .toList();

/// Inverse of [parseSteps] for prefilling a text area.
String stepsToText(List<String> steps) => steps.join('\n');

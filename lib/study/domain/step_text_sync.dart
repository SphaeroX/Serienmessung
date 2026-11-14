import 'step_parser.dart';
import 'study.dart';

/// One step of the edited list: an existing step ([id] set) or a new one.
class StepEdit {
  const StepEdit({required this.id, required this.name});

  final int? id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is StepEdit && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'StepEdit($id, $name)';
}

/// Result of [planStepText]: the new step order and the steps to delete.
class StepTextPlan {
  const StepTextPlan({required this.steps, required this.deletedIds});

  final List<StepEdit> steps;
  final List<int> deletedIds;
}

/// Matches the lines of the step text area to the [existing] steps.
///
/// A line with the name of an existing step keeps that step (and its recorded
/// times), whatever its position. A remaining line that is similar to a
/// remaining step (typo fixed, case changed, words added or removed) renames
/// it; the most similar pairs win. Other lines become new steps and the steps
/// left over are deleted, so recorded times never move to an unrelated name.
StepTextPlan planStepText(List<StepDefinition> existing, String text) {
  final lines = parseSteps(text);
  final ids = List<int?>.filled(lines.length, null);
  final unused = [...existing];
  for (var i = 0; i < lines.length; i++) {
    final match = unused.indexWhere((s) => s.name == lines[i]);
    if (match >= 0) ids[i] = unused.removeAt(match).id;
  }
  final pairs = <(double, int, StepDefinition)>[
    for (var i = 0; i < lines.length; i++)
      if (ids[i] == null)
        for (final step in unused)
          if (_similarity(lines[i], step.name) case final score
              when score >= _renameThreshold)
            (score, i, step),
  ]..sort((a, b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : a.$2 - b.$2);
  for (final (_, line, step) in pairs) {
    if (ids[line] == null && unused.remove(step)) ids[line] = step.id;
  }
  return StepTextPlan(
    steps: [
      for (var i = 0; i < lines.length; i++)
        StepEdit(id: ids[i], name: lines[i]),
    ],
    deletedIds: unused.map((s) => s.id).toList(),
  );
}

const _renameThreshold = 0.5;

/// 1 for equal names (ignoring case), 0 for completely different ones.
double _similarity(String a, String b) {
  a = a.toLowerCase();
  b = b.toLowerCase();
  if (a == b) return 1;
  final contained = a.contains(b) || b.contains(a) ? 0.75 : 0.0;
  final ratio =
      1 - _levenshtein(a, b) / (a.length > b.length ? a.length : b.length);
  return ratio > contained ? ratio : contained;
}

int _levenshtein(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}

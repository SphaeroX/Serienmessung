import 'study_group.dart';

/// Separator between the names of a group path ("Plant › Press").
const groupPathSeparator = ' › ';

/// The path of every group in [groups]: the names from the top level down
/// to the group itself. A parent missing from [groups] (or a cycle) ends
/// the path there.
Map<int, List<String>> groupPaths(Iterable<StudyGroup> groups) {
  final byId = {for (final g in groups) g.id: g};
  final result = <int, List<String>>{};
  List<String> path(StudyGroup g, Set<int> seen) {
    final known = result[g.id];
    if (known != null) return known;
    final parent = g.parentId == null ? null : byId[g.parentId];
    final names = [
      if (parent != null && seen.add(parent.id)) ...path(parent, seen),
      g.name,
    ];
    return result[g.id] = names;
  }

  for (final g in groups) {
    path(g, {g.id});
  }
  return result;
}

/// The groups of a list in tree order: each top-level group (in the order
/// of [groups]) followed by its areas (by their place in the parent),
/// depth first, with their depth (0 = top level).
List<(StudyGroup, int)> groupTreeOrder(List<StudyGroup> groups) {
  final ids = {for (final g in groups) g.id};
  final children = <int, List<StudyGroup>>{};
  for (final g in groups) {
    final parent = g.parentId;
    if (parent != null && ids.contains(parent)) {
      (children[parent] ??= []).add(g);
    }
  }
  for (final list in children.values) {
    list.sort((a, b) => a.parentPosition.compareTo(b.parentPosition));
  }
  final result = <(StudyGroup, int)>[];
  final done = <int>{};
  void visit(StudyGroup g, int depth) {
    if (!done.add(g.id)) return;
    result.add((g, depth));
    for (final child in children[g.id] ?? const <StudyGroup>[]) {
      visit(child, depth + 1);
    }
  }

  for (final g in groups) {
    if (g.parentId == null || !ids.contains(g.parentId)) visit(g, 0);
  }
  // Groups caught in a cycle (never expected) still show up.
  for (final g in groups) {
    visit(g, 0);
  }
  return result;
}

/// Station labels of the group members in order: serial members are
/// numbered ("1", "2"), members of a parallel station get letters ("2a",
/// "2b"). [parallel] says per member whether it works in parallel with the
/// member before it (ignored for the first member).
List<String> stationLabels(List<bool> parallel) {
  final groups = stationGroups(parallel);
  return [
    for (var s = 0; s < groups.length; s++)
      for (var k = 0; k < groups[s].length; k++)
        groups[s].length == 1
            ? '${s + 1}'
            : '${s + 1}${String.fromCharCode('a'.codeUnitAt(0) + k % 26)}',
  ];
}

/// Indices of the members per station, in order.
List<List<int>> stationGroups(List<bool> parallel) {
  final groups = <List<int>>[];
  for (var i = 0; i < parallel.length; i++) {
    if (i > 0 && parallel[i]) {
      groups.last.add(i);
    } else {
      groups.add([i]);
    }
  }
  return groups;
}

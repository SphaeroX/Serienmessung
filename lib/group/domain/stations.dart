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

/// Parallel flags after the member at index [from] was moved to index [to]
/// (its index in the new order), so that all other members keep their
/// station:
///
/// - If the moved member was the first machine of a station with parallel
///   machines, the next one becomes the first ([newHead], its index in the
///   new order) – it takes over what stands before the station.
/// - The moved member is parallel only when it was dropped inside a
///   station (the member behind it works in parallel); anywhere else it is
///   a station of its own.
///
/// The flag of the first member is never set.
({List<bool> parallel, int? newHead}) parallelAfterMove(
  List<bool> parallel,
  int from,
  int to,
) {
  final flags = [...parallel];
  if (flags.isNotEmpty) flags[0] = false;
  if (from == to) return (parallel: flags, newHead: null);
  final wasHead = !flags[from];
  final follower = from + 1 < flags.length && flags[from + 1];
  flags.removeAt(from);
  int? newHead;
  if (wasHead && follower) {
    flags[from] = false;
    newHead = from >= to ? from + 1 : from;
  }
  flags.insert(to, to < flags.length && flags[to]);
  return (parallel: flags, newHead: newHead);
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

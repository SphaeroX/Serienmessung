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
/// [isArea] (in the old order) marks the members that are areas – groups
/// inside the group. An area is always a station boundary (see
/// [stationFlags]): an area dropped inside a station splits it, and the
/// member behind the area becomes the first machine of a station of its
/// own ([split], its index in the new order). That member keeps no buffer
/// and no conveyor of its own – they stay with the station before.
///
/// The flag of the first member is never set.
({List<bool> parallel, int? newHead, int? split}) parallelAfterMove(
  List<bool> parallel,
  int from,
  int to, {
  List<bool>? isArea,
}) {
  final area = isArea ?? List.filled(parallel.length, false);
  final flags = stationFlags(parallel, area);
  if (from == to) return (parallel: flags, newHead: null, split: null);
  final wasHead = !flags[from];
  final follower = from + 1 < flags.length && flags[from + 1];
  final movedArea = area[from];
  flags.removeAt(from);
  final areas = [...area]..removeAt(from);
  int? newHead;
  if (wasHead && follower) {
    flags[from] = false;
    newHead = from >= to ? from + 1 : from;
  }
  int? split;
  final inside = to < flags.length && flags[to];
  if (movedArea && inside) {
    flags[to] = false;
    split = to + 1;
  }
  flags.insert(to, !movedArea && inside);
  areas.insert(to, movedArea);
  return (parallel: stationFlags(flags, areas), newHead: newHead, split: split);
}

/// The parallel flags as they count for the stations: the first member,
/// an area (a group inside the group, [isArea]) and the member right
/// behind an area are never parallel – an area is always a station
/// boundary.
List<bool> stationFlags(List<bool> parallel, List<bool> isArea) => [
  for (var i = 0; i < parallel.length; i++)
    i > 0 && parallel[i] && !isArea[i] && !isArea[i - 1],
];

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

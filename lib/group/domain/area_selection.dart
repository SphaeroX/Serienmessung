import 'group_member.dart';
import 'stations.dart';

/// [selected] members of a group extended to whole stations: a machine of
/// a station of parallel machines (or a loader of a cell) brings all
/// members of its station. [order] is the group's member order, [flags]
/// the parallel flags as they count for the stations (see
/// [stationFlags]; an area is a station of its own).
Set<MemberKey> expandToStations(
  List<MemberKey> order,
  List<bool> flags,
  Set<MemberKey> selected,
) => {
  for (final station in stationGroups(flags))
    if (station.any((k) => selected.contains(order[k])))
      for (final k in station) order[k],
};

/// Whether [selected] is a non-empty run of consecutive members of
/// [order] – only such a run can become an area.
bool isContiguous(List<MemberKey> order, Set<MemberKey> selected) {
  final at = [
    for (var k = 0; k < order.length; k++)
      if (selected.contains(order[k])) k,
  ];
  return at.isNotEmpty &&
      at.length == selected.length &&
      at.last - at.first + 1 == at.length;
}

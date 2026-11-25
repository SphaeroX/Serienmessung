import 'group_tree.dart';
import 'line_analysis.dart';
import 'stations.dart';

/// Figures of one area of a line.
class AreaFigures {
  const AreaFigures({
    required this.area,
    required this.firstStation,
    required this.lastStation,
    required this.cycleTime,
    required this.totalTime,
    required this.leadTime,
    required this.waiting,
    required this.isBottleneck,
  });

  final LineArea area;

  /// Positions of the area's first and last station in the whole line
  /// (0-based, see [LineStation.position]); null for an empty area.
  final int? firstStation;
  final int? lastStation;

  /// Cycle time of the area alone: its slowest measured station; null
  /// without a measured station.
  final double? cycleTime;

  /// Sum of the measured station times and of their lead times.
  final double totalTime;
  final double leadTime;

  /// How long the area waits per part for the line's pace; null when it
  /// has no measured station.
  final double? waiting;

  /// The bottleneck of the whole line lies in this area.
  final bool isBottleneck;

  /// Parts per hour if the area ran on its own.
  double? get outputPerHour =>
      cycleTime == null || cycleTime == 0 ? null : 3600 * 1000000 / cycleTime!;
}

/// The figures of [areas] in [line], the analysis of the flattened entries
/// whose parallel flags are [parallel] (the same entries [line] was built
/// from). An area is always a station boundary, so each station belongs to
/// exactly one area or to none.
List<AreaFigures> analyseAreas(
  LineAnalysis line,
  List<bool> parallel,
  List<LineArea> areas,
) {
  final groups = stationGroups(parallel);
  return [
    for (final area in areas)
      _figures(line, [
        for (var s = 0; s < groups.length; s++)
          if (groups[s].first >= area.start && groups[s].first < area.end) s,
      ], area),
  ];
}

AreaFigures _figures(LineAnalysis line, List<int> stations, LineArea area) {
  final own = [for (final s in stations) line.stations[s]];
  final measured = [
    for (final st in own)
      if (st.cycleTime != null) st,
  ];
  final cycle = measured.isEmpty
      ? null
      : measured.map((st) => st.cycleTime!).reduce((a, b) => a > b ? a : b);
  final lineCycle = line.lineCycleTime;
  return AreaFigures(
    area: area,
    firstStation: stations.isEmpty ? null : stations.first,
    lastStation: stations.isEmpty ? null : stations.last,
    cycleTime: cycle,
    totalTime: measured.fold(0, (a, st) => a + st.cycleTime!),
    leadTime: measured.fold(0, (a, st) => a + (st.leadTime ?? 0)),
    waiting: cycle == null || lineCycle == null ? null : lineCycle - cycle,
    isBottleneck: own.any((st) => st.isBottleneck),
  );
}

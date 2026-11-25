import 'area_analysis.dart';
import 'group_tree.dart';
import 'line_simulation.dart';

/// Simulated figures of one area of a plant: the sums over its stations.
class AreaSimFigures {
  const AreaSimFigures({
    required this.area,
    required this.machines,
    required this.horizonMicros,
    required this.busyMicros,
    required this.blockedMicros,
    required this.downMicros,
    required this.bufferCapacity,
    required this.bufferMaxLevel,
  });

  final LineArea area;

  /// Simulated machines of the area (stations without times are left out).
  final int machines;
  final int horizonMicros;
  final int busyMicros;

  /// Time finished parts could not move on: the area jams.
  final int blockedMicros;
  final int downMicros;

  /// Places of the buffers before the area's stations (the one before the
  /// area included) and the highest level they reached together.
  final int bufferCapacity;
  final int bufferMaxLevel;

  /// Share of the available machine time spent working (0..1).
  double get utilization => machines == 0 || horizonMicros == 0
      ? 0
      : busyMicros / (machines * horizonMicros);

  /// Time without a part to work on: the area waits.
  int get starvedMicros =>
      machines * horizonMicros - busyMicros - blockedMicros - downMicros;
}

/// Sums [result] per area. [positions] is the line position of every
/// simulated station (`LineStation.position`; stations without times are
/// not simulated), [areas] the areas with their station ranges.
List<AreaSimFigures> areaSimulation(
  SimResult result,
  List<int> positions,
  List<AreaFigures> areas,
) => [
  for (final a in areas)
    _sum(result, [
      for (var si = 0; si < positions.length; si++)
        if (a.firstStation != null &&
            positions[si] >= a.firstStation! &&
            positions[si] <= a.lastStation!)
          si,
    ], a.area),
];

AreaSimFigures _sum(SimResult r, List<int> stations, LineArea area) {
  var machines = 0, busy = 0, blocked = 0, down = 0, capacity = 0, level = 0;
  for (final si in stations) {
    final st = r.stations[si];
    machines += st.machines;
    busy += st.busyMicros;
    blocked += st.blockedMicros;
    down += st.downMicros;
    final buffer = si < r.buffers.length ? r.buffers[si] : null;
    if (buffer != null) {
      capacity += buffer.capacity;
      level += buffer.maxLevel;
    }
  }
  return AreaSimFigures(
    area: area,
    machines: machines,
    horizonMicros: r.horizonMicros,
    busyMicros: busy,
    blockedMicros: blocked,
    downMicros: down,
    bufferCapacity: capacity,
    bufferMaxLevel: level,
  );
}

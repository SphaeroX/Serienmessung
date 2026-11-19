import '../../analysis/domain/analysis.dart';
import '../../study/domain/study.dart';
import 'loader_cell.dart';
import 'special_cycle.dart';
import 'stations.dart';

/// One study of a group (a machine of the line).
class LineStationInput {
  const LineStationInput({
    required this.name,
    required this.mode,
    required this.current,
    this.previous,
    this.parallel = false,
    this.buffer,
    this.conveyor,
    this.specialCycles = const [],
    this.cellLoader = false,
    this.cellParts = 1,
    this.cellMachines = 1,
  });

  /// Special cycles and planned stops of this machine.
  final List<SpecialCycle> specialCycles;

  /// Loader of the station it belongs to (needs [parallel]): the station
  /// is a loader cell, see [LoaderCell].
  final bool cellLoader;

  /// Parts a loader handles per own cycle.
  final int cellParts;

  /// Number of equal machines this input stands for (loader cells only).
  final int cellMachines;

  /// Conveyor before this member's station (first member only).
  final LineConveyor? conveyor;

  final String name;
  final StudyMode mode;
  final StudyAnalysis current;

  /// Buffer before this member's station (only used on a station's first
  /// member).
  final LineBuffer? buffer;

  /// Analysis of the most recently archived revision (optional).
  final StudyAnalysis? previous;

  /// Works in parallel with the input before it (same station).
  final bool parallel;
}

/// A buffer (intermediate storage) before a station.
class LineBuffer {
  const LineBuffer({
    required this.capacity,
    required this.storeMicros,
    required this.retrieveMicros,
  });

  final int capacity;
  final int storeMicros;
  final int retrieveMicros;
}

/// A conveyor before a station: parts that can jam on it and the time a
/// part needs from the station before.
class LineConveyor {
  const LineConveyor({required this.capacity, required this.transportMicros});

  final int capacity;
  final int transportMicros;
}

/// Part of a station bar: one step (or the whole cycle without steps).
class LineSegment {
  const LineSegment(this.name, this.micros);

  final String name;
  final double micros;
}

/// A machine of a station.
class LineMachine {
  const LineMachine({
    required this.name,
    required this.mode,
    required this.cycleTime,
    required this.previousCycleTime,
    this.baseCycleTime,
    this.specialCycles = const [],
  });

  final String name;
  final StudyMode mode;

  /// Effective cycle time (µs) including the [specialCycles]; null without
  /// complete cycles (or step timer).
  final double? cycleTime;
  final double? previousCycleTime;

  /// Measured real cycle time without special cycles.
  final double? baseCycleTime;
  final List<SpecialCycle> specialCycles;

  bool get measured => cycleTime != null;
}

/// A station of the line: one machine, several machines working in
/// parallel whose capacities add up, or a loader cell ([cell]).
class LineStation {
  const LineStation({
    required this.name,
    required this.position,
    required this.mode,
    required this.machines,
    required this.cycleTime,
    required this.leadTime,
    required this.previousCycleTime,
    required this.share,
    required this.idle,
    required this.segments,
    required this.isBottleneck,
    this.bufferBefore,
    this.conveyorBefore,
    this.cell,
  });

  /// The loader cell this station is: machines served by loaders. The cell
  /// then counts as one machine ([machines] has one entry with the cell
  /// cycle time), so failure risk, simulation and reports treat it as one.
  final LoaderCell? cell;

  bool get isCell => cell != null;

  /// Conveyor between the previous station and this one.
  final LineConveyor? conveyorBefore;

  /// Buffer between the previous station and this one.
  final LineBuffer? bufferBefore;

  /// Machine name, or the names of the parallel machines.
  final String name;

  /// 0-based place of the station in the line.
  final int position;

  /// Mode of the first machine.
  final StudyMode mode;
  final List<LineMachine> machines;

  /// Effective cycle time (µs): 1 / Σ(1 / machine cycle time) over the
  /// measured machines; null if none is measured.
  final double? cycleTime;

  /// Time one part spends in the station (mean machine cycle time, µs).
  final double? leadTime;

  /// Effective cycle time of the previous revisions; null unless every
  /// measured machine has one.
  final double? previousCycleTime;

  /// Share of the sum of all station cycle times (0..1).
  final double share;

  /// Waiting time per cycle compared with the bottleneck (µs).
  final double? idle;

  /// Step times scaled so that they add up to [cycleTime] (parallel
  /// stations: one segment).
  final List<LineSegment> segments;
  final bool isBottleneck;

  bool get measured => cycleTime != null;

  bool get isParallel => machines.length > 1;

  List<LineMachine> get measuredMachines => [
    for (final m in machines)
      if (m.measured) m,
  ];
}

/// Effective cycle time of machines working in parallel (µs).
double? parallelCycleTime(Iterable<double> times) {
  final rate = times.fold<double>(0, (a, t) => a + 1 / t);
  return rate == 0 ? null : 1 / rate;
}

/// The studies of a group looked at as one line (stations in group order).
///
/// - [totalTime]: sum of the (effective) station cycle times.
/// - [leadTime]: time one part needs through the line (one machine per
///   station, no buffers or transport).
/// - [lineCycleTime]: the slowest station (bottleneck) paces the line.
/// - [balance]: total / (stations × bottleneck), 1 = perfectly balanced.
/// - [outputPerHour]: parts per hour at the bottleneck pace.
class LineAnalysis {
  const LineAnalysis({
    required this.stations,
    required this.totalTime,
    required this.leadTime,
    required this.lineCycleTime,
    required this.previousTotalTime,
    required this.previousLineCycleTime,
  });

  factory LineAnalysis.of(List<LineStationInput> inputs) {
    // A cycle time below one microsecond is no measurement (the line would
    // have no pace and the simulation could never finish a part).
    double? cycle(StudyAnalysis? a, StudyMode mode) =>
        a == null ||
            mode == StudyMode.stepTimer ||
            a.cycleStats.n == 0 ||
            a.realCycleTime < 1
        ? null
        : a.realCycleTime;
    double? effective(double? base, List<SpecialCycle> cycles) =>
        base == null || cycles.isEmpty
        ? base
        : effectiveCycleTime(base, cycles);
    // The time a resource of a loader cell needs per own cycle: waiting
    // steps left out, special cycles included.
    double? work(StudyAnalysis? a, LineStationInput i) => effective(
      a == null ||
              i.mode == StudyMode.stepTimer ||
              a.cycleStats.n == 0 ||
              a.workCycleTime < 1
          ? null
          : a.workCycleTime,
      i.specialCycles,
    );
    final groups = stationGroups([for (final i in inputs) i.parallel]);
    bool isLoader(List<int> group, int k) =>
        k != group.first && inputs[k].cellLoader;
    LoaderCell cellOf(
      List<int> group,
      StudyAnalysis? Function(LineStationInput) pick,
    ) => LoaderCell.of(
      machines: [
        for (final k in group)
          if (!isLoader(group, k))
            CellMachine(
              name: inputs[k].name,
              workMicros: work(pick(inputs[k]), inputs[k]),
              count: inputs[k].cellMachines,
            ),
      ],
      loaders: [
        for (final k in group)
          if (isLoader(group, k))
            CellLoader(
              name: inputs[k].name,
              workMicros: work(pick(inputs[k]), inputs[k]),
              partsPerCycle: inputs[k].cellParts,
            ),
      ],
    );
    final cells = [
      for (final group in groups)
        group.any((k) => isLoader(group, k))
            ? cellOf(group, (i) => i.current)
            : null,
    ];
    // Cell time of the previous revisions; only when every resource
    // measured now has one.
    double? previousCell(List<int> group) =>
        group.any(
          (k) =>
              work(inputs[k].current, inputs[k]) != null &&
              work(inputs[k].previous, inputs[k]) == null,
        )
        ? null
        : cellOf(group, (i) => i.previous).cycleTime;
    final machines = [
      for (var g = 0; g < groups.length; g++)
        if (cells[g] != null)
          [
            LineMachine(
              name: [
                for (final k in groups[g])
                  if (!isLoader(groups[g], k)) inputs[k].name,
              ].join(' / '),
              mode: inputs[groups[g].first].mode,
              cycleTime: cells[g]!.cycleTime,
              previousCycleTime: previousCell(groups[g]),
              baseCycleTime: cells[g]!.cycleTime,
            ),
          ]
        else
          [
            for (final k in groups[g])
              LineMachine(
                name: inputs[k].name,
                mode: inputs[k].mode,
                cycleTime: effective(
                  cycle(inputs[k].current, inputs[k].mode),
                  inputs[k].specialCycles,
                ),
                previousCycleTime: effective(
                  cycle(inputs[k].previous, inputs[k].mode),
                  inputs[k].specialCycles,
                ),
                baseCycleTime: cycle(inputs[k].current, inputs[k].mode),
                specialCycles: inputs[k].specialCycles,
              ),
          ],
    ];
    final times = [
      for (final ms in machines)
        parallelCycleTime([for (final m in ms) ?m.cycleTime]),
    ];
    final previous = [
      for (final ms in machines)
        ms.any((m) => m.measured && m.previousCycleTime == null)
            ? null
            : parallelCycleTime([
                for (final m in ms)
                  if (m.measured) m.previousCycleTime!,
              ]),
    ];
    final measured = [for (final t in times) ?t];
    final total = measured.fold<double>(0, (a, b) => a + b);
    final max = measured.isEmpty
        ? null
        : measured.reduce((a, b) => a > b ? a : b);
    final bottleneck = max == null ? -1 : times.indexOf(max);
    final comparable =
        measured.isNotEmpty &&
        [
          for (var k = 0; k < groups.length; k++)
            if (times[k] != null) previous[k],
        ].every((p) => p != null);
    final prevTimes = [
      for (var k = 0; k < groups.length; k++)
        if (times[k] != null && previous[k] != null) previous[k]!,
    ];
    double? lead(List<LineMachine> ms) {
      final t = [for (final m in ms) ?m.cycleTime];
      return t.isEmpty ? null : t.reduce((a, b) => a + b) / t.length;
    }

    final stations = [
      for (var k = 0; k < groups.length; k++)
        LineStation(
          name: machines[k].map((m) => m.name).join(' / '),
          position: k,
          mode: machines[k].first.mode,
          machines: machines[k],
          cycleTime: times[k],
          leadTime: cells[k] == null
              ? lead(machines[k])
              : (times[k] == null ? null : cells[k]!.machineTime),
          cell: cells[k],
          previousCycleTime: previous[k],
          share: times[k] == null || total == 0 ? 0 : times[k]! / total,
          idle: times[k] == null ? null : max! - times[k]!,
          segments: cells[k] != null
              ? [
                  if (times[k] != null)
                    LineSegment(machines[k].single.name, times[k]!),
                ]
              : machines[k].length == 1
              ? _segments(inputs[groups[k].single], times[k])
              : times[k] == null
              ? const []
              : [LineSegment(machines[k].first.name, times[k]!)],
          isBottleneck: k == bottleneck,
          bufferBefore: k == 0 ? null : inputs[groups[k].first].buffer,
          conveyorBefore: k == 0 ? null : inputs[groups[k].first].conveyor,
        ),
    ];
    return LineAnalysis(
      stations: stations,
      totalTime: total,
      // One part: its machine in every station plus the transport times.
      leadTime: [
        for (final s in stations) ...[
          ?s.leadTime,
          if (s.conveyorBefore != null) s.conveyorBefore!.transportMicros,
        ],
      ].fold<double>(0, (a, b) => a + b),
      lineCycleTime: max,
      previousTotalTime: comparable
          ? prevTimes.fold<double>(0, (a, b) => a + b)
          : null,
      previousLineCycleTime: comparable
          ? prevTimes.reduce((a, b) => a > b ? a : b)
          : null,
    );
  }

  static List<LineSegment> _segments(LineStationInput i, double? cycle) {
    if (cycle == null) return const [];
    final steps = [
      for (final st in i.current.steps)
        if (st.stats.n > 0 && st.realTime > 0) st,
    ];
    final sum = steps.fold<double>(0, (a, st) => a + st.realTime);
    if (steps.isEmpty || sum == 0) return [LineSegment(i.name, cycle)];
    return [
      for (final st in steps)
        LineSegment(st.step.name, st.realTime * cycle / sum),
    ];
  }

  final List<LineStation> stations;
  final double totalTime;
  final double leadTime;
  final double? lineCycleTime;
  final double? previousTotalTime;
  final double? previousLineCycleTime;

  int get measuredCount => stations.where((s) => s.measured).length;

  LineStation? get bottleneck {
    for (final s in stations) {
      if (s.isBottleneck) return s;
    }
    return null;
  }

  double? get balance => lineCycleTime == null || lineCycleTime == 0
      ? null
      : totalTime / (measuredCount * lineCycleTime!);

  double? get outputPerHour => lineCycleTime == null || lineCycleTime == 0
      ? null
      : 3600 * 1000000 / lineCycleTime!;

  double? get totalDelta =>
      previousTotalTime == null ? null : totalTime - previousTotalTime!;

  double? get totalDeltaRatio => totalDelta == null || previousTotalTime == 0
      ? null
      : totalDelta! / previousTotalTime!;

  double? get lineCycleDelta =>
      previousLineCycleTime == null || lineCycleTime == null
      ? null
      : lineCycleTime! - previousLineCycleTime!;
}

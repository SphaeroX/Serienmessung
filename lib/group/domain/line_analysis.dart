import '../../analysis/domain/analysis.dart';
import '../../study/domain/study.dart';

/// One study of a group as a station of the line.
class LineStationInput {
  const LineStationInput({
    required this.name,
    required this.mode,
    required this.current,
    this.previous,
  });

  final String name;
  final StudyMode mode;
  final StudyAnalysis current;

  /// Analysis of the most recently archived revision (optional).
  final StudyAnalysis? previous;
}

/// Part of a station bar: one step (or the whole cycle without steps).
class LineSegment {
  const LineSegment(this.name, this.micros);

  final String name;
  final double micros;
}

/// A station with its figures relative to the whole line.
class LineStation {
  const LineStation({
    required this.name,
    required this.position,
    required this.mode,
    required this.cycleTime,
    required this.previousCycleTime,
    required this.share,
    required this.idle,
    required this.segments,
    required this.isBottleneck,
  });

  final String name;

  /// 0-based place in the group.
  final int position;
  final StudyMode mode;

  /// Real cycle time (µs); null without complete cycles (or step timer).
  final double? cycleTime;
  final double? previousCycleTime;

  /// Share of the sum of all station cycle times (0..1).
  final double share;

  /// Waiting time per cycle compared with the bottleneck (µs).
  final double? idle;

  /// Step times scaled so that they add up to [cycleTime].
  final List<LineSegment> segments;
  final bool isBottleneck;

  bool get measured => cycleTime != null;
}

/// The studies of a group looked at as one line (stations in group order).
///
/// - [totalTime]: sum of the station cycle times = processing time of one
///   part through the line (no buffers or transport).
/// - [lineCycleTime]: the slowest station (bottleneck) paces the line.
/// - [balance]: total / (stations × bottleneck), 1 = perfectly balanced.
/// - [outputPerHour]: parts per hour at the bottleneck pace.
class LineAnalysis {
  const LineAnalysis({
    required this.stations,
    required this.totalTime,
    required this.lineCycleTime,
    required this.previousTotalTime,
    required this.previousLineCycleTime,
  });

  factory LineAnalysis.of(List<LineStationInput> inputs) {
    double? cycle(StudyAnalysis? a, StudyMode mode) =>
        a == null || mode == StudyMode.stepTimer || a.cycleStats.n == 0
        ? null
        : a.realCycleTime;
    final times = [for (final i in inputs) cycle(i.current, i.mode)];
    final previous = [for (final i in inputs) cycle(i.previous, i.mode)];
    final measured = [for (final t in times) ?t];
    final total = measured.fold<double>(0, (a, b) => a + b);
    final max = measured.isEmpty
        ? null
        : measured.reduce((a, b) => a > b ? a : b);
    final bottleneck = max == null ? -1 : times.indexOf(max);
    final comparable =
        measured.isNotEmpty &&
        [
          for (var k = 0; k < inputs.length; k++)
            if (times[k] != null) previous[k],
        ].every((p) => p != null);
    final prevTimes = [
      for (var k = 0; k < inputs.length; k++)
        if (times[k] != null && previous[k] != null) previous[k]!,
    ];
    return LineAnalysis(
      stations: [
        for (var k = 0; k < inputs.length; k++)
          LineStation(
            name: inputs[k].name,
            position: k,
            mode: inputs[k].mode,
            cycleTime: times[k],
            previousCycleTime: previous[k],
            share: times[k] == null || total == 0 ? 0 : times[k]! / total,
            idle: times[k] == null ? null : max! - times[k]!,
            segments: _segments(inputs[k], times[k]),
            isBottleneck: k == bottleneck,
          ),
      ],
      totalTime: total,
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

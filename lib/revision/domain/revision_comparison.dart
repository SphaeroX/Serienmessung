import '../../analysis/domain/analysis.dart';

/// Deviation of one step between an earlier revision and now.
class StepDeviation {
  const StepDeviation({
    required this.name,
    required this.position,
    required this.previous,
    required this.current,
  });

  /// Current name (or the old one for steps that no longer exist).
  final String name;

  /// 0-based position in the current steps; null for removed steps.
  final int? position;

  /// Real step time (µs) then and now; null if the step had no times.
  final double? previous;
  final double? current;

  double? get delta =>
      previous == null || current == null ? null : current! - previous!;

  /// Relative change (0.1 = 10 % longer); null without both values.
  double? get deltaRatio =>
      delta == null || previous == 0 ? null : delta! / previous!;
}

/// Compares two analyses of the same study (an archived revision and the
/// current measurement). Steps are matched by id, else by name (trimmed,
/// case-insensitive); unmatched steps keep only one side.
class RevisionComparison {
  const RevisionComparison({
    required this.previousCycleTime,
    required this.currentCycleTime,
    required this.steps,
  });

  factory RevisionComparison.compare({
    required StudyAnalysis previous,
    required StudyAnalysis current,
  }) {
    String key(String name) => name.trim().toLowerCase();
    double? real(StepAnalysis s) => s.stats.n == 0 ? null : s.realTime;
    final unmatched = [...previous.steps];
    StepAnalysis? take(bool Function(StepAnalysis) test) {
      final i = unmatched.indexWhere(test);
      return i < 0 ? null : unmatched.removeAt(i);
    }

    final byId = {
      for (final s in current.steps)
        s.step.id: take((p) => p.step.id == s.step.id),
    };
    final rows = <StepDeviation>[
      for (final s in current.steps)
        () {
          final old =
              byId[s.step.id] ??
              take((p) => key(p.step.name) == key(s.step.name));
          return StepDeviation(
            name: s.step.name,
            position: s.step.position,
            previous: old == null ? null : real(old),
            current: real(s),
          );
        }(),
      for (final p in unmatched)
        StepDeviation(
          name: p.step.name,
          position: null,
          previous: real(p),
          current: null,
        ),
    ];
    return RevisionComparison(
      previousCycleTime: previous.cycleStats.n == 0
          ? null
          : previous.realCycleTime,
      currentCycleTime: current.cycleStats.n == 0
          ? null
          : current.realCycleTime,
      steps: rows,
    );
  }

  /// Real cycle time (µs) then and now; null without complete cycles.
  final double? previousCycleTime;
  final double? currentCycleTime;
  final List<StepDeviation> steps;

  double? get cycleDelta =>
      previousCycleTime == null || currentCycleTime == null
      ? null
      : currentCycleTime! - previousCycleTime!;

  double? get cycleDeltaRatio => cycleDelta == null || previousCycleTime == 0
      ? null
      : cycleDelta! / previousCycleTime!;
}

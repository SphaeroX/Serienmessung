import '../../recording/domain/cycles.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import 'statistics.dart';

/// Figures for one step definition.
class StepAnalysis {
  const StepAnalysis({
    required this.step,
    required this.stats,
    required this.realTime,
    required this.share,
  });

  final StepDefinition step;

  /// Statistics of all completed times of this step (µs).
  final Stats stats;

  /// Step time by the selected method (µs).
  final double realTime;

  /// Share of the total step time (0..1).
  final double share;
}

/// Complete evaluation of a study. Special times are always excluded from
/// step and cycle times and reported separately.
class StudyAnalysis {
  const StudyAnalysis({
    required this.method,
    required this.cycleTotals,
    required this.cycleStats,
    required this.realCycleTime,
    required this.removedCycles,
    required this.steps,
    required this.specialTotal,
    required this.specialCount,
    required this.incompleteCycles,
  });

  factory StudyAnalysis.compute({
    required List<Measurement> measurements,
    required List<StepDefinition> steps,
    required StudyMode mode,
    required CycleTimeMethod method,
  }) {
    final normals = measurements
        .where((m) => m.kind == MeasurementKind.normal)
        .toList();
    final specials = measurements
        .where((m) => m.kind == MeasurementKind.special)
        .toList();

    // Cycle times: complete cycles only. The step timer has no cycles.
    var totals = <int>[];
    var incomplete = 0;
    if (mode != StudyMode.stepTimer) {
      final groups = groupCycles(
        measurements,
        stepIds: mode.usesSteps ? steps.map((s) => s.id).toList() : const [],
      );
      for (final g in groups) {
        if (g.isComplete) {
          totals.add(g.normalTotal);
        } else {
          incomplete++;
        }
      }
    }

    final allStepTime = normals.fold<int>(0, (a, m) => a + m.durationMicros);
    final stepFigures = <StepAnalysis>[
      for (final step in steps)
        () {
          final times = normals
              .where((m) => m.stepId == step.id)
              .map((m) => m.durationMicros)
              .toList();
          final sum = times.fold<int>(0, (a, b) => a + b);
          return StepAnalysis(
            step: step,
            stats: Stats.of(times),
            realTime: method.apply(times),
            share: allStepTime == 0 ? 0 : sum / allStepTime,
          );
        }(),
    ];

    final removed = method == CycleTimeMethod.iqr
        ? iqrFilter(totals).removed.length
        : 0;
    return StudyAnalysis(
      method: method,
      cycleTotals: totals,
      cycleStats: Stats.of(totals),
      realCycleTime: method.apply(totals),
      removedCycles: removed,
      steps: stepFigures,
      specialTotal: specials.fold(0, (a, m) => a + m.durationMicros),
      specialCount: specials.length,
      incompleteCycles: incomplete,
    );
  }

  final CycleTimeMethod method;

  /// Times of the complete cycles (µs), chronological.
  final List<int> cycleTotals;
  final Stats cycleStats;

  /// The real cycle time by [method] (µs).
  final double realCycleTime;

  /// Cycles dropped as outliers (IQR method only).
  final int removedCycles;
  final List<StepAnalysis> steps;
  final int specialTotal;
  final int specialCount;
  final int incompleteCycles;
}

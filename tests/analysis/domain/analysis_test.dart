import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;
var _id = 0;

Measurement m(int cycle, int? step, num seconds, {bool special = false}) {
  _id++;
  return Measurement(
    id: _id,
    studyId: 1,
    cycle: cycle,
    stepId: step,
    kind: special ? MeasurementKind.special : MeasurementKind.normal,
    startMicros: _id * 100 * s,
    endMicros: _id * 100 * s + (seconds * s).round(),
    durationMicros: (seconds * s).round(),
  );
}

const steps = [
  StepDefinition(id: 1, studyId: 1, position: 0, name: 'A'),
  StepDefinition(id: 2, studyId: 1, position: 1, name: 'B'),
];

void main() {
  // Cycle totals: 10, 11, 12, 13, 40 s (cycle 5 has a disturbance).
  final data = [
    m(1, 1, 4), m(1, 2, 6),
    m(2, 1, 5), m(2, 2, 6),
    m(3, 1, 5), m(3, 2, 7),
    m(4, 1, 6), m(4, 2, 7),
    m(5, 1, 30), m(5, 2, 10),
    m(6, 1, 5), // incomplete
    m(2, 1, 99, special: true),
  ];

  StudyAnalysis run(CycleTimeMethod method) => StudyAnalysis.compute(
    measurements: data,
    steps: steps,
    mode: StudyMode.timeStudy,
    method: method,
  );

  test('cycle statistics use complete cycles only', () {
    final a = run(CycleTimeMethod.mean);
    expect(a.cycleStats.n, 5);
    expect(a.cycleStats.mean, closeTo(17.2 * s, 1));
    expect(a.cycleStats.median, 12 * s);
  });

  test('real cycle time follows the selected method', () {
    expect(run(CycleTimeMethod.mean).realCycleTime, closeTo(17.2 * s, 1));
    expect(run(CycleTimeMethod.median).realCycleTime, 12 * s);
    final iqr = run(CycleTimeMethod.iqr);
    expect(iqr.realCycleTime, 11.5 * s);
    expect(iqr.removedCycles, 1);
  });

  test('special times never change step or cycle times', () {
    final a = run(CycleTimeMethod.mean);
    expect(a.specialTotal, 99 * s);
    expect(a.specialCount, 1);
    final stepA = a.steps.first;
    expect(stepA.step.name, 'A');
    // Step A times: 4,5,5,6,30 plus 5 from the incomplete cycle 6.
    expect(stepA.stats.n, 6);
    expect(stepA.stats.median, 5 * s);
  });

  test('per-step real time uses the same method', () {
    final a = run(CycleTimeMethod.iqr);
    // Step A: [4,5,5,5,6,30] → 30 is an outlier; mean of rest = 5.
    expect(a.steps.first.realTime, 5 * s);
  });

  test('simple mode: every lap is a cycle', () {
    final a = StudyAnalysis.compute(
      measurements: [m(1, null, 2), m(2, null, 4)],
      steps: const [],
      mode: StudyMode.simple,
      method: CycleTimeMethod.mean,
    );
    expect(a.cycleStats.n, 2);
    expect(a.realCycleTime, 3 * s);
  });

  test('step timer: share of total per step', () {
    final a = StudyAnalysis.compute(
      measurements: [m(0, 1, 3), m(0, 2, 1), m(0, 1, 4)],
      steps: steps,
      mode: StudyMode.stepTimer,
      method: CycleTimeMethod.mean,
    );
    expect(a.steps.map((x) => x.share), [0.875, 0.125]);
    expect(a.cycleStats.n, 0);
  });
}

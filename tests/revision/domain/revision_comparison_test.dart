import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/revision/domain/revision_comparison.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StepDefinition step(int id, int pos, String name) =>
      StepDefinition(id: id, studyId: 1, position: pos, name: name);

  var nextId = 1;
  Measurement time(int cycle, int stepId, int micros) => Measurement(
    id: nextId++,
    studyId: 1,
    cycle: cycle,
    stepId: stepId,
    kind: MeasurementKind.normal,
    startMicros: 0,
    endMicros: micros,
    durationMicros: micros,
  );

  StudyAnalysis analyse(List<StepDefinition> steps, List<Measurement> ms) =>
      StudyAnalysis.compute(
        measurements: ms,
        steps: steps,
        mode: StudyMode.timeStudy,
        method: CycleTimeMethod.mean,
      );

  test('deviation per step and for the cycle time', () {
    final steps = [step(1, 0, 'Load'), step(2, 1, 'Cut')];
    final before = analyse(steps, [time(1, 1, 10), time(1, 2, 30)]);
    final now = analyse(steps, [time(1, 1, 15), time(1, 2, 27)]);

    final c = RevisionComparison.compare(previous: before, current: now);

    expect(c.previousCycleTime, 40);
    expect(c.currentCycleTime, 42);
    expect(c.cycleDelta, 2);
    expect(c.cycleDeltaRatio, closeTo(0.05, 1e-9));
    expect(c.steps.map((s) => (s.name, s.previous, s.current, s.delta)), [
      ('Load', 10, 15, 5),
      ('Cut', 30, 27, -3),
    ]);
    expect(c.steps.first.deltaRatio, closeTo(0.5, 1e-9));
  });

  test('steps match by id first, then by name; the rest stays one-sided', () {
    final old = [step(1, 0, 'Load'), step(2, 1, 'Cut'), step(3, 2, 'Drop')];
    final cur = [
      step(1, 0, 'Load part'),
      step(9, 1, 'cut '),
      step(8, 2, 'New'),
    ];
    final before = analyse(old, [
      time(1, 1, 10),
      time(1, 2, 30),
      time(1, 3, 5),
    ]);
    final now = analyse(cur, [time(1, 1, 12), time(1, 9, 31), time(1, 8, 7)]);

    final c = RevisionComparison.compare(previous: before, current: now);

    expect(c.steps.map((s) => (s.name, s.previous, s.current)), [
      ('Load part', 10, 12),
      ('cut ', 30, 31),
      ('New', null, 7),
      ('Drop', 5, null),
    ]);
    expect(c.steps[2].delta, isNull);
    expect(c.steps[2].position, 2);
    expect(c.steps[3].position, isNull);
  });

  test('without complete cycles there is no cycle deviation', () {
    final steps = [step(1, 0, 'Load'), step(2, 1, 'Cut')];
    final before = analyse(steps, [time(1, 1, 10)]);
    final now = analyse(steps, [time(1, 1, 12), time(1, 2, 3)]);
    final c = RevisionComparison.compare(previous: before, current: now);
    expect(c.previousCycleTime, isNull);
    expect(c.currentCycleTime, 15);
    expect(c.cycleDelta, isNull);
    expect(c.cycleDeltaRatio, isNull);
  });
}

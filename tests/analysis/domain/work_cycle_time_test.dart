import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

var _id = 0;

Measurement time(int cycle, int stepId, int seconds) => Measurement(
  id: ++_id,
  studyId: 1,
  cycle: cycle,
  stepId: stepId,
  kind: MeasurementKind.normal,
  startMicros: _id * 100 * s,
  endMicros: _id * 100 * s + seconds * s,
  durationMicros: seconds * s,
);

StepDefinition step(int id, String name, {bool waiting = false}) =>
    StepDefinition(
      id: id,
      studyId: 1,
      position: id - 1,
      name: name,
      waiting: waiting,
    );

void main() {
  group('work cycle time', () {
    test('leaves out the steps marked as waiting', () {
      final a = StudyAnalysis.compute(
        measurements: [
          time(1, 1, 10),
          time(1, 2, 5),
          time(1, 3, 20),
          time(2, 1, 10),
          time(2, 2, 9),
          time(2, 3, 20),
        ],
        steps: [
          step(1, 'Change'),
          step(2, 'Wait for machine', waiting: true),
          step(3, 'Drive'),
        ],
        mode: StudyMode.timeStudy,
        method: CycleTimeMethod.median,
      );
      expect(a.realCycleTime, 37 * s);
      expect(a.workCycleTime, 30 * s);
    });

    test('equals the real cycle time without waiting steps', () {
      final a = StudyAnalysis.compute(
        measurements: [time(1, 1, 10), time(1, 2, 5)],
        steps: [step(1, 'A'), step(2, 'B')],
        mode: StudyMode.timeStudy,
        method: CycleTimeMethod.mean,
      );
      expect(a.workCycleTime, a.realCycleTime);
      expect(a.workCycleTime, 15 * s);
    });

    test('waiting steps can be given for archived steps by id', () {
      final a = StudyAnalysis.compute(
        measurements: [time(1, 1, 10), time(1, 2, 5)],
        steps: [step(1, 'A'), step(2, 'B')],
        mode: StudyMode.timeStudy,
        method: CycleTimeMethod.mean,
        waitingStepIds: {2},
      );
      expect(a.realCycleTime, 15 * s);
      expect(a.workCycleTime, 10 * s);
    });

    test('incomplete cycles do not count', () {
      final a = StudyAnalysis.compute(
        measurements: [time(1, 1, 10), time(1, 2, 5), time(2, 1, 50)],
        steps: [step(1, 'A'), step(2, 'W', waiting: true)],
        mode: StudyMode.timeStudy,
        method: CycleTimeMethod.mean,
      );
      expect(a.workCycleTime, 10 * s);
    });
  });
}

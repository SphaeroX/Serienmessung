import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/group/domain/failure_risk.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

/// Machine (simple study) with one lap of [micros].
LineStationInput machine(String name, int micros) => LineStationInput(
  name: name,
  mode: StudyMode.simple,
  current: StudyAnalysis.compute(
    measurements: [
      Measurement(
        id: 1,
        studyId: 1,
        cycle: 1,
        stepId: null,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: micros,
        durationMicros: micros,
      ),
    ],
    steps: const [],
    mode: StudyMode.simple,
    method: CycleTimeMethod.median,
  ),
);

void main() {
  test('a machine with a cycle time of zero counts as not measured', () {
    final line = LineAnalysis.of([machine('A', 10 * s), machine('B', 0)]);
    expect(line.stations[1].measured, isFalse);
    expect(line.measuredCount, 1);
    expect(line.lineCycleTime, 10.0 * s);
    expect(line.outputPerHour, 360);
    expect(FailureRisk.of(line).failures.single.machine, 'A');
    // The simulation only gets machines that take time.
    final sim = LineSimulation.fromLine(line);
    expect(sim.stations.single.name, 'A');
    expect(sim.run(horizonMicros: 100 * s).output, 10);
  });

  test('the simulation refuses machines that take no time', () {
    const sim = LineSimulation([
      SimStation(
        name: 'A',
        machines: [SimMachine(name: 'A', cycleMicros: 0)],
      ),
    ]);
    expect(() => sim.run(horizonMicros: 10 * s), throwsArgumentError);
  });
}

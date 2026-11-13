import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;
const hour = 3600 * s;

SpecialCycle parts(int every, int seconds) => SpecialCycle(
  id: 0,
  studyId: 1,
  name: 'Measure',
  kind: SpecialCycleKind.parts,
  interval: every,
  durationMicros: seconds * s,
);

SpecialCycle stop(int everyHours, int seconds) => SpecialCycle(
  id: 0,
  studyId: 1,
  name: 'Tool change',
  kind: SpecialCycleKind.time,
  interval: everyHours * hour,
  durationMicros: seconds * s,
);

void main() {
  group('effective cycle time', () {
    test('a special cycle every N parts adds its share', () {
      expect(
        effectiveCycleTime(40.0 * s, [parts(50, 120)]),
        closeTo(42.4 * s, 1),
      );
    });

    test('a planned stop lowers the availability', () {
      expect(availability([stop(24, 300)]), closeTo(1 - 300 / 86400, 1e-12));
      expect(
        effectiveCycleTime(40.0 * s, [stop(24, 300)]),
        closeTo(40.0 * s / (1 - 300 / 86400), 1),
      );
    });

    test('both together, and nothing without rules', () {
      expect(
        effectiveCycleTime(40.0 * s, [parts(50, 120), stop(24, 300)]),
        closeTo(42.4 * s / (1 - 300 / 86400), 1),
      );
      expect(effectiveCycleTime(40.0 * s, const []), 40.0 * s);
    });
  });

  group('line analysis', () {
    var id = 0;
    StudyAnalysis lap(int seconds) => StudyAnalysis.compute(
      measurements: [
        Measurement(
          id: ++id,
          studyId: 1,
          cycle: 1,
          stepId: null,
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: seconds * s,
          durationMicros: seconds * s,
        ),
      ],
      steps: const [],
      mode: StudyMode.simple,
      method: CycleTimeMethod.median,
    );

    test('machines count with their effective cycle time', () {
      final line = LineAnalysis.of([
        LineStationInput(name: 'Saw', mode: StudyMode.simple, current: lap(41)),
        LineStationInput(
          name: 'Press',
          mode: StudyMode.simple,
          current: lap(40),
          specialCycles: [parts(50, 120)],
        ),
      ]);
      final press = line.stations[1].machines.single;
      expect(press.baseCycleTime, 40 * s);
      expect(press.cycleTime, closeTo(42.4 * s, 1));
      expect(press.specialCycles, hasLength(1));
      // With the special cycles the press is the bottleneck.
      expect(line.bottleneck!.name, 'Press');
      final sim = LineSimulation.fromLine(line);
      expect(sim.stations[1].machines.single.cycleMicros, 40 * s);
      expect(sim.stations[1].machines.single.specialCycles, hasLength(1));
    });
  });

  group('simulation', () {
    SimResult run(SimMachine machine, int seconds) => LineSimulation([
      SimStation(name: machine.name, machines: [machine]),
    ]).run(horizonMicros: seconds * s);

    test('every N-th part takes the extra time', () {
      final r = run(
        SimMachine(
          name: 'A',
          cycleMicros: 10 * s,
          specialCycles: [parts(5, 10)],
        ),
        100,
      );
      // 10, 20, 30, 40, 60 (fifth part 20 s), 70, 80, 90, 100.
      expect(r.output, 9);
    });

    test('a planned stop first comes after half its interval', () {
      final machine = SimMachine(
        name: 'A',
        cycleMicros: 10 * s,
        specialCycles: [
          SpecialCycle(
            id: 0,
            studyId: 1,
            name: 'Tool change',
            kind: SpecialCycleKind.time,
            interval: 200 * s,
            durationMicros: 30 * s,
          ),
        ],
      );
      final r = run(machine, 200);
      // Stop from 100 to 130: 10 parts before, then 140 ... 200.
      expect(r.output, 17);
      expect(r.stations.single.downMicros, 30 * s);
    });
  });
}

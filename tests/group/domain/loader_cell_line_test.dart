import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/group/domain/failure_risk.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

var _id = 0;

Measurement _time(int cycle, int? stepId, double seconds) => Measurement(
  id: ++_id,
  studyId: 1,
  cycle: cycle,
  stepId: stepId,
  kind: MeasurementKind.normal,
  startMicros: 0,
  endMicros: (seconds * s).round(),
  durationMicros: (seconds * s).round(),
);

/// A resource measured as a simple study: one lap of [seconds].
StudyAnalysis lap(double seconds) => StudyAnalysis.compute(
  measurements: [_time(1, null, seconds)],
  steps: const [],
  mode: StudyMode.simple,
  method: CycleTimeMethod.median,
);

/// A time study with a work step and a step marked as waiting.
StudyAnalysis withWaiting(double work, double waiting) => StudyAnalysis.compute(
  measurements: [_time(1, 1, work), _time(1, 2, waiting)],
  steps: const [
    StepDefinition(id: 1, studyId: 1, position: 0, name: 'Work'),
    StepDefinition(id: 2, studyId: 1, position: 1, name: 'Wait', waiting: true),
  ],
  mode: StudyMode.timeStudy,
  method: CycleTimeMethod.median,
);

final empty = StudyAnalysis.compute(
  measurements: const [],
  steps: const [],
  mode: StudyMode.simple,
  method: CycleTimeMethod.median,
);

LineStationInput m(
  String name,
  double seconds, {
  int machines = 1,
  double? previous,
  List<SpecialCycle> specialCycles = const [],
}) => LineStationInput(
  name: name,
  mode: StudyMode.simple,
  current: lap(seconds),
  previous: previous == null ? null : lap(previous),
  cellMachines: machines,
  specialCycles: specialCycles,
);

LineStationInput loader(
  String name,
  double? seconds, {
  int parts = 1,
  double? previous,
}) => LineStationInput(
  name: name,
  mode: StudyMode.simple,
  current: seconds == null ? empty : lap(seconds),
  previous: previous == null ? null : lap(previous),
  parallel: true,
  cellLoader: true,
  cellParts: parts,
);

/// Saw, the cell of the roadmap example with [machines] machines, packing.
LineAnalysis example(int machines) => LineAnalysis.of([
  m('Saw', 12),
  m('Machine', 88, machines: machines),
  loader('Loader 1', 32),
  loader('Loader 2', 20),
  loader('Loader 3', 15),
  m('Packing', 20),
]);

void main() {
  group('line with a loader cell', () {
    test('the cell is one station with its cell cycle time', () {
      final line = example(3);
      expect(line.stations, hasLength(3));
      final cell = line.stations[1];
      expect(cell.isCell, isTrue);
      expect(cell.isParallel, isFalse);
      expect(cell.name, 'Machine');
      expect(cell.cycleTime, closeTo(32 * s, 1));
      // One part occupies its machine for 88 s.
      expect(cell.leadTime, closeTo(88 * s, 1));
      expect(cell.cell!.bottleneck.single.name, 'Loader 1');
      expect(cell.cell!.bestMachineCount, 3);
      expect(cell.isBottleneck, isTrue);
      expect(line.lineCycleTime, closeTo(32 * s, 1));
      expect(line.totalTime, closeTo(64 * s, 1));
      expect(line.leadTime, closeTo(120 * s, 1));
      expect(line.stations[0].isCell, isFalse);
      expect(line.stations[0].cell, isNull);
    });

    test('fewer machines make the machines the bottleneck', () {
      final line = example(2);
      expect(line.stations[1].cycleTime, closeTo(44 * s, 1));
      expect(line.stations[1].cell!.machinesAreBottleneck, isTrue);
    });

    test('steps marked as waiting are left out of the work time', () {
      final line = LineAnalysis.of([
        LineStationInput(
          name: 'Machine',
          mode: StudyMode.timeStudy,
          current: withWaiting(88, 40),
          cellMachines: 4,
        ),
        LineStationInput(
          name: 'Loader',
          mode: StudyMode.timeStudy,
          current: withWaiting(32, 7),
          parallel: true,
          cellLoader: true,
        ),
      ]);
      final cell = line.stations.single.cell!;
      expect(cell.resources.map((r) => r.workMicros), [88.0 * s, 32.0 * s]);
      expect(line.stations.single.cycleTime, closeTo(32 * s, 1));
    });

    test('special cycles of the machine act on the machine time', () {
      final line = LineAnalysis.of([
        m(
          'Machine',
          88,
          specialCycles: const [
            SpecialCycle(
              id: 1,
              studyId: 1,
              name: 'Measure',
              kind: SpecialCycleKind.parts,
              interval: 10,
              durationMicros: 20 * s,
            ),
          ],
        ),
        loader('Loader', 32),
      ]);
      expect(line.stations.single.cycleTime, closeTo(90 * s, 1));
    });

    test('a loader handling two parts per cycle counts half', () {
      final line = LineAnalysis.of([
        m('Machine', 30, machines: 2),
        loader('L1', 30),
        loader('L2', 62, parts: 2),
      ]);
      expect(line.stations.single.cycleTime, closeTo(31 * s, 1));
    });

    test('a cell without a measured loader is not measured', () {
      final line = LineAnalysis.of([
        m('Saw', 12),
        m('Machine', 88),
        loader('Loader', null),
      ]);
      expect(line.stations[1].measured, isFalse);
      expect(line.stations[1].isCell, isTrue);
      expect(line.measuredCount, 1);
      expect(line.lineCycleTime, closeTo(12 * s, 1));
    });

    test('previous cell time only when every resource has one', () {
      final all = LineAnalysis.of([
        m('Machine', 88, machines: 3, previous: 99),
        loader('L1', 32, previous: 30),
        loader('L2', 20, previous: 25),
      ]);
      // max(99 / 3, 30, 25) = 33 s.
      expect(all.stations.single.previousCycleTime, closeTo(33 * s, 1));
      final some = LineAnalysis.of([
        m('Machine', 88, machines: 3, previous: 99),
        loader('L1', 32),
      ]);
      expect(some.stations.single.previousCycleTime, isNull);
    });

    test('a parallel member that is no loader is another machine', () {
      final line = LineAnalysis.of([
        m('A', 60),
        LineStationInput(
          name: 'B',
          mode: StudyMode.simple,
          current: lap(120),
          parallel: true,
          cellMachines: 2,
        ),
        loader('L1', 10),
      ]);
      final station = line.stations.single;
      expect(station.name, 'A / B');
      expect(station.cycleTime, closeTo(30 * s, 1));
    });

    test('the loader flag of the first member is ignored', () {
      final line = LineAnalysis.of([loader('L1', 10), m('A', 20)]);
      expect(line.stations, hasLength(2));
      expect(line.stations.every((st) => !st.isCell), isTrue);
    });

    test('for the failure risk the cell is one machine', () {
      final risk = FailureRisk.of(example(3));
      expect(risk.failures.map((f) => f.machine), [
        'Saw',
        'Machine',
        'Packing',
      ]);
      expect(risk.failures.every((f) => f.standstill), isTrue);
    });
  });

  group('simulation with a loader cell', () {
    test('the cell works at its cell cycle time', () {
      final sim = LineSimulation.fromLine(
        LineAnalysis.of([
          m('Machine', 88, machines: 3),
          loader('L1', 32),
          loader('L2', 20),
        ]),
      );
      expect(sim.stations.single.machines.single.cycleMicros, 32 * s);
      expect(sim.run(horizonMicros: 3200 * s).output, 100);
    });

    test('buffers and conveyors around the cell work as before', () {
      LineAnalysis line(double loaderSeconds) => LineAnalysis.of([
        m('Saw', 10),
        LineStationInput(
          name: 'Machine',
          mode: StudyMode.simple,
          current: lap(88),
          cellMachines: 4,
          buffer: const LineBuffer(
            capacity: 5,
            storeMicros: 2 * s,
            retrieveMicros: 2 * s,
          ),
        ),
        loader('L1', loaderSeconds),
        LineStationInput(
          name: 'Packing',
          mode: StudyMode.simple,
          current: lap(10),
          conveyor: const LineConveyor(capacity: 4, transportMicros: 5 * s),
        ),
      ]);
      final analysed = line(32);
      expect(analysed.stations[1].bufferBefore!.capacity, 5);
      expect(analysed.stations[2].conveyorBefore!.capacity, 4);
      final sim = LineSimulation.fromLine(analysed);
      expect(sim.stations[1].bufferBefore, isNotNull);
      expect(sim.stations[2].conveyorBefore, isNotNull);
      final result = sim.run(horizonMicros: 3600 * s);
      // The cell paces the line: one part every 32 s after the start-up.
      expect(result.output, inInclusiveRange(108, 112));
    });
  });
}

import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

SimStation station(
  String name,
  int seconds, {
  SimConveyor? conveyor,
  SimBuffer? buffer,
}) => SimStation(
  name: name,
  machines: [SimMachine(name: name, cycleMicros: seconds * s)],
  conveyorBefore: conveyor,
  bufferBefore: buffer,
);

const failB = SimFailure(
  station: 1,
  machine: 0,
  startMicros: 102 * s,
  durationMicros: 100 * s,
);

const buffer20 = SimBuffer(
  capacity: 20,
  storeMicros: 2 * s,
  retrieveMicros: 2 * s,
);

SimResult run(List<SimStation> line, int seconds, {SimFailure? failure}) =>
    LineSimulation(line).run(horizonMicros: seconds * s, failure: failure);

void main() {
  test('the transport time delays the parts but not the pace', () {
    final r = run([
      station('A', 10),
      station(
        'B',
        10,
        conveyor: const SimConveyor(capacity: 8, transportMicros: 30 * s),
      ),
    ], 100);
    // First part at B after 10 + 30 s, done at 50, then every 10 s.
    expect(r.output, 6);
    expect(r.conveyors[1]!.capacity, 8);
    expect(r.conveyors[0], isNull);
  });

  test('parts jam on the conveyor until it is full', () {
    const conveyor = SimConveyor(capacity: 8, transportMicros: 5 * s);
    final withConveyor = run(
      [station('A', 10), station('B', 5, conveyor: conveyor)],
      1000,
      failure: failB,
    );
    final without = run(
      [station('A', 10), station('B', 5)],
      1000,
      failure: failB,
    );
    expect(withConveyor.conveyors[1]!.maxLevel, 8);
    expect(withConveyor.output, greaterThan(without.output));
    expect(
      withConveyor.stations[0].blockedMicros,
      lessThan(without.stations[0].blockedMicros),
    );
  });

  test('a buffer at the conveyor stores only when the conveyor is full', () {
    const conveyor = SimConveyor(capacity: 3, transportMicros: 5 * s);
    final line = [
      station('A', 10),
      station('B', 5, conveyor: conveyor, buffer: buffer20),
    ];
    final normal = run(line, 1000);
    expect(normal.buffers[1]!.stores, 0);
    expect(normal.conveyors[1]!.maxLevel, lessThan(3));

    final failed = run(line, 1000, failure: failB);
    expect(failed.conveyors[1]!.maxLevel, 3);
    expect(failed.buffers[1]!.stores, greaterThan(0));
    expect(failed.buffers[1]!.endLevel, 0);
    final conveyorOnly = run(
      [station('A', 10), station('B', 5, conveyor: conveyor)],
      1000,
      failure: failB,
    );
    expect(failed.output, greaterThan(conveyorOnly.output));
  });

  test('before a bottleneck conveyor and buffer fill up', () {
    final r = run([
      station('A', 5),
      station(
        'B',
        10,
        conveyor: const SimConveyor(capacity: 3, transportMicros: 1 * s),
        buffer: const SimBuffer(
          capacity: 5,
          storeMicros: 1 * s,
          retrieveMicros: 1 * s,
        ),
      ),
    ], 600);
    expect(r.conveyors[1]!.maxLevel, 3);
    expect(r.buffers[1]!.maxLevel, 5);
    // B is the bottleneck: one part every 10 s after the first arrives.
    final plain = run([station('A', 5), station('B', 10)], 600);
    expect(r.output, plain.output);
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

    test('the transport time adds to the lead time and goes to the '
        'simulation', () {
      final line = LineAnalysis.of([
        LineStationInput(name: 'A', mode: StudyMode.simple, current: lap(10)),
        LineStationInput(
          name: 'B',
          mode: StudyMode.simple,
          current: lap(20),
          conveyor: const LineConveyor(capacity: 8, transportMicros: 30 * s),
        ),
      ]);
      expect(line.stations[1].conveyorBefore!.capacity, 8);
      expect(line.leadTime, closeTo(60 * s, 1));
      // The line cycle time is still the slowest station.
      expect(line.lineCycleTime, closeTo(20 * s, 1));
      final sim = LineSimulation.fromLine(line);
      expect(sim.stations[1].conveyorBefore!.transportMicros, 30 * s);
    });
  });
}

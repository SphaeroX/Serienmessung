import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

SimStation station(String name, List<int> seconds, {SimBuffer? buffer}) =>
    SimStation(
      name: name,
      machines: [
        for (var i = 0; i < seconds.length; i++)
          SimMachine(
            name: seconds.length == 1 ? name : '$name ${i + 1}',
            cycleMicros: seconds[i] * s,
          ),
      ],
      bufferBefore: buffer,
    );

SimResult run(
  List<SimStation> stations,
  int horizonSeconds, {
  SimFailure? failure,
}) =>
    LineSimulation(stations)
        .run(horizonMicros: horizonSeconds * s, failure: failure);

const buffer20 = SimBuffer(
  capacity: 20,
  storeMicros: 2 * s,
  retrieveMicros: 2 * s,
);

void main() {
  group('without buffers', () {
    test('a single station finishes one part per cycle', () {
      expect(
        run([
          station('A', [10]),
        ], 100).output,
        10,
      );
    });

    test('two stations in a row', () {
      expect(
        run([
          station('A', [10]),
          station('B', [10]),
        ], 100).output,
        9,
      );
    });

    test('the slower station paces the line, the faster one is blocked', () {
      final r = run([
        station('A', [10]),
        station('B', [20]),
      ], 1000);
      // B finishes at 30, 50, ... 990.
      expect(r.output, 49);
      expect(r.stations[0].blockedMicros, greaterThan(400 * s));
      expect(r.stations[1].blockedMicros, 0);
      expect(r.stations[1].utilization, closeTo(0.98, 0.02));
    });

    test('parallel machines share the work', () {
      expect(
        run([
          station('P', [40, 40, 40, 40]),
        ], 400).output,
        40,
      );
      // Saw (12 s) feeds four presses (40 s): the saw paces the line.
      final r = run([
        station('Saw', [12]),
        station('P', [40, 40, 40, 40]),
      ], 3600);
      expect(r.output, 296);
    });

    test('a part goes to the fastest free machine, whatever their order', () {
      // Both presses are free when the first part comes: the fast one
      // takes it, so the saw is blocked less.
      int output(List<int> presses) => run([
        station('Saw', [10]),
        station('P', presses),
        station('Wash', [10]),
      ], 8 * 3600).output;
      expect(output([30, 20]), output([20, 30]));
      expect(output([30, 20]), 2158);
    });

    test('a failure costs its duration at the bottleneck', () {
      final line = [
        station('A', [10]),
        station('B', [10]),
      ];
      expect(run(line, 1000).output, 99);
      final r = run(
        line,
        1000,
        failure: const SimFailure(
          station: 1,
          machine: 0,
          startMicros: 105 * s,
          durationMicros: 100 * s,
        ),
      );
      expect(r.output, 89);
      expect(r.stations[0].blockedMicros, greaterThanOrEqualTo(100 * s));
    });
  });

  group('with a buffer', () {
    test('parts pass on the conveyor when nothing jams', () {
      final r = run([
        station('A', [10]),
        station('B', [5], buffer: buffer20),
      ], 1000);
      expect(r.output, 99);
      expect(r.buffers[1]!.stores, 0);
      expect(r.buffers[1]!.retrieves, 0);
      expect(r.buffers[0], isNull);
    });

    test('it fills up when the next station is the bottleneck', () {
      final small = SimBuffer(
        capacity: 3,
        storeMicros: 1 * s,
        retrieveMicros: 1 * s,
      );
      final withBuffer = run([
        station('A', [5]),
        station('B', [10], buffer: small),
      ], 200);
      final without = run([
        station('A', [5]),
        station('B', [10]),
      ], 200);
      expect(withBuffer.output, without.output);
      final b = withBuffer.buffers[1]!;
      expect(b.maxLevel, 3);
      expect(b.endLevel, 3);
      // Parts keep cycling: stored on a jam, brought back in front of B.
      expect(b.stores, greaterThan(3));
      expect(b.handlingMicros, (b.stores + b.retrieves) * s);
    });

    test('a failure behind the buffer: the line before keeps working and '
        'the buffer empties again', () {
      const failure = SimFailure(
        station: 1,
        machine: 0,
        startMicros: 102 * s,
        durationMicros: 100 * s,
      );
      final withBuffer = run(
        [
          station('A', [10]),
          station('B', [5], buffer: buffer20),
        ],
        1000,
        failure: failure,
      );
      final without = run(
        [
          station('A', [10]),
          station('B', [5]),
        ],
        1000,
        failure: failure,
      );

      expect(without.output, lessThan(99));
      // Short waits for the buffer machine can cost the very last part.
      expect(withBuffer.output, greaterThanOrEqualTo(98));
      expect(withBuffer.output, greaterThan(without.output + 5));
      // A only waits for the buffer machine now and then.
      expect(
        withBuffer.stations[0].blockedMicros,
        lessThan(without.stations[0].blockedMicros ~/ 4),
      );
      final b = withBuffer.buffers[1]!;
      // One retrieved part already waits in front of B.
      expect(b.maxLevel, greaterThanOrEqualTo(9));
      expect(b.stores, greaterThanOrEqualTo(10));
      expect(b.retrieves, b.stores);
      expect(b.endLevel, 0);
      expect(b.handlingMicros, (b.stores + b.retrieves) * 2 * s);
    });

    test('an empty buffer does not help when the station before fails', () {
      const failure = SimFailure(
        station: 0,
        machine: 0,
        startMicros: 102 * s,
        durationMicros: 100 * s,
      );
      final withBuffer = run(
        [
          station('A', [10]),
          station('B', [5], buffer: buffer20),
        ],
        1000,
        failure: failure,
      );
      final without = run(
        [
          station('A', [10]),
          station('B', [5]),
        ],
        1000,
        failure: failure,
      );
      expect(withBuffer.output, without.output);
      expect(withBuffer.output, lessThan(99));
    });
  });

  group('failure scenarios', () {
    test('lost parts per machine with and without buffers', () {
      final line = LineSimulation([
        station('A', [10]),
        station('B', [5], buffer: buffer20),
      ]);
      final scenarios = line.failureScenarios(
        horizonMicros: 1000 * s,
        durationMicros: 100 * s,
        startMicros: 102 * s,
      );
      expect(scenarios.map((x) => x.machine), ['A', 'B']);
      final b = scenarios[1];
      expect(b.lostWithBuffers, lessThanOrEqualTo(1));
      expect(b.lostWithBuffers, lessThan(b.lostWithoutBuffers));
      expect(b.lostWithoutBuffers, greaterThan(0));
      final a = scenarios[0];
      expect(a.lostWithBuffers, a.lostWithoutBuffers);
      expect(line.hasBuffers, isTrue);
    });
  });

  group('built from the line analysis', () {
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

    test('stations, parallel machines and buffers are taken over', () {
      final analysis = LineAnalysis.of([
        LineStationInput(name: 'Saw', mode: StudyMode.simple, current: lap(12)),
        LineStationInput(
          name: 'Press 1',
          mode: StudyMode.simple,
          current: lap(40),
          buffer: const LineBuffer(
            capacity: 50,
            storeMicros: 20 * s,
            retrieveMicros: 15 * s,
          ),
        ),
        LineStationInput(
          name: 'Press 2',
          mode: StudyMode.simple,
          current: lap(40),
          parallel: true,
        ),
      ]);
      expect(analysis.stations[1].bufferBefore!.capacity, 50);
      final sim = LineSimulation.fromLine(analysis);
      expect(sim.stations, hasLength(2));
      expect(sim.stations[1].machines.map((m) => m.name), [
        'Press 1',
        'Press 2',
      ]);
      expect(sim.stations[1].bufferBefore!.storeMicros, 20 * s);
      expect(sim.stations[0].bufferBefore, isNull);
    });
  });
}

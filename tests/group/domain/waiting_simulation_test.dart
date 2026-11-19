import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'waiting_station_test.dart' show m;

const s = 1000000;

SimStation station(
  String name,
  List<int> seconds, {
  bool waits = false,
  SimBuffer? buffer,
  Map<int, List<SpecialCycle>> specials = const {},
}) => SimStation(
  name: name,
  machines: [
    for (var i = 0; i < seconds.length; i++)
      SimMachine(
        name: seconds.length == 1 ? name : '$name ${i + 1}',
        cycleMicros: seconds[i] * s,
        specialCycles: specials[i] ?? const [],
      ),
  ],
  waitForSlowest: waits,
  bufferBefore: buffer,
);

SimResult run(
  List<SimStation> stations,
  int horizonSeconds, {
  SimFailure? failure,
}) =>
    LineSimulation(stations)
        .run(horizonMicros: horizonSeconds * s, failure: failure);

void main() {
  group('station that waits for its slowest machine', () {
    test('finishes one part when all of its machines are done', () {
      expect(
        run([
          station('Parts', [30, 40, 50], waits: true),
        ], 500).output,
        10,
      );
      // Without the option the machines share the work: 16 + 12 + 10.
      expect(
        run([
          station('Parts', [30, 40, 50]),
        ], 500).output,
        38,
      );
    });

    test('takes one part at a time from the station before', () {
      final r = run([
        station('Saw', [10]),
        station('Parts', [20, 30], waits: true),
        station('Wash', [10]),
      ], 3000);
      // First part at 50 s, then one every 30 s.
      expect(r.output, 99);
      // The saw waits with its finished part.
      expect(r.stations[0].blockedMicros, greaterThan(1900 * s));
      // 20 s and 30 s of work in every 30 s.
      expect(r.stations[1].machines, 2);
      expect(r.stations[1].utilization, closeTo(50 / 60, 0.02));
      expect(r.stations[1].blockedMicros, 0);
    });

    test('the order of its machines does not matter', () {
      int output(List<int> parts) => run([
        station('Saw', [10]),
        station('Parts', parts, waits: true),
        station('Wash', [10]),
      ], 8 * 3600).output;
      expect(output([20, 30, 25]), output([30, 25, 20]));
    });

    test('a stopped machine stops the station', () {
      final line = [
        station('Parts', [20, 30], waits: true),
      ];
      expect(run(line, 600).output, 20);
      // The fast machine stops for 60 s while it works on the 4th part: it
      // is done at 170 s instead of 110 s, two parts are lost.
      final r = run(
        line,
        600,
        failure: const SimFailure(
          station: 0,
          machine: 0,
          startMicros: 95 * s,
          durationMicros: 60 * s,
        ),
      );
      expect(r.output, 18);
      expect(r.stations[0].downMicros, 60 * s);
    });

    test('a short stop of the fast machine is hidden by the slow one', () {
      final r = run(
        [
          station('Parts', [20, 30], waits: true),
        ],
        600,
        failure: const SimFailure(
          station: 0,
          machine: 0,
          startMicros: 95 * s,
          durationMicros: 5 * s,
        ),
      );
      expect(r.output, 20);
    });

    test('a stop while the station is free delays the next part', () {
      // The station is starved by the slow saw; its slow machine stops
      // while it waits for the next part.
      final line = [
        station('Saw', [100]),
        station('Parts', [20, 30], waits: true),
      ];
      // Parts at 130, 230, ... 930.
      expect(run(line, 1000).output, 9);
      final r = run(
        line,
        1000,
        failure: const SimFailure(
          station: 1,
          machine: 1,
          startMicros: 190 * s,
          durationMicros: 50 * s,
        ),
      );
      // The part of 200 s is taken at 240 s and done at 270 s; the saw is
      // 40 s late from then on: parts at 130, 270, 370, ... 970.
      expect(r.output, 9);
      expect(r.stations[0].blockedMicros, 40 * s);
    });

    test('special cycles count per machine', () {
      // Every second part of the fast machine takes 20 s longer: the
      // rounds take 30 s and 40 s in turn.
      final r = run([
        station(
          'Parts',
          [20, 30],
          waits: true,
          specials: {
            0: const [
              SpecialCycle(
                id: 1,
                studyId: 1,
                name: 'Tool',
                kind: SpecialCycleKind.parts,
                interval: 2,
                durationMicros: 20 * s,
              ),
            ],
          },
        ),
      ], 700);
      expect(r.output, 20);
    });

    test('time accounts never exceed the period', () {
      final r = run(
        [
          station('Saw', [10]),
          station('Parts', [20, 30, 25], waits: true),
          station('Wash', [45]),
        ],
        3600,
        failure: const SimFailure(
          station: 1,
          machine: 2,
          startMicros: 1000 * s,
          durationMicros: 300 * s,
        ),
      );
      for (final st in r.stations) {
        expect(
          st.busyMicros + st.blockedMicros + st.downMicros,
          lessThanOrEqualTo(st.machines * st.horizonMicros),
        );
        expect(st.starvedMicros, greaterThanOrEqualTo(0));
      }
      // The wash paces the line, the waiting station is blocked by it.
      expect(r.stations[1].blockedMicros, greaterThan(0));
    });

    test('a buffer before it never costs parts', () {
      const buffer = SimBuffer(
        capacity: 10,
        storeMicros: 3 * s,
        retrieveMicros: 3 * s,
      );
      for (final parts in [
        [20, 30],
        [40, 15, 25],
      ]) {
        final line = LineSimulation([
          station('Saw', [10]),
          station('Parts', parts, waits: true, buffer: buffer),
          station('Wash', [12]),
        ]);
        final slowest = parts.reduce((a, b) => a > b ? a : b);
        const horizon = 8 * 3600;
        final withBuffer = line.run(horizonMicros: horizon * s).output;
        final without = line
            .withoutBuffers()
            .run(horizonMicros: horizon * s)
            .output;
        expect(withBuffer, greaterThanOrEqualTo(without - 1));
        expect(withBuffer, lessThanOrEqualTo(horizon ~/ slowest));
      }
    });

    test('failure scenarios: each of its machines costs the same', () {
      final scenarios =
          LineSimulation([
            station('Parts', [20, 30], waits: true),
            station('Wash', [10]),
          ]).failureScenarios(
            horizonMicros: 3600 * s,
            durationMicros: 300 * s,
            startMicros: 900 * s,
          );
      expect(scenarios.map((x) => x.machine), ['Parts 1', 'Parts 2', 'Wash']);
      expect(scenarios[0].lostWithoutBuffers, 10);
      expect(scenarios[1].lostWithoutBuffers, 10);
    });
  });

  group('simulation from the line analysis', () {
    final line = LineAnalysis.of([
      m('Saw', 12),
      m('Part 1', 30, waits: true),
      m('Part 2', 40, parallel: true),
      m('Part 3', 50, parallel: true),
    ]);

    test('keeps the option, also without buffers', () {
      final sim = LineSimulation.fromLine(line);
      expect(sim.stations.map((x) => x.waitForSlowest), [false, true]);
      expect(sim.withoutBuffers().stations.map((x) => x.waitForSlowest), [
        false,
        true,
      ]);
    });

    test('gives the output of the line analysis', () {
      // 72 parts per hour at 50 s; the line starts empty.
      final output = LineSimulation.fromLine(line)
          .run(horizonMicros: 3600 * s)
          .output;
      expect(output, 71);
    });
  });
}

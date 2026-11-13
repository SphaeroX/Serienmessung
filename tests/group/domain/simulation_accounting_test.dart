import 'dart:math';

import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;
const hour = 3600 * s;

SpecialCycle stop({required int every, required int lasts}) => SpecialCycle(
  id: 1,
  studyId: 1,
  name: 'stop',
  kind: SpecialCycleKind.time,
  interval: every,
  durationMicros: lasts,
);

SimStation single(
  String name,
  int seconds, {
  List<SpecialCycle> rules = const [],
}) => SimStation(
  name: name,
  machines: [
    SimMachine(name: name, cycleMicros: seconds * s, specialCycles: rules),
  ],
);

void main() {
  test('a planned stop inside a failure that lasts beyond the period', () {
    // Blade change after 4 h, failure from 2 h until after the 8 h period.
    final r =
        LineSimulation([
          single(
            'Saw',
            38,
            rules: [stop(every: 8 * hour, lasts: 600 * s)],
          ),
        ]).run(
          horizonMicros: 8 * hour,
          failure: const SimFailure(
            station: 0,
            machine: 0,
            startMicros: 2 * hour,
            durationMicros: 7 * hour,
          ),
        );
    expect(r.stations.single.downMicros, 6 * hour);
    expect(r.stations.single.starvedMicros, greaterThanOrEqualTo(0));
  });

  test('stops longer than their interval never give a negative time', () {
    final r = LineSimulation([
      single(
        'A',
        100,
        rules: [stop(every: hour, lasts: 2 * hour)],
      ),
    ]).run(horizonMicros: 24 * hour);
    // Stopped from half an hour on.
    expect(r.stations.single.downMicros, 24 * hour - hour ~/ 2);
    expect(r.stations.single.starvedMicros, 0);
  });

  test('time blocked and stopped at once counts as stopped only', () {
    // A (10 s) waits for B (100 s) and fails from 1000 s to 2800 s.
    final r = LineSimulation([single('A', 10), single('B', 100)]).run(
      horizonMicros: hour,
      failure: const SimFailure(
        station: 0,
        machine: 0,
        startMicros: 1000 * s,
        durationMicros: 1800 * s,
      ),
    );
    final a = r.stations.first;
    expect(a.busyMicros, 200 * s);
    expect(a.downMicros, 1800 * s);
    expect(a.blockedMicros, 1600 * s);
    expect(a.starvedMicros, 0);
  });

  test('work interrupted by a stop counts only until the period ends', () {
    // The second part starts at 100 s, the machine stops from 120 s to
    // 220 s; the period ends at 150 s.
    final r = LineSimulation([single('A', 100)]).run(
      horizonMicros: 150 * s,
      failure: const SimFailure(
        station: 0,
        machine: 0,
        startMicros: 120 * s,
        durationMicros: 100 * s,
      ),
    );
    final a = r.stations.single;
    expect(a.busyMicros, 120 * s);
    expect(a.downMicros, 30 * s);
    expect(a.starvedMicros, 0);
  });

  test('busy, blocked and stopped time never exceed the period', () {
    final rnd = Random(7);
    for (var n = 0; n < 150; n++) {
      final count = 1 + rnd.nextInt(5);
      final stations = [
        for (var i = 0; i < count; i++)
          SimStation(
            name: 'S$i',
            machines: [
              for (var m = 0; m < 1 + rnd.nextInt(3); m++)
                SimMachine(
                  name: 'S$i-$m',
                  cycleMicros: (5 + rnd.nextInt(60)) * s,
                  specialCycles: [
                    if (rnd.nextInt(3) == 0)
                      stop(
                        every: (600 + rnd.nextInt(7200)) * s,
                        lasts: (10 + rnd.nextInt(500)) * s,
                      ),
                  ],
                ),
            ],
            bufferBefore: rnd.nextInt(3) == 0
                ? SimBuffer(
                    capacity: 1 + rnd.nextInt(10),
                    storeMicros: (1 + rnd.nextInt(30)) * s,
                    retrieveMicros: (1 + rnd.nextInt(30)) * s,
                  )
                : null,
            conveyorBefore: rnd.nextInt(3) == 0
                ? SimConveyor(
                    capacity: 1 + rnd.nextInt(6),
                    transportMicros: (1 + rnd.nextInt(90)) * s,
                  )
                : null,
          ),
      ];
      final h = (1 + rnd.nextInt(8)) * hour;
      final si = rnd.nextInt(count);
      final r = LineSimulation(stations).run(
        horizonMicros: h,
        failure: SimFailure(
          station: si,
          machine: rnd.nextInt(stations[si].machines.length),
          startMicros: rnd.nextInt(h ~/ s) * s,
          durationMicros: (60 + rnd.nextInt(4 * 3600)) * s,
        ),
      );
      for (final st in r.stations) {
        final reason = 'run $n';
        expect(st.downMicros, greaterThanOrEqualTo(0), reason: reason);
        expect(st.blockedMicros, greaterThanOrEqualTo(0), reason: reason);
        expect(st.busyMicros, greaterThanOrEqualTo(0), reason: reason);
        expect(st.starvedMicros, greaterThanOrEqualTo(0), reason: reason);
      }
    }
  });
}

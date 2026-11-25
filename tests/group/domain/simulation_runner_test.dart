import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/domain/simulation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;
const hour = 3600 * s;

LineSimulation line(int stations, {int machines = 1}) => LineSimulation([
  for (var i = 0; i < stations; i++)
    SimStation(
      name: 'S$i',
      machines: [
        for (var m = 0; m < machines; m++)
          SimMachine(name: 'S$i.$m', cycleMicros: (30 + i % 7) * s),
      ],
      bufferBefore: i == 3
          ? const SimBuffer(capacity: 5, storeMicros: s, retrieveMicros: s)
          : null,
    ),
]);

void main() {
  test('small lines stay on this thread, large ones do not', () {
    expect(runsOffThread(line(5)), isFalse);
    expect(runsOffThread(line(20, machines: 2)), isTrue);
  });

  test('a run gives the same figures on and off the thread', () async {
    final sim = line(20, machines: 2);
    const failures = [
      SimFailure(
        station: 4,
        machine: 1,
        startMicros: hour,
        durationMicros: hour ~/ 2,
      ),
    ];
    final direct = simulateRun(
      sim,
      horizonMicros: 4 * hour,
      failures: failures,
    );
    final off = await runSimulation(
      sim,
      horizonMicros: 4 * hour,
      failures: failures,
    );
    expect(off.base.output, direct.base.output);
    expect(off.failed!.output, direct.failed!.output);
    expect(off.plainLost, direct.plainLost);
    expect(off.failed!.stations[4].downMicros, hour ~/ 2);
  });

  test('failure scenarios off the thread match the direct ones', () async {
    final sim = line(20, machines: 2);
    final direct = sim.failureScenarios(
      horizonMicros: 2 * hour,
      durationMicros: hour ~/ 4,
      startMicros: hour ~/ 2,
    );
    final off = await failureScenariosOf(
      sim,
      horizonMicros: 2 * hour,
      durationMicros: hour ~/ 4,
      startMicros: hour ~/ 2,
    );
    expect(
      [for (final f in off) (f.lostWithBuffers, f.lostWithoutBuffers)],
      [for (final f in direct) (f.lostWithBuffers, f.lostWithoutBuffers)],
    );
  });
}

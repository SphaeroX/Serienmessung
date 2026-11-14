import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

const line = LineSimulation([
  SimStation(
    name: 'A',
    machines: [SimMachine(name: 'A', cycleMicros: 10 * s)],
  ),
  SimStation(
    name: 'B',
    machines: [SimMachine(name: 'B', cycleMicros: 5 * s)],
  ),
]);

const h = 1000 * s;

void main() {
  test('several failures on different machines all stop the line', () {
    const a = SimFailure(
      station: 0,
      machine: 0,
      startMicros: 100 * s,
      durationMicros: 100 * s,
    );
    const b = SimFailure(
      station: 1,
      machine: 0,
      startMicros: 500 * s,
      durationMicros: 100 * s,
    );
    final base = line.run(horizonMicros: h).output;
    final onlyA = line.run(horizonMicros: h, failures: [a]).output;
    final onlyB = line.run(horizonMicros: h, failures: [b]).output;
    final both = line.run(horizonMicros: h, failures: [a, b]);

    expect(onlyA, line.run(horizonMicros: h, failure: a).output);
    expect(base - both.output, (base - onlyA) + (base - onlyB));
    expect(both.stations[0].downMicros, 100 * s);
    expect(both.stations[1].downMicros, 100 * s);
  });

  test('several failures of the same machine add up', () {
    const first = SimFailure(
      station: 0,
      machine: 0,
      startMicros: 100 * s,
      durationMicros: 50 * s,
    );
    const second = SimFailure(
      station: 0,
      machine: 0,
      startMicros: 400 * s,
      durationMicros: 50 * s,
    );
    final r = line.run(horizonMicros: h, failures: [second, first]);
    expect(r.stations[0].downMicros, 100 * s);
    expect(r.output, line.run(horizonMicros: h).output - 10);
  });

  test('overlapping failures of the same machine count only once', () {
    SimFailure f(int start, int duration) => SimFailure(
      station: 0,
      machine: 0,
      startMicros: start * s,
      durationMicros: duration * s,
    );
    // 100–150 s and 125–175 s: down from 100 to 175 s.
    final overlapping = line.run(
      horizonMicros: h,
      failures: [f(100, 50), f(125, 50)],
    );
    final merged = line.run(horizonMicros: h, failures: [f(100, 75)]);
    expect(overlapping.stations[0].downMicros, 75 * s);
    expect(overlapping.output, merged.output);

    // A failure inside another one changes nothing.
    final inside = line.run(
      horizonMicros: h,
      failures: [f(100, 100), f(120, 20)],
    );
    final single = line.run(horizonMicros: h, failures: [f(100, 100)]);
    expect(inside.stations[0].downMicros, 100 * s);
    expect(inside.output, single.output);
  });

  test('the single failure and the list are combined', () {
    const a = SimFailure(
      station: 0,
      machine: 0,
      startMicros: 100 * s,
      durationMicros: 50 * s,
    );
    const b = SimFailure(
      station: 1,
      machine: 0,
      startMicros: 600 * s,
      durationMicros: 50 * s,
    );
    expect(
      line.run(horizonMicros: h, failure: a, failures: [b]).output,
      line.run(horizonMicros: h, failures: [a, b]).output,
    );
  });
}

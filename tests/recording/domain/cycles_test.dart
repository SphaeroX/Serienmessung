import 'package:cyclescope/recording/domain/cycles.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:flutter_test/flutter_test.dart';

var _id = 0;

Measurement m(int cycle, int? step, int dur, {bool special = false}) =>
    Measurement(
      id: ++_id,
      studyId: 1,
      cycle: cycle,
      stepId: step,
      kind: special ? MeasurementKind.special : MeasurementKind.normal,
      startMicros: _id * 10,
      endMicros: _id * 10 + dur,
      durationMicros: dur,
    );

void main() {
  test('groups measurements of several sessions into ordered cycles', () {
    final groups = groupCycles(
      [
        m(1, 1, 10), m(1, 2, 20),
        m(2, 1, 11), m(2, 2, 21),
        m(3, 1, 12), // second session, incomplete
      ],
      stepIds: [1, 2],
    );
    expect(groups.map((g) => g.cycle), [1, 2, 3]);
    expect(groups.map((g) => g.isComplete), [true, true, false]);
    expect(groups.first.normalTotal, 30);
  });

  test('special times are listed but not counted in the cycle time', () {
    final g = groupCycles(
      [m(1, 1, 10), m(1, 1, 99, special: true), m(1, 2, 20)],
      stepIds: [1, 2],
    ).single;
    expect(g.normalTotal, 30);
    expect(g.specialTotal, 99);
    expect(g.items.length, 3);
    expect(g.isComplete, isTrue);
  });

  test('a cycle missing a step after deletion is incomplete', () {
    final g = groupCycles([m(5, 2, 20)], stepIds: [1, 2]).single;
    expect(g.isComplete, isFalse);
  });

  test('without step definitions every lap is a complete cycle', () {
    final groups = groupCycles([m(1, null, 5), m(2, null, 6)], stepIds: []);
    expect(groups.every((g) => g.isComplete), isTrue);
  });
}

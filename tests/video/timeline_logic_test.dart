import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/video/domain/boundary.dart';
import 'package:cyclescope/video/domain/position_interpolator.dart';
import 'package:flutter_test/flutter_test.dart';

const ms = 1000;

Measurement m(int id, int start, int end, {int? dur, bool special = false}) =>
    Measurement(
      id: id,
      studyId: 1,
      cycle: 1,
      stepId: id,
      kind: special ? MeasurementKind.special : MeasurementKind.normal,
      startMicros: start,
      endMicros: end,
      durationMicros: dur ?? end - start,
    );

void main() {
  group('PositionInterpolator', () {
    test('extrapolates linearly between reports with the speed', () {
      final p = PositionInterpolator()
        ..report(position: 1000 * ms, now: 0, playing: true, speed: 1);
      expect(p.estimate(100 * ms), 1100 * ms);
      p.report(position: 1200 * ms, now: 200 * ms, playing: true, speed: 1);
      expect(p.estimate(300 * ms), 1300 * ms);

      final half = PositionInterpolator()
        ..report(position: 0, now: 0, playing: true, speed: 0.5);
      expect(half.estimate(400 * ms), 200 * ms);
    });

    test('stands still while paused', () {
      final p = PositionInterpolator()
        ..report(position: 5000 * ms, now: 0, playing: false, speed: 1);
      expect(p.estimate(1000 * ms), 5000 * ms);
    });

    test('jumps immediately after a seek', () {
      final p = PositionInterpolator()
        ..report(position: 0, now: 0, playing: true, speed: 1);
      p.estimate(100 * ms);
      p.report(position: 30000 * ms, now: 120 * ms, playing: true, speed: 1);
      expect(p.estimate(120 * ms), 30000 * ms);
    });

    test('small lag is corrected without running backwards', () {
      final p = PositionInterpolator()
        ..report(position: 0, now: 0, playing: true, speed: 1);
      expect(p.estimate(250 * ms), 250 * ms);
      // The player reports 80 ms less than we showed.
      p.report(position: 170 * ms, now: 250 * ms, playing: true, speed: 1);
      var last = p.estimate(250 * ms);
      expect(last, 250 * ms);
      for (var t = 260; t <= 1000; t += 10) {
        final v = p.estimate(t * ms);
        expect(v, greaterThanOrEqualTo(last));
        last = v;
      }
      // After the smoothing window the reported timeline is reached.
      expect(p.estimate(1000 * ms), 920 * ms);
    });
  });

  group('marker boundaries', () {
    test('only inner markers between adjacent step times are movable', () {
      final list = [
        m(1, 0, 2000 * ms),
        m(2, 2000 * ms, 5000 * ms),
        m(9, 3000 * ms, 3500 * ms, special: true),
        m(3, 6000 * ms, 7000 * ms), // gap: new run
      ];
      final b = movableBoundaries(list);
      expect(b.single.at, 2000 * ms);
    });

    test('moving changes both durations in opposite directions', () {
      final b = Boundary(m(1, 0, 2000 * ms), m(2, 2000 * ms, 5000 * ms));
      final (before, after) = moveBoundary(b, 2500 * ms)!;
      expect((before.endMicros, before.durationMicros), (2500 * ms, 2500 * ms));
      expect((after.startMicros, after.durationMicros), (2500 * ms, 2500 * ms));
      expect(before.durationMicros + after.durationMicros, 5000 * ms);
    });

    test('excluded special time inside a step is kept', () {
      // Step 2 contains 1 s special time: duration 2 s for a 3 s span.
      final b = Boundary(
        m(1, 0, 2000 * ms),
        m(2, 2000 * ms, 5000 * ms, dur: 2000 * ms),
      );
      final (_, after) = moveBoundary(b, 1500 * ms)!;
      expect(after.durationMicros, 2500 * ms);
    });

    test('a marker cannot pass its neighbours', () {
      final b = Boundary(
        m(1, 1000 * ms, 2000 * ms),
        m(2, 2000 * ms, 3000 * ms),
      );
      expect(moveBoundary(b, 900 * ms), isNull);
      expect(moveBoundary(b, 3100 * ms), isNull);
      expect(clampBoundary(b, 0), 1001 * ms);
      expect(clampBoundary(b, 9999 * ms), 2999 * ms);
    });
  });
}

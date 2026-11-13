import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/video/domain/boundary.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

void main() {
  test('moving a marker keeps the time of measurement', () {
    final at = DateTime(2026, 5, 4, 10, 30);
    Measurement step(int id, int from, int to) => Measurement(
      id: id,
      studyId: 1,
      cycle: 1,
      stepId: id,
      kind: MeasurementKind.normal,
      startMicros: from * s,
      endMicros: to * s,
      durationMicros: (to - from) * s,
      recordedAt: at,
    );
    final moved = moveBoundary(
      Boundary(step(1, 0, 10), step(2, 10, 20)),
      12 * s,
    )!;
    expect(moved.$1.recordedAt, at);
    expect(moved.$2.recordedAt, at);
  });
}

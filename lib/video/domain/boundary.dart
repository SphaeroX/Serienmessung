import '../../recording/domain/measurement.dart';

/// Two adjacent step times whose shared boundary (a marker) can be moved.
class Boundary {
  const Boundary(this.before, this.after);

  final Measurement before;
  final Measurement after;

  int get at => before.endMicros;
}

/// Inner markers: consecutive normal measurements where one ends exactly
/// where the next starts. Markers at the start of a run or of the running
/// step are not movable.
List<Boundary> movableBoundaries(List<Measurement> measurements) {
  final normals =
      measurements.where((m) => m.kind == MeasurementKind.normal).toList()
        ..sort((a, b) => a.startMicros.compareTo(b.startMicros));
  return [
    for (var i = 0; i + 1 < normals.length; i++)
      if (normals[i].endMicros == normals[i + 1].startMicros)
        Boundary(normals[i], normals[i + 1]),
  ];
}

/// [b] with its marker moved to [to]. Durations change by the same amount
/// in opposite directions (their sum stays equal); time excluded for special
/// times is kept. Returns null if a step would become shorter than
/// [minDuration] (a marker can never pass its neighbours).
(Measurement, Measurement)? moveBoundary(
  Boundary b,
  int to, {
  int minDuration = 1000,
}) {
  final delta = to - b.at;
  final newBefore = b.before.durationMicros + delta;
  final newAfter = b.after.durationMicros - delta;
  if (newBefore < minDuration || newAfter < minDuration) return null;
  if (to <= b.before.startMicros || to >= b.after.endMicros) return null;
  return (
    _copy(b.before, end: to, duration: newBefore),
    _copy(b.after, start: to, duration: newAfter),
  );
}

/// Clamps [to] so that [moveBoundary] succeeds (for dragging).
int clampBoundary(Boundary b, int to, {int minDuration = 1000}) {
  final lo = b.at - b.before.durationMicros + minDuration;
  final hi = b.at + b.after.durationMicros - minDuration;
  final lo2 = b.before.startMicros + 1;
  final hi2 = b.after.endMicros - 1;
  final min = lo > lo2 ? lo : lo2;
  final max = hi < hi2 ? hi : hi2;
  return to < min ? min : (to > max ? max : to);
}

Measurement _copy(
  Measurement m, {
  int? start,
  int? end,
  required int duration,
}) => Measurement(
  id: m.id,
  studyId: m.studyId,
  cycle: m.cycle,
  stepId: m.stepId,
  kind: m.kind,
  startMicros: start ?? m.startMicros,
  endMicros: end ?? m.endMicros,
  durationMicros: duration,
  note: m.note,
  recordedAt: m.recordedAt,
);

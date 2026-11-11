import 'measurement.dart';

/// All measurements of one cycle (or lap).
class CycleGroup {
  const CycleGroup({
    required this.cycle,
    required this.items,
    required this.isComplete,
  });

  final int cycle;

  /// Step times and special times in chronological order.
  final List<Measurement> items;

  /// True when every defined step has a time in this cycle.
  final bool isComplete;

  /// Cycle time: sum of step times, special times excluded.
  int get normalTotal => items
      .where((m) => m.kind == MeasurementKind.normal)
      .fold(0, (s, m) => s + m.durationMicros);

  int get specialTotal => items
      .where((m) => m.kind == MeasurementKind.special)
      .fold(0, (s, m) => s + m.durationMicros);

  int get stepCount =>
      items.where((m) => m.kind == MeasurementKind.normal).length;
}

/// Groups [measurements] by cycle number in ascending order.
///
/// A cycle is complete when it contains a normal time for each id in
/// [stepIds]. Without step definitions (simple mode) every lap is complete.
List<CycleGroup> groupCycles(
  List<Measurement> measurements, {
  required List<int> stepIds,
}) {
  final byCycle = <int, List<Measurement>>{};
  for (final m in measurements) {
    byCycle.putIfAbsent(m.cycle, () => []).add(m);
  }
  final cycles = byCycle.keys.toList()..sort();
  return [
    for (final c in cycles)
      CycleGroup(
        cycle: c,
        items: byCycle[c]!..sort((a, b) => a.endMicros.compareTo(b.endMicros)),
        isComplete: _complete(byCycle[c]!, stepIds),
      ),
  ];
}

bool _complete(List<Measurement> items, List<int> stepIds) {
  final normals = items.where((m) => m.kind == MeasurementKind.normal);
  if (stepIds.isEmpty) return normals.isNotEmpty;
  final seen = normals.map((m) => m.stepId).toSet();
  return stepIds.every(seen.contains);
}

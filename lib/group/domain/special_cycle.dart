/// How often a special cycle comes.
enum SpecialCycleKind {
  /// Every [SpecialCycle.interval] parts the machine needs extra time (e.g.
  /// taking a part to the measuring place).
  parts,

  /// Every [SpecialCycle.interval] microseconds the machine stops (e.g. a
  /// tool change).
  time;

  static SpecialCycleKind parse(String v) =>
      SpecialCycleKind.values.firstWhere((k) => k.name == v);
}

/// A recurring special cycle or planned stop of a machine.
class SpecialCycle {
  const SpecialCycle({
    required this.id,
    required this.studyId,
    required this.name,
    required this.kind,
    required this.interval,
    required this.durationMicros,
  });

  final int id;
  final int studyId;
  final String name;
  final SpecialCycleKind kind;

  /// Parts ([SpecialCycleKind.parts]) or microseconds ([SpecialCycleKind.time]).
  final int interval;

  /// Extra time per occurrence (µs).
  final int durationMicros;
}

/// Share of the time a machine is not stopped by its planned stops (0..1).
double availability(List<SpecialCycle> cycles) {
  var stopped = 0.0;
  for (final c in cycles) {
    if (c.kind == SpecialCycleKind.time && c.interval > 0) {
      stopped += c.durationMicros / c.interval;
    }
  }
  return (1 - stopped).clamp(0.01, 1.0);
}

/// Extra time per part (µs) of the part-based rules.
double extraPerPart(List<SpecialCycle> cycles) {
  var extra = 0.0;
  for (final c in cycles) {
    if (c.kind == SpecialCycleKind.parts && c.interval > 0) {
      extra += c.durationMicros / c.interval;
    }
  }
  return extra;
}

/// Cycle time including the special cycles: the extra time per part of the
/// part-based rules is added, then divided by the [availability].
double effectiveCycleTime(double baseMicros, List<SpecialCycle> cycles) =>
    (baseMicros + extraPerPart(cycles)) / availability(cycles);

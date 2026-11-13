/// Kind of a recorded time.
enum MeasurementKind {
  /// Regular step (or lap) time.
  normal,

  /// Unforeseen interruption. Never counts towards step or cycle times.
  special;

  static MeasurementKind parse(String v) =>
      MeasurementKind.values.firstWhere((k) => k.name == v);
}

/// A completed time produced by the engine, not yet stored.
class MeasurementDraft {
  const MeasurementDraft({
    required this.cycle,
    required this.stepId,
    required this.kind,
    required this.startMicros,
    required this.endMicros,
    required this.durationMicros,
    this.note = '',
  });

  /// Cycle number (1-based). Lap number in simple mode, 0 in step-timer mode.
  final int cycle;

  /// Step definition id; null in simple mode.
  final int? stepId;
  final MeasurementKind kind;

  /// Start/end in the time base of the source (monotonic clock or video
  /// position). For steps with pauses or interruptions, duration is smaller
  /// than end − start.
  final int startMicros;
  final int endMicros;
  final int durationMicros;
  final String note;
}

/// A stored measurement.
class Measurement extends MeasurementDraft {
  const Measurement({
    required this.id,
    required this.studyId,
    required super.cycle,
    required super.stepId,
    required super.kind,
    required super.startMicros,
    required super.endMicros,
    required super.durationMicros,
    super.note,
    this.recordedAt,
  });

  final int id;
  final int studyId;

  /// Wall-clock time the measurement was stored; null for data from before
  /// schema 10.
  final DateTime? recordedAt;

  bool get isSpecial => kind == MeasurementKind.special;
}

/// The four recording modes of a study.
enum StudyMode {
  simple,
  timeStudy,
  stepTimer,
  video;

  /// Whether the mode needs step definitions.
  bool get usesSteps => this != StudyMode.simple;

  static StudyMode parse(String value) =>
      StudyMode.values.firstWhere((m) => m.name == value);
}

/// A time study.
class Study {
  const Study({
    required this.id,
    required this.name,
    required this.description,
    required this.mode,
    required this.createdAt,
    required this.lastActiveAt,
    this.cycleTimeMethod,
    this.videoPath,
  });

  final int id;
  final String name;
  final String description;
  final StudyMode mode;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  /// Name of the selected cycle time method (see analysis), null = default.
  final String? cycleTimeMethod;

  /// Local path of the imported video (video studies only).
  final String? videoPath;
}

/// One defined work step of a study.
class StepDefinition {
  const StepDefinition({
    required this.id,
    required this.studyId,
    required this.position,
    required this.name,
  });

  final int id;
  final int studyId;
  final int position;
  final String name;
}

/// Study plus figures shown on the study list card.
class StudySummary {
  const StudySummary({required this.study, required this.cycleCount});

  final Study study;

  /// Number of cycles (laps / measurements for modes without cycles).
  final int cycleCount;
}

/// The four recording modes of a study.
enum StudyMode {
  simple,
  timeStudy,
  stepTimer,
  video;

  /// Whether the mode needs step definitions.
  bool get usesSteps => this != StudyMode.simple;

  /// Whether steps are entered when the study is created. Video studies
  /// define their steps while marking the video instead.
  bool get definesStepsUpfront =>
      this == StudyMode.timeStudy || this == StudyMode.stepTimer;

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
    this.stepsOpen = false,
    this.notes = '',
    this.groupId,
    this.groupPosition = 0,
    this.revision = 1,
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

  /// Video study still defining its steps: every marker of the first cycle
  /// creates a new step until the cycle is closed.
  final bool stepsOpen;

  /// Free notes on the study (analysis tab), printed in the reports.
  final String notes;

  /// Group the study belongs to (optional, at most one).
  final int? groupId;

  /// 0-based place of the study within its group.
  final int groupPosition;

  /// Number of the current revision (measurement round); earlier rounds are
  /// archived as revisions.
  final int revision;
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
  const StudySummary({
    required this.study,
    required this.cycleCount,
    this.isRecording = false,
    this.groupName,
  });

  final Study study;

  /// Name of the study's group, null if it has none.
  final String? groupName;

  /// Number of cycles (laps / measurements for modes without cycles).
  final int cycleCount;

  /// A recording of this study is in progress (saved run state).
  final bool isRecording;
}

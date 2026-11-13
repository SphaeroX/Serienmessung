import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';

/// An archived measurement round of a study: a complete snapshot of its
/// steps and times at the moment a new revision was started.
class Revision {
  const Revision({
    required this.id,
    required this.studyId,
    required this.number,
    required this.closedAt,
    required this.firstRecordedAt,
    required this.lastRecordedAt,
    required this.cycleTimeMethod,
    required this.notes,
    required this.steps,
    required this.measurements,
  });

  final int id;
  final int studyId;

  /// 1-based revision number; the study continues with [number] + 1.
  final int number;

  /// When the revision was archived.
  final DateTime closedAt;

  /// Wall-clock time of the first and last recorded time (null for data
  /// from before timestamps were stored).
  final DateTime? firstRecordedAt;
  final DateTime? lastRecordedAt;

  /// Cycle time method the study used then (null = default).
  final String? cycleTimeMethod;
  final String notes;

  /// Steps as they were; [StepDefinition.id] is the id the step had (and
  /// still has, if it exists) in the study.
  final List<StepDefinition> steps;

  /// Times of the revision; [Measurement.stepId] refers to [steps].
  final List<Measurement> measurements;
}

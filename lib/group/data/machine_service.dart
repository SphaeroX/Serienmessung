import '../../core/database.dart';
import '../../recording/data/measurement_repository.dart';
import '../../recording/domain/measurement.dart';
import '../../revision/data/revision_repository.dart';
import '../../study/data/study_repository.dart';
import '../../study/domain/study.dart';
import 'group_repository.dart';

/// Machines whose cycle time is entered instead of measured.
///
/// Such a machine is a simple study with exactly one lap of the entered
/// duration, so analysis, exports, revisions and backup work as for any
/// other study (and it can still be measured with the stopwatch).
class MachineService {
  MachineService(this._db, {required this.now});

  final AppDatabase _db;

  /// Wall clock for timestamps.
  final DateTime Function() now;

  /// Creates the machine at the end of group [groupId] and returns its id.
  Future<int> createMachine({
    required String name,
    required int groupId,
    required int cycleMicros,
    bool parallel = false,
  }) async {
    final id = await StudyRepository(_db).createStudy(
      name: name,
      mode: StudyMode.simple,
      steps: const [],
      now: now(),
    );
    final groups = GroupRepository(_db);
    await groups.moveToGroup(id, groupId);
    if (parallel) await groups.setParallel(id, true);
    await _store(id, cycleMicros);
    return id;
  }

  /// Replaces the times of study [studyId] by one lap of [cycleMicros]; the
  /// previous times are archived as a revision.
  Future<void> setCycleTime(int studyId, int cycleMicros) async {
    await RevisionRepository(_db).startNewRevision(studyId, now: now());
    await _store(studyId, cycleMicros);
  }

  Future<void> _store(int studyId, int micros) =>
      MeasurementRepository(_db, now: now).insert(
        studyId,
        MeasurementDraft(
          cycle: 1,
          stepId: null,
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: micros,
          durationMicros: micros,
        ),
      );
}

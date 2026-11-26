import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/cycles.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

const _s = 1000000;

/// Step timer times all live in cycle 0. A device reboot restarts the clock,
/// so a later time can have a smaller end than an earlier one.
void main() {
  late AppDatabase db;
  late MeasurementRepository repo;
  late int studyId;
  late List<int> stepIds;

  setUp(() async {
    db = await openTestDatabase();
    repo = MeasurementRepository(db);
    final studies = StudyRepository(db);
    studyId = await studies.createStudy(
      name: 'Timer',
      mode: StudyMode.stepTimer,
      steps: ['A', 'B'],
      now: DateTime(2026),
    );
    stepIds = (await studies.getSteps(studyId)).map((s) => s.id).toList();
  });

  tearDown(() => db.close());

  MeasurementDraft draft(int step, int endSeconds, int seconds) =>
      MeasurementDraft(
        cycle: 0,
        stepId: stepIds[step],
        kind: MeasurementKind.normal,
        startMicros: (endSeconds - seconds) * _s,
        endMicros: endSeconds * _s,
        durationMicros: seconds * _s,
      );

  Future<void> recordAcrossReboot() async {
    await repo.insert(studyId, draft(0, 9010, 10)); // A, before the reboot
    await repo.insert(studyId, draft(1, 60, 5)); // B, after the reboot
  }

  test('times keep the order they were recorded in', () async {
    await recordAcrossReboot();
    final list = await repo.listForStudy(studyId);
    expect(list.map((m) => m.stepId), [stepIds[0], stepIds[1]]);
    final group = groupCycles(list, stepIds: stepIds).single;
    expect(group.items.map((m) => m.stepId), [stepIds[0], stepIds[1]]);
  });

  test('undo of a deleted time puts it back in its place', () async {
    await recordAcrossReboot();
    await repo.insert(studyId, draft(0, 70, 3));
    final first = (await repo.listForStudy(studyId)).first;
    final removed = await repo.deleteById(first.id);
    await repo.restore(removed);
    final list = await repo.listForStudy(studyId);
    expect(list.map((m) => m.durationMicros), [10 * _s, 5 * _s, 3 * _s]);
  });

  test('an archived revision keeps the order', () async {
    await recordAcrossReboot();
    await RevisionRepository(db).startNewRevision(studyId, now: DateTime(2026));
    final revision = (await RevisionRepository(db).listRevisions(studyId))
        .single;
    expect(revision.measurements.map((m) => m.stepId), [
      stepIds[0],
      stepIds[1],
    ]);
  });

  test('cycles of other modes still sort by their end', () async {
    final timeStudy = await StudyRepository(db).createStudy(
      name: 'T',
      mode: StudyMode.timeStudy,
      steps: ['A', 'B'],
      now: DateTime(2026),
    );
    final ids = (await StudyRepository(db).getSteps(timeStudy))
        .map((s) => s.id)
        .toList();
    MeasurementDraft d(int step, int end) => MeasurementDraft(
      cycle: 1,
      stepId: ids[step],
      kind: MeasurementKind.normal,
      startMicros: (end - 1) * _s,
      endMicros: end * _s,
      durationMicros: _s,
    );
    // A moved video marker: stored later, but earlier on the timeline.
    await repo.insert(timeStudy, d(1, 20));
    await repo.insert(timeStudy, d(0, 10));
    final list = await repo.listForStudy(timeStudy);
    expect(list.map((m) => m.endMicros), [10 * _s, 20 * _s]);
  });
}

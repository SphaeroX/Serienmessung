import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_clock.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late StudyRepository studies;
  late MeasurementRepository measurements;
  late int studyId;
  late List<int> ids;

  setUp(() async {
    db = await openTestDatabase();
    studies = StudyRepository(db);
    measurements = MeasurementRepository(db);
    studyId = await studies.createStudy(
      name: 'S',
      mode: StudyMode.timeStudy,
      steps: ['A', 'B', 'C'],
      now: DateTime(2026),
    );
    ids = (await studies.getSteps(studyId)).map((s) => s.id).toList();
    for (final id in ids) {
      await measurements.insert(
        studyId,
        MeasurementDraft(
          cycle: 1,
          stepId: id,
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: id,
          durationMicros: 1,
        ),
      );
    }
  });

  tearDown(() => db.close());

  test('reordering changes positions, measurements keep their step', () async {
    await studies.reorderSteps(studyId, [ids[2], ids[0], ids[1]]);
    final steps = await studies.getSteps(studyId);
    expect(steps.map((s) => s.name), ['C', 'A', 'B']);
    expect(steps.map((s) => s.position), [0, 1, 2]);
    final m = await measurements.listForStudy(studyId);
    expect(m.map((x) => x.stepId).toSet(), ids.toSet());
  });

  test('renaming keeps the id', () async {
    await studies.renameStep(ids[1], 'Place part');
    final steps = await studies.getSteps(studyId);
    expect(steps[1].id, ids[1]);
    expect(steps[1].name, 'Place part');
  });

  test('added steps are appended at the end', () async {
    final id = await studies.addStep(studyId, 'D');
    final steps = await studies.getSteps(studyId);
    expect(steps.last.id, id);
    expect(steps.last.position, 3);
  });

  test('deleting a step also deletes its times', () async {
    expect(await studies.countStepTimes(ids[0]), 1);
    await studies.deleteStep(ids[0]);
    final steps = await studies.getSteps(studyId);
    expect(steps.map((s) => s.name), ['B', 'C']);
    expect(steps.map((s) => s.position), [0, 1]);
    expect((await measurements.listForStudy(studyId)).length, 2);
  });

  test('engine uses the new order for the next cycle', () async {
    await studies.reorderSteps(studyId, [ids[1], ids[0], ids[2]]);
    final seq = (await studies.getSteps(studyId)).map<int?>((s) => s.id);
    final engine = RecordingEngine(clock: FakeClock(), sequence: seq.toList());
    engine.start(cycle: 2);
    expect(engine.currentStepId, ids[1]);
  });

  test('study name and description can be changed', () async {
    await studies.updateStudy(studyId, name: 'New', description: 'Desc');
    final s = (await studies.getStudy(studyId))!;
    expect((s.name, s.description), ('New', 'Desc'));
  });
}

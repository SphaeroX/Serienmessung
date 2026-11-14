import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/step_text_sync.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

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
          endMicros: 1,
          durationMicros: 1,
        ),
      );
    }
  });

  tearDown(() => db.close());

  Future<StepTextPlan> plan(String text) async =>
      planStepText(await studies.getSteps(studyId), text);

  test('applies renames, order and deleted steps at once', () async {
    await studies.applyStepPlan(studyId, await plan('C\nA2'));
    final steps = await studies.getSteps(studyId);
    expect(steps.map((s) => s.name), ['C', 'A2']);
    expect(steps.map((s) => s.position), [0, 1]);
    expect(steps.map((s) => s.id), [ids[2], ids[0]]);
    final m = await measurements.listForStudy(studyId);
    expect(m.map((x) => x.stepId).toSet(), {ids[0], ids[2]});
  });

  test('new lines are inserted at their position', () async {
    await studies.applyStepPlan(studyId, await plan('A\nD\nB\nC'));
    final steps = await studies.getSteps(studyId);
    expect(steps.map((s) => s.name), ['A', 'D', 'B', 'C']);
    expect(steps.map((s) => s.position), [0, 1, 2, 3]);
    expect((await measurements.listForStudy(studyId)).length, 3);
  });

  test('times of deleted steps are counted before applying', () async {
    expect(await studies.countTimesOfSteps((await plan('A')).deletedIds), 2);
  });
}

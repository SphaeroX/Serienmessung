import 'dart:io';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late StudyRepository studies;
  late RevisionRepository revisions;
  late int studyId;
  late List<int> stepIds;
  var now = DateTime(2026, 3, 1, 8);

  MeasurementRepository times() => MeasurementRepository(db, now: () => now);

  setUp(() async {
    db = await openTestDatabase();
    studies = StudyRepository(db);
    revisions = RevisionRepository(db);
    studyId = await studies.createStudy(
      name: 'Saw',
      mode: StudyMode.timeStudy,
      steps: ['Load', 'Cut'],
      now: DateTime(2026),
    );
    stepIds = [for (final s in await studies.getSteps(studyId)) s.id];
  });

  tearDown(() => db.close());

  Future<void> record(int cycle, int step, int micros, {String note = ''}) =>
      times().insert(
        studyId,
        MeasurementDraft(
          cycle: cycle,
          stepId: stepIds[step],
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: micros,
          durationMicros: micros,
          note: note,
        ),
      );

  test('stored times carry the wall-clock time they were recorded', () async {
    now = DateTime(2026, 3, 1, 8, 15);
    await record(1, 0, 10);
    final m = (await MeasurementRepository(db).listForStudy(studyId)).single;
    expect(m.recordedAt, DateTime(2026, 3, 1, 8, 15));
  });

  test('a study starts at revision 1 without archived revisions', () async {
    expect((await studies.getStudy(studyId))!.revision, 1);
    expect(await revisions.listRevisions(studyId), isEmpty);
    expect(await revisions.lastRecordedAt(studyId), isNull);
  });

  test(
    'last recorded time is the newest time of the current revision',
    () async {
      now = DateTime(2026, 3, 1, 8);
      await record(1, 0, 10);
      now = DateTime(2026, 3, 2, 9);
      await record(1, 1, 20);
      expect(await revisions.lastRecordedAt(studyId), DateTime(2026, 3, 2, 9));
    },
  );

  test(
    'old times without a timestamp fall back to the last activity',
    () async {
      await MeasurementRepository(db).insert(
        studyId,
        MeasurementDraft(
          cycle: 1,
          stepId: stepIds[0],
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: 1,
          durationMicros: 1,
        ),
      );
      await studies.touch(studyId, DateTime(2025, 12, 24));
      expect(await revisions.lastRecordedAt(studyId), DateTime(2025, 12, 24));
    },
  );

  test(
    'a new revision archives steps and times and empties the study',
    () async {
      now = DateTime(2026, 3, 1, 8);
      await record(1, 0, 10, note: 'jam');
      now = DateTime(2026, 3, 2, 9);
      await record(1, 1, 20);
      await studies.setCycleTimeMethod(studyId, 'mean');
      await RunStateRepository(db).save(
        studyId,
        const EngineSnapshot(
          status: EngineStatus.paused,
          cycle: 2,
          stepIndex: 0,
          currentStepId: null,
          stepStartMicros: 0,
          segmentStartMicros: 0,
          accumulatedMicros: 0,
          specialStartMicros: 0,
        ),
        clockMicros: 0,
        now: now,
      );

      final number = await revisions.startNewRevision(
        studyId,
        now: DateTime(2027, 3, 1),
      );

      expect(number, 2);
      expect((await studies.getStudy(studyId))!.revision, 2);
      expect(await MeasurementRepository(db).listForStudy(studyId), isEmpty);
      expect(await RunStateRepository(db).load(studyId), isNull);
      expect(await studies.getSteps(studyId), hasLength(2));
      expect(await revisions.lastRecordedAt(studyId), isNull);

      final archived = (await revisions.listRevisions(studyId)).single;
      expect(archived.number, 1);
      expect(archived.closedAt, DateTime(2027, 3, 1));
      expect(archived.firstRecordedAt, DateTime(2026, 3, 1, 8));
      expect(archived.lastRecordedAt, DateTime(2026, 3, 2, 9));
      expect(archived.cycleTimeMethod, 'mean');
      expect(archived.steps.map((s) => (s.id, s.name)), [
        (stepIds[0], 'Load'),
        (stepIds[1], 'Cut'),
      ]);
      expect(
        archived.measurements.map((m) => (m.stepId, m.durationMicros, m.note)),
        [(stepIds[0], 10, 'jam'), (stepIds[1], 20, '')],
      );
      expect(archived.measurements.first.recordedAt, DateTime(2026, 3, 1, 8));
    },
  );

  test('without times no empty revision is created', () async {
    expect(
      await revisions.startNewRevision(studyId, now: DateTime(2027)),
      isNull,
    );
    expect(await revisions.listRevisions(studyId), isEmpty);
    expect((await studies.getStudy(studyId))!.revision, 1);
  });

  test('revisions are listed newest first and keep old step names', () async {
    await record(1, 0, 10);
    await revisions.startNewRevision(studyId, now: DateTime(2027));
    await studies.renameStep(stepIds[0], 'Load part');
    await record(1, 0, 12);
    await revisions.startNewRevision(studyId, now: DateTime(2028));

    final list = await revisions.listRevisions(studyId);
    expect(list.map((r) => r.number), [2, 1]);
    expect(list.last.steps.first.name, 'Load');
    expect(list.first.steps.first.name, 'Load part');
    expect((await revisions.latestRevision(studyId))!.number, 2);
    expect((await studies.getStudy(studyId))!.revision, 3);
  });

  test('a revision can be deleted', () async {
    await record(1, 0, 10);
    await revisions.startNewRevision(studyId, now: DateTime(2027));
    final r = (await revisions.listRevisions(studyId)).single;
    await revisions.deleteRevision(r.id);
    expect(await revisions.listRevisions(studyId), isEmpty);
  });

  test('copying a study copies its revisions with remapped steps', () async {
    await record(1, 1, 10);
    await revisions.startNewRevision(studyId, now: DateTime(2027));
    await record(1, 1, 12);

    final copy = await studies.copyStudy(
      studyId,
      name: 'Saw (copy)',
      now: DateTime(2027, 2),
    );

    expect((await studies.getStudy(copy))!.revision, 2);
    final copySteps = await studies.getSteps(copy);
    final archived = (await revisions.listRevisions(copy)).single;
    expect(archived.steps.map((s) => s.id), [for (final s in copySteps) s.id]);
    expect(archived.measurements.single.stepId, copySteps[1].id);
    expect(
      (await revisions.listRevisions(studyId)).single.steps.first.id,
      stepIds[0],
    );
  });

  test('migration to schema 10 starts old studies at revision 1', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig10');
    final file = path.join(dir.path, 'm.db');
    final v9 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 9,
    );
    final id = await v9.db.insert('study', {
      'name': 'Old',
      'description': '',
      'mode': 'timeStudy',
      'created_at': 0,
      'last_active_at': 0,
    });
    await v9.db.insert('measurement', {
      'study_id': id,
      'cycle': 1,
      'kind': 'normal',
      'start_us': 0,
      'end_us': 1,
      'duration_us': 1,
    });
    await v9.close();

    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    expect((await StudyRepository(latest).getStudy(id))!.revision, 1);
    final m = (await MeasurementRepository(latest).listForStudy(id)).single;
    expect(m.recordedAt, isNull);
    expect(await RevisionRepository(latest).listRevisions(id), isEmpty);
    await latest.close();
    await dir.delete(recursive: true);
  });
}

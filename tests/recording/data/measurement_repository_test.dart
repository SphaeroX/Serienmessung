import 'dart:io';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/recording/domain/recording_session.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fakes/fake_clock.dart';
import '../../helpers.dart';

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
      name: 'S',
      mode: StudyMode.timeStudy,
      steps: ['A', 'B'],
      now: DateTime(2026),
    );
    stepIds = (await studies.getSteps(studyId)).map((s) => s.id).toList();
  });

  tearDown(() => db.close());

  test('session persists every completed measurement immediately', () async {
    final clock = FakeClock();
    final session = RecordingSession(
      studyId: studyId,
      engine: RecordingEngine(clock: clock, sequence: stepIds),
      measurements: repo,
    );
    await session.start();
    clock.advanceSeconds(1);
    await session.next();
    expect((await repo.listForStudy(studyId)).length, 1);
    clock.advanceSeconds(2);
    await session.next();
    clock.advanceSeconds(3);
    await session.next();

    final all = await repo.listForStudy(studyId);
    expect(all.map((m) => (m.cycle, m.stepId, m.durationMicros)).toList(), [
      (1, stepIds[0], 1000000),
      (1, stepIds[1], 2000000),
      (2, stepIds[0], 3000000),
    ]);
  });

  test('a new session continues after the last stored cycle', () async {
    await repo.insert(
      studyId,
      const MeasurementDraft(
        cycle: 4,
        stepId: null,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: 1,
        durationMicros: 1,
      ),
    );
    expect(await repo.nextCycle(studyId), 5);
    final session = RecordingSession(
      studyId: studyId,
      engine: RecordingEngine(clock: FakeClock(), sequence: stepIds),
      measurements: repo,
    );
    await session.start();
    expect(session.engine.cycle, 5);
  });

  test('migration from schema 1 keeps existing studies', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig');
    final path = p.join(dir.path, 'm.db');
    final v1 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
      version: 1,
    );
    await StudyRepository(v1).createStudy(
      name: 'Old',
      mode: StudyMode.timeStudy,
      steps: ['A'],
      now: DateTime(2026),
    );
    await v1.close();

    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final list = await StudyRepository(latest).listStudies();
    expect(list.single.study.name, 'Old');
    expect(
      await MeasurementRepository(latest).listForStudy(list.single.study.id),
      isEmpty,
    );
    await latest.close();
    await dir.delete(recursive: true);
  });
}

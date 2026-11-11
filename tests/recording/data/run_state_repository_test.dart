import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late RunStateRepository repo;
  late int studyId;

  const snap = EngineSnapshot(
    status: EngineStatus.special,
    cycle: 3,
    stepIndex: 1,
    currentStepId: 7,
    stepStartMicros: 10,
    segmentStartMicros: 20,
    accumulatedMicros: 30,
    specialStartMicros: 40,
  );

  setUp(() async {
    db = await openTestDatabase();
    repo = RunStateRepository(db);
    studyId = await StudyRepository(db).createStudy(
      name: 'Running',
      mode: StudyMode.timeStudy,
      steps: ['A'],
      now: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  test('saves, loads and deletes the run state of a study', () async {
    expect(await repo.load(studyId), isNull);
    await repo.save(studyId, snap, clockMicros: 99, now: DateTime(2026, 5));
    final rs = (await repo.load(studyId))!;
    expect(rs.snapshot.status, EngineStatus.special);
    expect(rs.snapshot.specialStartMicros, 40);
    expect(rs.savedClockMicros, 99);

    await repo.save(studyId, snap, clockMicros: 100, now: DateTime(2026, 5));
    expect((await repo.load(studyId))!.savedClockMicros, 100);

    await repo.delete(studyId);
    expect(await repo.load(studyId), isNull);
  });

  test('lists active runs with study names', () async {
    await repo.save(studyId, snap, clockMicros: 1, now: DateTime(2026));
    final runs = await repo.activeRuns();
    expect(runs.single.studyId, studyId);
    expect(runs.single.studyName, 'Running');
  });

  test('run state is removed with its study', () async {
    await repo.save(studyId, snap, clockMicros: 1, now: DateTime(2026));
    await StudyRepository(db).deleteStudy(studyId);
    expect(await repo.activeRuns(), isEmpty);
  });
}

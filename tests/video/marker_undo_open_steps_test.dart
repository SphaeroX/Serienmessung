import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/recording/presentation/recording_controller.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/video/domain/video_clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_platform.dart';
import '../helpers.dart';

const _s = 1000000;

/// Undoing markers while the steps are still open (first cycle of a video
/// study without steps), and markers at the same position.
void main() {
  late AppDatabase db;
  late StudyRepository repo;
  late int studyId;
  late int position;

  setUp(() async {
    db = await openTestDatabase();
    repo = StudyRepository(db);
    position = 0;
    studyId = await repo.createStudy(
      name: 'Video',
      mode: StudyMode.video,
      steps: const [],
      now: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  RecordingController build() => RecordingController(
    studyId: studyId,
    studies: repo,
    measurementRepo: MeasurementRepository(db),
    runStates: RunStateRepository(db),
    clock: VideoClock(() => position),
    feedback: FakeDeviceFeedback(),
    wallClock: () => DateTime(2026),
    detectReboot: false,
  )..newStepName = (n) => 'Step $n';

  Future<bool> markAt(RecordingController c, int seconds) {
    position = seconds * _s;
    return c.mark();
  }

  test('undoing one marker too many removes the step it created', () async {
    final c = build();
    await c.load();
    await markAt(c, 1); // start, step 1
    await markAt(c, 2); // step 1 done, step 2
    await markAt(c, 3); // one too many: step 2 done, step 3
    expect(c.steps, hasLength(3));

    await c.undoLastMarker();
    expect(c.steps.map((st) => st.name), ['Step 1', 'Step 2']);
    expect((await repo.getSteps(studyId)), hasLength(2));
    expect(c.currentStep!.name, 'Step 2');
    expect(c.status, EngineStatus.running);

    position = 4 * _s;
    expect(await c.closeCycle(), isTrue);
    final stored = await MeasurementRepository(db).listForStudy(studyId);
    expect(stored.map((m) => m.durationMicros), [_s, 2 * _s]);
    expect((await repo.getStudy(studyId))!.stepsOpen, isFalse);
  });

  test('undoing every marker returns to idle without steps', () async {
    final c = build();
    await c.load();
    await markAt(c, 1);
    await markAt(c, 2);
    await c.undoLastMarker();
    await c.undoLastMarker();
    expect(c.status, EngineStatus.idle);
    expect(c.steps, isEmpty);
    expect(await repo.getSteps(studyId), isEmpty);
    expect(await MeasurementRepository(db).listForStudy(studyId), isEmpty);
  });

  test('a step that already has times is not removed', () async {
    final c = build();
    await c.load();
    await markAt(c, 1);
    await markAt(c, 2); // step 1 has a time, step 2 runs
    await c.resetMarkers(); // marker run dropped, the time is kept
    await markAt(c, 5); // starts step 1 again
    await c.undoLastMarker(); // undoes only the start marker
    expect(c.status, EngineStatus.idle);
    // Step 1 keeps its time; step 2 never had one.
    expect(c.steps.map((st) => st.name), ['Step 1']);
    expect(await MeasurementRepository(db).listForStudy(studyId), hasLength(1));
  });

  test('a second marker at the same position is rejected', () async {
    final c = build();
    await c.load();
    await markAt(c, 1);
    await markAt(c, 2);
    expect(await markAt(c, 2), isFalse);
    expect(c.steps, hasLength(2));
    final stored = await MeasurementRepository(db).listForStudy(studyId);
    expect(stored.map((m) => m.durationMicros), [_s]);
    expect(c.canMarkAt(2 * _s), isFalse);
    expect(c.canMarkAt(2 * _s + 1), isTrue);
  });

  test('closing the cycle at the last marker is rejected', () async {
    final c = build();
    await c.load();
    await markAt(c, 1);
    await markAt(c, 2);
    position = 2 * _s;
    expect(await c.closeCycle(), isFalse);
    expect((await repo.getStudy(studyId))!.stepsOpen, isTrue);
  });
}

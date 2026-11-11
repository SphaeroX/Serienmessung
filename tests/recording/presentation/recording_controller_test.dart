import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/recording/presentation/recording_controller.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_clock.dart';
import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late int studyId;
  late FakeClock clock;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock(500 * s);
    studyId = await StudyRepository(db).createStudy(
      name: 'S',
      mode: StudyMode.timeStudy,
      steps: ['A', 'B', 'C'],
      now: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  RecordingController build() => RecordingController(
    studyId: studyId,
    studies: StudyRepository(db),
    measurementRepo: MeasurementRepository(db),
    runStates: RunStateRepository(db),
    clock: clock,
    feedback: FakeDeviceFeedback(),
    wallClock: () => DateTime(2026),
  );

  test('a running recording continues after the app was restarted', () async {
    final first = build();
    await first.load();
    await first.startStop();
    clock.advanceSeconds(2);
    await first.next();
    clock.advanceSeconds(3);
    first.dispose();

    // App killed and reopened 10 s later (same monotonic clock base).
    clock.advanceSeconds(10);
    final second = build();
    await second.load();
    expect(second.status, EngineStatus.running);
    expect(second.currentStep!.name, 'B');
    expect(second.engine.currentStepElapsed(), 13 * s);
    expect(second.totalElapsed(), 15 * s);

    await second.next();
    final stored = await MeasurementRepository(db).listForStudy(studyId);
    expect(stored.map((m) => m.durationMicros), [2 * s, 13 * s]);
  });

  test('restores a running special time', () async {
    final first = build();
    await first.load();
    await first.startStop();
    clock.advanceSeconds(1);
    await first.beginSpecial();
    clock.advanceSeconds(4);

    final second = build();
    await second.load();
    expect(second.status, EngineStatus.special);
    expect(second.engine.specialElapsed(), 4 * s);
    await second.endSpecial();
    expect(second.measurements.single.durationMicros, 4 * s);
  });

  test('state is cleared after reset', () async {
    final c = build();
    await c.load();
    await c.startStop();
    expect(await RunStateRepository(db).load(studyId), isNotNull);
    await c.reset();
    expect(await RunStateRepository(db).load(studyId), isNull);
  });

  test('a device reboot discards the unfinished step', () async {
    final c = build();
    await c.load();
    await c.startStop();
    clock.advanceSeconds(5);

    // After a reboot the monotonic clock starts again near zero.
    clock.micros = 3 * s;
    final after = build();
    await after.load();
    expect(after.status, EngineStatus.idle);
    expect(after.interruptedByReboot, isTrue);
    expect(await RunStateRepository(db).load(studyId), isNull);
  });

  test('no saved run means a fresh idle recording', () async {
    final c = build();
    await c.load();
    expect(c.status, EngineStatus.idle);
    expect(c.interruptedByReboot, isFalse);
  });
}

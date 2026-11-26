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

const _s = 1000000;
const _min = 60 * _s;

/// A reboot restarts the monotonic clock near zero. When the device then runs
/// longer than it had when the run was saved, only the wall clock reveals it.
void main() {
  late AppDatabase db;
  late int studyId;
  late FakeClock clock;
  late DateTime wall;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock(5 * _min);
    wall = DateTime(2026, 11, 20, 8);
    studyId = await StudyRepository(db).createStudy(
      name: 'S',
      mode: StudyMode.timeStudy,
      steps: ['A', 'B'],
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
    wallClock: () => wall,
  );

  void elapse(Duration d) {
    clock.advance(d);
    wall = wall.add(d);
  }

  test('a reboot is found when the clock has passed the saved value', () async {
    final first = build();
    await first.load();
    await first.startStop();
    elapse(const Duration(seconds: 4));
    await first.next();
    first.dispose();

    // Two days later, the rebooted device has been up for 10 minutes.
    clock.micros = 10 * _min;
    wall = wall.add(const Duration(days: 2));
    final after = build();
    await after.load();
    expect(after.interruptedByReboot, isTrue);
    expect(after.status, EngineStatus.idle);
    expect(await RunStateRepository(db).load(studyId), isNull);
    final stored = await MeasurementRepository(db).listForStudy(studyId);
    expect(stored.map((m) => m.durationMicros), [4 * _s]);
  });

  test('a restart without reboot continues the run', () async {
    final first = build();
    await first.load();
    await first.startStop();
    elapse(const Duration(seconds: 2));
    first.dispose();

    elapse(const Duration(seconds: 10));
    final second = build();
    await second.load();
    expect(second.interruptedByReboot, isFalse);
    expect(second.status, EngineStatus.running);
    expect(second.engine.currentStepElapsed(), 12 * _s);
  });

  test('a long pause without reboot keeps the run', () async {
    final first = build();
    await first.load();
    await first.startStop();
    elapse(const Duration(seconds: 3));
    await first.startStop(); // pause
    first.dispose();

    elapse(const Duration(hours: 20));
    final second = build();
    await second.load();
    expect(second.interruptedByReboot, isFalse);
    expect(second.status, EngineStatus.paused);
  });

  test('a paused run is dropped after a reboot like a running one', () async {
    final first = build();
    await first.load();
    await first.startStop();
    elapse(const Duration(seconds: 3));
    await first.startStop(); // pause
    first.dispose();

    clock.micros = 30 * _min;
    wall = wall.add(const Duration(hours: 5));
    final after = build();
    await after.load();
    expect(after.interruptedByReboot, isTrue);
    expect(after.status, EngineStatus.idle);
  });

  test('a small difference between the clocks is no reboot', () async {
    final first = build();
    await first.load();
    await first.startStop();
    first.dispose();

    // The wall clock was corrected by a minute meanwhile.
    clock.advance(const Duration(minutes: 30));
    wall = wall.add(const Duration(minutes: 31));
    final second = build();
    await second.load();
    expect(second.interruptedByReboot, isFalse);
    expect(second.status, EngineStatus.running);
  });

  test('video studies never detect a reboot', () async {
    final first = build();
    await first.load();
    await first.startStop(at: 0);
    first.dispose();

    clock.micros = 10 * _min;
    wall = wall.add(const Duration(days: 2));
    final video = RecordingController(
      studyId: studyId,
      studies: StudyRepository(db),
      measurementRepo: MeasurementRepository(db),
      runStates: RunStateRepository(db),
      clock: clock,
      feedback: FakeDeviceFeedback(),
      wallClock: () => wall,
      detectReboot: false,
    );
    await video.load();
    expect(video.interruptedByReboot, isFalse);
    expect(video.status, EngineStatus.running);
  });
}

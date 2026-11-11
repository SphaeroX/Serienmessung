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

const s = 1000000;

void main() {
  late AppDatabase db;
  late int studyId;
  late int position;

  setUp(() async {
    db = await openTestDatabase();
    position = 0;
    studyId = await StudyRepository(db).createStudy(
      name: 'Video',
      mode: StudyMode.video,
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
    clock: VideoClock(() => position),
    feedback: FakeDeviceFeedback(),
    wallClock: () => DateTime(2026),
    detectReboot: false,
  );

  test('markers at 2.0 / 5.5 / 9.0 s give step times in video time', () async {
    final c = build();
    await c.load();
    position = 2 * s;
    await c.mark();
    position = 5500000;
    await c.mark();
    position = 9 * s;
    await c.mark();
    expect(c.measurements.map((m) => (m.cycle, m.durationMicros)).toList(), [
      (1, 3500000),
      (1, 3500000),
    ]);
    expect(c.currentStep!.name, 'A');
    expect(c.engine.cycle, 2);
  });

  test('playback speed does not change durations (video time)', () async {
    // Same positions, whatever the real time between the presses was.
    final c = build();
    await c.load();
    position = 0;
    await c.mark();
    position = 4 * s;
    await c.mark();
    expect(c.measurements.single.durationMicros, 4 * s);
  });

  test('a marker before the last marker is rejected', () async {
    final c = build();
    await c.load();
    position = 5 * s;
    await c.mark();
    position = 3 * s;
    expect(c.canMarkAt(position), isFalse);
    expect(await c.mark(), isFalse);
    expect(c.measurements, isEmpty);
  });

  test('undo removes the last marker and continues from there', () async {
    final c = build();
    await c.load();
    position = 1 * s;
    await c.mark();
    position = 3 * s;
    await c.mark();
    position = 6 * s;
    await c.mark();
    expect(c.measurements.length, 2);

    await c.undoLastMarker();
    expect(c.measurements.length, 1);
    expect(c.currentStep!.name, 'B');
    expect(c.engine.cycle, 1);
    position = 7 * s;
    await c.mark();
    expect(c.measurements.last.durationMicros, 4 * s);
  });

  test('undo of the start marker returns to idle', () async {
    final c = build();
    await c.load();
    position = 1 * s;
    await c.mark();
    await c.undoLastMarker();
    expect(c.status, EngineStatus.idle);
  });

  test(
    'restoring after reopening does not treat video time as reboot',
    () async {
      final c = build();
      await c.load();
      position = 10 * s;
      await c.mark();
      position = 0; // video reopened at the beginning
      final again = build();
      await again.load();
      expect(again.status, EngineStatus.running);
      expect(again.interruptedByReboot, isFalse);
      expect(again.markerPosition, 10 * s);
    },
  );

  test('key press time is converted to the video position', () {
    expect(
      videoPositionAt(
        keyAtMonotonic: 900,
        nowMonotonic: 1000,
        videoNow: 5000,
        playing: true,
        speed: 2,
      ),
      4800,
    );
    expect(
      videoPositionAt(
        keyAtMonotonic: 0,
        nowMonotonic: 1000,
        videoNow: 5000,
        playing: false,
        speed: 1,
      ),
      5000,
    );
  });
}

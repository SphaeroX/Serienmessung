import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
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
  group('engine', () {
    test('reopening a step keeps its special times excluded', () {
      final e = RecordingEngine(clock: FakeClock(), sequence: [1, 2]);
      e.start(cycle: 1, at: 0);
      e.beginSpecial(at: 10 * s);
      final special = e.endSpecial(at: 15 * s);
      final done = e.next(at: 20 * s).single;
      expect(done.durationMicros, 15 * s);

      e.rewindTo(done, specials: special);
      expect(e.status, EngineStatus.running);
      expect(e.currentStepId, 1);
      expect(e.stepStartMicros, 0);
      // Timing continues behind the special time.
      expect(e.segmentStartMicros, 15 * s);
      expect(e.currentStepElapsed(20 * s), 15 * s);

      final again = e.next(at: 25 * s).single;
      expect(again.startMicros, 0);
      expect(again.endMicros, 25 * s);
      expect(again.durationMicros, 20 * s);
    });

    test('several special times in the step', () {
      final e = RecordingEngine(clock: FakeClock(), sequence: [1, 2]);
      e.start(cycle: 1, at: 0);
      e.beginSpecial(at: 4 * s);
      final first = e.endSpecial(at: 6 * s);
      e.beginSpecial(at: 10 * s);
      final second = e.endSpecial(at: 13 * s);
      final done = e.next(at: 20 * s).single;
      expect(done.durationMicros, 15 * s);
      e.rewindTo(done, specials: [...second, ...first]);
      expect(e.segmentStartMicros, 13 * s);
      expect(e.next(at: 20 * s).single.durationMicros, 15 * s);
    });

    test('without special times timing restarts at the step start', () {
      final e = RecordingEngine(clock: FakeClock(), sequence: [1, 2]);
      e.start(cycle: 1, at: 5 * s);
      final done = e.next(at: 20 * s).single;
      e.rewindTo(done);
      expect(e.segmentStartMicros, 5 * s);
      expect(e.next(at: 12 * s).single.durationMicros, 7 * s);
    });
  });

  group('controller', () {
    late AppDatabase db;
    late RecordingController c;

    setUp(() async {
      db = await openTestDatabase();
      final id = await StudyRepository(db).createStudy(
        name: 'V',
        mode: StudyMode.video,
        steps: ['A', 'B'],
        now: DateTime(2026),
      );
      c = RecordingController(
        studyId: id,
        studies: StudyRepository(db),
        measurementRepo: MeasurementRepository(db),
        runStates: RunStateRepository(db),
        clock: FakeClock(),
        feedback: FakeDeviceFeedback(),
        wallClock: () => DateTime(2026),
        detectReboot: false,
      );
      await c.load();
    });

    tearDown(() => db.close());

    List<int> normals() => [
      for (final m in c.measurements)
        if (m.kind == MeasurementKind.normal) m.durationMicros,
    ];

    test('undoing a marker does not count the special time twice', () async {
      await c.mark(at: 0);
      await c.beginSpecial(at: 10 * s);
      await c.endSpecial(at: 15 * s);
      await c.mark(at: 20 * s);
      expect(normals(), [15 * s]);

      await c.undoLastMarker();
      expect(normals(), isEmpty);
      // The special time stays; a marker inside it is not possible.
      expect(c.measurements.single.kind, MeasurementKind.special);
      expect(c.canMarkAt(12 * s), isFalse);
      expect(c.canMarkAt(16 * s), isTrue);

      await c.mark(at: 20 * s);
      expect(normals(), [15 * s]);
    });
  });
}

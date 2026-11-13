import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/presentation/recording_controller.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../export/export_test.dart' show labels;
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late int studyId;
  late FakeClock clock;
  final measuredAt = DateTime(2026, 5, 4, 10, 30);

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock(500 * s);
    studyId = await StudyRepository(db).createStudy(
      name: 'S',
      mode: StudyMode.timeStudy,
      steps: ['A', 'B'],
      now: DateTime(2020),
    );
  });

  tearDown(() => db.close());

  RecordingController build() => RecordingController(
    studyId: studyId,
    studies: StudyRepository(db),
    measurementRepo: MeasurementRepository(db, now: () => measuredAt),
    runStates: RunStateRepository(db),
    clock: clock,
    feedback: FakeDeviceFeedback(),
    wallClock: () => measuredAt,
  );

  test('times recorded just now carry their timestamp', () async {
    final c = build();
    await c.load();
    await c.startStop();
    clock.advanceSeconds(5);
    await c.next();
    expect(c.measurements.single.recordedAt, measuredAt);
  });

  test('a special time recorded just now carries its timestamp', () async {
    final c = build();
    await c.load();
    await c.startStop();
    clock.advanceSeconds(2);
    await c.beginSpecial();
    clock.advanceSeconds(3);
    await c.endSpecial();
    expect(c.measurements.single.kind, MeasurementKind.special);
    expect(c.measurements.single.recordedAt, measuredAt);
  });

  test('editing a note keeps the timestamp', () async {
    final c = build();
    await c.load();
    await c.startStop();
    clock.advanceSeconds(2);
    await c.beginSpecial();
    clock.advanceSeconds(3);
    await c.endSpecial();
    await c.updateNote(c.measurements.single.id, 'jam');
    expect(c.measurements.single.note, 'jam');
    expect(c.measurements.single.recordedAt, measuredAt);
  });

  test(
    'an export right after recording shows the time of measurement',
    () async {
      final c = build();
      await c.load();
      await c.startStop();
      clock.advanceSeconds(5);
      await c.next();
      final input = ExportInput(
        study: c.study!,
        steps: c.steps,
        measurements: c.measurements,
        unit: TimeUnit.seconds,
        method: CycleTimeMethod.median,
        locale: 'en',
        exportedAt: DateTime(2026, 5, 4, 11),
        labels: labels,
      );
      expect(input.lastMeasuredAt, measuredAt);
    },
  );
}

import 'dart:io';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/recording/presentation/recording_controller.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/video/domain/video_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fakes/fake_platform.dart';
import '../helpers.dart';

const s = 1000000;

/// Video studies start without steps: markers create the steps of the first
/// cycle, "close cycle" fixes them as the sequence.
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

  Future<void> markAt(RecordingController c, int at) async {
    position = at;
    expect(await c.mark(), isTrue);
  }

  test('a video study without steps has open steps', () async {
    expect((await repo.getStudy(studyId))!.stepsOpen, isTrue);
    final withSteps = await repo.createStudy(
      name: 'V2',
      mode: StudyMode.video,
      steps: const ['A'],
      now: DateTime(2026),
    );
    expect((await repo.getStudy(withSteps))!.stepsOpen, isFalse);
    final live = await repo.createStudy(
      name: 'T',
      mode: StudyMode.timeStudy,
      steps: const ['A'],
      now: DateTime(2026),
    );
    expect((await repo.getStudy(live))!.stepsOpen, isFalse);
  });

  test('markers create new steps until the cycle is closed', () async {
    final c = build();
    await c.load();
    expect(c.stepsOpen, isTrue);

    await markAt(c, 1 * s);
    expect(c.currentStep!.name, 'Step 1');
    await markAt(c, 3 * s);
    expect(c.currentStep!.name, 'Step 2');
    await markAt(c, 6 * s);
    expect(c.currentStep!.name, 'Step 3');
    expect(c.steps.map((st) => st.name), ['Step 1', 'Step 2', 'Step 3']);
    expect(c.engine.cycle, 1);

    position = 8 * s;
    expect(await c.closeCycle(), isTrue);
    expect(c.stepsOpen, isFalse);
    expect((await repo.getStudy(studyId))!.stepsOpen, isFalse);
    expect(c.engine.cycle, 2);
    expect(c.currentStep!.name, 'Step 1');
    expect(c.measurements.map((m) => (m.cycle, m.durationMicros)).toList(), [
      (1, 2 * s),
      (1, 3 * s),
      (1, 2 * s),
    ]);

    // From now on markers follow the fixed sequence.
    await markAt(c, 10 * s);
    await markAt(c, 11 * s);
    await markAt(c, 12 * s);
    expect(c.steps.length, 3);
    expect(c.engine.cycle, 3);
  });

  test('closing the cycle needs a running first cycle', () async {
    final c = build();
    await c.load();
    expect(await c.closeCycle(), isFalse);
    await markAt(c, 1 * s);
    position = 0;
    // Before the last marker.
    expect(await c.closeCycle(), isFalse);
    expect(c.stepsOpen, isTrue);
  });

  test('reopening continues the open first cycle', () async {
    final c = build();
    await c.load();
    await markAt(c, 1 * s);
    await markAt(c, 2 * s);
    c.dispose();

    final again = build();
    await again.load();
    expect(again.status, EngineStatus.running);
    expect(again.currentStep!.name, 'Step 2');
    await markAt(again, 4 * s);
    expect(again.currentStep!.name, 'Step 3');
  });

  test('after undo a marker reuses the next existing step', () async {
    final c = build();
    await c.load();
    await markAt(c, 1 * s);
    await markAt(c, 2 * s);
    await markAt(c, 3 * s);
    await c.undoLastMarker();
    expect(c.currentStep!.name, 'Step 2');
    await markAt(c, 4 * s);
    expect(c.currentStep!.name, 'Step 3');
    expect(c.steps.length, 3);
  });

  test('a time study can be created from the defined steps', () async {
    final c = build();
    await c.load();
    await markAt(c, 1 * s);
    await markAt(c, 2 * s);
    position = 3 * s;
    await c.closeCycle();
    await repo.renameStep(c.steps.first.id, 'Pick');

    final id = await repo.copyAsTimeStudy(
      studyId,
      name: 'Video (live)',
      now: DateTime(2026, 2),
    );
    final copy = (await repo.getStudy(id))!;
    expect(copy.mode, StudyMode.timeStudy);
    expect(copy.name, 'Video (live)');
    expect(copy.stepsOpen, isFalse);
    expect((await repo.getSteps(id)).map((st) => st.name), ['Pick', 'Step 2']);
  });

  test(
    'migration to schema 7 keeps old video studies with fixed steps',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('cyclescope_mig7');
      final file = path.join(dir.path, 'm.db');
      final v6 = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: file,
        version: 6,
      );
      await v6.db.insert('study', {
        'name': 'Old video',
        'description': '',
        'mode': 'video',
        'created_at': 0,
        'last_active_at': 0,
      });
      await v6.close();

      final latest = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: file,
      );
      final old = (await StudyRepository(latest).listStudies()).single.study;
      expect(old.name, 'Old video');
      expect(old.stepsOpen, isFalse);
      await latest.close();
      await dir.delete(recursive: true);
    },
  );
}

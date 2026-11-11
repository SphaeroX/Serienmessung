import 'dart:convert';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;

  Future<void> seed(AppDatabase db) async {
    final studies = StudyRepository(db);
    final id = await studies.createStudy(
      name: 'Line 200',
      description: 'Früh',
      mode: StudyMode.timeStudy,
      steps: ['Pick', 'Place'],
      now: DateTime(2026, 11, 11, 9),
      cycleTimeMethod: 'iqr',
    );
    final steps = await studies.getSteps(id);
    final repo = MeasurementRepository(db);
    await repo.insert(
      id,
      MeasurementDraft(
        cycle: 1,
        stepId: steps[0].id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: 10,
        durationMicros: 10,
      ),
    );
    await repo.insert(
      id,
      MeasurementDraft(
        cycle: 1,
        stepId: steps[1].id,
        kind: MeasurementKind.special,
        startMicros: 10,
        endMicros: 15,
        durationMicros: 5,
        note: 'Jam',
      ),
    );
    final video = await studies.createStudy(
      name: 'Video',
      mode: StudyMode.video,
      steps: ['A'],
      now: DateTime(2026, 11, 11, 10),
    );
    await studies.setVideoPath(video, '/videos/x.mp4');
    await studies.createStudy(
      name: 'Laps',
      mode: StudyMode.simple,
      steps: const [],
      now: DateTime(2026, 11, 11, 11),
    );
  }

  Future<List<String>> describe(AppDatabase db) async {
    final out = <String>[];
    for (final s in (await StudyRepository(db).listStudies()).reversed) {
      final st = s.study;
      final steps = await StudyRepository(db).getSteps(st.id);
      final names = {for (final x in steps) x.id: x.name};
      final ms = await MeasurementRepository(db).listForStudy(st.id);
      out.add(
        '${st.name}|${st.description}|${st.mode.name}|${st.createdAt}|'
        '${st.cycleTimeMethod}|${st.videoPath}|'
        '${steps.map((x) => '${x.position}:${x.name}').join(',')}|'
        '${ms.map((m) => '${m.cycle}/${names[m.stepId]}/${m.kind.name}/'
            '${m.startMicros}-${m.endMicros}/${m.durationMicros}/${m.note}').join(',')}',
      );
    }
    return out;
  }

  setUp(() async {
    source = await openTestDatabase();
    target = await openTestDatabase();
    await seed(source);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('round trip into an empty database gives identical data', () async {
    final json = await BackupService(source).exportJson(now: DateTime(2026));
    final r = await BackupService(target).importJson(json, replace: false);
    expect(r.imported, 3);
    expect(r.videoStudies, 1);
    expect(await describe(target), await describe(source));
  });

  test('merging twice does not create duplicates', () async {
    final json = await BackupService(source).exportJson(now: DateTime(2026));
    await BackupService(target).importJson(json, replace: false);
    final again = await BackupService(target).importJson(json, replace: false);
    expect((again.imported, again.skipped), (0, 3));
    expect((await StudyRepository(target).listStudies()).length, 3);
  });

  test('replace removes existing studies first', () async {
    await StudyRepository(target).createStudy(
      name: 'Local only',
      mode: StudyMode.simple,
      steps: const [],
      now: DateTime(2025),
    );
    final json = await BackupService(source).exportJson(now: DateTime(2026));
    await BackupService(target).importJson(json, replace: true);
    final names = (await StudyRepository(
      target,
    ).listStudies()).map((s) => s.study.name);
    expect(names, isNot(contains('Local only')));
    expect(names.length, 3);
  });

  test('a damaged file is rejected and changes nothing', () async {
    final json = await BackupService(source).exportJson(now: DateTime(2026));
    final broken = json.substring(0, json.length ~/ 2);
    expect(
      () => BackupService(source).importJson(broken, replace: true),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.invalid,
        ),
      ),
    );
    final wrong = jsonEncode({'format': 'other', 'version': 1, 'studies': []});
    expect(
      () => BackupService(source).importJson(wrong, replace: true),
      throwsA(isA<BackupException>()),
    );
    expect((await StudyRepository(source).listStudies()).length, 3);
  });

  test('a file from a newer app version is rejected', () async {
    final newer = jsonEncode({
      'format': backupFormat,
      'version': backupVersion + 1,
      'studies': [],
    });
    expect(
      () => BackupService(target).importJson(newer, replace: false),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.tooNew,
        ),
      ),
    );
  });

  test('a video study still defining its steps keeps that state', () async {
    final id = await StudyRepository(source).createStudy(
      name: 'Open video',
      mode: StudyMode.video,
      steps: const [],
      now: DateTime(2026, 11, 11, 12),
    );
    expect((await StudyRepository(source).getStudy(id))!.stepsOpen, isTrue);
    final json = await BackupService(source).exportJson(now: DateTime(2026));
    await BackupService(target).importJson(json, replace: false);
    final restored = (await StudyRepository(
      target,
    ).listStudies()).map((s) => s.study).toList();
    expect(
      restored.singleWhere((s) => s.name == 'Open video').stepsOpen,
      isTrue,
    );
    expect(restored.singleWhere((s) => s.name == 'Video').stepsOpen, isFalse);
  });
}

import 'dart:convert';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;

  Future<int> study(AppDatabase db, String name, DateTime created) async {
    final studies = StudyRepository(db);
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.timeStudy,
      steps: ['Load', 'Cut'],
      now: created,
    );
    return id;
  }

  Future<void> time(AppDatabase db, int studyId, int step, DateTime at) async {
    final steps = await StudyRepository(db).getSteps(studyId);
    await MeasurementRepository(db, now: () => at).insert(
      studyId,
      MeasurementDraft(
        cycle: 1,
        stepId: steps[step].id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: 7,
        durationMicros: 7,
      ),
    );
  }

  Future<void> seed(AppDatabase db) async {
    final groups = GroupRepository(db);
    final line = await groups.createGroup(
      name: 'Line 4',
      description: 'Assembly',
      now: DateTime(2025, 1, 1),
    );
    await groups.createGroup(name: 'Empty', now: DateTime(2025, 1, 2));
    final saw = await study(db, 'Saw', DateTime(2025, 2, 1));
    final drill = await study(db, 'Drill', DateTime(2025, 2, 2));
    await study(db, 'Loose', DateTime(2025, 2, 3));
    await groups.moveToGroup(saw, line);
    await groups.moveToGroup(drill, line);
    await groups.reorder(line, [drill, saw]);

    await time(db, saw, 1, DateTime(2025, 3, 1, 8));
    await RevisionRepository(db)
        .startNewRevision(saw, now: DateTime(2026, 3, 1));
    // A step deleted after the revision: the revision keeps it.
    final steps = await StudyRepository(db).getSteps(saw);
    await StudyRepository(db).deleteStep(steps[0].id);
    await time(db, saw, 0, DateTime(2026, 3, 2, 9));
  }

  /// Everything a backup must keep, independent of database ids.
  Future<List<String>> describe(AppDatabase db) async {
    final out = <String>[];
    for (final g in await GroupRepository(db).listGroups()) {
      final members = await StudyRepository(db)
          .listStudies(groupId: g.group.id);
      out.add(
        'group ${g.group.name}|${g.group.description}|${g.group.createdAt}|'
        '${members.map((m) => m.study.name).join(',')}',
      );
    }
    final studies = await StudyRepository(db).listStudies();
    for (final s in studies.reversed) {
      final st = s.study;
      final steps = await StudyRepository(db).getSteps(st.id);
      final names = {for (final x in steps) x.id: x.name};
      final ms = await MeasurementRepository(db).listForStudy(st.id);
      out.add(
        '${st.name}|${s.groupName}|rev ${st.revision}|'
        '${ms.map((m) => '${names[m.stepId]}/${m.durationMicros}/${m.recordedAt}').join(',')}',
      );
      for (final r in await RevisionRepository(db).listRevisions(st.id)) {
        final rNames = {for (final x in r.steps) x.id: x.name};
        // Revision steps still in use must point to the study's steps.
        final linked = r.steps.where((x) => names.containsKey(x.id));
        out.add(
          '  r${r.number}|${r.closedAt}|${r.firstRecordedAt}|'
          '${r.lastRecordedAt}|${r.steps.map((x) => x.name).join(',')}|'
          'linked ${linked.map((x) => x.name).join(',')}|'
          '${r.measurements.map((m) => '${rNames[m.stepId]}/${m.durationMicros}/${m.recordedAt}').join(',')}',
        );
      }
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

  test('the backup has version 2 with groups and revisions', () async {
    final json = jsonDecode(
      await BackupService(source).exportJson(now: DateTime(2026)),
    ) as Map;
    expect(json['version'], 2);
    expect((json['groups'] as List).length, 2);
  });

  test('round trip keeps groups, order, revisions and timestamps', () async {
    final json = await BackupService(source).exportJson(now: DateTime(2026));
    await BackupService(target).importJson(json, replace: false);
    final expected = await describe(source);
    expect(
      expected,
      contains(
        'group Line 4|Assembly|2025-01-01 00:00:00.000|'
        'Drill,Saw',
      ),
    );
    expect(expected.any((e) => e.startsWith('  r1|')), isTrue);
    expect(await describe(target), expected);
  });

  test('merging twice creates no duplicate groups', () async {
    final json = await BackupService(source).exportJson(now: DateTime(2026));
    await BackupService(target).importJson(json, replace: false);
    await BackupService(target).importJson(json, replace: false);
    expect((await GroupRepository(target).listGroups()).length, 2);
  });

  test(
    'merging appends behind studies already in a group of that name',
    () async {
      final groups = GroupRepository(target);
      final line = await groups.createGroup(
        name: 'Line 4',
        now: DateTime(2024),
      );
      final local = await study(target, 'Local press', DateTime(2024));
      await groups.moveToGroup(local, line);

      final json = await BackupService(source).exportJson(now: DateTime(2026));
      await BackupService(target).importJson(json, replace: false);

      expect((await groups.listGroups()).length, 2);
      final members = await StudyRepository(target).listStudies(groupId: line);
      expect(members.map((m) => m.study.name), ['Local press', 'Drill', 'Saw']);
    },
  );

  test('replace removes groups and revisions first', () async {
    final groups = GroupRepository(target);
    await groups.createGroup(name: 'Old', now: DateTime(2024));
    final json = await BackupService(source).exportJson(now: DateTime(2026));
    await BackupService(target).importJson(json, replace: true);
    expect((await groups.listGroups()).map((g) => g.group.name).toSet(), {
      'Line 4',
      'Empty',
    });
    expect(await describe(target), await describe(source));
  });

  test('version 1 files are still imported', () async {
    const v1 = '''
{"format":"cyclescope-backup","version":1,"exportedAt":"2026-01-01",
 "studies":[{"name":"Old","description":"","mode":"timeStudy",
  "createdAt":0,"lastActiveAt":0,"cycleTimeMethod":null,"videoPath":null,
  "stepsOpen":false,"notes":"",
  "steps":[{"ref":5,"position":0,"name":"A"}],
  "measurements":[{"cycle":1,"stepRef":5,"kind":"normal","start":0,
   "end":3,"duration":3,"note":""}]}]}''';
    final r = await BackupService(target).importJson(v1, replace: false);
    expect(r.imported, 1);
    final s = (await StudyRepository(target).listStudies()).single;
    expect(s.study.revision, 1);
    expect(s.groupName, isNull);
    final m = (await MeasurementRepository(target).listForStudy(s.study.id))
        .single;
    expect(m.recordedAt, isNull);
  });

  test('a malformed revision rejects the file without changes', () async {
    final json = jsonDecode(
      await BackupService(source).exportJson(now: DateTime(2026)),
    ) as Map<String, dynamic>;
    final studies = json['studies'] as List;
    final saw = studies.firstWhere((s) => s['name'] == 'Saw') as Map;
    (saw['revisions'] as List).first['measurements'] = 'nope';
    await expectLater(
      BackupService(target).importJson(jsonEncode(json), replace: true),
      throwsA(isA<BackupException>()),
    );
    expect(await StudyRepository(target).listStudies(), isEmpty);
  });
}

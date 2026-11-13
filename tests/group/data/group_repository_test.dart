import 'dart:io';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late StudyRepository studies;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    studies = StudyRepository(db);
  });

  tearDown(() => db.close());

  Future<int> study(String name) => studies.createStudy(
    name: name,
    mode: StudyMode.timeStudy,
    steps: ['A', 'B'],
    now: DateTime(2026),
  );

  test('creates, renames and lists groups by name', () async {
    final b = await groups.createGroup(name: 'Line B', now: DateTime(2026));
    final a = await groups.createGroup(
      name: 'Line A',
      description: 'Assembly',
      now: DateTime(2026, 2),
    );
    await groups.updateGroup(b, name: 'Line C', description: 'Paint');

    final list = await groups.listGroups();
    expect(list.map((g) => g.group.name), ['Line A', 'Line C']);
    expect(list.first.group.id, a);
    expect(list.first.group.description, 'Assembly');
    expect(list.first.group.createdAt, DateTime(2026, 2));
    expect(list.last.group.description, 'Paint');
    expect(list.first.studyCount, 0);
    expect((await groups.getGroup(b))!.name, 'Line C');
  });

  test('moving appends a study at the end of the group', () async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final s1 = await study('Saw');
    final s2 = await study('Drill');
    final s3 = await study('Press');
    await groups.moveToGroup(s2, g);
    await groups.moveToGroup(s1, g);
    await groups.moveToGroup(s3, g);

    final members = await studies.listStudies(groupId: g);
    expect(members.map((s) => s.study.name), ['Drill', 'Saw', 'Press']);
    expect(members.first.study.groupId, g);
    expect(members.first.groupName, 'Line');
    expect((await groups.listGroups()).single.studyCount, 3);
  });

  test('order can be set and stays', () async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final ids = [await study('A'), await study('B'), await study('C')];
    for (final id in ids) {
      await groups.moveToGroup(id, g);
    }
    await groups.reorder(g, [ids[2], ids[0], ids[1]]);
    final members = await studies.listStudies(groupId: g);
    expect(members.map((s) => s.study.name), ['C', 'A', 'B']);
    expect(members.map((s) => s.study.groupPosition), [0, 1, 2]);
  });

  test('moving to another group or out of a group', () async {
    final g1 = await groups.createGroup(name: 'One', now: DateTime(2026));
    final g2 = await groups.createGroup(name: 'Two', now: DateTime(2026));
    final id = await study('Saw');
    await groups.moveToGroup(id, g1);
    await groups.moveToGroup(id, g2);
    expect(await studies.listStudies(groupId: g1), isEmpty);
    expect((await studies.listStudies(groupId: g2)).single.study.id, id);

    await groups.moveToGroup(id, null);
    expect(await studies.listStudies(groupId: g2), isEmpty);
    expect((await studies.getStudy(id))!.groupId, isNull);
  });

  test('deleting a group keeps its studies without a group', () async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final id = await study('Saw');
    await groups.moveToGroup(id, g);
    await groups.deleteGroup(g);
    expect(await groups.getGroup(g), isNull);
    final s = await studies.getStudy(id);
    expect(s, isNotNull);
    expect(s!.groupId, isNull);
  });

  test('the study list names the group of each study', () async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final inGroup = await study('Saw');
    await study('Loose');
    await groups.moveToGroup(inGroup, g);
    final all = await studies.listStudies();
    expect(
      {for (final s in all) s.study.name: s.groupName},
      {'Saw': 'Line', 'Loose': null},
    );
  });

  test('copying a study duplicates steps and times into a group', () async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final other = await study('First');
    await groups.moveToGroup(other, g);
    final id = await study('Saw');
    await studies.setNotes(id, 'note');
    final steps = await studies.getSteps(id);
    final times = MeasurementRepository(db);
    await times.insert(
      id,
      MeasurementDraft(
        cycle: 1,
        stepId: steps[1].id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: 5,
        durationMicros: 5,
        note: 'x',
      ),
    );

    final copy = await studies.copyStudy(
      id,
      name: 'Saw (copy)',
      groupId: g,
      now: DateTime(2026, 5),
    );

    final c = (await studies.getStudy(copy))!;
    expect(c.name, 'Saw (copy)');
    expect(c.notes, 'note');
    expect(c.groupId, g);
    expect(c.createdAt, DateTime(2026, 5));
    final copySteps = await studies.getSteps(copy);
    expect(copySteps.map((s) => s.name), ['A', 'B']);
    expect(copySteps.map((s) => s.id), isNot(contains(steps[0].id)));
    final copyTimes = await times.listForStudy(copy);
    expect(copyTimes.single.stepId, copySteps[1].id);
    expect(copyTimes.single.note, 'x');
    expect(copyTimes.single.durationMicros, 5);
    // Appended behind the existing member; the original is unchanged.
    expect((await studies.listStudies(groupId: g)).map((s) => s.study.id), [
      other,
      copy,
    ]);
    expect((await studies.getStudy(id))!.groupId, isNull);
    expect(await times.listForStudy(id), hasLength(1));
  });

  test('migration to schema 9 leaves old studies without a group', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig9');
    final file = path.join(dir.path, 'm.db');
    final v8 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 8,
    );
    await v8.db.insert('study', {
      'name': 'Old',
      'description': '',
      'mode': 'timeStudy',
      'created_at': 0,
      'last_active_at': 0,
    });
    await v8.close();

    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    final old = (await StudyRepository(latest).listStudies()).single;
    expect(old.study.groupId, isNull);
    expect(old.groupName, isNull);
    expect(await GroupRepository(latest).listGroups(), isEmpty);
    await latest.close();
    await dir.delete(recursive: true);
  });
}

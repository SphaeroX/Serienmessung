import 'dart:convert';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late int line;
  late int saw;
  late int drill;
  late int loose;
  late int other;

  Future<int> study(String name, int day) => StudyRepository(source)
      .createStudy(
        name: name,
        mode: StudyMode.timeStudy,
        steps: ['Load', 'Cut'],
        now: DateTime(2025, 2, day),
      );

  setUp(() async {
    source = await openTestDatabase();
    target = await openTestDatabase();
    final groups = GroupRepository(source);
    line = await groups.createGroup(
      name: 'Line 4',
      description: 'Assembly',
      now: DateTime(2025),
    );
    await groups.createGroup(name: 'Unrelated', now: DateTime(2025));
    saw = await study('Saw', 1);
    drill = await study('Drill', 2);
    loose = await study('Loose', 3);
    other = await study('Other', 4);
    await groups.moveToGroup(saw, line);
    await groups.moveToGroup(drill, line);
    await groups.setBuffer(
      drill,
      capacity: 5,
      storeMicros: 1000000,
      retrieveMicros: 2000000,
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map> export({
    Set<int> studies = const {},
    Set<int> groups = const {},
  }) async => jsonDecode(
    await BackupService(source).exportJson(
      now: DateTime(2026),
      selection: ExportSelection(studyIds: studies, groupIds: groups),
    ),
  ) as Map;

  test('selected studies only, without their group', () async {
    final json = await export(studies: {loose, saw});
    final names = [for (final s in json['studies'] as List) s['name']];
    expect(names, unorderedEquals(['Loose', 'Saw']));
    expect(json['groups'], isEmpty);
    expect([
      for (final s in json['studies'] as List) s['groupRef'],
    ], everyElement(isNull));
  });

  test('a selected group comes with all its studies', () async {
    final json = await export(groups: {line});
    expect([for (final g in json['groups'] as List) g['name']], ['Line 4']);
    final names = [for (final s in json['studies'] as List) s['name']];
    expect(names, unorderedEquals(['Saw', 'Drill']));
  });

  test('a study selected together with its group is exported once', () async {
    final json = await export(groups: {line}, studies: {saw, other});
    final names = [for (final s in json['studies'] as List) s['name']];
    expect(names, unorderedEquals(['Saw', 'Drill', 'Other']));
  });

  test('importing a shared group restores the complete group', () async {
    final json = await BackupService(source).exportJson(
      now: DateTime(2026),
      selection: ExportSelection(groupIds: {line}),
    );
    final r = await BackupService(target).importJson(json, replace: false);
    expect(r.imported, 2);
    final groups = await GroupRepository(target).listGroups();
    expect(groups.single.group.name, 'Line 4');
    expect(groups.single.group.description, 'Assembly');
    final members = await StudyRepository(target)
        .listStudies(groupId: groups.single.group.id);
    expect(members.map((m) => m.study.name), ['Saw', 'Drill']);
    expect(members.last.study.bufferCapacity, 5);
  });

  test('importing the same shared file twice adds nothing', () async {
    final json = await BackupService(source).exportJson(
      now: DateTime(2026),
      selection: ExportSelection(groupIds: {line}, studyIds: {loose}),
    );
    await BackupService(target).importJson(json, replace: false);
    final again = await BackupService(target).importJson(json, replace: false);
    expect(again.imported, 0);
    expect(again.skipped, 3);
    expect(await GroupRepository(target).listGroups(), hasLength(1));
  });

  test('an empty selection is not allowed', () {
    expect(
      () => BackupService(source)
          .exportJson(now: DateTime(2026), selection: const ExportSelection()),
      throwsArgumentError,
    );
  });
}

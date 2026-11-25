import 'dart:io';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/domain/group_member.dart';
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

  Future<int> newGroup(String name, {int? parent}) async {
    final id = await groups.createGroup(name: name, now: DateTime(2026));
    if (parent != null) await groups.setParent(id, parent);
    return id;
  }

  Future<int> study(String name, int? groupId) async {
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.simple,
      steps: const [],
      now: DateTime(2026),
    );
    if (groupId != null) await groups.moveToGroup(id, groupId);
    return id;
  }

  /// "A [X] B": studies by name, areas in brackets.
  Future<String> members(int groupId) async => [
    for (final m in await groups.listMembers(groupId))
      switch (m) {
        StudyMember(:final study) => study.name,
        AreaMember(:final group) => '[${group.name}]',
      },
  ].join(' ');

  test('migration to schema 17 keeps all groups at the top level', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig17');
    final file = path.join(dir.path, 'm.db');
    final v16 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 16,
    );
    final g = await v16.db.insert('study_group', {
      'name': 'Line',
      'description': '',
      'created_at': 0,
    });
    for (final (i, name) in ['A', 'B', 'C'].indexed) {
      await v16.db.insert('study', {
        'name': name,
        'description': '',
        'mode': 'simple',
        'created_at': 0,
        'last_active_at': 0,
        'group_id': g,
        'group_position': i,
        'parallel': i == 2 ? 1 : 0,
      });
    }
    await v16.close();
    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    final repo = GroupRepository(latest);
    final summary = (await repo.listGroups()).single;
    expect(summary.group.parentId, isNull);
    expect(summary.areaCount, 0);
    expect(summary.studyCount, 3);
    expect(summary.totalStudyCount, 3);
    final list = await repo.listMembers(g);
    expect(
      [for (final m in list) (m as StudyMember).study.name],
      ['A', 'B', 'C'],
    );
    expect(
      [for (final m in list) (m as StudyMember).study.parallel],
      [false, false, true],
    );
    await latest.close();
    await dir.delete(recursive: true);
  });

  group('members', () {
    test('studies and areas in the stored order', () async {
      final plant = await newGroup('Plant');
      await study('A', plant);
      final x = await newGroup('X', parent: plant);
      await study('B', plant);
      expect(await members(plant), 'A [X] B');
      final area = (await groups.getGroup(x))!;
      expect(area.parentId, plant);
    });

    test('mixed reorder sets the shared positions', () async {
      final plant = await newGroup('Plant');
      final a = await study('A', plant);
      final x = await newGroup('X', parent: plant);
      final b = await study('B', plant);
      await groups.reorderMembers(plant, [
        MemberKey.area(x),
        MemberKey.study(b),
        MemberKey.study(a),
      ]);
      expect(await members(plant), '[X] B A');
      // A new study lands behind the last member.
      await study('C', plant);
      expect(await members(plant), '[X] B A C');
    });

    test('reorder by study ids keeps the areas in their places', () async {
      final plant = await newGroup('Plant');
      final a = await study('A', plant);
      await newGroup('X', parent: plant);
      final b = await study('B', plant);
      await groups.reorder(plant, [b, a]);
      expect(await members(plant), 'B [X] A');
    });

    test('a copied study lands behind an area at the end', () async {
      final plant = await newGroup('Plant');
      final a = await study('A', plant);
      await newGroup('X', parent: plant);
      await studies.copyStudy(
        a,
        name: 'A',
        groupId: plant,
        now: DateTime(2026),
      );
      expect(await members(plant), 'A [X] A');
    });

    test('an area moved to another parent leaves the old one', () async {
      final one = await newGroup('One');
      final two = await newGroup('Two');
      final x = await newGroup('X', parent: one);
      await study('A', two);
      await groups.setParent(x, two);
      expect(await members(one), '');
      expect(await members(two), 'A [X]');
      await groups.setParent(x, null);
      expect(await members(two), 'A');
      expect((await groups.getGroup(x))!.parentId, isNull);
    });

    test('summaries count areas and the studies of the subtree', () async {
      final plant = await newGroup('Plant');
      await study('A', plant);
      final x = await newGroup('X', parent: plant);
      await study('B', x);
      final y = await newGroup('Y', parent: x);
      await study('C', y);
      await study('D', y);
      final byName = {
        for (final s in await groups.listGroups()) s.group.name: s,
      };
      expect(byName['Plant']!.studyCount, 1);
      expect(byName['Plant']!.areaCount, 1);
      expect(byName['Plant']!.totalStudyCount, 4);
      expect(byName['X']!.areaCount, 1);
      expect(byName['X']!.totalStudyCount, 3);
      expect(byName['Y']!.totalStudyCount, 2);
    });
  });

  group('no cycles', () {
    test('a group cannot go into itself, a child or a grandchild', () async {
      final plant = await newGroup('Plant');
      final x = await newGroup('X', parent: plant);
      final y = await newGroup('Y', parent: x);
      for (final target in [plant, x, y]) {
        await expectLater(
          groups.setParent(plant, target),
          throwsA(isA<GroupCycleException>()),
        );
      }
      await expectLater(
        groups.setParent(x, x),
        throwsA(isA<GroupCycleException>()),
      );
      expect((await groups.getGroup(plant))!.parentId, isNull);
      expect(await members(plant), '[X]');
      expect(await members(x), '[Y]');
    });

    test('ancestors and descendants', () async {
      final plant = await newGroup('Plant');
      final x = await newGroup('X', parent: plant);
      final y = await newGroup('Y', parent: x);
      final z = await newGroup('Z', parent: plant);
      expect(
        [for (final g in await groups.ancestors(y)) g.name],
        ['Plant', 'X'],
      );
      expect(await groups.ancestors(plant), isEmpty);
      expect((await groups.descendants(plant)).toSet(), {x, y, z});
      expect(await groups.descendants(y), isEmpty);
    });
  });

  group('delete', () {
    test('without studies: studies lose their group, areas go to the top '
        'level', () async {
      final plant = await newGroup('Plant');
      final a = await study('A', plant);
      final x = await newGroup('X', parent: plant);
      final b = await study('B', x);
      await groups.deleteGroup(plant);
      expect((await studies.getStudy(a))!.groupId, isNull);
      expect((await groups.getGroup(x))!.parentId, isNull);
      expect(await members(x), 'B');
      expect((await studies.getStudy(b))!.groupId, x);
    });

    test('with studies: the whole subtree goes, other groups stay', () async {
      final plant = await newGroup('Plant');
      await study('A', plant);
      final x = await newGroup('X', parent: plant);
      await study('B', x);
      final y = await newGroup('Y', parent: x);
      await study('C', y);
      final other = await newGroup('Other');
      final d = await study('D', other);
      final free = await study('E', null);
      final doomed = await groups.subtreeStudies(plant);
      expect({for (final s in doomed) s.name}, {'A', 'B', 'C'});
      await groups.deleteGroup(plant, withStudies: true);
      expect(await groups.getGroup(x), isNull);
      expect(await groups.getGroup(y), isNull);
      expect(
        [for (final s in await groups.listGroups()) s.group.name],
        ['Other'],
      );
      expect(
        {for (final s in await studies.listStudies()) s.study.name},
        {'D', 'E'},
      );
      expect((await studies.getStudy(d))!.groupId, other);
      expect((await studies.getStudy(free))!.groupId, isNull);
    });
  });
}

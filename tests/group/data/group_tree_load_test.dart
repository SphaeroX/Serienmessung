import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/domain/group_tree.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<int> study(String name, int groupId, {bool parallel = false}) async {
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.simple,
      steps: const [],
      now: DateTime(2026),
    );
    await groups.moveToGroup(id, groupId);
    if (parallel) await groups.setParallel(id, true);
    return id;
  }

  test('loads the members of the group and of every area below', () async {
    final plant = await newGroup('Plant');
    await study('A', plant);
    final hall = await newGroup('Hall', parent: plant);
    await study('H', hall);
    final cell = await newGroup('Cell', parent: hall);
    await study('C1', cell);
    await study('C2', cell, parallel: true);
    await study('Z', plant);
    final tree = await groups.loadTree(plant);
    expect(tree.keys.toSet(), {plant, hall, cell});
    final line = flattenGroup(plant, tree);
    expect(
      [for (final e in line.entries) e.study.name],
      ['A', 'H', 'C1', 'C2', 'Z'],
    );
    expect(
      [for (final e in line.entries) e.study.parallel],
      [false, false, false, true, false],
    );
    expect([for (final a in line.areas) a.group.name], ['Hall']);
  });

  test(
    'a stored parallel flag behind an area does not join stations',
    () async {
      final plant = await newGroup('Plant');
      await study('A', plant);
      await newGroup('X', parent: plant);
      final b = await study('B', plant);
      // Old data or a broken import: the flag is in the database.
      await db.db.update(
        'study',
        {'parallel': 1},
        where: 'id = ?',
        whereArgs: [b],
      );
      final line = flattenGroup(plant, await groups.loadTree(plant));
      expect(line.entries.last.study.parallel, isFalse);
    },
  );
}

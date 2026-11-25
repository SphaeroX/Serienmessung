import 'dart:io';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/domain/group_member.dart';
import 'package:cyclescope/group/domain/group_tree.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late StudyRepository studies;
  late int plant;
  late int a;
  late int b;

  Future<int> study(String name, int groupId) async {
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.simple,
      steps: const [],
      now: DateTime(2026),
    );
    await groups.moveToGroup(id, groupId);
    return id;
  }

  Future<int> newGroup(String name, {int? parent}) async {
    final id = await groups.createGroup(name: name, now: DateTime(2026));
    if (parent != null) await groups.setParent(id, parent);
    return id;
  }

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    studies = StudyRepository(db);
    plant = await newGroup('Plant');
    a = await newGroup('A', parent: plant);
    await study('A1', a);
    b = await newGroup('B', parent: plant);
    await study('B1', b);
    await groups.setAreaBuffer(
      b,
      capacity: 6,
      storeMicros: 3 * s,
      retrieveMicros: 4 * s,
    );
    await groups.setAreaConveyor(b, capacity: 2, transportMicros: 9 * s);
  });

  tearDown(() => db.close());

  Future<bool> linked() async {
    final g = (await groups.getGroup(b))!;
    return g.hasBuffer || g.hasConveyor;
  }

  test('the link is stored on the area and flattened onto its first '
      'study', () async {
    final g = (await groups.getGroup(b))!;
    expect(
      (
        g.bufferCapacity,
        g.bufferStoreMicros,
        g.bufferRetrieveMicros,
        g.conveyorCapacity,
        g.conveyorTransportMicros,
      ),
      (6, 3 * s, 4 * s, 2, 9 * s),
    );
    final line = flattenGroup(plant, await groups.loadTree(plant));
    expect(line.entries.last.study.bufferCapacity, 6);
    expect(line.entries.last.study.conveyorTransportMicros, 9 * s);
    // The area alone: nothing before its first station.
    final alone = flattenGroup(b, await groups.loadTree(b));
    expect(alone.entries.single.study.hasBuffer, isFalse);
  });

  test('removing buffer and conveyor', () async {
    await groups.removeAreaBuffer(b);
    expect((await groups.getGroup(b))!.hasBuffer, isFalse);
    expect((await groups.getGroup(b))!.hasConveyor, isTrue);
    await groups.removeAreaConveyor(b);
    expect(await linked(), isFalse);
  });

  test('reordering in the parent keeps the link', () async {
    await groups.reorderMembers(plant, [
      MemberKey.area(b),
      MemberKey.area(a),
    ], moved: MemberKey.area(b));
    expect(await linked(), isTrue);
    // As the first member it has no effect, but it is kept and works again
    // once something stands before it.
    var line = flattenGroup(plant, await groups.loadTree(plant));
    expect(line.entries.first.study.hasBuffer, isFalse);
    await groups.reorderMembers(plant, [
      MemberKey.area(a),
      MemberKey.area(b),
    ], moved: MemberKey.area(a));
    line = flattenGroup(plant, await groups.loadTree(plant));
    expect(line.entries.last.study.bufferCapacity, 6);
  });

  test('taking the area out resets the link', () async {
    await groups.setParent(b, null);
    expect(await linked(), isFalse);
  });

  test('moving the area to another group resets the link', () async {
    final other = await newGroup('Other');
    await study('O1', other);
    await groups.setParent(b, other);
    expect(await linked(), isFalse);
  });

  test('deleting the parent resets the link', () async {
    await groups.deleteGroup(plant);
    expect(await linked(), isFalse);
  });

  test('migration to schema 18 gives every group no link', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig18');
    final file = path.join(dir.path, 'm.db');
    final v17 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 17,
    );
    await v17.db.insert('study_group', {
      'name': 'Old',
      'description': '',
      'created_at': 0,
    });
    await v17.close();
    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    final g = (await GroupRepository(latest).listGroups()).single.group;
    expect(g.hasBuffer, isFalse);
    expect(g.hasConveyor, isFalse);
    await latest.close();
    await dir.delete(recursive: true);
  });
}

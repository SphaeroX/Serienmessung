import 'dart:convert';
import 'dart:io';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/step_text_sync.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late StudyRepository studies;
  late int groupId;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    studies = StudyRepository(db);
    groupId = await groups.createGroup(name: 'Line', now: DateTime(2026));
  });

  tearDown(() => db.close());

  Future<int> member(String name, {bool loader = false}) async {
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.timeStudy,
      steps: ['Work', 'Wait'],
      now: DateTime(2026),
    );
    await groups.moveToGroup(id, groupId);
    if (loader) await groups.setCellLoader(id, true);
    return id;
  }

  /// "Saw Machine[x3] >L1 >L2[/2]": loaders are marked with ">".
  Future<String> line([int? group]) async {
    final m = await studies.listStudies(groupId: group ?? groupId);
    return [
      for (final x in m)
        '${x.study.isCellLoader ? '>' : ''}'
            '${x.study.parallel && !x.study.isCellLoader ? '|' : ''}'
            '${x.study.name}'
            '${x.study.cellMachines == 1 ? '' : '[x${x.study.cellMachines}]'}'
            '${x.study.cellParts == 1 ? '' : '[/${x.study.cellParts}]'}',
    ].join(' ');
  }

  group('waiting steps', () {
    test('a step is no waiting step until it is marked', () async {
      final id = await member('Loader');
      var steps = await studies.getSteps(id);
      expect(steps.map((x) => x.waiting), [false, false]);
      await studies.setStepWaiting(steps[1].id, true);
      steps = await studies.getSteps(id);
      expect(steps.map((x) => x.waiting), [false, true]);
      await studies.setStepWaiting(steps[1].id, false);
      expect((await studies.getSteps(id)).map((x) => x.waiting), [
        false,
        false,
      ]);
    });

    test('renaming, reordering and editing as text keep the mark', () async {
      final id = await member('Loader');
      final steps = await studies.getSteps(id);
      await studies.setStepWaiting(steps[1].id, true);
      await studies.renameStep(steps[1].id, 'Wait for machine');
      await studies.reorderSteps(id, [steps[1].id, steps[0].id]);
      await studies.applyStepPlan(
        id,
        planStepText(
          await studies.getSteps(id),
          'Wait for the machine\nWork\nNew',
        ),
      );
      final after = await studies.getSteps(id);
      expect(after.map((x) => (x.name, x.waiting)), [
        ('Wait for the machine', true),
        ('Work', false),
        ('New', false),
      ]);
    });

    test('a copy keeps the marks', () async {
      final id = await member('Loader');
      await studies.setStepWaiting((await studies.getSteps(id))[1].id, true);
      final copy = await studies.copyStudy(
        id,
        name: 'Copy',
        now: DateTime(2026),
      );
      expect((await studies.getSteps(copy)).map((x) => x.waiting), [
        false,
        true,
      ]);
    });
  });

  group('cell members', () {
    test('a loader belongs to the station of the member before it', () async {
      await member('Saw');
      final machine = await member('Machine');
      final l1 = await member('L1', loader: true);
      await member('L2', loader: true);
      await groups.setCellMachines(machine, 3);
      await groups.setCellParts(l1, 2);
      expect(await line(), 'Saw Machine[x3] >L1[/2] >L2');
      final m = await studies.listStudies(groupId: groupId);
      expect(m.map((x) => x.study.parallel), [false, false, true, true]);
    });

    test('a loader loses the buffer and the conveyor of its own', () async {
      await member('Saw');
      await member('Machine');
      final l1 = await member('L1');
      await groups.setBuffer(
        l1,
        capacity: 3,
        storeMicros: 1000000,
        retrieveMicros: 1000000,
      );
      await groups.setConveyor(l1, capacity: 2, transportMicros: 1000000);
      await groups.setCellLoader(l1, true);
      final study = (await studies.getStudy(l1))!;
      expect(study.hasBuffer, isFalse);
      expect(study.hasConveyor, isFalse);
    });

    test('switching the loader role off makes a station of its own', () async {
      await member('Machine');
      final l1 = await member('L1', loader: true);
      await groups.setCellLoader(l1, false);
      final study = (await studies.getStudy(l1))!;
      expect(study.isCellLoader, isFalse);
      expect(study.parallel, isFalse);
    });

    test('switching to a parallel machine ends the loader role', () async {
      await member('Machine');
      final l1 = await member('L1', loader: true);
      await groups.setParallel(l1, true);
      expect(await line(), 'Machine |L1');
      await groups.setCellLoader(l1, true);
      await groups.setParallel(l1, false);
      expect(await line(), 'Machine L1');
    });

    test('moving to another group and copying reset the cell data', () async {
      final machine = await member('Machine');
      final l1 = await member('L1', loader: true);
      await groups.setCellMachines(machine, 4);
      await groups.setCellParts(l1, 2);
      final copy = await studies.copyStudy(
        l1,
        name: 'L1 copy',
        groupId: groupId,
        now: DateTime(2026),
      );
      final copied = (await studies.getStudy(copy))!;
      expect(
        (copied.isCellLoader, copied.parallel, copied.cellParts),
        (false, false, 1),
      );
      final other = await groups.createGroup(name: 'B', now: DateTime(2026));
      await groups.moveToGroup(l1, other);
      await groups.moveToGroup(machine, other);
      expect(await line(other), 'L1 Machine');
    });

    test(
      'when the machine leaves, the next member heads the station',
      () async {
        await member('Saw');
        final machine = await member('Machine');
        await member('L1', loader: true);
        await member('L2', loader: true);
        await groups.moveToGroup(machine, null);
        expect(await line(), 'Saw L1 >L2');
      },
    );

    test('a loader dragged out of its cell is a station of its own', () async {
      final saw = await member('Saw');
      final machine = await member('Machine');
      final l1 = await member('L1', loader: true);
      final l2 = await member('L2', loader: true);
      await groups.reorder(groupId, [l2, saw, machine, l1], moved: l2);
      expect(await line(), 'L2 Saw Machine >L1');
    });

    test('a member dragged into a cell is another machine of it', () async {
      final saw = await member('Saw');
      final machine = await member('Machine');
      final l1 = await member('L1', loader: true);
      await groups.reorder(groupId, [machine, saw, l1], moved: saw);
      expect(await line(), 'Machine |Saw >L1');
    });

    test('counts below one are not stored', () async {
      final machine = await member('Machine');
      expect(() => groups.setCellMachines(machine, 0), throwsArgumentError);
      expect(() => groups.setCellParts(machine, 0), throwsArgumentError);
    });
  });

  group('backup', () {
    test('cell data and waiting marks survive a round trip', () async {
      await member('Saw');
      final machine = await member('Machine');
      final l1 = await member('L1', loader: true);
      await groups.setCellMachines(machine, 3);
      await groups.setCellParts(l1, 2);
      await studies.setStepWaiting((await studies.getSteps(l1))[1].id, true);
      final json = await BackupService(db).exportJson(now: DateTime(2026));
      final target = await openTestDatabase();
      addTearDown(target.close);
      await BackupService(target).importJson(json, replace: false);
      final g = (await GroupRepository(target).listGroups()).single.group;
      final repo = StudyRepository(target);
      final m = await repo.listStudies(groupId: g.id);
      expect(m.map((x) => x.study.isCellLoader), [false, false, true]);
      expect(m.map((x) => x.study.cellMachines), [1, 3, 1]);
      expect(m.map((x) => x.study.cellParts), [1, 1, 2]);
      expect((await repo.getSteps(m[2].study.id)).map((x) => x.waiting), [
        false,
        true,
      ]);
    });

    test('a backup without the new fields still loads', () async {
      await member('Machine');
      final l1 = await member('L1', loader: true);
      await studies.setStepWaiting((await studies.getSteps(l1))[1].id, true);
      final data = jsonDecode(
        await BackupService(db).exportJson(now: DateTime(2026)),
      ) as Map<String, Object?>;
      for (final s in data['studies'] as List) {
        (s as Map)
          ..remove('cellLoader')
          ..remove('cellParts')
          ..remove('cellMachines');
        for (final st in s['steps'] as List) {
          (st as Map).remove('waiting');
        }
      }
      final target = await openTestDatabase();
      addTearDown(target.close);
      await BackupService(target).importJson(jsonEncode(data), replace: true);
      final repo = StudyRepository(target);
      final m = await repo.listStudies();
      expect(m, hasLength(2));
      for (final x in m) {
        expect(x.study.isCellLoader, isFalse);
        expect((x.study.cellParts, x.study.cellMachines), (1, 1));
        expect(
          (await repo.getSteps(x.study.id)).any((st) => st.waiting),
          isFalse,
        );
      }
    });

    test('malformed cell data is rejected', () async {
      await member('Machine');
      final data = jsonDecode(
        await BackupService(db).exportJson(now: DateTime(2026)),
      ) as Map<String, Object?>;
      ((data['studies'] as List).single as Map)['cellMachines'] = 0;
      expect(
        () => BackupService(db).importJson(jsonEncode(data), replace: false),
        throwsA(isA<BackupException>()),
      );
    });
  });

  test('migration to schema 15 gives old studies no cell data', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig15');
    final file = path.join(dir.path, 'm.db');
    final v14 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 14,
    );
    final id = await v14.db.insert('study', {
      'name': 'Old',
      'description': '',
      'mode': 'timeStudy',
      'created_at': 0,
      'last_active_at': 0,
    });
    await v14.db.insert('step_definition', {
      'study_id': id,
      'position': 0,
      'name': 'A',
    });
    await v14.close();
    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    final repo = StudyRepository(latest);
    final old = (await repo.getStudy(id))!;
    expect((old.isCellLoader, old.cellParts, old.cellMachines), (false, 1, 1));
    expect((await repo.getSteps(id)).single.waiting, isFalse);
    await latest.close();
    await dir.delete(recursive: true);
  });
}

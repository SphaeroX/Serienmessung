import 'dart:convert';
import 'dart:io';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/domain/stations.dart';
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
  late int groupId;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    studies = StudyRepository(db);
    groupId = await groups.createGroup(name: 'Line', now: DateTime(2026));
  });

  tearDown(() => db.close());

  Future<int> member(String name, {bool parallel = false}) async {
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

  /// "1:A 2a:B+waits 2b:C": the option is marked on the member that
  /// stores it.
  Future<String> line([int? group, AppDatabase? source]) async {
    final m = await StudyRepository(source ?? db)
        .listStudies(groupId: group ?? groupId);
    final labels = stationLabels([for (final x in m) x.study.parallel]);
    return [
      for (var i = 0; i < m.length; i++)
        '${labels[i]}:${m[i].study.name}'
            '${m[i].study.waitForSlowest ? '+waits' : ''}',
    ].join(' ');
  }

  /// A, then the waiting station B/C/D, then E.
  Future<({int a, int b, int c, int d, int e})> station() async {
    final a = await member('A');
    final b = await member('B');
    final c = await member('C', parallel: true);
    final d = await member('D', parallel: true);
    final e = await member('E');
    await groups.setWaitForSlowest(c, true);
    expect(await line(), '1:A 2a:B+waits 2b:C 2c:D 3:E');
    return (a: a, b: b, c: c, d: d, e: e);
  }

  group('the option', () {
    test('is stored on the first machine of the station', () async {
      await member('A');
      final b = await member('B');
      final c = await member('C', parallel: true);
      expect(await line(), '1:A 2a:B 2b:C');
      await groups.setWaitForSlowest(c, true);
      expect(await line(), '1:A 2a:B+waits 2b:C');
      await groups.setWaitForSlowest(b, false);
      expect(await line(), '1:A 2a:B 2b:C');
    });

    test('is not kept for a station with one machine', () async {
      final a = await member('A');
      await member('B');
      await groups.setWaitForSlowest(a, true);
      expect(await line(), '1:A 2:B');
    });

    test('also works for the first station of the line', () async {
      await member('A');
      final b = await member('B', parallel: true);
      await groups.setWaitForSlowest(b, true);
      expect(await line(), '1a:A+waits 1b:B');
    });
  });

  group('the waiting station stays together', () {
    test('its first machine is removed: the next one takes over', () async {
      final x = await station();
      await groups.moveToGroup(x.b, null);
      expect(await line(), '1:A 2a:C+waits 2b:D 3:E');
      expect((await studies.getStudy(x.b))!.waitForSlowest, isFalse);
    });

    test('the first machine of the first station is removed', () async {
      final a = await member('A');
      await member('B', parallel: true);
      await member('C', parallel: true);
      await groups.setWaitForSlowest(a, true);
      await groups.moveToGroup(a, null);
      expect(await line(), '1a:B+waits 1b:C');
    });

    test('its first machine is deleted', () async {
      final x = await station();
      await studies.deleteStudy(x.b);
      expect(await line(), '1:A 2a:C+waits 2b:D 3:E');
    });

    test('its first machine is moved to another group', () async {
      final x = await station();
      final other = await groups.createGroup(
        name: 'Other',
        now: DateTime(2026),
      );
      await groups.moveToGroup(x.b, other);
      expect(await line(), '1:A 2a:C+waits 2b:D 3:E');
      expect(await line(other), '1:B');
    });

    test('its first machine is dragged away', () async {
      final x = await station();
      await groups.reorder(groupId, [x.a, x.c, x.d, x.e, x.b], moved: x.b);
      expect(await line(), '1:A 2a:C+waits 2b:D 3:E 4:B');
    });

    test('a machine dropped inside joins it', () async {
      final x = await station();
      await groups.reorder(groupId, [x.a, x.b, x.e, x.c, x.d], moved: x.e);
      expect(await line(), '1:A 2a:B+waits 2b:E 2c:C 2d:D');
    });

    test('one of its other machines leaves', () async {
      final x = await station();
      await groups.moveToGroup(x.d, null);
      expect(await line(), '1:A 2a:B+waits 2b:C 3:E');
    });

    test('a machine switched to serial keeps waiting with the machines '
        'behind it', () async {
      final x = await station();
      await groups.setParallel(x.c, false);
      // B is alone now, C and D still wait for each other.
      expect(await line(), '1:A 2:B 3a:C+waits 3b:D 4:E');
    });
  });

  group('the option is dropped', () {
    test('when the last parallel machine leaves', () async {
      await member('A');
      final b = await member('B', parallel: true);
      await groups.setWaitForSlowest(b, true);
      await groups.moveToGroup(b, null);
      expect(await line(), '1:A');
      // A new parallel machine starts with the default again.
      await member('C', parallel: true);
      expect(await line(), '1a:A 1b:C');
    });

    test('when the last parallel machine is switched to serial', () async {
      await member('A');
      final b = await member('B', parallel: true);
      await groups.setWaitForSlowest(b, true);
      await groups.setParallel(b, false);
      expect(await line(), '1:A 2:B');
    });

    test('when the last parallel machine is deleted or dragged away', () async {
      final a = await member('A');
      final b = await member('B', parallel: true);
      final c = await member('C');
      await groups.setWaitForSlowest(a, true);
      await groups.reorder(groupId, [a, c, b], moved: b);
      expect(await line(), '1:A 2:C 3:B');
      await groups.setParallel(b, true);
      await groups.setWaitForSlowest(b, true);
      expect(await line(), '1:A 2a:C+waits 2b:B');
      await studies.deleteStudy(b);
      expect(await line(), '1:A 2:C');
    });

    test('on the first machine that joins the station before', () async {
      final x = await station();
      await groups.setParallel(x.b, true);
      // One station A/B/C/D that follows A.
      expect(await line(), '1a:A 1b:B 1c:C 1d:D 2:E');
    });

    test('by copying and by moving to another group', () async {
      final x = await station();
      final copy = await studies.copyStudy(
        x.b,
        name: 'B 2',
        groupId: groupId,
        now: DateTime(2026),
      );
      expect((await studies.getStudy(copy))!.waitForSlowest, isFalse);
      expect(await line(), '1:A 2a:B+waits 2b:C 2c:D 3:E 4:B 2');
    });
  });

  group('loader cells', () {
    test('a loader cell cannot wait for its slowest machine', () async {
      await member('A');
      final b = await member('B');
      final loader = await member('Loader');
      await groups.setCellLoader(loader, true);
      await groups.setWaitForSlowest(b, true);
      expect(await line(), '1:A 2a:B 2b:Loader');
    });

    test('a waiting station that gets a loader stops waiting', () async {
      final x = await station();
      await groups.setCellLoader(x.d, true);
      expect(await line(), '1:A 2a:B 2b:C 2c:D 3:E');
      // Without the loader the machines share the work again.
      await groups.setCellLoader(x.d, false);
      expect(await line(), '1:A 2a:B 2b:C 3:D 4:E');
    });
  });

  group('backup', () {
    test('the option survives a round trip', () async {
      await station();
      final json = await BackupService(db).exportJson(now: DateTime(2026));
      final target = await openTestDatabase();
      addTearDown(target.close);
      await BackupService(target).importJson(json, replace: false);
      final g = (await GroupRepository(target).listGroups()).single.group;
      expect(await line(g.id, target), '1:A 2a:B+waits 2b:C 2c:D 3:E');
    });

    test('files without the field import as before', () async {
      await station();
      final json = await BackupService(db).exportJson(now: DateTime(2026));
      final data = jsonDecode(json) as Map<String, dynamic>;
      for (final s in data['studies'] as List) {
        (s as Map).remove('waitForSlowest');
      }
      final target = await openTestDatabase();
      addTearDown(target.close);
      await BackupService(target).importJson(jsonEncode(data), replace: false);
      final g = (await GroupRepository(target).listGroups()).single.group;
      expect(await line(g.id, target), '1:A 2a:B 2b:C 2c:D 3:E');
    });
  });

  test('migration to schema 16 keeps parallel stations as they were', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig16');
    final file = path.join(dir.path, 'm.db');
    final v15 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 15,
    );
    await v15.db.insert('study', {
      'name': 'Old',
      'description': '',
      'mode': 'simple',
      'created_at': 0,
      'last_active_at': 0,
      'parallel': 1,
    });
    await v15.close();
    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    final old = (await StudyRepository(latest).listStudies()).single.study;
    expect(old.parallel, isTrue);
    expect(old.waitForSlowest, isFalse);
    await latest.close();
    await dir.delete(recursive: true);
  });
}

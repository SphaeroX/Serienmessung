import 'dart:io';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
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

  Future<int> study(String name) async {
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.timeStudy,
      steps: ['A'],
      now: DateTime(2026),
    );
    await groups.moveToGroup(id, groupId);
    return id;
  }

  test('a buffer before a station is stored and removed', () async {
    await study('Saw');
    final press = await study('Press');
    expect((await studies.getStudy(press))!.hasBuffer, isFalse);

    await groups.setBuffer(
      press,
      capacity: 50,
      storeMicros: 20000000,
      retrieveMicros: 15000000,
    );
    final s = (await studies.listStudies(groupId: groupId)).last.study;
    expect(s.hasBuffer, isTrue);
    expect(
      (s.bufferCapacity, s.bufferStoreMicros, s.bufferRetrieveMicros),
      (50, 20000000, 15000000),
    );

    await groups.removeBuffer(press);
    expect((await studies.getStudy(press))!.hasBuffer, isFalse);
  });

  test('parallel switching, moving and copying drop the buffer', () async {
    await study('Saw');
    final press = await study('Press');
    Future<void> buffer() =>
        groups.setBuffer(press, capacity: 5, storeMicros: 1, retrieveMicros: 1);

    await buffer();
    await groups.setParallel(press, true);
    expect((await studies.getStudy(press))!.hasBuffer, isFalse);
    await groups.setParallel(press, false);

    await buffer();
    final copy = await studies.copyStudy(
      press,
      name: 'Press 2',
      groupId: groupId,
      now: DateTime(2026),
    );
    expect((await studies.getStudy(copy))!.hasBuffer, isFalse);
    expect((await studies.getStudy(press))!.hasBuffer, isTrue);

    final other = await groups.createGroup(name: 'B', now: DateTime(2026));
    await groups.moveToGroup(press, other);
    expect((await studies.getStudy(press))!.hasBuffer, isFalse);
  });

  test('the buffer survives a backup round trip', () async {
    await study('Saw');
    final press = await study('Press');
    await groups.setBuffer(
      press,
      capacity: 50,
      storeMicros: 20000000,
      retrieveMicros: 15000000,
    );
    final json = await BackupService(db).exportJson(now: DateTime(2026));
    final target = await openTestDatabase();
    addTearDown(target.close);
    await BackupService(target).importJson(json, replace: false);
    final g = (await GroupRepository(target).listGroups()).single.group;
    final s = (await StudyRepository(target).listStudies(groupId: g.id))
        .last
        .study;
    expect(
      (s.bufferCapacity, s.bufferStoreMicros, s.bufferRetrieveMicros),
      (50, 20000000, 15000000),
    );
  });

  test('migration to schema 12 gives old studies no buffer', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig12');
    final file = path.join(dir.path, 'm.db');
    final v11 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 11,
    );
    await v11.db.insert('study', {
      'name': 'Old',
      'description': '',
      'mode': 'timeStudy',
      'created_at': 0,
      'last_active_at': 0,
    });
    await v11.close();
    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    expect(
      (await StudyRepository(latest).listStudies()).single.study.hasBuffer,
      isFalse,
    );
    await latest.close();
    await dir.delete(recursive: true);
  });
}

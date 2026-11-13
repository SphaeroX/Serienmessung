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

  test('a conveyor before a station is stored and removed', () async {
    await study('Saw');
    final press = await study('Press');
    await groups.setConveyor(press, capacity: 8, transportMicros: 30000000);
    final s = (await studies.getStudy(press))!;
    expect(s.hasConveyor, isTrue);
    expect((s.conveyorCapacity, s.conveyorTransportMicros), (8, 30000000));
    await groups.removeConveyor(press);
    expect((await studies.getStudy(press))!.hasConveyor, isFalse);
  });

  test('parallel switching, moving and copying drop the conveyor', () async {
    await study('Saw');
    final press = await study('Press');
    Future<void> conveyor() =>
        groups.setConveyor(press, capacity: 8, transportMicros: 1);
    await conveyor();
    await groups.setParallel(press, true);
    expect((await studies.getStudy(press))!.hasConveyor, isFalse);
    await groups.setParallel(press, false);
    await conveyor();
    final copy = await studies.copyStudy(
      press,
      name: 'Press 2',
      groupId: groupId,
      now: DateTime(2026),
    );
    expect((await studies.getStudy(copy))!.hasConveyor, isFalse);
    final other = await groups.createGroup(name: 'B', now: DateTime(2026));
    await groups.moveToGroup(press, other);
    expect((await studies.getStudy(press))!.hasConveyor, isFalse);
  });

  test('the conveyor survives a backup round trip', () async {
    await study('Saw');
    final press = await study('Press');
    await groups.setConveyor(press, capacity: 8, transportMicros: 30000000);
    final json = await BackupService(db).exportJson(now: DateTime(2026));
    final target = await openTestDatabase();
    addTearDown(target.close);
    await BackupService(target).importJson(json, replace: false);
    final g = (await GroupRepository(target).listGroups()).single.group;
    final s = (await StudyRepository(target).listStudies(groupId: g.id))
        .last
        .study;
    expect((s.conveyorCapacity, s.conveyorTransportMicros), (8, 30000000));
  });

  test('migration to schema 13 gives old studies no conveyor', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig13');
    final file = path.join(dir.path, 'm.db');
    final v12 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 12,
    );
    await v12.db.insert('study', {
      'name': 'Old',
      'description': '',
      'mode': 'timeStudy',
      'created_at': 0,
      'last_active_at': 0,
    });
    await v12.close();
    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    expect(
      (await StudyRepository(latest).listStudies()).single.study.hasConveyor,
      isFalse,
    );
    await latest.close();
    await dir.delete(recursive: true);
  });
}

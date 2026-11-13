import 'dart:io';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/special_cycle_repository.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late SpecialCycleRepository cycles;
  late StudyRepository studies;
  late int press;

  setUp(() async {
    db = await openTestDatabase();
    cycles = SpecialCycleRepository(db);
    studies = StudyRepository(db);
    press = await studies.createStudy(
      name: 'Press',
      mode: StudyMode.simple,
      steps: const [],
      now: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  test('rules are added, listed in order and deleted', () async {
    final measure = await cycles.add(
      press,
      name: 'Measure part',
      kind: SpecialCycleKind.parts,
      interval: 50,
      durationMicros: 120000000,
    );
    await cycles.add(
      press,
      name: 'Tool change',
      kind: SpecialCycleKind.time,
      interval: 24 * 3600 * 1000000,
      durationMicros: 300000000,
    );
    final list = await cycles.list(press);
    expect(list.map((c) => (c.name, c.kind, c.interval)), [
      ('Measure part', SpecialCycleKind.parts, 50),
      ('Tool change', SpecialCycleKind.time, 24 * 3600 * 1000000),
    ]);
    await cycles.delete(measure);
    expect((await cycles.list(press)).single.name, 'Tool change');
    expect(await cycles.countFor([press]), {press: 1});
  });

  test('a copy of the study takes its rules, deleting removes them', () async {
    await cycles.add(
      press,
      name: 'Measure part',
      kind: SpecialCycleKind.parts,
      interval: 50,
      durationMicros: 120000000,
    );
    final copy = await studies.copyStudy(
      press,
      name: 'Press 2',
      now: DateTime(2026),
    );
    expect((await cycles.list(copy)).single.interval, 50);
    await studies.deleteStudy(press);
    expect(await cycles.list(press), isEmpty);
    expect(await cycles.list(copy), hasLength(1));
  });

  test('rules survive a backup round trip', () async {
    await cycles.add(
      press,
      name: 'Tool change',
      kind: SpecialCycleKind.time,
      interval: 24 * 3600 * 1000000,
      durationMicros: 300000000,
    );
    final json = await BackupService(db).exportJson(now: DateTime(2026));
    final target = await openTestDatabase();
    addTearDown(target.close);
    await BackupService(target).importJson(json, replace: false);
    final id = (await StudyRepository(target).listStudies()).single.study.id;
    final c = (await SpecialCycleRepository(target).list(id)).single;
    expect(
      (c.name, c.kind, c.interval, c.durationMicros),
      ('Tool change', SpecialCycleKind.time, 24 * 3600 * 1000000, 300000000),
    );
  });

  test('migration to schema 14 creates the empty table', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig14');
    final file = path.join(dir.path, 'm.db');
    final v13 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 13,
    );
    final id = await v13.db.insert('study', {
      'name': 'Old',
      'description': '',
      'mode': 'timeStudy',
      'created_at': 0,
      'last_active_at': 0,
    });
    await v13.close();
    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    expect(await SpecialCycleRepository(latest).list(id), isEmpty);
    await latest.close();
    await dir.delete(recursive: true);
  });
}

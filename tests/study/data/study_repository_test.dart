import 'dart:io';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late StudyRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = StudyRepository(db);
  });

  tearDown(() => db.close());

  test('stores a study with steps in order and loads it again', () async {
    final id = await repo.createStudy(
      name: 'Line 200',
      description: 'Morning shift',
      mode: StudyMode.timeStudy,
      steps: ['Pick', 'Insert', 'Press'],
      now: DateTime(2026, 11, 11, 9, 54),
    );

    final study = await repo.getStudy(id);
    expect(study!.name, 'Line 200');
    expect(study.description, 'Morning shift');
    expect(study.mode, StudyMode.timeStudy);
    expect(study.createdAt, DateTime(2026, 11, 11, 9, 54));

    final steps = await repo.getSteps(id);
    expect(steps.map((s) => s.name), ['Pick', 'Insert', 'Press']);
    expect(steps.map((s) => s.position), [0, 1, 2]);
  });

  test('lists studies newest activity first', () async {
    await repo.createStudy(
      name: 'Old',
      mode: StudyMode.simple,
      steps: [],
      now: DateTime(2026, 1, 1),
    );
    await repo.createStudy(
      name: 'New',
      mode: StudyMode.simple,
      steps: [],
      now: DateTime(2026, 2, 1),
    );
    final list = await repo.listStudies();
    expect(list.map((s) => s.study.name), ['New', 'Old']);
    expect(list.first.cycleCount, 0);
  });

  test('deleting a study removes its steps', () async {
    final id = await repo.createStudy(
      name: 'X',
      mode: StudyMode.timeStudy,
      steps: ['A'],
      now: DateTime(2026),
    );
    await repo.deleteStudy(id);
    expect(await repo.getStudy(id), isNull);
    expect(await repo.getSteps(id), isEmpty);
  });

  test('notes are saved per study and start empty', () async {
    final id = await repo.createStudy(
      name: 'Line 200',
      mode: StudyMode.timeStudy,
      steps: ['Pick'],
      now: DateTime(2026),
    );
    expect((await repo.getStudy(id))!.notes, '');
    await repo.setNotes(id, 'Worker A\nnew fixture');
    expect((await repo.getStudy(id))!.notes, 'Worker A\nnew fixture');
  });

  test('migration to schema 8 gives old studies empty notes', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('cyclescope_mig8');
    final file = path.join(dir.path, 'm.db');
    final v7 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
      version: 7,
    );
    await v7.db.insert('study', {
      'name': 'Old',
      'description': '',
      'mode': 'timeStudy',
      'created_at': 0,
      'last_active_at': 0,
    });
    await v7.close();

    final latest = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: file,
    );
    final old = (await StudyRepository(latest).listStudies()).single.study;
    expect(old.name, 'Old');
    expect(old.notes, '');
    await latest.close();
    await dir.delete(recursive: true);
  });
}

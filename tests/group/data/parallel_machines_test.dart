import 'dart:io';

import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/domain/stations.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
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

  group('parallel flag', () {
    test('is stored and listed with the group', () async {
      await study('Saw');
      final drill = await study('Drill');
      await groups.setParallel(drill, true);
      final members = await studies.listStudies(groupId: groupId);
      expect(members.map((m) => m.study.parallel), [false, true]);
      await groups.setParallel(drill, false);
      expect((await studies.getStudy(drill))!.parallel, isFalse);
    });

    test('moving and copying reset it', () async {
      await study('Saw');
      final drill = await study('Drill');
      await groups.setParallel(drill, true);
      final copy = await studies.copyStudy(
        drill,
        name: 'Drill 2',
        groupId: groupId,
        now: DateTime(2026),
      );
      expect((await studies.getStudy(copy))!.parallel, isFalse);
      final other = await groups.createGroup(name: 'B', now: DateTime(2026));
      await groups.moveToGroup(drill, other);
      expect((await studies.getStudy(drill))!.parallel, isFalse);
    });

    test('survives a backup round trip', () async {
      await study('Saw');
      final drill = await study('Drill');
      await groups.setParallel(drill, true);
      final json = await BackupService(db).exportJson(now: DateTime(2026));
      final target = await openTestDatabase();
      addTearDown(target.close);
      await BackupService(target).importJson(json, replace: false);
      final g = (await GroupRepository(target).listGroups()).single.group;
      final members = await StudyRepository(target).listStudies(groupId: g.id);
      expect(members.map((m) => (m.study.name, m.study.parallel)), [
        ('Saw', false),
        ('Drill', true),
      ]);
    });

    test('migration to schema 11 keeps old studies serial', () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('cyclescope_mig11');
      final file = path.join(dir.path, 'm.db');
      final v10 = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: file,
        version: 10,
      );
      await v10.db.insert('study', {
        'name': 'Old',
        'description': '',
        'mode': 'timeStudy',
        'created_at': 0,
        'last_active_at': 0,
      });
      await v10.close();
      final latest = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: file,
      );
      expect(
        (await StudyRepository(latest).listStudies()).single.study.parallel,
        isFalse,
      );
      await latest.close();
      await dir.delete(recursive: true);
    });
  });

  group('station labels', () {
    test('serial members are numbered, parallel ones get letters', () {
      expect(stationLabels([false, false, true, true, false]), [
        '1',
        '2a',
        '2b',
        '2c',
        '3',
      ]);
      // A parallel flag on the first member has nothing to be parallel to.
      expect(stationLabels([true, true]), ['1a', '1b']);
      expect(stationLabels([true]), ['1']);
      expect(stationLabels(const []), isEmpty);
    });

    test('members are grouped into stations', () {
      expect(stationGroups([false, true, false, true, true]), [
        [0, 1],
        [2, 3, 4],
      ]);
    });
  });

  group('machine with a fixed cycle time', () {
    MachineService service() =>
        MachineService(db, now: () => DateTime(2026, 4, 1, 9));

    test(
      'is a simple study whose real cycle time is the entered value',
      () async {
        await study('Saw');
        final id = await service().createMachine(
          name: 'Press 2',
          groupId: groupId,
          cycleMicros: 40 * 1000000,
          parallel: true,
        );
        final s = (await studies.getStudy(id))!;
        expect(s.mode, StudyMode.simple);
        expect(s.groupId, groupId);
        expect(s.parallel, isTrue);
        final times = await MeasurementRepository(db).listForStudy(id);
        expect(times.single.durationMicros, 40 * 1000000);
        expect(times.single.recordedAt, DateTime(2026, 4, 1, 9));
        final a = StudyAnalysis.compute(
          measurements: times,
          steps: const [],
          mode: StudyMode.simple,
          method: CycleTimeMethod.median,
        );
        expect(a.realCycleTime, 40 * 1000000);
        expect((await studies.listStudies(groupId: groupId)).last.study.id, id);
      },
    );

    test('changing the cycle time keeps the old one as a revision', () async {
      final id = await service().createMachine(
        name: 'Press 2',
        groupId: groupId,
        cycleMicros: 40 * 1000000,
      );
      await service().setCycleTime(id, 35 * 1000000);
      final times = await MeasurementRepository(db).listForStudy(id);
      expect(times.single.durationMicros, 35 * 1000000);
      final archived = await RevisionRepository(db).listRevisions(id);
      expect(archived.single.measurements.single.durationMicros, 40 * 1000000);
      expect((await studies.getStudy(id))!.revision, 2);
    });
  });
}

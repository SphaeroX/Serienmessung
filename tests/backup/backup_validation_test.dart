import 'dart:convert';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/demo/data/demo_data_service.dart';
import 'package:cyclescope/demo/presentation/demo_data_tile.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/l10n/app_localizations.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// A valid v2 file with a group, a study with a step, a time, a revision and
/// a special cycle. Tests break one field at a time.
Map<String, Object?> _file() => {
  'format': backupFormat,
  'version': 2,
  'groups': [
    {'ref': 1, 'name': 'Line', 'description': 'd', 'createdAt': 1000},
  ],
  'studies': [
    {
      'name': 'Press',
      'description': 'about',
      'mode': 'timeStudy',
      'createdAt': 2000,
      'lastActiveAt': 3000,
      'cycleTimeMethod': 'median',
      'videoPath': null,
      'notes': 'n',
      'groupRef': 1,
      'groupPosition': 0,
      'revision': 2,
      'bufferCapacity': 0,
      'bufferStore': 0,
      'bufferRetrieve': 0,
      'conveyorCapacity': 0,
      'conveyorTransport': 0,
      'steps': [
        {'ref': 7, 'position': 0, 'name': 'Pick'},
      ],
      'measurements': [
        {
          'cycle': 1,
          'stepRef': 7,
          'kind': 'normal',
          'start': 0,
          'end': 5,
          'duration': 5,
          'note': '',
          'recordedAt': 2500,
        },
      ],
      'revisions': [
        {
          'number': 1,
          'closedAt': 2400,
          'firstRecordedAt': 2100,
          'lastRecordedAt': 2300,
          'cycleTimeMethod': 'mean',
          'notes': '',
          'steps': [
            {'stepRef': 7, 'position': 0, 'name': 'Pick'},
          ],
          'measurements': [
            {
              'cycle': 1,
              'stepRef': 7,
              'kind': 'normal',
              'start': 0,
              'end': 4,
              'duration': 4,
              'note': 'x',
            },
          ],
        },
      ],
      'specialCycles': [
        {'name': 'Tool', 'kind': 'parts', 'interval': 10, 'duration': 30},
      ],
    },
  ],
};

Map<String, Object?> _study(Map<String, Object?> f) =>
    ((f['studies'] as List).single as Map).cast<String, Object?>();

void main() {
  late AppDatabase db;
  late BackupService backup;

  setUp(() async {
    db = await openTestDatabase();
    backup = BackupService(db);
  });

  tearDown(() => db.close());

  Future<void> expectRejected(Map<String, Object?> file) async {
    await expectLater(
      backup.importJson(jsonEncode(file), replace: false),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.invalid,
        ),
      ),
    );
    final studies = StudyRepository(db);
    expect(await studies.listStudies(), isEmpty);
    expect(await GroupRepository(db).listGroups(), isEmpty);
  }

  test('the valid file imports', () async {
    final result = await backup.importJson(jsonEncode(_file()), replace: false);
    expect(result.imported, 1);
  });

  test(
    'a text in lastActiveAt is rejected and the list stays readable',
    () async {
      final f = _file();
      _study(f)['lastActiveAt'] = 'yesterday';
      await expectRejected(f);
      expect(await StudyRepository(db).listStudies(), isEmpty);
    },
  );

  test('a text in groupPosition is rejected instead of a TypeError', () async {
    final f = _file();
    _study(f)['groupPosition'] = '3';
    await expectRejected(f);
  });

  test('a text in lastRecordedAt of a revision is rejected', () async {
    final f = _file();
    ((_study(f)['revisions'] as List).single as Map)['lastRecordedAt'] = 'x';
    await expectRejected(f);
  });

  final studyCases = <String, Object?>{
    'description': 5,
    'cycleTimeMethod': 3,
    'videoPath': 1,
    'notes': 12,
    'revision': '2',
    'groupPosition': 1.0,
    'lastActiveAt': 3000.0,
    'bufferCapacity': 'two',
    'bufferStore': -1,
    'bufferRetrieve': 'x',
    'conveyorCapacity': true,
    'conveyorTransport': 'x',
  };
  for (final MapEntry(:key, :value) in studyCases.entries) {
    test('study field $key = ${jsonEncode(value)} is rejected', () async {
      final f = _file();
      _study(f)[key] = value;
      await expectRejected(f);
    });
  }

  test('a revision number below 1 is rejected', () async {
    final f = _file();
    _study(f)['revision'] = 0;
    await expectRejected(f);
  });

  final timeCases = <String, Object?>{'stepRef': 'seven', 'note': 4};
  for (final MapEntry(:key, :value) in timeCases.entries) {
    test('time field $key = ${jsonEncode(value)} is rejected', () async {
      final f = _file();
      ((_study(f)['measurements'] as List).single as Map)[key] = value;
      await expectRejected(f);
    });
    test(
      'revision time field $key = ${jsonEncode(value)} is rejected',
      () async {
        final f = _file();
        final revision = (_study(f)['revisions'] as List).single as Map;
        ((revision['measurements'] as List).single as Map)[key] = value;
        await expectRejected(f);
      },
    );
  }

  final revisionCases = <String, Object?>{
    'firstRecordedAt': 'x',
    'lastRecordedAt': 1.5,
    'cycleTimeMethod': 1,
    'notes': false,
  };
  for (final MapEntry(:key, :value) in revisionCases.entries) {
    test('revision field $key = ${jsonEncode(value)} is rejected', () async {
      final f = _file();
      ((_study(f)['revisions'] as List).single as Map)[key] = value;
      await expectRejected(f);
    });
  }

  test('a special cycle name that is no text is rejected', () async {
    final f = _file();
    ((_study(f)['specialCycles'] as List).single as Map)['name'] = 3;
    await expectRejected(f);
  });

  test('a group description that is no text is rejected', () async {
    final f = _file();
    ((f['groups'] as List).single as Map)['description'] = 3;
    await expectRejected(f);
  });

  test('a file without the optional fields imports', () async {
    final v1 = {
      'format': backupFormat,
      'version': 1,
      'studies': [
        {
          'name': 'Old',
          'mode': 'simple',
          'createdAt': 1,
          'steps': <Object?>[],
          'measurements': [
            {'cycle': 1, 'kind': 'normal', 'start': 0, 'end': 2, 'duration': 2},
          ],
        },
      ],
    };
    final result = await backup.importJson(jsonEncode(v1), replace: false);
    expect(result.imported, 1);
    final early = _file()..remove('groups');
    final s = _study(early);
    for (final key in [
      'description',
      'lastActiveAt',
      'cycleTimeMethod',
      'videoPath',
      'notes',
      'groupRef',
      'groupPosition',
      'revision',
      'bufferCapacity',
      'bufferStore',
      'bufferRetrieve',
      'conveyorCapacity',
      'conveyorTransport',
      'revisions',
      'specialCycles',
    ]) {
      s.remove(key);
    }
    s['name'] = 'Early v2';
    ((s['measurements'] as List).single as Map)
      ..remove('note')
      ..remove('recordedAt');
    expect(
      (await backup.importJson(jsonEncode(early), replace: false)).imported,
      1,
    );
    expect(await StudyRepository(db).listStudies(), hasLength(2));
  });

  test('the app\'s own export of the demo data imports again', () async {
    final t = demoTextsOf(lookupAppLocalizations(const Locale('en')));
    await DemoDataService(db, now: () => DateTime(2026, 11, 13, 10)).load(t);
    final studies = StudyRepository(db);
    final before = await studies.listStudies();
    final groupsBefore = await GroupRepository(db).listGroups();
    var revisionsBefore = 0;
    for (final st in before) {
      revisionsBefore += (await RevisionRepository(
        db,
      ).listRevisions(st.study.id)).length;
    }
    final json = await backup.exportJson(now: DateTime(2026, 11, 14));

    final result = await backup.importJson(json, replace: true);
    expect(result.imported, before.length);
    final after = await studies.listStudies();
    expect(
      after.map((s) => s.study.name).toSet(),
      before.map((s) => s.study.name).toSet(),
    );
    expect(
      (await GroupRepository(db).listGroups()).length,
      groupsBefore.length,
    );
    var revisionsAfter = 0;
    for (final st in after) {
      revisionsAfter += (await RevisionRepository(
        db,
      ).listRevisions(st.study.id)).length;
    }
    expect(revisionsAfter, revisionsBefore);
    final specials = await db.db.query('special_cycle');
    expect(specials, isNotEmpty);
  });
}

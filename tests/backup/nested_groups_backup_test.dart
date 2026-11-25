import 'dart:convert';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/domain/group_member.dart';
import 'package:cyclescope/group/domain/stations.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() async {
    source = await openTestDatabase();
    target = await openTestDatabase();
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  var day = 0;

  Future<int> newGroup(AppDatabase db, String name, {int? parent}) async {
    final groups = GroupRepository(db);
    final id = await groups.createGroup(name: name, now: DateTime(2025));
    if (parent != null) await groups.setParent(id, parent);
    return id;
  }

  Future<int> study(
    AppDatabase db,
    String name,
    int groupId, {
    bool parallel = false,
  }) async {
    final id = await StudyRepository(db).createStudy(
      name: name,
      mode: StudyMode.simple,
      steps: const [],
      now: DateTime(2025, 1, 1, 0, ++day),
    );
    await GroupRepository(db).moveToGroup(id, groupId);
    if (parallel) await GroupRepository(db).setParallel(id, true);
    return id;
  }

  /// The tree of all top-level groups: "Plant(A1a A1b [Press(P) [Sub(S)]]
  /// B2 [Paint(C)])".
  Future<String> tree(AppDatabase db) async {
    final groups = GroupRepository(db);
    Future<String> describe(int id, String name) async {
      final members = await groups.listMembers(id);
      final studies = [
        for (final m in members)
          if (m is StudyMember) m.study,
      ];
      final labels = stationLabels([for (final s in studies) s.parallel]);
      var k = 0;
      final parts = <String>[];
      for (final m in members) {
        switch (m) {
          case StudyMember(:final study):
            parts.add('${study.name}${labels[k++]}');
          case AreaMember(:final group):
            parts.add('[${await describe(group.id, group.name)}]');
        }
      }
      return '$name(${parts.join(' ')})';
    }

    final top = [
      for (final s in await groups.listGroups())
        if (s.group.parentId == null) s.group,
    ];
    return [for (final g in top) await describe(g.id, g.name)].join(' ');
  }

  /// A plant: A, B (parallel), area Press (P, area Sub (S)), C, area
  /// Paint (D).
  Future<int> plant(AppDatabase db) async {
    final plant = await newGroup(db, 'Plant');
    await study(db, 'A', plant);
    await study(db, 'B', plant, parallel: true);
    final press = await newGroup(db, 'Press', parent: plant);
    await study(db, 'P', press);
    final sub = await newGroup(db, 'Sub', parent: press);
    await study(db, 'S', sub);
    await study(db, 'C', plant);
    final paint = await newGroup(db, 'Paint', parent: plant);
    await study(db, 'D', paint);
    return plant;
  }

  const plantTree = 'Plant(A1a B1b [Press(P1 [Sub(S1)])] C2 [Paint(D1)])';

  Future<String> export(AppDatabase db, {Set<int>? groups}) =>
      BackupService(db).exportJson(
        now: DateTime(2026),
        selection: groups == null ? null : ExportSelection(groupIds: groups),
      );

  test('round trip with replace restores the tree', () async {
    await plant(source);
    expect(await tree(source), plantTree);
    await BackupService(target).importJson(await export(source), replace: true);
    expect(await tree(target), plantTree);
  });

  test('merging the same file twice adds nothing the second time', () async {
    await plant(source);
    final json = await export(source);
    await BackupService(target).importJson(json, replace: false);
    final again = await BackupService(target).importJson(json, replace: false);
    expect(again.imported, 0);
    expect(await tree(target), plantTree);
    expect(await GroupRepository(target).listGroups(), hasLength(4));
  });

  test('merging behind existing members keeps the shared order', () async {
    final local = await newGroup(target, 'Plant');
    await study(target, 'Z', local);
    await plant(source);
    await BackupService(target)
        .importJson(await export(source), replace: false);
    expect(
      await tree(target),
      'Plant(Z1 A2a B2b [Press(P1 [Sub(S1)])] C3 [Paint(D1)])',
    );
  });

  test('sharing the plant takes all areas and their studies', () async {
    final id = await plant(source);
    final json = jsonDecode(await export(source, groups: {id})) as Map;
    expect(
      {for (final g in json['groups'] as List) g['name']},
      {'Plant', 'Press', 'Sub', 'Paint'},
    );
    expect(
      {for (final s in json['studies'] as List) s['name']},
      {'A', 'B', 'P', 'S', 'C', 'D'},
    );
  });

  test('sharing an area alone sends it without its parent', () async {
    await plant(source);
    final press = (await GroupRepository(
      source,
    ).listGroups()).firstWhere((g) => g.group.name == 'Press').group.id;
    final json = jsonDecode(await export(source, groups: {press})) as Map;
    final groups = (json['groups'] as List).cast<Map>();
    expect({for (final g in groups) g['name']}, {'Press', 'Sub'});
    final pressJson = groups.firstWhere((g) => g['name'] == 'Press');
    expect(pressJson['parentRef'], isNull);
    final subJson = groups.firstWhere((g) => g['name'] == 'Sub');
    expect(subJson['parentRef'], pressJson['ref']);
    await BackupService(target).importJson(jsonEncode(json), replace: false);
    expect(await tree(target), 'Press(P1 [Sub(S1)])');
  });

  test('a received area joins the one local area of that name', () async {
    // Colleague measures "Press" on their device.
    final press = await newGroup(source, 'Press');
    await study(source, 'P2', press);
    // Locally, Press already lies in the plant.
    final local = await newGroup(target, 'Plant');
    await study(target, 'A', local);
    final localPress = await newGroup(target, 'Press', parent: local);
    await study(target, 'P', localPress);
    await BackupService(target)
        .importJson(await export(source, groups: {press}), replace: false);
    expect(await tree(target), 'Plant(A1 [Press(P1 P22)])');
  });

  test('with two areas of that name a new top-level group is made', () async {
    final press = await newGroup(source, 'Press');
    await study(source, 'P2', press);
    final one = await newGroup(target, 'One');
    await newGroup(target, 'Press', parent: one);
    final two = await newGroup(target, 'Two');
    await newGroup(target, 'Press', parent: two);
    await BackupService(target)
        .importJson(await export(source, groups: {press}), replace: false);
    expect(await tree(target), 'One([Press()]) Press(P21) Two([Press()])');
  });

  test('two plants with an area of the same name stay apart', () async {
    final one = await newGroup(source, 'One');
    final m1 = await newGroup(source, 'Assembly', parent: one);
    await study(source, 'X', m1);
    final two = await newGroup(source, 'Two');
    final m2 = await newGroup(source, 'Assembly', parent: two);
    await study(source, 'Y', m2);
    await BackupService(target)
        .importJson(await export(source), replace: false);
    expect(await tree(target), 'One([Assembly(X1)]) Two([Assembly(Y1)])');
  });

  test('a study behind an area is never parallel after import', () async {
    final plant = await newGroup(source, 'Plant');
    await study(source, 'A', plant);
    await newGroup(source, 'X', parent: plant);
    await study(source, 'B', plant);
    final json = jsonDecode(await export(source)) as Map;
    for (final s in (json['studies'] as List).cast<Map>()) {
      if (s['name'] == 'B') {
        s['parallel'] = true;
        s['cellLoader'] = true;
      }
    }
    await BackupService(target).importJson(jsonEncode(json), replace: true);
    final b = (await StudyRepository(
      target,
    ).listStudies()).firstWhere((s) => s.study.name == 'B').study;
    expect(b.parallel, isFalse);
    expect(b.cellLoader, isFalse);
  });

  test('parents are created first, whatever the order in the file', () async {
    await plant(source);
    final json = jsonDecode(await export(source)) as Map;
    json['groups'] = (json['groups'] as List).reversed.toList();
    await BackupService(target).importJson(jsonEncode(json), replace: true);
    expect(await tree(target), plantTree);
  });

  group('invalid files change nothing', () {
    Future<void> rejects(void Function(List<Map> groups) edit) async {
      final local = await newGroup(target, 'Local');
      await study(target, 'L', local);
      await plant(source);
      final json = jsonDecode(await export(source)) as Map;
      edit((json['groups'] as List).cast<Map>());
      await expectLater(
        BackupService(target).importJson(jsonEncode(json), replace: true),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.invalid,
          ),
        ),
      );
      expect(await tree(target), 'Local(L1)');
    }

    test('unknown parent', () => rejects((g) => g.first['parentRef'] = 999));

    test('a cycle', () {
      return rejects((g) {
        final plant = g.firstWhere((x) => x['name'] == 'Plant');
        final sub = g.firstWhere((x) => x['name'] == 'Sub');
        plant['parentRef'] = sub['ref'];
      });
    });

    test('a group as its own parent', () {
      return rejects((g) => g.first['parentRef'] = g.first['ref']);
    });

    test('a position that is no number', () {
      return rejects((g) => g.last['parentPosition'] = 'first');
    });
  });

  test('a v2 file without the new fields loads flat as before', () async {
    final json = {
      'format': backupFormat,
      'version': 2,
      'exportedAt': '2025-01-01T00:00:00.000',
      'groups': [
        {'ref': 1, 'name': 'Line', 'description': '', 'createdAt': 0},
        {'ref': 2, 'name': 'Other', 'description': '', 'createdAt': 0},
      ],
      'studies': [
        {
          'name': 'A',
          'mode': 'simple',
          'createdAt': 0,
          'groupRef': 1,
          'groupPosition': 0,
          'steps': <Object>[],
          'measurements': <Object>[],
        },
      ],
    };
    await BackupService(target).importJson(jsonEncode(json), replace: false);
    expect(await tree(target), 'Line(A1) Other()');
  });
}

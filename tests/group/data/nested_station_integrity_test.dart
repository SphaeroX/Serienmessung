import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/domain/group_member.dart';
import 'package:cyclescope/group/domain/stations.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late StudyRepository studies;
  late int plant;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    studies = StudyRepository(db);
    plant = await groups.createGroup(name: 'Plant', now: DateTime(2026));
  });

  tearDown(() => db.close());

  Future<int> member(String name, {bool parallel = false}) async {
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.simple,
      steps: const [],
      now: DateTime(2026),
    );
    await groups.moveToGroup(id, plant);
    if (parallel) await groups.setParallel(id, true);
    return id;
  }

  Future<int> area(String name) async {
    final id = await groups.createGroup(name: name, now: DateTime(2026));
    await groups.setParent(id, plant);
    return id;
  }

  /// "1:A [X] 2a:B+buffer 2b:C": stations of the studies, numbered over
  /// the studies only; areas in brackets.
  Future<String> line() async {
    final list = await groups.listMembers(plant);
    final studyList = [
      for (final m in list)
        if (m is StudyMember) m.study,
    ];
    final labels = stationLabels([for (final x in studyList) x.parallel]);
    var k = 0;
    return [
      for (final m in list)
        switch (m) {
          AreaMember(:final group) => '[${group.name}]',
          StudyMember(:final study) =>
            '${labels[k++]}:${study.name}'
                '${study.hasBuffer ? '+buffer' : ''}'
                '${study.hasConveyor ? '+conveyor' : ''}'
                '${study.waitForSlowest ? '+wait' : ''}'
                '${study.cellLoader ? '+loader' : ''}',
        },
    ].join(' ');
  }

  test('a study right behind an area cannot be parallel or a loader', () async {
    await member('A');
    await area('X');
    final b = await member('B');
    await groups.setBuffer(
      b,
      capacity: 3,
      storeMicros: 2 * s,
      retrieveMicros: 2 * s,
    );
    await groups.setParallel(b, true);
    expect(await line(), '1:A [X] 2:B+buffer');
    await groups.setCellLoader(b, true);
    expect(await line(), '1:A [X] 2:B+buffer');
  });

  test('an area dropped inside a station splits it, both parts keep '
      'waiting', () async {
    final a = await member('A');
    await groups.setBuffer(
      a,
      capacity: 3,
      storeMicros: 2 * s,
      retrieveMicros: 2 * s,
    );
    final b = await member('B', parallel: true);
    final c = await member('C', parallel: true);
    final d = await member('D', parallel: true);
    await groups.setWaitForSlowest(a, true);
    final x = await area('X');
    expect(await line(), '1a:A+buffer+wait 1b:B 1c:C 1d:D [X]');
    await groups.reorderMembers(plant, [
      MemberKey.study(a),
      MemberKey.study(b),
      MemberKey.area(x),
      MemberKey.study(c),
      MemberKey.study(d),
    ], moved: MemberKey.area(x));
    // C is the first machine of a station of its own behind the area; the
    // buffer stays before A.
    expect(await line(), '1a:A+buffer+wait 1b:B [X] 2a:C+wait 2b:D');
  });

  test('a split part with a single machine stops waiting', () async {
    final a = await member('A');
    final b = await member('B', parallel: true);
    final c = await member('C', parallel: true);
    await groups.setWaitForSlowest(a, true);
    final x = await area('X');
    await groups.reorderMembers(plant, [
      MemberKey.study(a),
      MemberKey.area(x),
      MemberKey.study(b),
      MemberKey.study(c),
    ], moved: MemberKey.area(x));
    expect(await line(), '1:A [X] 2a:B+wait 2b:C');
  });

  test('an area between the first and the second machine', () async {
    final a = await member('A');
    final b = await member('B');
    await groups.setBuffer(
      b,
      capacity: 3,
      storeMicros: 2 * s,
      retrieveMicros: 2 * s,
    );
    await groups.setConveyor(b, capacity: 2, transportMicros: 5 * s);
    final c = await member('C', parallel: true);
    await groups.setCellLoader(c, true);
    final x = await area('X');
    await groups.reorderMembers(plant, [
      MemberKey.study(a),
      MemberKey.study(b),
      MemberKey.area(x),
      MemberKey.study(c),
    ], moved: MemberKey.area(x));
    expect(await line(), '1:A 2:B+buffer+conveyor [X] 3:C');
  });

  test('the first machine of a station behind an area leaves the group: '
      'the next one takes over', () async {
    await member('A');
    await area('X');
    final b = await member('B');
    await groups.setBuffer(
      b,
      capacity: 3,
      storeMicros: 2 * s,
      retrieveMicros: 2 * s,
    );
    await groups.setConveyor(b, capacity: 2, transportMicros: 5 * s);
    await member('C', parallel: true);
    await member('D', parallel: true);
    await groups.setWaitForSlowest(b, true);
    expect(await line(), '1:A [X] 2a:B+buffer+conveyor+wait 2b:C 2c:D');
    await groups.moveToGroup(b, null);
    expect(await line(), '1:A [X] 2a:C+buffer+conveyor+wait 2b:D');
  });

  test('moving a study over an area keeps the other stations', () async {
    final a = await member('A');
    final b = await member('B', parallel: true);
    final x = await area('X');
    final c = await member('C');
    await groups.setBuffer(
      c,
      capacity: 3,
      storeMicros: 2 * s,
      retrieveMicros: 2 * s,
    );
    final d = await member('D', parallel: true);
    final e = await member('E');
    expect(await line(), '1a:A 1b:B [X] 2a:C+buffer 2b:D 3:E');
    await groups.reorderMembers(plant, [
      MemberKey.study(e),
      MemberKey.study(a),
      MemberKey.study(b),
      MemberKey.area(x),
      MemberKey.study(c),
      MemberKey.study(d),
    ], moved: MemberKey.study(e));
    expect(await line(), '1:E 2a:A 2b:B [X] 3a:C+buffer 3b:D');
  });

  test('reorder by study ids with moved keeps an area boundary', () async {
    final a = await member('A');
    await area('X');
    final b = await member('B');
    final c = await member('C', parallel: true);
    // Move A behind C: it drops at the end, a station of its own.
    await groups.reorder(plant, [b, c, a], moved: a);
    expect(await line(), '[X] 1a:B 1b:C 2:A');
  });
}

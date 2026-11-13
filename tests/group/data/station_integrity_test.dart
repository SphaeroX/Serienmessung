import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
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

  /// "1:A 2a:B+buffer+conveyor 2b:C".
  Future<String> line([int? group]) async {
    final m = await studies.listStudies(groupId: group ?? groupId);
    final labels = stationLabels([for (final x in m) x.study.parallel]);
    return [
      for (var i = 0; i < m.length; i++)
        '${labels[i]}:${m[i].study.name}'
            '${m[i].study.hasBuffer ? '+buffer' : ''}'
            '${m[i].study.hasConveyor ? '+conveyor' : ''}',
    ].join(' ');
  }

  /// A, then the station B/C with a buffer and a conveyor before it, then D.
  Future<({int a, int b, int c, int d})> station() async {
    final a = await member('A');
    final b = await member('B');
    await groups.setBuffer(
      b,
      capacity: 5,
      storeMicros: 2 * s,
      retrieveMicros: 3 * s,
    );
    await groups.setConveyor(b, capacity: 4, transportMicros: 6 * s);
    final c = await member('C', parallel: true);
    final d = await member('D');
    expect(await line(), '1:A 2a:B+buffer+conveyor 2b:C 3:D');
    return (a: a, b: b, c: c, d: d);
  }

  group('the first machine of a parallel station leaves', () {
    test('removed from the group: the next machine takes over', () async {
      final x = await station();
      await groups.moveToGroup(x.b, null);
      expect(await line(), '1:A 2:C+buffer+conveyor 3:D');
      final c = (await studies.getStudy(x.c))!;
      expect(c.bufferCapacity, 5);
      expect(c.bufferStoreMicros, 2 * s);
      expect(c.bufferRetrieveMicros, 3 * s);
      expect(c.conveyorCapacity, 4);
      expect(c.conveyorTransportMicros, 6 * s);
      expect((await studies.getStudy(x.b))!.hasBuffer, isFalse);
    });

    test('moved to another group', () async {
      final x = await station();
      final other = await groups.createGroup(
        name: 'Other',
        now: DateTime(2026),
      );
      await groups.moveToGroup(x.b, other);
      expect(await line(), '1:A 2:C+buffer+conveyor 3:D');
      expect(await line(other), '1:B');
    });

    test('deleted', () async {
      final x = await station();
      await studies.deleteStudy(x.b);
      expect(await line(), '1:A 2:C+buffer+conveyor 3:D');
    });

    test('three machines: the others stay together', () async {
      final x = await station();
      await groups.reorder(groupId, [x.a, x.b, x.c, x.d]);
      await groups.setParallel(x.d, true);
      expect(await line(), '1:A 2a:B+buffer+conveyor 2b:C 2c:D');
      await studies.deleteStudy(x.b);
      expect(await line(), '1:A 2a:C+buffer+conveyor 2b:D');
    });

    test('the very first member: no buffer before the first station', () async {
      final a = await member('A');
      await member('B', parallel: true);
      await member('C');
      await groups.moveToGroup(a, null);
      expect(await line(), '1:B 2:C');
      final members = await studies.listStudies(groupId: groupId);
      expect(members.first.study.parallel, isFalse);
    });
  });

  test('removing a machine from the middle of a station', () async {
    final x = await station();
    await groups.setParallel(x.d, true);
    await groups.moveToGroup(x.c, null);
    expect(await line(), '1:A 2a:B+buffer+conveyor 2b:D');
  });

  group('reorder with the moved member', () {
    test('a head moves away: its station stays with the buffer', () async {
      final x = await station();
      await groups.reorder(groupId, [x.b, x.a, x.c, x.d], moved: x.b);
      expect(await line(), '1:B 2:A 3:C+buffer+conveyor 4:D');
      expect((await studies.getStudy(x.b))!.hasBuffer, isFalse);
      expect((await studies.getStudy(x.b))!.hasConveyor, isFalse);
    });

    test(
      'a machine dropped inside a station joins it without buffer',
      () async {
        final x = await station();
        await groups.setBuffer(
          x.d,
          capacity: 9,
          storeMicros: s,
          retrieveMicros: s,
        );
        await groups.reorder(groupId, [x.a, x.b, x.d, x.c], moved: x.d);
        expect(await line(), '1:A 2a:B+buffer+conveyor 2b:D 2c:C');
      },
    );

    test('a single station keeps its buffer when it moves', () async {
      final x = await station();
      await groups.setBuffer(
        x.d,
        capacity: 9,
        storeMicros: s,
        retrieveMicros: s,
      );
      final e = await member('E');
      await groups.reorder(groupId, [x.a, x.b, x.c, e, x.d], moved: x.d);
      expect(await line(), '1:A 2a:B+buffer+conveyor 2b:C 3:E 4:D+buffer');
    });

    test('a parallel machine moved out is a station of its own', () async {
      final x = await station();
      await groups.reorder(groupId, [x.a, x.b, x.d, x.c], moved: x.c);
      expect(await line(), '1:A 2:B+buffer+conveyor 3:D 4:C');
    });
  });
}

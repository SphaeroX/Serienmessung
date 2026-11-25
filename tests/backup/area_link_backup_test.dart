import 'dart:convert';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late int area;

  setUp(() async {
    source = await openTestDatabase();
    target = await openTestDatabase();
    final groups = GroupRepository(source);
    final plant = await groups.createGroup(name: 'Plant', now: DateTime(2025));
    final first = await groups.createGroup(name: 'Saw', now: DateTime(2025));
    await groups.setParent(first, plant);
    area = await groups.createGroup(name: 'Press', now: DateTime(2025));
    await groups.setParent(area, plant);
    await groups.setAreaBuffer(
      area,
      capacity: 6,
      storeMicros: 3 * s,
      retrieveMicros: 4 * s,
    );
    await groups.setAreaConveyor(area, capacity: 2, transportMicros: 9 * s);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<({int buffer, int store, int retrieve, int conveyor, int transport})>
  link(AppDatabase db) async {
    final g = (await GroupRepository(
      db,
    ).listGroups()).firstWhere((g) => g.group.name == 'Press').group;
    return (
      buffer: g.bufferCapacity,
      store: g.bufferStoreMicros,
      retrieve: g.bufferRetrieveMicros,
      conveyor: g.conveyorCapacity,
      transport: g.conveyorTransportMicros,
    );
  }

  test('a round trip keeps the link before an area', () async {
    final json = await BackupService(source).exportJson(now: DateTime(2026));
    final press = (jsonDecode(json)['groups'] as List).cast<Map>().firstWhere(
      (g) => g['name'] == 'Press',
    );
    expect(press['bufferCapacity'], 6);
    expect(press['conveyorTransport'], 9 * s);
    await BackupService(target).importJson(json, replace: true);
    expect(await link(target), (
      buffer: 6,
      store: 3 * s,
      retrieve: 4 * s,
      conveyor: 2,
      transport: 9 * s,
    ));
  });

  test(
    'an area shared alone arrives at the top level without the link',
    () async {
      final json = await BackupService(source).exportJson(
        now: DateTime(2026),
        selection: ExportSelection(groupIds: {area}),
      );
      await BackupService(target).importJson(json, replace: false);
      expect(await link(target), (
        buffer: 0,
        store: 0,
        retrieve: 0,
        conveyor: 0,
        transport: 0,
      ));
    },
  );

  test('a file without the fields loads without a link', () async {
    final data = jsonDecode(
      await BackupService(source).exportJson(now: DateTime(2026)),
    ) as Map;
    for (final g in (data['groups'] as List).cast<Map>()) {
      g.removeWhere((k, _) => k.toString().startsWith('buffer'));
      g.removeWhere((k, _) => k.toString().startsWith('conveyor'));
    }
    await BackupService(target).importJson(jsonEncode(data), replace: true);
    expect((await link(target)).buffer, 0);
    expect(
      (await GroupRepository(
        target,
      ).listGroups()).firstWhere((g) => g.group.name == 'Press').group.parentId,
      isNotNull,
    );
  });
}

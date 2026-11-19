import 'dart:io';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/export/presentation/export_menu.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_platform.dart';
import '../helpers.dart';
import 'export_menu_test.dart' show FakeFileSharer;

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeFileSharer sharer;
  late int groupId;

  setUp(() async {
    db = await openTestDatabase();
    dir = await Directory.systemTemp.createTemp('cyclescope_cell_export');
    sharer = FakeFileSharer();
    final groups = GroupRepository(db);
    groupId = await groups.createGroup(name: 'Cell', now: DateTime(2026));
    final machines = MachineService(db, now: () => DateTime(2026));
    Future<int> member(String name, int seconds) => machines.createMachine(
      name: name,
      groupId: groupId,
      cycleMicros: seconds * 1000000,
    );
    await groups.setCellMachines(await member('Machine', 88), 3);
    await groups.setCellLoader(await member('Loader 1', 32), true);
    await groups.setCellLoader(await member('Loader 2', 20), true);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  testWidgets('the Excel report of the app describes the loader cell', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 3, 20)),
          fileSharerProvider.overrideWithValue(sharer),
          exportDirectoryProvider.overrideWithValue(() async => dir),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(GroupScreen(groupId: groupId)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('groupExportButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('groupReportXlsx')));
    await tester.pump();
    await settleUntil(tester, () => sharer.shared.isNotEmpty);
    final bytes = (await tester.runAsync(
      () => File(sharer.shared.single.$1).readAsBytes(),
    ))!;
    final line = [
      for (final r in Excel.decodeBytes(bytes).tables['Line analysis']!.rows)
        [for (final c in r) c?.value?.toString() ?? ''],
    ];
    bool has(String first) => line.any((r) => r.isNotEmpty && r[0] == first);
    expect(has('Loader cell: 1. Machine'), isTrue);
    expect(has('Machine ×3'), isTrue);
    expect(has('Loader 1'), isTrue);
    expect(
      has(
        'From 3 machines on, another machine brings nothing: '
        'Loader 1 sets the pace.',
      ),
      isTrue,
    );
  });
}

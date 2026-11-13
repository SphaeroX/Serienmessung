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
    dir = await Directory.systemTemp.createTemp('cyclescope_risk_export');
    sharer = FakeFileSharer();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Press shop', now: DateTime(2026));
    final machines = MachineService(db, now: () => DateTime(2026));
    await machines.createMachine(
      name: 'Saw',
      groupId: groupId,
      cycleMicros: 12000000,
    );
    for (var i = 1; i <= 2; i++) {
      await machines.createMachine(
        name: 'Press $i',
        groupId: groupId,
        cycleMicros: 40000000,
        parallel: i > 1,
      );
    }
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  testWidgets('with parallel machines the report has the failure risk', (
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
    expect(Excel.decodeBytes(bytes).tables.keys.take(4), [
      'Contents',
      'Line analysis',
      'Failure risk',
      'Overview',
    ]);
  });
}

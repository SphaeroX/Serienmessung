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
    dir = await Directory.systemTemp.createTemp('cyclescope_buffer_export');
    sharer = FakeFileSharer();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Buffered', now: DateTime(2026));
    final machines = MachineService(db, now: () => DateTime(2026));
    await machines.createMachine(
      name: 'A',
      groupId: groupId,
      cycleMicros: 10000000,
    );
    final b = await machines.createMachine(
      name: 'B',
      groupId: groupId,
      cycleMicros: 5000000,
    );
    await GroupRepository(
      db,
    ).setBuffer(b, capacity: 20, storeMicros: 2000000, retrieveMicros: 2000000);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  testWidgets('a line with a buffer gets the simulated failure risk', (
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
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.keys, contains('Failure risk'));
    final risk = [
      for (final r in book.tables['Failure risk']!.rows)
        [for (final c in r) c?.value.toString()],
    ];
    expect(risk.any((r) => r.contains('Lost with buffers')), isTrue);
    final line = [
      for (final r in book.tables['Line analysis']!.rows)
        [for (final c in r) c?.value.toString()],
    ];
    expect(line.any((r) => r.contains('Before station')), isTrue);
  });
}

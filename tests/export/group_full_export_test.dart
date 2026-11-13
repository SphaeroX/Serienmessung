import 'dart:io';

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/export/presentation/export_menu.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
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
    dir = await Directory.systemTemp.createTemp('cyclescope_full_export');
    sharer = FakeFileSharer();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line 4', now: DateTime(2026));
    for (final (name, sec) in [('Saw', 4), ('Drill', 3)]) {
      final studies = StudyRepository(db);
      final id = await studies.createStudy(
        name: name,
        mode: StudyMode.timeStudy,
        steps: ['Cut'],
        now: DateTime(2026),
      );
      await MeasurementRepository(db).insert(
        id,
        MeasurementDraft(
          cycle: 1,
          stepId: (await studies.getSteps(id)).single.id,
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: sec * 1000000,
          durationMicros: sec * 1000000,
        ),
      );
      await GroupRepository(db).moveToGroup(id, groupId);
    }
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> export(WidgetTester tester, String key) async {
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
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
    await settleUntil(tester, () => sharer.shared.isNotEmpty);
  }

  testWidgets('the complete Excel report is linked', (tester) async {
    await export(tester, 'groupReportXlsx');
    expect(sharer.shared.single.$1, endsWith('Line_4_2026-03-20.xlsx'));
    final bytes = (await tester.runAsync(
      () => File(sharer.shared.single.$1).readAsBytes(),
    ))!;
    expect(Excel.decodeBytes(bytes).tables.keys.toList(), [
      'Contents',
      'Line analysis',
      'Overview',
      '1 Saw',
      '2 Drill',
    ]);
  });

  testWidgets('the complete PDF report is shared', (tester) async {
    await export(tester, 'groupReportPdf');
    expect(sharer.shared.single.$1, endsWith('Line_4_2026-03-20.pdf'));
    expect(sharer.shared.single.$2, 'application/pdf');
  });
}

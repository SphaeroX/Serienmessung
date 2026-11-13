import 'dart:io';

import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/export/presentation/export_menu.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_platform.dart';
import '../helpers.dart';
import 'export_menu_test.dart' show FakeFileSharer;

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeFileSharer sharer;
  late int groupId;
  late int sawId;

  Future<int> study(String name, int seconds, DateTime at) async {
    final studies = StudyRepository(db);
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.timeStudy,
      steps: ['Cut'],
      now: DateTime(2026),
    );
    final step = (await studies.getSteps(id)).single;
    await MeasurementRepository(db, now: () => at).insert(
      id,
      MeasurementDraft(
        cycle: 1,
        stepId: step.id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: seconds * 1000000,
        durationMicros: seconds * 1000000,
      ),
    );
    await GroupRepository(db).moveToGroup(id, groupId);
    return id;
  }

  setUp(() async {
    db = await openTestDatabase();
    dir = await Directory.systemTemp.createTemp('cyclescope_group_export');
    sharer = FakeFileSharer();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line 4', now: DateTime(2026));
    sawId = await study('Saw', 4, DateTime(2025, 3, 1));
    // Revision 1 of the saw took 4 s, the current one 6 s.
    await RevisionRepository(db).startNewRevision(sawId, now: DateTime(2026));
    final cut = (await StudyRepository(db).getSteps(sawId)).single;
    await MeasurementRepository(db, now: () => DateTime(2026, 3, 2, 9)).insert(
      sawId,
      MeasurementDraft(
        cycle: 1,
        stepId: cut.id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: 6000000,
        durationMicros: 6000000,
      ),
    );
    await study('Drill', 3, DateTime(2026, 3, 3));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  List<Override> overrides() => [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(FakeClock(1) as Clock),
    wallClockProvider.overrideWithValue(() => DateTime(2026, 3, 20)),
    fileSharerProvider.overrideWithValue(sharer),
    exportDirectoryProvider.overrideWithValue(() async => dir),
    ...fakePlatformOverrides(),
  ];

  Future<void> exportGroup(WidgetTester tester, String key) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
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

  testWidgets('the group is exported as Excel with one sheet per study', (
    tester,
  ) async {
    await exportGroup(tester, 'groupExportXlsx');
    expect(sharer.shared.single.$1, endsWith('Line_4_2026-03-20.xlsx'));
    final bytes = (await tester.runAsync(
      () => File(sharer.shared.single.$1).readAsBytes(),
    ))!;
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.keys.toList(), ['Overview', '1 Saw', '2 Drill']);
    final overview = book.tables['Overview']!.rows
        .map((r) => [for (final c in r) c?.value.toString()])
        .toList();
    final saw = overview.firstWhere((r) => r.length > 1 && r[1] == 'Saw');
    expect(saw, contains('2026-03-02 09:00'));
    expect(saw, contains('2'));
  });

  testWidgets('the group is exported as a PDF report', (tester) async {
    await exportGroup(tester, 'groupExportPdf');
    expect(sharer.shared.single.$1, endsWith('Line_4_2026-03-20.pdf'));
    expect(sharer.shared.single.$2, 'application/pdf');
  });

  testWidgets('a single export names revision and last measurement', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: localizedApp(RecordingScreen(studyId: sawId)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('exportButton')));
    await pumpFrames(tester, count: 5);
    await tester.tap(find.byKey(const Key('exportCsv')));
    await pumpFrames(tester, count: 3);
    await settleUntil(tester, () => sharer.shared.isNotEmpty);
    final content = (await tester.runAsync(
      () => File(sharer.shared.single.$1).readAsString(),
    ))!;
    expect(content, contains('Revision,2'));
    expect(content, contains('Last measurement,2026-03-02 09:00'));
  });
}

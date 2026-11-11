import 'dart:io';

import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/export/platform/file_sharer.dart';
import 'package:cyclescope/export/presentation/export_menu.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_platform.dart';
import '../helpers.dart';

class FakeFileSharer implements FileSharer {
  final shared = <(String, String)>[];

  @override
  Future<void> share(
    String path, {
    required String mimeType,
    String? subject,
  }) async => shared.add((path, mimeType));
}

void main() {
  late AppDatabase db;
  late int studyId;
  late Directory dir;
  late FakeFileSharer sharer;

  setUp(() async {
    db = await openTestDatabase();
    dir = await Directory.systemTemp.createTemp('cyclescope_export');
    sharer = FakeFileSharer();
    final studies = StudyRepository(db);
    studyId = await studies.createStudy(
      name: 'Line 200',
      mode: StudyMode.timeStudy,
      steps: ['Pick'],
      now: DateTime(2026),
    );
    final step = (await studies.getSteps(studyId)).single;
    await MeasurementRepository(db).insert(
      studyId,
      MeasurementDraft(
        cycle: 1,
        stepId: step.id,
        kind: MeasurementKind.normal,
        startMicros: 0,
        endMicros: 2000000,
        durationMicros: 2000000,
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> exportAs(WidgetTester tester, String key) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FakeClock(1) as Clock),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 11, 11)),
          fileSharerProvider.overrideWithValue(sharer),
          exportDirectoryProvider.overrideWithValue(() async => dir),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(RecordingScreen(studyId: studyId)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('exportButton')));
    await pumpFrames(tester, count: 5);
    await tester.tap(find.byKey(Key(key)));
    await pumpFrames(tester, count: 3);
    await settle(tester);
  }

  testWidgets('exports a CSV file and opens the share sheet', (tester) async {
    await exportAs(tester, 'exportCsv');
    expect(sharer.shared.single.$1, endsWith('Line_200_2026-11-11.csv'));
    expect(sharer.shared.single.$2, 'text/csv');
    final content = await tester.runAsync(
      () => File(sharer.shared.single.$1).readAsString(),
    );
    expect(content, contains('Line 200'));
    expect(content, contains('Pick'));
  });

  testWidgets('exports an Excel file', (tester) async {
    await exportAs(tester, 'exportXlsx');
    expect(sharer.shared.single.$1, endsWith('.xlsx'));
    final size = await tester.runAsync(
      () => File(sharer.shared.single.$1).length(),
    );
    expect(size, greaterThan(1000));
  });

  test('file names are safe', () {
    expect(
      exportFileName('Band / voll: 200-210', DateTime(2026, 1, 2), 'csv'),
      'Band_voll_200-210_2026-01-02.csv',
    );
    expect(
      exportFileName('///', DateTime(2026), 'pdf'),
      'study_2026-01-01.pdf',
    );
  });

  testWidgets('exports a PDF report', (tester) async {
    await exportAs(tester, 'exportPdf');
    expect(sharer.shared.single.$1, endsWith('.pdf'));
    expect(sharer.shared.single.$2, 'application/pdf');
  });
}

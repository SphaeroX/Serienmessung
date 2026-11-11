import 'dart:io';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/backup/platform/backup_picker.dart';
import 'package:cyclescope/backup/presentation/backup_tiles.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/export/presentation/export_menu.dart';
import 'package:cyclescope/settings/presentation/settings_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../export/export_menu_test.dart' show FakeFileSharer;
import '../fakes/fake_platform.dart';
import '../helpers.dart';

class FakeBackupPicker implements BackupPicker {
  FakeBackupPicker(this.content);

  final String? content;

  @override
  Future<String?> pickBackup() async => content;
}

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeFileSharer sharer;

  setUp(() async {
    db = await openTestDatabase();
    dir = await Directory.systemTemp.createTemp('cyclescope_backup');
    sharer = FakeFileSharer();
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, {String? pick}) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 11, 11)),
          fileSharerProvider.overrideWithValue(sharer),
          exportDirectoryProvider.overrideWithValue(() async => dir),
          backupPickerProvider.overrideWithValue(FakeBackupPicker(pick)),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(const SettingsScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('creating a backup shares a JSON file', (tester) async {
    await tester.runAsync(
      () => StudyRepository(db).createStudy(
        name: 'Line',
        mode: StudyMode.simple,
        steps: const [],
        now: DateTime(2026),
      ),
    );
    await pump(tester);
    await tapVisible(tester, find.byKey(const Key('createBackupTile')));
    // Writing the backup file takes longer on slow machines (CI).
    await settleUntil(tester, () => sharer.shared.isNotEmpty);
    expect(
      sharer.shared.single.$1,
      endsWith('cyclescope_backup_2026-11-11.json'),
    );
    final text = await tester.runAsync(
      () => File(sharer.shared.single.$1).readAsString(),
    );
    expect(text, contains('"format": "cyclescope-backup"'));
    expect(text, contains('"name": "Line"'));
  });

  testWidgets('restoring merges studies from the file', (tester) async {
    // Build a backup in a second database.
    final other = await tester.runAsync(openTestDatabase);
    final json = await tester.runAsync(() async {
      await StudyRepository(other!).createStudy(
        name: 'From backup',
        mode: StudyMode.timeStudy,
        steps: ['A'],
        now: DateTime(2025),
      );
      final j = await BackupService(other).exportJson(now: DateTime(2026));
      await other.close();
      return j;
    });

    await pump(tester, pick: json);
    await tapVisible(tester, find.byKey(const Key('restoreBackupTile')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('restoreMerge')));
    await settle(tester);
    await pumpFrames(tester, count: 3);
    expect(find.textContaining('1 imported'), findsOneWidget);
    final list = await tester.runAsync(() => StudyRepository(db).listStudies());
    expect(list!.single.study.name, 'From backup');
  });

  testWidgets('an invalid file shows an error', (tester) async {
    await pump(tester, pick: 'not json');
    await tapVisible(tester, find.byKey(const Key('restoreBackupTile')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('restoreMerge')));
    await settle(tester);
    await pumpFrames(tester, count: 3);
    expect(find.textContaining('not a valid'), findsOneWidget);
  });
}

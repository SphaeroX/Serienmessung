import 'dart:convert';
import 'dart:io';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/backup/presentation/backup_tiles.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/export/presentation/export_menu.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/recording/data/run_state_repository.dart';
import 'package:cyclescope/recording/domain/recording_engine.dart';
import 'package:cyclescope/recording/platform/recording_notifier.dart';
import 'package:cyclescope/settings/presentation/settings_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/study_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../export/export_menu_test.dart' show FakeFileSharer;
import '../fakes/fake_platform.dart';
import '../helpers.dart';
import 'backup_tiles_test.dart' show FakeBackupPicker;

const _notice = RecordingNotice(
  title: 't',
  text: 'x',
  elapsedMicros: 0,
  running: true,
  nextLabel: 'Next',
  toggleLabel: 'Stop',
);

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeRecordingNotifier notifier;
  late StudyRepository studies;

  setUp(() async {
    db = await openTestDatabase();
    dir = await Directory.systemTemp.createTemp('cyclescope_restore');
    notifier = FakeRecordingNotifier();
    studies = StudyRepository(db);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<int> study(String name, {int day = 1}) => studies.createStudy(
    name: name,
    mode: StudyMode.timeStudy,
    steps: ['A'],
    now: DateTime(2026, 1, day),
  );

  Future<void> saveRun(int studyId, DateTime at) => RunStateRepository(db).save(
    studyId,
    const EngineSnapshot(
      status: EngineStatus.running,
      cycle: 1,
      stepIndex: 0,
      currentStepId: null,
      stepStartMicros: 0,
      segmentStartMicros: 0,
      accumulatedMicros: 0,
      specialStartMicros: 0,
    ),
    clockMicros: 0,
    now: at,
  );

  /// A backup made in a second database with a group "From backup".
  Future<String> otherBackup() async {
    final other = await openTestDatabase();
    final g = await GroupRepository(other)
        .createGroup(name: 'From backup', now: DateTime(2025));
    final st = await StudyRepository(other).createStudy(
      name: 'Backup study',
      mode: StudyMode.timeStudy,
      steps: ['A'],
      now: DateTime(2025),
    );
    await GroupRepository(other).moveToGroup(st, g);
    final json = await BackupService(other).exportJson(now: DateTime(2026));
    await other.close();
    return json;
  }

  List<Override> overrides(String? pick) => [
    databaseProvider.overrideWithValue(db),
    wallClockProvider.overrideWithValue(() => DateTime(2026, 11, 26)),
    fileSharerProvider.overrideWithValue(FakeFileSharer()),
    exportDirectoryProvider.overrideWithValue(() async => dir),
    backupPickerProvider.overrideWithValue(FakeBackupPicker(pick)),
    ...fakePlatformOverrides(notifier: notifier),
  ];

  Future<void> pumpSettings(WidgetTester tester, {String? pick}) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(pick),
        child: localizedApp(const SettingsScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> restore(WidgetTester tester, {required bool replace}) async {
    await tapVisible(tester, find.byKey(const Key('restoreBackupTile')));
    await settle(tester);
    if (replace) {
      await tester.tap(find.byKey(const Key('restoreReplace')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('restoreReplaceConfirm')));
    } else {
      await tester.tap(find.byKey(const Key('restoreMerge')));
    }
    await settle(tester);
    await pumpFrames(tester, count: 3);
  }

  /// Makes every insert into `study` fail inside the import transaction.
  Future<void> breakStudyInserts() => db.db.execute(
    'CREATE TRIGGER no_study BEFORE INSERT ON study '
    "BEGIN SELECT RAISE(ABORT, 'broken'); END",
  );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  group('restore', () {
    testWidgets('an unexpected error shows "not valid"', (tester) async {
      final json = (await tester.runAsync(otherBackup))!;
      await tester.runAsync(breakStudyInserts);
      await pumpSettings(tester, pick: json);
      await restore(tester, replace: false);
      expect(find.textContaining('not a valid'), findsOneWidget);
    });

    for (final replace in [true, false]) {
      testWidgets('the group list is fresh after restoring '
          '(${replace ? 'replace' : 'merge'})', (tester) async {
        await tester.runAsync(
          () =>
              GroupRepository(db).createGroup(name: 'Old', now: DateTime(2026)),
        );
        final json = (await tester.runAsync(otherBackup))!;
        await pumpSettings(tester, pick: json);
        final before = (await tester.runAsync(
          () => container(tester).read(groupListProvider.future),
        ))!;
        expect(before.map((g) => g.group.name), ['Old']);

        await restore(tester, replace: replace);
        final after = (await tester.runAsync(
          () => container(tester).read(groupListProvider.future),
        ))!;
        expect(
          after.map((g) => g.group.name).toSet(),
          replace ? {'From backup'} : {'Old', 'From backup'},
        );
      });
    }

    testWidgets('replacing hides the notification of a running recording', (
      tester,
    ) async {
      final id = (await tester.runAsync(() => study('Running')))!;
      await tester.runAsync(() => saveRun(id, DateTime(2026, 11, 26)));
      final json = (await tester.runAsync(otherBackup))!;
      await pumpSettings(tester, pick: json);
      notifier.shown = _notice;
      await restore(tester, replace: true);
      expect(notifier.shown, isNull);
    });

    testWidgets('merging keeps the notification', (tester) async {
      final id = (await tester.runAsync(() => study('Running')))!;
      await tester.runAsync(() => saveRun(id, DateTime(2026, 11, 26)));
      final json = (await tester.runAsync(otherBackup))!;
      await pumpSettings(tester, pick: json);
      notifier.shown = _notice;
      await restore(tester, replace: false);
      expect(notifier.shown, isNotNull);
    });
  });

  group('import button', () {
    Future<void> pumpList(WidgetTester tester, {String? pick}) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(pick),
          child: localizedApp(const StudyListScreen()),
        ),
      );
      await settle(tester);
    }

    Future<void> import(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('importButton')));
      await settle(tester);
      await pumpFrames(tester, count: 3);
    }

    testWidgets('an invalid file shows "cannot be imported"', (tester) async {
      final json = (await tester.runAsync(otherBackup))!;
      final broken = jsonDecode(json) as Map<String, Object?>;
      ((broken['studies'] as List).single as Map)['lastActiveAt'] = 'yesterday';
      await pumpList(tester, pick: jsonEncode(broken));
      await import(tester);
      expect(find.textContaining('cannot be imported'), findsOneWidget);
    });

    testWidgets('an unexpected error shows "cannot be imported"', (
      tester,
    ) async {
      final json = (await tester.runAsync(otherBackup))!;
      await tester.runAsync(breakStudyInserts);
      await pumpList(tester, pick: json);
      await import(tester);
      expect(find.textContaining('cannot be imported'), findsOneWidget);
    });
  });

  group('deleting a study', () {
    Future<void> pumpList(WidgetTester tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(null),
          child: localizedApp(const StudyListScreen()),
        ),
      );
      await settle(tester);
      // The "recording in progress" question: leave it open-ended.
      if (find.byKey(const Key('openRunButton')).evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(5, 5));
        await settle(tester);
      }
    }

    Future<void> deleteViaMenu(WidgetTester tester, String name) async {
      await tester.tap(
        find.descendant(
          of: find.ancestor(of: find.text(name), matching: find.byType(Card)),
          matching: find.byType(PopupMenuButton<StudyCardAction>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deleteStudyItem')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await settle(tester);
    }

    Future<void> deleteViaSelection(WidgetTester tester, String name) async {
      await tester.longPress(find.text(name));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deleteSelected')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmDeleteSelected')));
      await settle(tester);
    }

    for (final (label, delete) in [
      ('menu', deleteViaMenu),
      ('selection', deleteViaSelection),
    ]) {
      testWidgets('a recording study hides the notification ($label)', (
        tester,
      ) async {
        final id = (await tester.runAsync(() => study('Running')))!;
        await tester.runAsync(() => saveRun(id, DateTime(2026, 11, 26)));
        await pumpList(tester);
        notifier.shown = _notice;
        await delete(tester, 'Running');
        expect(notifier.shown, isNull);
      });

      testWidgets('a study without recording keeps it ($label)', (
        tester,
      ) async {
        final running = (await tester.runAsync(() => study('Running')))!;
        await tester.runAsync(() => study('Idle', day: 2));
        await tester.runAsync(() => saveRun(running, DateTime(2026, 11, 26)));
        await pumpList(tester);
        notifier.shown = _notice;
        await delete(tester, 'Idle');
        expect(notifier.shown, isNotNull);
      });
    }

    testWidgets('an older recording keeps the newer one\'s notification', (
      tester,
    ) async {
      final old = (await tester.runAsync(() => study('Old run')))!;
      final recent = (await tester.runAsync(() => study('New run', day: 2)))!;
      await tester.runAsync(() => saveRun(old, DateTime(2026, 11, 20)));
      await tester.runAsync(() => saveRun(recent, DateTime(2026, 11, 26)));
      await pumpList(tester);
      notifier.shown = _notice;
      await deleteViaMenu(tester, 'Old run');
      expect(notifier.shown, isNotNull);
    });
  });
}

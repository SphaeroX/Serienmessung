import 'dart:convert';
import 'dart:io';

import 'package:cyclescope/backup/data/backup_service.dart';
import 'package:cyclescope/backup/presentation/backup_tiles.dart';
import 'package:cyclescope/backup/presentation/share_actions.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/export/presentation/export_menu.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/presentation/group_list_screen.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/study_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../export/export_menu_test.dart' show FakeFileSharer;
import '../fakes/fake_platform.dart';
import '../helpers.dart';
import 'backup_tiles_test.dart' show FakeBackupPicker;

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeFileSharer sharer;
  late int line;
  late int saw;
  late int drill;

  Future<int> study(AppDatabase on, String name, int day) => StudyRepository(on)
      .createStudy(
        name: name,
        mode: StudyMode.timeStudy,
        steps: ['A'],
        now: DateTime(2025, 1, day),
      );

  setUp(() async {
    db = await openTestDatabase();
    dir = await Directory.systemTemp.createTemp('cyclescope_share');
    sharer = FakeFileSharer();
    line = await GroupRepository(db)
        .createGroup(name: 'Line 4', now: DateTime(2025));
    saw = await study(db, 'Saw', 1);
    drill = await study(db, 'Drill', 2);
    await study(db, 'Loose', 3);
    await GroupRepository(db).moveToGroup(saw, line);
    await GroupRepository(db).moveToGroup(drill, line);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, Widget screen, {String? pick}) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 11, 17)),
          fileSharerProvider.overrideWithValue(sharer),
          exportDirectoryProvider.overrideWithValue(() async => dir),
          backupPickerProvider.overrideWithValue(FakeBackupPicker(pick)),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(screen),
      ),
    );
    await settle(tester);
  }

  Future<Map> sharedJson(WidgetTester tester) async {
    await settleUntil(tester, () => sharer.shared.isNotEmpty);
    final text = await tester.runAsync(
      () => File(sharer.shared.single.$1).readAsString(),
    );
    return jsonDecode(text!) as Map;
  }

  List<Object?> names(Map json) => [
    for (final s in json['studies'] as List) s['name'],
  ];

  test('share file names use the item name and the date', () {
    expect(
      shareFileName('Line 4 / Saw', DateTime(2026, 11, 17)),
      'cyclescope_Line_4_Saw_2026-11-17.json',
    );
    expect(
      shareFileName('Säge', DateTime(2026, 1, 2)),
      'cyclescope_Säge_2026-01-02.json',
    );
  });

  group('study list', () {
    const screen = StudyListScreen(checkActiveRuns: false);

    testWidgets('long press starts selecting, taps toggle', (tester) async {
      await pump(tester, screen);
      await tester.longPress(find.text('Saw'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Loose'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.text('Saw'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('clearSelection')));
      await tester.pump();
      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgets('select all selects every study', (tester) async {
      await pump(tester, screen);
      await tester.longPress(find.text('Saw'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('selectAll')));
      await tester.pump();
      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('sharing the selection shares exactly those studies', (
      tester,
    ) async {
      await pump(tester, screen);
      await tester.longPress(find.text('Saw'));
      await tester.pump();
      await tester.tap(find.text('Loose'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('shareSelected')));
      final json = await sharedJson(tester);
      expect(names(json), unorderedEquals(['Saw', 'Loose']));
      expect(json['groups'], isEmpty);
      expect(
        sharer.shared.single.$1,
        endsWith('cyclescope_studies_2026-11-17.json'),
      );
      expect(sharer.shared.single.$2, 'application/json');
    });

    testWidgets('one study is shared from its card menu', (tester) async {
      await pump(tester, screen);
      await tester.tap(find.byKey(Key('studyMenu_$saw')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shareStudyItem')));
      await pumpFrames(tester, count: 5);
      final json = await sharedJson(tester);
      expect(names(json), ['Saw']);
      expect(
        sharer.shared.single.$1,
        endsWith('cyclescope_Saw_2026-11-17.json'),
      );
    });

    testWidgets('deleting the selection asks and deletes', (tester) async {
      await pump(tester, screen);
      await tester.longPress(find.text('Saw'));
      await tester.pump();
      await tester.tap(find.text('Drill'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deleteSelected')));
      await settle(tester);
      expect(
        find.text('Delete 2 studies including all measurements?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirmDeleteSelected')));
      await settle(tester);
      final left = await tester.runAsync(
        () => StudyRepository(db).listStudies(),
      );
      expect(left!.map((s) => s.study.name), ['Loose']);
      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgets('importing a received file adds its studies', (tester) async {
      final json = await tester.runAsync(() async {
        final other = await openTestDatabase();
        await study(other, 'From colleague', 9);
        final j = await BackupService(other).exportJson(now: DateTime(2026));
        await other.close();
        return j;
      });
      await pump(tester, screen, pick: json);
      await tester.tap(find.byKey(const Key('importButton')));
      await settleUntil(
        tester,
        () => find.text('From colleague').evaluate().isNotEmpty,
      );
      await pumpFrames(tester, count: 3);
      expect(find.text('From colleague'), findsOneWidget);
      expect(find.textContaining('1 study imported.'), findsOneWidget);
    });

    testWidgets('an invalid file is reported', (tester) async {
      await pump(tester, screen, pick: 'not json');
      await tester.tap(find.byKey(const Key('importButton')));
      await settle(tester);
      await pumpFrames(tester, count: 3);
      expect(find.textContaining('cannot be imported'), findsOneWidget);
    });
  });

  group('group list', () {
    const screen = GroupListScreen();

    testWidgets('sharing a selected group shares it with its studies', (
      tester,
    ) async {
      await pump(tester, screen);
      await tester.longPress(find.text('Line 4'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shareSelected')));
      final json = await sharedJson(tester);
      expect([for (final g in json['groups'] as List) g['name']], ['Line 4']);
      expect(names(json), unorderedEquals(['Saw', 'Drill']));
      expect(
        sharer.shared.single.$1,
        endsWith('cyclescope_Line_4_2026-11-17.json'),
      );
    });

    testWidgets('deleting groups can keep their studies', (tester) async {
      await pump(tester, screen);
      await tester.longPress(find.text('Line 4'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deleteSelected')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('deleteGroupsKeepStudies')));
      await settle(tester);
      expect(
        await tester.runAsync(() => GroupRepository(db).listGroups()),
        isEmpty,
      );
      final left = await tester.runAsync(
        () => StudyRepository(db).listStudies(),
      );
      expect(left, hasLength(3));
    });

    testWidgets('deleting groups can delete their studies too', (tester) async {
      await pump(tester, screen);
      await tester.longPress(find.text('Line 4'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deleteSelected')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('deleteGroupsWithStudies')));
      await settle(tester);
      expect(
        await tester.runAsync(() => GroupRepository(db).listGroups()),
        isEmpty,
      );
      final left = await tester.runAsync(
        () => StudyRepository(db).listStudies(),
      );
      expect(left!.map((s) => s.study.name), ['Loose']);
    });

    testWidgets('importing a shared group shows it in the list', (
      tester,
    ) async {
      final json = await tester.runAsync(() async {
        final other = await openTestDatabase();
        final g = await GroupRepository(other)
            .createGroup(name: 'Line 9', now: DateTime(2025));
        final s = await study(other, 'Press', 5);
        await GroupRepository(other).moveToGroup(s, g);
        final j = await BackupService(other).exportJson(
          now: DateTime(2026),
          selection: ExportSelection(groupIds: {g}),
        );
        await other.close();
        return j;
      });
      await pump(tester, screen, pick: json);
      await tester.tap(find.byKey(const Key('importButton')));
      await settleUntil(
        tester,
        () => find.text('Line 9').evaluate().isNotEmpty,
      );
      expect(find.text('Line 9'), findsOneWidget);
    });
  });

  testWidgets('a group is shared from the group screen menu', (tester) async {
    await pump(tester, GroupScreen(groupId: line));
    await tester.tap(find.byKey(const Key('groupMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shareGroup')));
    await pumpFrames(tester, count: 5);
    final json = await sharedJson(tester);
    expect(names(json), unorderedEquals(['Saw', 'Drill']));
  });
}

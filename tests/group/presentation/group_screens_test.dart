import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/presentation/group_list_screen.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:cyclescope/study/presentation/study_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late StudyRepository studies;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    studies = StudyRepository(db);
  });

  tearDown(() => db.close());

  Future<int> study(String name) => studies.createStudy(
    name: name,
    mode: StudyMode.timeStudy,
    steps: ['A'],
    now: DateTime(2026),
  );

  Widget app(Widget child) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      wallClockProvider.overrideWithValue(() => DateTime(2026, 3, 1)),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(child),
  );

  Future<List<String>> memberNames(int groupId) async => [
    for (final s in await studies.listStudies(groupId: groupId)) s.study.name,
  ];

  testWidgets('creating a group opens it', (tester) async {
    await tester.pumpWidget(app(const GroupListScreen()));
    await settle(tester);
    expect(find.text('No groups yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('newGroupFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('groupNameField')), 'Line 4');
    await tester.enterText(
      find.byKey(const Key('groupDescriptionField')),
      'Assembly',
    );
    await tester.tap(find.byKey(const Key('saveGroupButton')));
    await settle(tester);
    await tester.pumpAndSettle();

    final g = (await tester.runAsync(groups.listGroups))!.single.group;
    expect(g.name, 'Line 4');
    expect(g.description, 'Assembly');
    expect(find.byType(GroupScreen), findsOneWidget);
    expect(find.text('No studies in this group yet'), findsOneWidget);
  });

  testWidgets('group list shows groups with their study count', (tester) async {
    final g = (await tester.runAsync(
      () => groups.createGroup(name: 'Line 4', now: DateTime(2026)),
    ))!;
    await tester.runAsync(() async {
      await groups.moveToGroup(await study('Saw'), g);
      await groups.moveToGroup(await study('Drill'), g);
    });
    await tester.pumpWidget(app(const GroupListScreen()));
    await settle(tester);
    expect(find.text('Line 4'), findsOneWidget);
    expect(find.text('2 studies'), findsOneWidget);
  });

  testWidgets('group screen lists studies in order and moves them', (
    tester,
  ) async {
    late int g;
    late int saw;
    await tester.runAsync(() async {
      g = await groups.createGroup(name: 'Line 4', now: DateTime(2026));
      saw = await study('Saw');
      await groups.moveToGroup(saw, g);
      await groups.moveToGroup(await study('Drill'), g);
    });
    await tester.pumpWidget(app(GroupScreen(groupId: g)));
    await settle(tester);
    expect(find.text('Line 4'), findsOneWidget);
    expect(find.text('1. Saw'), findsOneWidget);
    expect(find.text('2. Drill'), findsOneWidget);

    await tester.tap(find.byKey(Key('groupStudyMenu_$saw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveDown')));
    await settle(tester);
    expect(await tester.runAsync(() => memberNames(g)), ['Drill', 'Saw']);
    expect(find.text('1. Drill'), findsOneWidget);
    expect(find.text('2. Saw'), findsOneWidget);
  });

  testWidgets('dragging the handle reorders the studies', (tester) async {
    late int g;
    await tester.runAsync(() async {
      g = await groups.createGroup(name: 'Line 4', now: DateTime(2026));
      for (final n in ['Saw', 'Drill', 'Press']) {
        await groups.moveToGroup(await study(n), g);
      }
    });
    await tester.pumpWidget(app(GroupScreen(groupId: g)));
    await settle(tester);

    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await settle(tester);

    expect(await tester.runAsync(() => memberNames(g)), [
      'Drill',
      'Press',
      'Saw',
    ]);
  });

  testWidgets('existing studies are added to the group', (tester) async {
    late int g;
    late int saw;
    await tester.runAsync(() async {
      g = await groups.createGroup(name: 'Line 4', now: DateTime(2026));
      final other = await groups.createGroup(
        name: 'Line 5',
        now: DateTime(2026),
      );
      saw = await study('Saw');
      await groups.moveToGroup(saw, other);
      await study('Drill');
    });
    await tester.pumpWidget(app(GroupScreen(groupId: g)));
    await settle(tester);

    await tester.tap(find.byKey(const Key('addStudiesFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addExistingStudies')));
    await settle(tester);
    await tester.pumpAndSettle();
    // Studies of other groups are offered, too (they are moved).
    expect(find.text('Line 5'), findsOneWidget);
    await tester.tap(find.byKey(Key('pickStudy_$saw')));
    await tester.pump();
    await tester.tap(find.text('Drill'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('addSelectedButton')));
    await settleUntil(tester, () => find.text('1. Saw').evaluate().isNotEmpty);

    expect(await tester.runAsync(() => memberNames(g)), ['Saw', 'Drill']);
    expect(find.text('1. Saw'), findsOneWidget);
  });

  testWidgets('removing a study keeps it outside the group', (tester) async {
    late int g;
    late int saw;
    await tester.runAsync(() async {
      g = await groups.createGroup(name: 'Line 4', now: DateTime(2026));
      saw = await study('Saw');
      await groups.moveToGroup(saw, g);
    });
    await tester.pumpWidget(app(GroupScreen(groupId: g)));
    await settle(tester);
    await tester.tap(find.byKey(Key('groupStudyMenu_$saw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('removeFromGroup')));
    await settle(tester);
    expect(await tester.runAsync(() => memberNames(g)), isEmpty);
    expect(await tester.runAsync(() => studies.getStudy(saw)), isNotNull);
  });

  testWidgets('a study is copied into another group', (tester) async {
    late int g;
    late int target;
    late int saw;
    await tester.runAsync(() async {
      g = await groups.createGroup(name: 'Line 4', now: DateTime(2026));
      target = await groups.createGroup(name: 'Line 9', now: DateTime(2026));
      saw = await study('Saw');
      await groups.moveToGroup(saw, g);
    });
    await tester.pumpWidget(app(GroupScreen(groupId: g)));
    await settle(tester);
    await tester.tap(find.byKey(Key('groupStudyMenu_$saw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copyToGroup')));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('groupChoice_$target')));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => memberNames(g)), ['Saw']);
    expect(await tester.runAsync(() => memberNames(target)), ['Saw (copy)']);
  });

  testWidgets('renaming and deleting the group', (tester) async {
    late int g;
    late int saw;
    await tester.runAsync(() async {
      g = await groups.createGroup(name: 'Line 4', now: DateTime(2026));
      saw = await study('Saw');
      await groups.moveToGroup(saw, g);
    });
    await tester.pumpWidget(app(GroupScreen(groupId: g)));
    await settle(tester);

    await tester.tap(find.byKey(const Key('groupMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editGroup')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('groupNameField')), 'Line 40');
    await tester.tap(find.byKey(const Key('saveGroupButton')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Line 40'), findsOneWidget);

    await tester.tap(find.byKey(const Key('groupMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteGroup')));
    await tester.pumpAndSettle();
    expect(find.textContaining('studies are kept'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmDeleteGroup')));
    await settle(tester);
    expect(await tester.runAsync(() => groups.getGroup(g)), isNull);
    expect(await tester.runAsync(() => studies.getStudy(saw)), isNotNull);
  });

  testWidgets('study list: group label, move and copy from the card menu', (
    tester,
  ) async {
    late int g;
    late int saw;
    await tester.runAsync(() async {
      g = await groups.createGroup(name: 'Line 4', now: DateTime(2026));
      saw = await study('Saw');
    });
    var opened = false;
    await tester.pumpWidget(
      app(
        StudyListScreen(
          checkActiveRuns: false,
          onOpenGroups: (_) async => opened = true,
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.byKey(Key('studyMenu_$saw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveStudy')));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('groupChoice_$g')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => memberNames(g)), ['Saw']);
    expect(find.byKey(Key('groupLabel_$saw')), findsOneWidget);

    await tester.tap(find.byKey(Key('studyMenu_$saw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copyStudy')));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('noGroupChoice')));
    await settleUntil(
      tester,
      () => find.text('Saw (copy)').evaluate().isNotEmpty,
    );
    expect(find.text('Saw (copy)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('groupsButton')));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('a new group can be created while moving a study', (
    tester,
  ) async {
    final saw = (await tester.runAsync(() => study('Saw')))!;
    await tester.pumpWidget(app(const StudyListScreen(checkActiveRuns: false)));
    await settle(tester);
    await tester.tap(find.byKey(Key('studyMenu_$saw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveStudy')));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newGroupChoice')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('groupNameField')), 'Paint');
    await tester.tap(find.byKey(const Key('saveGroupButton')));
    await settle(tester);
    await tester.pumpAndSettle();

    final g = (await tester.runAsync(groups.listGroups))!.single;
    expect(g.group.name, 'Paint');
    expect(await tester.runAsync(() => memberNames(g.group.id)), ['Saw']);
  });
}

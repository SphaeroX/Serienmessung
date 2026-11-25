import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/domain/group_member.dart';
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

  Widget app(Widget child) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      wallClockProvider.overrideWithValue(() => DateTime(2026, 3, 1)),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(child),
  );

  Future<int> study(String name, int? groupId, {bool parallel = false}) async {
    final id = await studies.createStudy(
      name: name,
      mode: StudyMode.timeStudy,
      steps: ['A'],
      now: DateTime(2026),
    );
    if (groupId != null) await groups.moveToGroup(id, groupId);
    if (parallel) await groups.setParallel(id, true);
    return id;
  }

  Future<int> newGroup(String name, {int? parent}) async {
    final id = await groups.createGroup(name: name, now: DateTime(2026));
    if (parent != null) await groups.setParent(id, parent);
    return id;
  }

  /// "A [X] B": the members of [groupId].
  Future<String> members(int groupId) async => [
    for (final m in await groups.listMembers(groupId))
      switch (m) {
        StudyMember(:final study) => study.name,
        AreaMember(:final group) => '[${group.name}]',
      },
  ].join(' ');

  Future<void> open(WidgetTester tester, int groupId) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(GroupScreen(groupId: groupId)));
    await settle(tester);
    await settle(tester);
  }

  Future<void> menu(WidgetTester tester, String menuKey, String item) async {
    await tester.tap(find.byKey(Key(menuKey)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(item)));
    await settle(tester);
    await settle(tester);
  }

  testWidgets('station numbers run through an area', (tester) async {
    late int press;
    late int plant;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      await study('Saw', plant);
      press = await newGroup('Press', parent: plant);
      await study('Punch', press);
      await study('Bend', press);
      await study('Trim', press);
      await study('Pack', plant);
    });
    await open(tester, plant);
    expect(find.text('1. Saw'), findsOneWidget);
    expect(find.text('2–4. Press'), findsOneWidget);
    expect(find.text('5. Pack'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(Key('area_$press')),
        matching: find.textContaining('3 studies'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an existing group is added as an area at the end', (
    tester,
  ) async {
    late int site;
    late int plant;
    late int other;
    await tester.runAsync(() async {
      site = await newGroup('Site');
      plant = await newGroup('Plant', parent: site);
      await study('Saw', plant);
      other = await newGroup('Other');
      await study('X', other);
    });
    await open(tester, plant);
    await tester.tap(find.byKey(const Key('addStudiesFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addExistingGroup')));
    await settle(tester);
    await tester.pumpAndSettle();
    // Neither the group itself nor its ancestors are offered.
    expect(find.byKey(Key('addGroupChoice_$plant')), findsNothing);
    expect(find.byKey(Key('addGroupChoice_$site')), findsNothing);
    await tester.tap(find.byKey(Key('addGroupChoice_$other')));
    await settle(tester);
    await settle(tester);
    expect(await tester.runAsync(() => members(plant)), 'Saw [Other]');
    expect(find.text('2. Other'), findsOneWidget);
  });

  testWidgets('a new area is created inside the group and opened', (
    tester,
  ) async {
    late int plant;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      await study('Saw', plant);
    });
    await open(tester, plant);
    await tester.tap(find.byKey(const Key('addStudiesFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addNewArea')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('groupNameField')), 'Press');
    await tester.tap(find.byKey(const Key('saveGroupButton')));
    await settle(tester);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(await tester.runAsync(() => members(plant)), 'Saw [Press]');
    // The new area is open: its path names the plant.
    expect(find.byKey(const Key('groupPath')), findsOneWidget);
    expect(find.text('Press'), findsWidgets);
  });

  testWidgets('tapping an area opens it; changes show after returning', (
    tester,
  ) async {
    late int plant;
    late int press;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      await study('Saw', plant);
      press = await newGroup('Press', parent: plant);
      await study('Punch', press);
      await study('Pack', plant);
    });
    await open(tester, plant);
    expect(find.text('2. Press'), findsOneWidget);
    await tester.tap(find.byKey(Key('area_$press')));
    await settle(tester);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('1. Punch'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('groupPath'))).data,
      'Plant',
    );
    await tester.runAsync(() => study('Bend', press));
    await tester.pageBack();
    await settle(tester);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('2–3. Press'), findsOneWidget);
    expect(find.text('4. Pack'), findsOneWidget);
  });

  testWidgets('areas and studies move up and down together', (tester) async {
    late int plant;
    late int x;
    late int c;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      await study('A', plant);
      await study('B', plant, parallel: true);
      x = await newGroup('X', parent: plant);
      await study('X1', x);
      c = await study('C', plant);
    });
    await open(tester, plant);
    expect(find.text('1a. A'), findsOneWidget);
    expect(find.text('1b. B'), findsOneWidget);
    await menu(tester, 'areaMenu_$x', 'areaMoveDown');
    expect(await tester.runAsync(() => members(plant)), 'A B C [X]');
    expect(find.text('1a. A'), findsOneWidget);
    expect(find.text('2. C'), findsOneWidget);
    expect(find.text('3. X'), findsOneWidget);
    await menu(tester, 'areaMenu_$x', 'areaMoveUp');
    expect(await tester.runAsync(() => members(plant)), 'A B [X] C');
    expect(find.text('1b. B'), findsOneWidget);
    // C cannot work in parallel with the area before it.
    await tester.tap(find.byKey(Key('groupStudyMenu_$c')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('toggleParallel')), findsNothing);
    expect(find.byKey(const Key('toggleCellLoader')), findsNothing);
    expect(find.byKey(const Key('addBuffer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('moveUp')));
    await settle(tester);
    await settle(tester);
    expect(await tester.runAsync(() => members(plant)), 'A B C [X]');
    expect(find.text('1b. B'), findsOneWidget);
    expect(find.text('2. C'), findsOneWidget);
  });

  testWidgets('dragging moves an area between studies', (tester) async {
    late int plant;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      final x = await newGroup('X', parent: plant);
      await study('X1', x);
      await study('A', plant);
      await study('B', plant);
    });
    await open(tester, plant);
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
    await settle(tester);
    final order = await tester.runAsync(() => members(plant));
    expect(order, isNot('[X] A B'));
    expect(order!.split(' '), unorderedEquals(['[X]', 'A', 'B']));
  });

  testWidgets('taking an area out keeps its studies in it', (tester) async {
    late int plant;
    late int x;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      await study('A', plant);
      x = await newGroup('X', parent: plant);
      await study('X1', x);
    });
    await open(tester, plant);
    await menu(tester, 'areaMenu_$x', 'detachArea');
    expect(await tester.runAsync(() => members(plant)), 'A');
    expect((await tester.runAsync(() => groups.getGroup(x)))!.parentId, isNull);
    expect(await tester.runAsync(() => members(x)), 'X1');
    expect(find.byKey(Key('area_$x')), findsNothing);
  });

  testWidgets('moving an area offers neither itself nor its areas', (
    tester,
  ) async {
    late int plant;
    late int x;
    late int y;
    late int other;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      x = await newGroup('X', parent: plant);
      y = await newGroup('Y', parent: x);
      other = await newGroup('Other');
    });
    await open(tester, plant);
    await menu(tester, 'areaMenu_$x', 'areaMoveToGroup');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('groupChoice_$x')), findsNothing);
    expect(find.byKey(Key('groupChoice_$y')), findsNothing);
    expect(find.byKey(Key('groupChoice_$plant')), findsNothing);
    await tester.tap(find.byKey(Key('groupChoice_$other')));
    await settle(tester);
    await settle(tester);
    expect(await tester.runAsync(() => members(other)), '[X]');
    expect(await tester.runAsync(() => members(plant)), '');
  });

  testWidgets('the header shows the path; the area leaves its parent', (
    tester,
  ) async {
    late int site;
    late int hall;
    await tester.runAsync(() async {
      site = await newGroup('Site');
      final plant = await newGroup('Plant', parent: site);
      hall = await newGroup('Hall', parent: plant);
    });
    await open(tester, hall);
    expect(
      tester.widget<Text>(find.byKey(const Key('groupPath'))).data,
      'Site › Plant',
    );
    await menu(tester, 'groupMenu', 'detachFromParent');
    expect(
      (await tester.runAsync(() => groups.getGroup(hall)))!.parentId,
      isNull,
    );
    expect(find.byKey(const Key('groupPath')), findsNothing);
    expect(site, isNonZero);
  });

  group('deleting a group with areas', () {
    late int plant;
    late int x;
    late int a;
    late int x1;

    Future<void> openDialog(WidgetTester tester) async {
      await tester.runAsync(() async {
        plant = await newGroup('Plant');
        a = await study('A', plant);
        x = await newGroup('X', parent: plant);
        x1 = await study('X1', x);
        final y = await newGroup('Y', parent: x);
        await study('Y1', y);
      });
      await open(tester, plant);
      await tester.tap(find.byKey(const Key('groupMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deleteGroup')));
      await settle(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('the option names studies and areas of the subtree', (
      tester,
    ) async {
      await openDialog(tester);
      expect(
        find.text('Also delete the 3 studies and 2 areas of this group'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('deleteGroupStudies')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDeleteGroup')));
      await settle(tester);
      expect(await tester.runAsync(() => groups.getGroup(plant)), isNull);
      expect(await tester.runAsync(() => groups.getGroup(x)), isNull);
      expect(await tester.runAsync(() => studies.getStudy(a)), isNull);
      expect(await tester.runAsync(() => studies.getStudy(x1)), isNull);
    });

    testWidgets('without the option studies and areas stay', (tester) async {
      await openDialog(tester);
      await tester.tap(find.byKey(const Key('confirmDeleteGroup')));
      await settle(tester);
      expect(await tester.runAsync(() => groups.getGroup(plant)), isNull);
      final area = await tester.runAsync(() => groups.getGroup(x));
      expect(area!.parentId, isNull);
      expect(
        (await tester.runAsync(() => studies.getStudy(a)))!.groupId,
        isNull,
      );
      expect((await tester.runAsync(() => studies.getStudy(x1)))!.groupId, x);
    });
  });

  testWidgets('the group list shows areas indented under their parent', (
    tester,
  ) async {
    late int plant;
    late int press;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      await study('Saw', plant);
      press = await newGroup('Press', parent: plant);
      await study('Punch', press);
      await study('Bend', press);
      await newGroup('Assembly');
    });
    await tester.pumpWidget(app(const GroupListScreen()));
    await settle(tester);
    final plantTile = find.byKey(Key('group_$plant'));
    final pressTile = find.byKey(Key('group_$press'));
    expect(
      find.descendant(of: plantTile, matching: find.text('1 area · 3 studies')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pressTile, matching: find.text('2 studies')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(pressTile).dx,
      greaterThan(tester.getTopLeft(plantTile).dx),
    );
    expect(
      tester.getTopLeft(pressTile).dy,
      greaterThan(tester.getTopLeft(plantTile).dy),
    );
  });

  testWidgets('deleting selected groups with studies takes the subtree', (
    tester,
  ) async {
    late int plant;
    late int press;
    late int punch;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      await study('Saw', plant);
      press = await newGroup('Press', parent: plant);
      punch = await study('Punch', press);
    });
    await tester.pumpWidget(app(const GroupListScreen()));
    await settle(tester);
    await tester.longPress(find.byKey(Key('group_$plant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteGroupsWithStudies')));
    await settle(tester);
    expect(await tester.runAsync(() => groups.getGroup(press)), isNull);
    expect(await tester.runAsync(() => studies.getStudy(punch)), isNull);
  });

  testWidgets('the study card and the group picker show the path', (
    tester,
  ) async {
    late int press;
    late int saw;
    await tester.runAsync(() async {
      final plant = await newGroup('Plant');
      press = await newGroup('Press', parent: plant);
      saw = await study('Saw', press);
      await study('Loose', null);
    });
    await tester.pumpWidget(app(const StudyListScreen(checkActiveRuns: false)));
    await settle(tester);
    expect(
      find.descendant(
        of: find.byKey(Key('groupLabel_$saw')),
        matching: find.text('Plant › Press'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(Key('studyMenu_$saw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copyStudy')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(Key('groupChoice_$press')),
        matching: find.text('Plant › Press'),
      ),
      findsOneWidget,
    );
  });
}

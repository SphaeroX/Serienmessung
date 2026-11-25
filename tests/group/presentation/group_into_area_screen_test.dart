import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/domain/group_member.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late int line;
  late Map<String, int> ids;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    final machines = MachineService(db, now: () => DateTime(2026));
    line = await groups.createGroup(name: 'Line', now: DateTime(2026));
    ids = {};
    for (final (name, parallel) in [
      ('A', false),
      ('B', false),
      ('B2', true),
      ('C', false),
      ('D', false),
    ]) {
      ids[name] = await machines.createMachine(
        name: name,
        groupId: line,
        cycleMicros: 30 * s,
        parallel: parallel,
      );
    }
  });

  tearDown(() => db.close());

  Future<String> members(int groupId) async => [
    for (final m in await groups.listMembers(groupId))
      switch (m) {
        StudyMember(:final study) => study.name,
        AreaMember(:final group) => '[${group.name}]',
      },
  ].join(' ');

  Future<void> open(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 3, 1)),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(GroupScreen(groupId: line)),
      ),
    );
    await settle(tester);
  }

  Finder card(String name) => find.ancestor(
    of: find.textContaining(RegExp('^[0-9a-z]+\\. $name\$')),
    matching: find.byType(ListTile),
  );

  testWidgets('a long press selects, the station is taken whole, and the '
      'selection becomes an area', (tester) async {
    await open(tester);
    await tester.longPress(card('B2'));
    await tester.pumpAndSettle();
    // B2 brings its whole station.
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(card('C'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('groupIntoArea')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('groupNameField')), 'Middle');
    await tester.tap(find.byKey(const Key('saveGroupButton')));
    await settle(tester);
    await settle(tester);
    expect(await tester.runAsync(() => members(line)), 'A [Middle] D');
    expect(find.text('2–3. Middle'), findsOneWidget);
    expect(find.text('4. D'), findsOneWidget);
  });

  testWidgets('a selection with a gap cannot become an area', (tester) async {
    await open(tester);
    await tester.longPress(card('A'));
    await tester.pumpAndSettle();
    await tester.tap(card('C'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selectionGapHint')), findsOneWidget);
    final button = tester.widget<IconButton>(
      find.byKey(const Key('groupIntoArea')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('back ends the selection', (tester) async {
    await open(tester);
    await tester.longPress(card('A'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clearSelection')));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Line'), findsOneWidget);
  });

  testWidgets('an area is dissolved after asking', (tester) async {
    late int area;
    await tester.runAsync(() async {
      area = await groups.groupIntoArea(
        line,
        [MemberKey.study(ids['C']!), MemberKey.study(ids['D']!)],
        name: 'Back',
        now: DateTime(2026),
      );
    });
    await open(tester);
    await settle(tester);
    await tester.tap(find.byKey(Key('areaMenu_$area')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dissolveArea')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDissolveArea')));
    await settle(tester);
    await settle(tester);
    expect(await tester.runAsync(() => members(line)), 'A B B2 C D');
    expect(find.text('3. C'), findsOneWidget);
  });
}

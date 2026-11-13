import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
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

  /// Saw, then Mill 1 and Mill 2 in parallel.
  Future<({int group, int saw, int mill1, int mill2})> line() async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final ids = <int>[];
    for (final n in ['Saw', 'Mill 1', 'Mill 2']) {
      final id = await studies.createStudy(
        name: n,
        mode: StudyMode.timeStudy,
        steps: ['A'],
        now: DateTime(2026),
      );
      await groups.moveToGroup(id, g);
      ids.add(id);
    }
    await groups.setParallel(ids[2], true);
    return (group: g, saw: ids[0], mill1: ids[1], mill2: ids[2]);
  }

  testWidgets('moving the first machine of a station up keeps the other '
      'machine out of the station before', (tester) async {
    final x = (await tester.runAsync(line))!;
    await tester.pumpWidget(app(GroupScreen(groupId: x.group)));
    await settle(tester);
    expect(find.text('2a. Mill 1'), findsOneWidget);
    expect(find.text('2b. Mill 2'), findsOneWidget);

    await tester.tap(find.byKey(Key('groupStudyMenu_${x.mill1}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveUp')));
    await settle(tester);

    expect(find.text('1. Mill 1'), findsOneWidget);
    expect(find.text('2. Saw'), findsOneWidget);
    expect(find.text('3. Mill 2'), findsOneWidget);
  });

  testWidgets('moving a machine down into a station makes it part of it', (
    tester,
  ) async {
    final x = (await tester.runAsync(line))!;
    await tester.pumpWidget(app(GroupScreen(groupId: x.group)));
    await settle(tester);

    await tester.tap(find.byKey(Key('groupStudyMenu_${x.saw}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveDown')));
    await settle(tester);

    expect(find.text('1a. Mill 1'), findsOneWidget);
    expect(find.text('1b. Saw'), findsOneWidget);
    expect(find.text('1c. Mill 2'), findsOneWidget);
  });

  testWidgets('dragging the first machine of a station away', (tester) async {
    final x = (await tester.runAsync(line))!;
    await tester.pumpWidget(app(GroupScreen(groupId: x.group)));
    await settle(tester);

    // Drag "Mill 1" (second handle) above "Saw".
    final handle = find.byIcon(Icons.drag_handle).at(1);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text('1. Mill 1'), findsOneWidget);
    expect(find.text('2. Saw'), findsOneWidget);
    expect(find.text('3. Mill 2'), findsOneWidget);
  });
}

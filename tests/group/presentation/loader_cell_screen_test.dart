import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/group/presentation/line_screen.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late int groupId;

  setUp(() async {
    db = await openTestDatabase();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line', now: DateTime(2026));
  });

  tearDown(() => db.close());

  /// A group member with a typed cycle time of [seconds].
  Future<int> member(
    WidgetTester tester,
    String name,
    int seconds, {
    bool loader = false,
  }) async => (await tester.runAsync(() async {
    final id = await MachineService(db, now: () => DateTime(2026, 4, 1))
        .createMachine(
          name: name,
          groupId: groupId,
          cycleMicros: seconds * 1000000,
        );
    if (loader) await GroupRepository(db).setCellLoader(id, true);
    return id;
  }))!;

  Future<Study> stored(WidgetTester tester, int id) async =>
      (await tester.runAsync(() => StudyRepository(db).getStudy(id)))!;

  Widget app(Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(
        const AppSettings(defaultUnit: TimeUnit.seconds),
      ),
      wallClockProvider.overrideWithValue(() => DateTime(2026, 4, 1)),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(home),
  );

  Future<void> pumpGroup(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(GroupScreen(groupId: groupId)));
    await settle(tester);
  }

  Future<void> openMenu(WidgetTester tester, int studyId) async {
    await tester.tap(find.byKey(Key('groupStudyMenu_$studyId')));
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, int studyId, String item) async {
    await openMenu(tester, studyId);
    await tester.tap(find.byKey(Key(item)));
    await settle(tester);
    await tester.pumpAndSettle();
  }

  group('group screen', () {
    testWidgets('a member becomes a loader of the machine above', (
      tester,
    ) async {
      await member(tester, 'Saw', 12);
      await member(tester, 'Machine', 88);
      final gantry = await member(tester, 'Gantry', 32);
      await pumpGroup(tester);
      expect(find.text('3. Gantry'), findsOneWidget);

      await menu(tester, gantry, 'toggleCellLoader');
      await settleUntil(
        tester,
        () => find.text('2b. Gantry').evaluate().isNotEmpty,
      );
      expect(find.text('2a. Machine'), findsOneWidget);
      expect(find.text('2b. Gantry'), findsOneWidget);
      expect(find.textContaining('Loader ·'), findsOneWidget);
      expect(find.textContaining('Machine of the cell · ×1'), findsOneWidget);
      expect((await stored(tester, gantry)).isCellLoader, isTrue);

      await menu(tester, gantry, 'toggleCellLoader');
      await settleUntil(
        tester,
        () => find.text('3. Gantry').evaluate().isNotEmpty,
      );
      expect((await stored(tester, gantry)).isCellLoader, isFalse);
      expect(find.textContaining('Machine of the cell'), findsNothing);
    });

    testWidgets('number of machines and parts per cycle are entered', (
      tester,
    ) async {
      final saw = await member(tester, 'Saw', 12);
      final machine = await member(tester, 'Machine', 88);
      final gantry = await member(tester, 'Gantry', 32, loader: true);
      await pumpGroup(tester);

      // Only members of a cell have the counts in their menu.
      await openMenu(tester, saw);
      expect(find.byKey(const Key('setCellMachines')), findsNothing);
      expect(find.byKey(const Key('setCellParts')), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await openMenu(tester, gantry);
      expect(find.byKey(const Key('setCellMachines')), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await menu(tester, machine, 'setCellMachines');
      expect(find.text('Equal machines in the cell'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('cellCountField')), '3');
      await tester.tap(find.byKey(const Key('saveCellCount')));
      await settleUntil(
        tester,
        () => find.textContaining('×3').evaluate().isNotEmpty,
      );
      expect(find.textContaining('Machine of the cell · ×3'), findsOneWidget);
      expect((await stored(tester, machine)).cellMachines, 3);

      await menu(tester, gantry, 'setCellParts');
      expect(find.text('Parts per loader cycle'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('cellCountField')), '2');
      await tester.tap(find.byKey(const Key('saveCellCount')));
      await settleUntil(
        tester,
        () => find.textContaining('2 parts per cycle').evaluate().isNotEmpty,
      );
      expect(find.textContaining('Loader · 2 parts per cycle'), findsOneWidget);
      expect((await stored(tester, gantry)).cellParts, 2);
    });

    testWidgets('a count below one is rejected', (tester) async {
      final machine = await member(tester, 'Machine', 88);
      await member(tester, 'Gantry', 32, loader: true);
      await pumpGroup(tester);
      await menu(tester, machine, 'setCellMachines');
      for (final bad in ['0', '', '2,5', 'x']) {
        await tester.enterText(find.byKey(const Key('cellCountField')), bad);
        await tester.tap(find.byKey(const Key('saveCellCount')));
        await tester.pumpAndSettle();
        expect(find.text('Enter a whole number from 1'), findsOneWidget);
      }
      expect((await stored(tester, machine)).cellMachines, 1);
    });

    testWidgets('"parallel" turns a loader into a parallel machine', (
      tester,
    ) async {
      await member(tester, 'Machine', 88);
      final gantry = await member(tester, 'Gantry', 32, loader: true);
      await pumpGroup(tester);
      await menu(tester, gantry, 'toggleParallel');
      await settleUntil(
        tester,
        () => find.textContaining('Loader ·').evaluate().isEmpty,
      );
      final study = await stored(tester, gantry);
      expect((study.parallel, study.isCellLoader), (true, false));
    });
  });

  group('line screen', () {
    Future<void> pumpLine(WidgetTester tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(app(LineScreen(groupId: groupId)));
      await settleUntil(
        tester,
        () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
      );
    }

    testWidgets('shows the cell with resources, bottleneck and the machine '
        'table', (tester) async {
      await member(tester, 'Saw', 12);
      final machine = await member(tester, 'Machine', 88);
      await member(tester, 'Loader 1', 32, loader: true);
      await member(tester, 'Loader 2', 20, loader: true);
      await member(tester, 'Loader 3', 15, loader: true);
      await tester.runAsync(
        () => GroupRepository(db).setCellMachines(machine, 3),
      );
      await pumpLine(tester);
      String text(String key) =>
          tester.widget<Text>(find.byKey(Key(key))).data!;
      expect(text('lineCycleTime'), '32.00 s');
      expect(text('lineBottleneck'), 'Machine');

      await tester.scrollUntilVisible(
        find.byKey(const Key('cellBest_1')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('lineCell_1')), findsOneWidget);
      expect(find.text('2. Machine'), findsOneWidget);
      expect(text('cellResource_1_0'), 'Machine ×3');
      expect(text('cellPerPart_1_0'), '29.33 s');
      expect(text('cellUtilization_1_0'), '91.7 %');
      expect(text('cellWaiting_1_0'), '8.00 s');
      expect(text('cellResource_1_1'), 'Loader 1');
      expect(text('cellUtilization_1_1'), '100.0 %');
      expect(text('cellWaiting_1_1'), '0.00 s');
      expect(text('cellUtilization_1_2'), '62.5 %');
      expect(text('cellWaiting_1_2'), '12.00 s');
      expect(text('cellOption_1_1'), '88.00 s');
      expect(text('cellOption_1_2'), '44.00 s');
      expect(text('cellOption_1_3'), '32.00 s');
      expect(text('cellOption_1_6'), '32.00 s');
      expect(text('cellOptionBottleneck_1_2'), 'Machines');
      expect(text('cellOptionBottleneck_1_3'), 'Loader 1');
      expect(
        text('cellBest_1'),
        'From 3 machines on, another machine brings nothing: '
        'Loader 1 sets the pace.',
      );
      expect(find.textContaining('Measure every loader'), findsOneWidget);
    });

    testWidgets('a loader with several parts per cycle is named so', (
      tester,
    ) async {
      await member(tester, 'Machine', 30);
      final l2 = await member(tester, 'L2', 62, loader: true);
      await tester.runAsync(() => GroupRepository(db).setCellParts(l2, 2));
      await pumpLine(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('cellResource_0_1')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('cellResource_0_1'))).data,
        'L2 (2 parts per cycle)',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('cellPerPart_0_1'))).data,
        '31.00 s',
      );
    });

    testWidgets('a cell without loader times says what is missing', (
      tester,
    ) async {
      await member(tester, 'Machine', 88);
      final loader = await tester.runAsync(() async {
        final id = await StudyRepository(db).createStudy(
          name: 'Gantry',
          mode: StudyMode.timeStudy,
          steps: ['Change', 'Wait'],
          now: DateTime(2026),
        );
        await GroupRepository(db).moveToGroup(id, groupId);
        await GroupRepository(db).setCellLoader(id, true);
        return id;
      });
      expect(loader, isNotNull);
      await pumpLine(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('lineCell_0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'The cell needs times for the machine and for at least one '
          'loader.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cellBest_0')), findsNothing);
    });
  });
}

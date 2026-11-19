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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late int groupId;
  late int saw;
  late int part1;
  late int part2;

  /// Saw (12 s), then Part 1 (30 s) and Part 2 (40 s) in parallel.
  setUp(() async {
    db = await openTestDatabase();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line', now: DateTime(2026));
    final machines = MachineService(db, now: () => DateTime(2026));
    saw = await machines.createMachine(
      name: 'Saw',
      groupId: groupId,
      cycleMicros: 12 * s,
    );
    part1 = await machines.createMachine(
      name: 'Part 1',
      groupId: groupId,
      cycleMicros: 30 * s,
    );
    part2 = await machines.createMachine(
      name: 'Part 2',
      groupId: groupId,
      cycleMicros: 40 * s,
      parallel: true,
    );
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(defaultUnit: TimeUnit.seconds),
          ),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 4, 1)),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(screen),
      ),
    );
    await settle(tester);
  }

  Future<void> openMenu(WidgetTester tester, int studyId) async {
    await tester.tap(find.byKey(Key('groupStudyMenu_$studyId')));
    await tester.pumpAndSettle();
  }

  Future<bool> waits(WidgetTester tester) async =>
      (await tester.runAsync(() => StudyRepository(db).getStudy(part1)))!
          .waitForSlowest;

  group('group screen', () {
    testWidgets('a parallel station is switched to wait for the slowest '
        'machine and back', (tester) async {
      await pump(tester, GroupScreen(groupId: groupId));
      expect(find.text('Station waits for its slowest machine'), findsNothing);

      // Any machine of the station offers the option.
      await openMenu(tester, part2);
      await tester.tap(find.byKey(const Key('toggleWaitForSlowest')));
      await settleUntil(
        tester,
        () => find
            .text('Station waits for its slowest machine')
            .evaluate()
            .isNotEmpty,
      );
      expect(await waits(tester), isTrue);
      expect(
        find.text('Station waits for its slowest machine'),
        findsOneWidget,
      );

      await openMenu(tester, part1);
      expect(
        tester
            .widget<CheckedPopupMenuItem<Object?>>(
              find.byKey(const Key('toggleWaitForSlowest')),
            )
            .checked,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('toggleWaitForSlowest')));
      await settleUntil(
        tester,
        () => find
            .text('Station waits for its slowest machine')
            .evaluate()
            .isEmpty,
      );
      expect(await waits(tester), isFalse);
    });

    testWidgets('a station with one machine has no such option', (
      tester,
    ) async {
      await pump(tester, GroupScreen(groupId: groupId));
      await openMenu(tester, saw);
      expect(find.byKey(const Key('toggleWaitForSlowest')), findsNothing);
    });
  });

  testWidgets('line screen: the waiting station runs at its slowest machine', (
    tester,
  ) async {
    await tester.runAsync(
      () => GroupRepository(db).setWaitForSlowest(part1, true),
    );
    await pump(tester, LineScreen(groupId: groupId));
    await settleUntil(
      tester,
      () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
    );

    String text(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(text('lineCycleTime'), '40.00 s');
    expect(text('lineBottleneck'), 'Part 1 / Part 2');
    expect(text('lineOutput'), '90.0');

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.textContaining('2 machines in parallel, waiting for the slowest'),
      200,
      scrollable: scrollable,
    );
    expect(find.textContaining('Part 1: 30.00 s'), findsOneWidget);

    // Each of the three machines stops the line.
    await tester.scrollUntilVisible(
      find.byKey(const Key('risk_2')),
      200,
      scrollable: scrollable,
    );
    expect(
      find.textContaining('2 stations without a spare machine'),
      findsOneWidget,
    );
    expect(find.text('Standstill'), findsNWidgets(3));
  });
}

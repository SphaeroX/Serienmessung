import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
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

  Future<int> study(WidgetTester tester, String name) async =>
      (await tester.runAsync(() async {
        final id = await StudyRepository(db).createStudy(
          name: name,
          mode: StudyMode.timeStudy,
          steps: ['A'],
          now: DateTime(2026),
        );
        await GroupRepository(db).moveToGroup(id, groupId);
        return id;
      }))!;

  Future<void> pump(WidgetTester tester) async {
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
        child: localizedApp(GroupScreen(groupId: groupId)),
      ),
    );
    await settle(tester);
  }

  Future<void> menu(WidgetTester tester, int studyId, String item) async {
    await tester.tap(find.byKey(Key('groupStudyMenu_$studyId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(item)));
    await settle(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('a member is switched to parallel and gets a station letter', (
    tester,
  ) async {
    await study(tester, 'Saw');
    final drill = await study(tester, 'Drill A');
    await study(tester, 'Press');
    await pump(tester);
    expect(find.text('2. Drill A'), findsOneWidget);

    await menu(tester, drill, 'toggleParallel');
    await settleUntil(
      tester,
      () => find.text('1b. Drill A').evaluate().isNotEmpty,
    );
    expect(find.text('1a. Saw'), findsOneWidget);
    expect(find.text('1b. Drill A'), findsOneWidget);
    expect(find.text('2. Press'), findsOneWidget);
    expect(
      (await tester.runAsync(() => StudyRepository(db).getStudy(drill)))!
          .parallel,
      isTrue,
    );

    await menu(tester, drill, 'toggleParallel');
    await settleUntil(
      tester,
      () => find.text('2. Drill A').evaluate().isNotEmpty,
    );
    expect(find.text('2. Drill A'), findsOneWidget);
  });

  testWidgets('a machine with a fixed cycle time is added in parallel', (
    tester,
  ) async {
    await study(tester, 'Press 1');
    await pump(tester);
    await tester.tap(find.byKey(const Key('addStudiesFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addMachine')));
    await tester.pumpAndSettle();
    expect(find.textContaining('[s]'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('machineNameField')),
      'Press 2',
    );
    await tester.enterText(find.byKey(const Key('machineCycleField')), '42,5');
    await tester.tap(find.byKey(const Key('machineParallelSwitch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveMachineButton')));
    await settleUntil(
      tester,
      () => find.text('1b. Press 2').evaluate().isNotEmpty,
    );
    expect(find.text('1b. Press 2'), findsOneWidget);

    final members = (await tester.runAsync(
      () => StudyRepository(db).listStudies(groupId: groupId),
    ))!;
    final machine = members.last.study;
    expect(machine.mode, StudyMode.simple);
    final times = (await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(machine.id),
    ))!;
    expect(times.single.durationMicros, 42500000);
  });

  testWidgets('invalid cycle times are rejected', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('addStudiesFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addMachine')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('machineNameField')), 'X');
    await tester.enterText(find.byKey(const Key('machineCycleField')), '0');
    await tester.tap(find.byKey(const Key('saveMachineButton')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a time greater than 0'), findsOneWidget);
  });

  testWidgets('the cycle time of a simple study is changed with history', (
    tester,
  ) async {
    late int machine;
    await tester.runAsync(() async {
      machine = await StudyRepository(db).createStudy(
        name: 'Press 2',
        mode: StudyMode.simple,
        steps: const [],
        now: DateTime(2026),
      );
      await GroupRepository(db).moveToGroup(machine, groupId);
    });
    await pump(tester);
    await menu(tester, machine, 'setCycleTime');
    await tester.enterText(find.byKey(const Key('cycleTimeField')), '30');
    await tester.tap(find.byKey(const Key('saveCycleTimeButton')));
    await settle(tester);
    await tester.pumpAndSettle();
    await menu(tester, machine, 'setCycleTime');
    await tester.enterText(find.byKey(const Key('cycleTimeField')), '28');
    await tester.tap(find.byKey(const Key('saveCycleTimeButton')));
    await settle(tester);
    await tester.pumpAndSettle();

    final times = (await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(machine),
    ))!;
    expect(times.single.durationMicros, 28000000);
    final archived = (await tester.runAsync(
      () => RevisionRepository(db).listRevisions(machine),
    ))!;
    expect(archived.single.measurements.single.durationMicros, 30000000);
  });

  testWidgets('time studies offer no fixed cycle time', (tester) async {
    final saw = await study(tester, 'Saw');
    await pump(tester);
    await tester.tap(find.byKey(Key('groupStudyMenu_$saw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setCycleTime')), findsNothing);
    expect(find.byKey(const Key('toggleParallel')), findsNothing);
  });
}

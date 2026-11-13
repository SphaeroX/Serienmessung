import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/data/special_cycle_repository.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/group/presentation/line_screen.dart';
import 'package:cyclescope/group/presentation/special_cycles_screen.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late int groupId;
  late int press;

  setUp(() async {
    db = await openTestDatabase();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line', now: DateTime(2026));
    press = await MachineService(
      db,
      now: () => DateTime(2026),
    ).createMachine(name: 'Press', groupId: groupId, cycleMicros: 40000000);
  });

  tearDown(() => db.close());

  Widget app(Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(
        const AppSettings(defaultUnit: TimeUnit.seconds),
      ),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(home),
  );

  Future<List<SpecialCycle>> rules(WidgetTester tester) async =>
      (await tester.runAsync(() => SpecialCycleRepository(db).list(press)))!;

  testWidgets('rules are added from the group screen and deleted', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(GroupScreen(groupId: groupId)));
    await settle(tester);
    await tester.tap(find.byKey(Key('groupStudyMenu_$press')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('specialCycles')));
    await pumpFrames(tester);
    await settle(tester);
    expect(find.byType(SpecialCyclesScreen), findsOneWidget);
    expect(find.text('No special cycles yet'), findsOneWidget);

    // Every 50 parts + 120 s.
    await tester.tap(find.byKey(const Key('addSpecialCycle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('specialCycleNameField')),
      'Measure part',
    );
    await tester.enterText(
      find.byKey(const Key('specialCycleIntervalField')),
      '50',
    );
    await tester.enterText(
      find.byKey(const Key('specialCycleDurationField')),
      '120',
    );
    await tester.tap(find.byKey(const Key('saveSpecialCycleButton')));
    await settleUntil(
      tester,
      () => find.textContaining('Every 50 parts').evaluate().isNotEmpty,
    );

    // Every 24 h a stop of 300 s.
    await tester.tap(find.byKey(const Key('addSpecialCycle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('specialCycleNameField')),
      'Tool change',
    );
    await tester.tap(find.byKey(const Key('kindTime')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('specialCycleIntervalField')),
      '24',
    );
    await tester.enterText(
      find.byKey(const Key('specialCycleDurationField')),
      '300',
    );
    await tester.tap(find.byKey(const Key('saveSpecialCycleButton')));
    await settleUntil(
      tester,
      () => find.textContaining('Every 24 h').evaluate().isNotEmpty,
    );
    final list = await rules(tester);
    expect(list.map((c) => (c.name, c.kind, c.interval, c.durationMicros)), [
      ('Measure part', SpecialCycleKind.parts, 50, 120000000),
      ('Tool change', SpecialCycleKind.time, 24 * 3600 * 1000000, 300000000),
    ]);
    expect(find.textContaining('120.00 s'), findsOneWidget);

    await tester.tap(find.byKey(Key('deleteSpecialCycle_${list.first.id}')));
    await settleUntil(
      tester,
      () => find.textContaining('Every 50 parts').evaluate().isEmpty,
    );
    expect(await rules(tester), hasLength(1));

    // Back in the group the member shows its rules.
    await tester.pageBack();
    await pumpFrames(tester);
    await settleUntil(
      tester,
      () => find.textContaining('1 special cycle').evaluate().isNotEmpty,
    );
  });

  testWidgets('invalid input is rejected', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(SpecialCyclesScreen(studyId: press, studyName: 'Press')),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('addSpecialCycle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('specialCycleIntervalField')),
      '0',
    );
    await tester.tap(find.byKey(const Key('saveSpecialCycleButton')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number greater than 0'), findsOneWidget);
    expect(find.text('Enter a time greater than 0'), findsOneWidget);
  });

  testWidgets('the line screen shows the effective cycle time', (tester) async {
    await tester.runAsync(
      () => SpecialCycleRepository(db).add(
        press,
        name: 'Measure part',
        kind: SpecialCycleKind.parts,
        interval: 50,
        durationMicros: 120000000,
      ),
    );
    usePhoneSize(tester);
    await tester.pumpWidget(app(LineScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('lineCycleTime'))).data,
      '42.40 s',
    );
    await tester.scrollUntilVisible(
      find.textContaining('measured 40.00 s'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  });
}

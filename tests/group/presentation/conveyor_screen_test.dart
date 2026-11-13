import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/group/presentation/line_screen.dart';
import 'package:cyclescope/group/presentation/simulation_screen.dart';
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
  late int a;
  late int b;

  setUp(() async {
    db = await openTestDatabase();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line', now: DateTime(2026));
    final machines = MachineService(db, now: () => DateTime(2026));
    a = await machines.createMachine(
      name: 'A',
      groupId: groupId,
      cycleMicros: 10000000,
    );
    b = await machines.createMachine(
      name: 'B',
      groupId: groupId,
      cycleMicros: 20000000,
    );
  });

  tearDown(() => db.close());

  Widget app(Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(
        const AppSettings(defaultUnit: TimeUnit.seconds, shiftMinutes: 60),
      ),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(home),
  );

  Future<Study> load(WidgetTester tester) async =>
      (await tester.runAsync(() => StudyRepository(db).getStudy(b)))!;

  testWidgets('a conveyor is inserted, edited and removed', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(GroupScreen(groupId: groupId)));
    await settle(tester);

    await tester.tap(find.byKey(Key('groupStudyMenu_$a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addConveyor')), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('groupStudyMenu_$b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addConveyor')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('conveyorTimeField')), '30');
    await tester.enterText(find.byKey(const Key('conveyorPlacesField')), '8');
    await tester.tap(find.byKey(const Key('saveConveyorButton')));
    await settleUntil(
      tester,
      () => find.byKey(Key('conveyor_$b')).evaluate().isNotEmpty,
    );
    expect(find.textContaining('8 places'), findsOneWidget);
    expect(find.textContaining('30.00 s'), findsOneWidget);
    var s = await load(tester);
    expect((s.conveyorCapacity, s.conveyorTransportMicros), (8, 30000000));

    await tester.tap(find.byKey(Key('conveyor_$b')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('conveyorPlacesField')), '12');
    await tester.tap(find.byKey(const Key('saveConveyorButton')));
    await settleUntil(
      tester,
      () => find.textContaining('12 places').evaluate().isNotEmpty,
    );
    s = await load(tester);
    expect(s.conveyorCapacity, 12);

    await tester.tap(find.byKey(Key('conveyor_$b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('removeConveyorButton')));
    await settleUntil(
      tester,
      () => find.byKey(Key('conveyor_$b')).evaluate().isEmpty,
    );
    expect((await load(tester)).hasConveyor, isFalse);
  });

  testWidgets('line and simulation screens show the conveyor', (tester) async {
    await tester.runAsync(
      () =>
          GroupRepository(db)
              .setConveyor(b, capacity: 8, transportMicros: 30000000),
    );
    usePhoneSize(tester);
    await tester.pumpWidget(app(LineScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
    );
    // Lead time: 10 s + 30 s transport + 20 s.
    expect(
      tester.widget<Text>(find.byKey(const Key('lineLead'))).data,
      '60.00 s',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('lineConveyor_1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpWidget(app(SimulationScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('simOutput')).evaluate().isNotEmpty,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('simConveyor_1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('8 places'), findsWidgets);
  });
}

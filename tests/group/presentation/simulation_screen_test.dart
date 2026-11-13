import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/presentation/line_screen.dart';
import 'package:cyclescope/group/presentation/simulation_screen.dart';
import 'package:cyclescope/settings/data/settings_repository.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late int groupId;
  late int bId;

  setUp(() async {
    db = await openTestDatabase();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line', now: DateTime(2026));
    final machines = MachineService(db, now: () => DateTime(2026));
    await machines.createMachine(
      name: 'A',
      groupId: groupId,
      cycleMicros: 10 * s,
    );
    bId = await machines.createMachine(
      name: 'B',
      groupId: groupId,
      cycleMicros: 5 * s,
    );
    await GroupRepository(
      db,
    ).setBuffer(bId, capacity: 20, storeMicros: 2 * s, retrieveMicros: 2 * s);
  });

  tearDown(() => db.close());

  const sim = LineSimulation([
    SimStation(
      name: 'A',
      machines: [SimMachine(name: 'A', cycleMicros: 10 * s)],
    ),
    SimStation(
      name: 'B',
      machines: [SimMachine(name: 'B', cycleMicros: 5 * s)],
      bufferBefore: SimBuffer(
        capacity: 20,
        storeMicros: 2 * s,
        retrieveMicros: 2 * s,
      ),
    ),
  ]);

  Widget app(Widget home, {AppSettings settings = const AppSettings()}) =>
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(settings),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(home),
      );

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  group('settings', () {
    test(
      'shift length and failure duration have defaults and are stored',
      () async {
        const d = AppSettings();
        expect((d.shiftMinutes, d.failureMinutes), (480, 30));
        await SettingsRepository(db)
            .save(d.copyWith(shiftMinutes: 600, failureMinutes: 45));
        final loaded = await SettingsRepository(db).load();
        expect((loaded.shiftMinutes, loaded.failureMinutes), (600, 45));
        expect(AppSettings.fromMap({'shiftMinutes': '0'}).shiftMinutes, 480);
      },
    );

    testWidgets('they are chosen in the settings screen', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(app(const SettingsScreen()));
      await settle(tester);
      await tapVisible(tester, find.byKey(const Key('shiftLengthTile')));
      await settle(tester);
      await tester.tap(find.text('10 h'));
      await settle(tester);
      await tapVisible(tester, find.byKey(const Key('failureDurationTile')));
      await settle(tester);
      await tester.tap(find.text('60 min'));
      await settle(tester);
      final saved = await tester.runAsync(() => SettingsRepository(db).load());
      expect((saved!.shiftMinutes, saved.failureMinutes), (600, 60));
    });
  });

  testWidgets('simulates a shift and a failure with and without buffers', (
    tester,
  ) async {
    usePhoneSize(tester);
    // Shift of 1 h, failure of 10 min.
    await tester.pumpWidget(
      app(
        SimulationScreen(groupId: groupId),
        settings: const AppSettings(shiftMinutes: 60, failureMinutes: 10),
      ),
    );
    await settleUntil(
      tester,
      () => find.byKey(const Key('simOutput')).evaluate().isNotEmpty,
    );
    final h = 3600 * s;
    expect(text(tester, 'simOutput'), '${sim.run(horizonMicros: h).output}');
    expect(find.byKey(const Key('simLost')), findsNothing);

    await tester.tap(find.byKey(const Key('failureMachine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runSimulation')));
    await settle(tester);
    await tester.pumpAndSettle();

    const failure = SimFailure(
      station: 1,
      machine: 0,
      startMicros: 900 * s,
      durationMicros: 600 * s,
    );
    final base = sim.run(horizonMicros: h).output;
    final withBuffer = sim.run(horizonMicros: h, failure: failure).output;
    final plain = sim.withoutBuffers();
    final lostPlain =
        plain.run(horizonMicros: h).output -
        plain.run(horizonMicros: h, failure: failure).output;
    expect(text(tester, 'simOutputFailure'), '$withBuffer');
    expect(text(tester, 'simLost'), '${base - withBuffer}');
    expect(text(tester, 'simLostWithoutBuffers'), '$lostPlain');
    expect(lostPlain, greaterThan(base - withBuffer));

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('simBuffer_1')),
      200,
      scrollable: scrollable,
    );
    expect(find.textContaining('20 places'), findsWidgets);
  });

  testWidgets('24 hours and a free horizon', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(SimulationScreen(groupId: groupId), settings: const AppSettings()),
    );
    await settleUntil(
      tester,
      () => find.byKey(const Key('simOutput')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('horizon24h')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runSimulation')));
    await tester.pumpAndSettle();
    expect(
      text(tester, 'simOutput'),
      '${sim.run(horizonMicros: 24 * 3600 * s).output}',
    );

    await tester.tap(find.byKey(const Key('horizonCustom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('horizonHoursField')), '0,5');
    await tester.tap(find.byKey(const Key('runSimulation')));
    await tester.pumpAndSettle();
    expect(
      text(tester, 'simOutput'),
      '${sim.run(horizonMicros: 1800 * s).output}',
    );
  });

  testWidgets('the line screen shows the buffer and opens the simulation', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(LineScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('lineBuffer_1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('20 places'), findsOneWidget);
    await tester.tap(find.byKey(const Key('simulationButton')));
    await pumpFrames(tester);
    await settleUntil(
      tester,
      () => find.byKey(const Key('simOutput')).evaluate().isNotEmpty,
    );
    expect(find.byType(SimulationScreen), findsOneWidget);
  });
}

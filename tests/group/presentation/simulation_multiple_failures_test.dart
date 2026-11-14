import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/presentation/simulation_screen.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late int groupId;

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
    await machines.createMachine(
      name: 'B',
      groupId: groupId,
      cycleMicros: 5 * s,
    );
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
    ),
  ]);
  const h = 3600 * s;
  const failB = SimFailure(
    station: 1,
    machine: 0,
    startMicros: 900 * s,
    durationMicros: 600 * s,
  );
  const failA = SimFailure(
    station: 0,
    machine: 0,
    startMicros: 1800 * s,
    durationMicros: 300 * s,
  );

  Widget app(Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(
        const AppSettings(shiftMinutes: 60, failureMinutes: 10),
      ),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(home),
  );

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('several failures can be added, simulated and removed', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(SimulationScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('simOutput')).evaluate().isNotEmpty,
    );
    // No second failure before the first one is chosen.
    expect(find.byKey(const Key('addFailure')), findsNothing);

    await tester.tap(find.byKey(const Key('failureMachine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. B').last);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const Key('addFailure')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('failureMachine_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. A').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('failureStartField_1')), '0,5');
    await tester.enterText(
      find.byKey(const Key('failureDurationField_1')),
      '5',
    );
    await tapVisible(tester, find.byKey(const Key('runSimulation')));
    await tester.pumpAndSettle();

    final both = sim.run(horizonMicros: h, failures: [failB, failA]).output;
    final base = sim.run(horizonMicros: h).output;
    expect(text(tester, 'simOutputFailure'), '$both');
    expect(text(tester, 'simLost'), '${base - both}');

    await tapVisible(tester, find.byKey(const Key('removeFailure_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('failureMachine_1')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('runSimulation')));
    await tester.pumpAndSettle();
    expect(
      text(tester, 'simOutputFailure'),
      '${sim.run(horizonMicros: h, failure: failB).output}',
    );
  });

  testWidgets('an invalid time in an added failure is reported', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(SimulationScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('simOutput')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('failureMachine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. B').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('addFailure')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('failureDurationField_1')),
      '0',
    );
    await tapVisible(tester, find.byKey(const Key('runSimulation')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a time greater than 0'), findsOneWidget);
  });
}

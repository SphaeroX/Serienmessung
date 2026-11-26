import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/domain/simulation_runner.dart';
import 'package:cyclescope/group/presentation/simulation_screen.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

const _s = 1000000;

/// A runner that fails while [fail] is set, on the UI thread or in the
/// background like a large plant.
class _FailingRunner extends SimulationRunner {
  _FailingRunner({this.background = false});

  final bool background;
  bool fail = true;
  final horizons = <int>[];

  @override
  bool offThread(LineSimulation sim) => background;

  @override
  SimulationRun run(
    LineSimulation sim, {
    required int horizonMicros,
    List<SimFailure> failures = const [],
  }) {
    horizons.add(horizonMicros);
    if (fail) throw ArgumentError('broken');
    return super.run(sim, horizonMicros: horizonMicros, failures: failures);
  }

  @override
  Future<SimulationRun> runInBackground(
    LineSimulation sim, {
    required int horizonMicros,
    List<SimFailure> failures = const [],
  }) async {
    horizons.add(horizonMicros);
    if (fail) throw StateError('isolate failed');
    return super.run(sim, horizonMicros: horizonMicros, failures: failures);
  }
}

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
      cycleMicros: 10 * _s,
    );
    await machines.createMachine(
      name: 'B',
      groupId: groupId,
      cycleMicros: 5 * _s,
    );
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {SimulationRunner? runner}) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
          if (runner != null)
            simulationRunnerProvider.overrideWithValue(runner),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(SimulationScreen(groupId: groupId)),
      ),
    );
    await settleUntil(
      tester,
      () =>
          find.byKey(const Key('simOutput')).evaluate().isNotEmpty ||
          find.textContaining('could not be calculated').evaluate().isNotEmpty,
    );
  }

  String output(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('simOutput'))).data!;

  Future<void> customHours(WidgetTester tester, String hours) async {
    if (find.byKey(const Key('horizonHoursField')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('horizonCustom')));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byKey(const Key('horizonHoursField')), hours);
    await tester.tap(find.byKey(const Key('runSimulation')));
    await tester.pumpAndSettle();
  }

  testWidgets('720 hours are simulated', (tester) async {
    final runner = _FailingRunner()..fail = false;
    await pump(tester, runner: runner);
    await customHours(tester, '720');
    expect(runner.horizons.last, 720 * 3600 * _s);
    expect(find.textContaining('At most'), findsNothing);
    expect(find.byKey(const Key('simOutput')), findsOneWidget);
  });

  for (final hours in ['721', '100000']) {
    testWidgets('$hours hours are not simulated', (tester) async {
      final runner = _FailingRunner()..fail = false;
      await pump(tester, runner: runner);
      final before = output(tester);
      final runs = runner.horizons.length;
      await customHours(tester, hours);
      expect(runner.horizons.length, runs);
      expect(find.textContaining('At most 720 hours'), findsOneWidget);
      // Like an invalid time: the previous results stay.
      expect(output(tester), before);
    });
  }

  for (final background in [false, true]) {
    testWidgets('a failing calculation shows an error '
        '(${background ? 'background' : 'UI thread'})', (tester) async {
      final runner = _FailingRunner(background: background);
      await pump(tester, runner: runner);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('simBusy')), findsNothing);
      expect(find.textContaining('could not be calculated'), findsOneWidget);
      expect(find.byKey(const Key('simOutput')), findsNothing);

      runner.fail = false;
      await tester.tap(find.byKey(const Key('runSimulation')));
      await settleUntil(
        tester,
        () => find.byKey(const Key('simOutput')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('simOutput')), findsOneWidget);
      expect(find.textContaining('could not be calculated'), findsNothing);
    });
  }
}

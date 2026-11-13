import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
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

const s = 1000000;

void main() {
  late AppDatabase db;
  late int groupId;

  setUp(() async {
    db = await openTestDatabase();
    final groups = GroupRepository(db);
    groupId = await groups.createGroup(name: 'Line', now: DateTime(2026));
    // Station 1 has no times yet.
    final draft = await StudyRepository(db).createStudy(
      name: 'Draft',
      mode: StudyMode.timeStudy,
      steps: ['Load'],
      now: DateTime(2026),
    );
    await groups.moveToGroup(draft, groupId);
    final machines = MachineService(db, now: () => DateTime(2026));
    await machines.createMachine(
      name: 'A',
      groupId: groupId,
      cycleMicros: 10 * s,
    );
    final b = await machines.createMachine(
      name: 'B',
      groupId: groupId,
      cycleMicros: 5 * s,
    );
    await groups.setBuffer(
      b,
      capacity: 20,
      storeMicros: 2 * s,
      retrieveMicros: 2 * s,
    );
    await groups.setConveyor(b, capacity: 3, transportMicros: 4 * s);
  });

  tearDown(() => db.close());

  Widget app(Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(home),
  );

  testWidgets('stations carry the same numbers as in the line', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(LineScreen(groupId: groupId)));
    await settleUntil(tester, () => find.text('3. B').evaluate().isNotEmpty);
    expect(find.text('1. Draft'), findsOneWidget);
    expect(find.text('2. A'), findsOneWidget);

    await tester.pumpWidget(app(SimulationScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('simOutput')).evaluate().isNotEmpty,
    );
    await tester.scrollUntilVisible(
      find.text('3. B'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2. A'), findsOneWidget);
    expect(find.text('3. B'), findsOneWidget);
    expect(find.text('1. A'), findsNothing);
    // Buffer and conveyor name the station they stand before.
    expect(find.textContaining('· 3. B'), findsNWidgets(2));

    // The machine to fail is chosen by the same numbers.
    await tapVisible(tester, find.byKey(const Key('failureMachine')));
    await tester.pumpAndSettle();
    expect(find.text('2. A'), findsWidgets);
    expect(find.text('1. A'), findsNothing);
  });
}

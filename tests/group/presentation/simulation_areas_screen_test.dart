import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/presentation/line_screen.dart';
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
  late GroupRepository groups;
  late MachineService machines;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    machines = MachineService(db, now: () => DateTime(2026));
  });

  tearDown(() => db.close());

  Future<int> newGroup(String name, {int? parent}) async {
    final id = await groups.createGroup(name: name, now: DateTime(2026));
    if (parent != null) await groups.setParent(id, parent);
    return id;
  }

  Widget app(Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(home),
  );

  /// Plant: area Front (Saw, Tester), area Back (Tester) with a buffer
  /// before it.
  Future<({int plant, int front, int back})> plant() async {
    final plant = await newGroup('Plant');
    final front = await newGroup('Front', parent: plant);
    await machines.createMachine(
      name: 'Saw',
      groupId: front,
      cycleMicros: 30 * s,
    );
    await machines.createMachine(
      name: 'Tester',
      groupId: front,
      cycleMicros: 40 * s,
    );
    final back = await newGroup('Back', parent: plant);
    await machines.createMachine(
      name: 'Tester',
      groupId: back,
      cycleMicros: 50 * s,
    );
    await groups.setAreaBuffer(
      back,
      capacity: 10,
      storeMicros: 2 * s,
      retrieveMicros: 2 * s,
    );
    return (plant: plant, front: front, back: back);
  }

  Future<void> open(WidgetTester tester, int groupId) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(SimulationScreen(groupId: groupId)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('simOutput')).evaluate().isNotEmpty,
    );
  }

  final vertical = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .first;

  testWidgets('a plant shows its areas, headings and labelled links', (
    tester,
  ) async {
    late ({int plant, int front, int back}) p;
    await tester.runAsync(() async => p = await plant());
    await open(tester, p.plant);

    // The failure machines name their area.
    await tester.tap(find.byKey(const Key('failureMachine')));
    await tester.pumpAndSettle();
    expect(find.text('2. Front · Tester'), findsWidgets);
    expect(find.text('3. Back · Tester'), findsWidgets);
    await tester.tap(find.text('3. Back · Tester').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('runSimulation')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('simAreas')),
      200,
      scrollable: vertical,
    );
    final back = find.byKey(Key('simArea_${p.back}'));
    expect(find.byKey(Key('simArea_${p.front}')), findsOneWidget);
    expect(back, findsOneWidget);
    // The failure is a standstill of the back area only.
    expect(
      find.descendant(of: back, matching: find.textContaining('down ')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(Key('simArea_${p.front}')),
        matching: find.textContaining('down '),
      ),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.textContaining('before area Back'),
      200,
      scrollable: vertical,
    );
    await tester.scrollUntilVisible(
      find.byKey(Key('simAreaHeading_${p.back}')),
      200,
      scrollable: vertical,
    );
    expect(find.byKey(Key('simAreaHeading_${p.front}')), findsOneWidget);
  });

  testWidgets('a group without areas shows no area card', (tester) async {
    late int line;
    await tester.runAsync(() async {
      line = await newGroup('Line');
      await machines.createMachine(
        name: 'A',
        groupId: line,
        cycleMicros: 10 * s,
      );
      await machines.createMachine(
        name: 'B',
        groupId: line,
        cycleMicros: 5 * s,
      );
    });
    await open(tester, line);
    expect(find.byKey(const Key('simAreas')), findsNothing);
    expect(find.textContaining(' · A'), findsNothing);
  });

  testWidgets('a large plant is simulated in the background', (tester) async {
    late int plant;
    await tester.runAsync(() async {
      plant = await newGroup('Plant');
      for (var a = 0; a < 4; a++) {
        final area = await newGroup('Area $a', parent: plant);
        for (var i = 0; i < 9; i++) {
          await machines.createMachine(
            name: 'M$a.$i',
            groupId: area,
            cycleMicros: (20 + i) * s,
          );
        }
      }
    });
    await open(tester, plant);
    expect(find.byKey(const Key('simOutput')), findsOneWidget);
  });

  testWidgets('the failure risk names the area of each machine', (
    tester,
  ) async {
    late ({int plant, int front, int back}) p;
    await tester.runAsync(() async {
      p = await plant();
      // A second tester in parallel, so there is a failure risk list.
      final id = await machines.createMachine(
        name: 'Tester B',
        groupId: p.back,
        cycleMicros: 50 * s,
      );
      await groups.setParallel(id, true);
    });
    usePhoneSize(tester);
    await tester.pumpWidget(app(LineScreen(groupId: p.plant)));
    await settleUntil(
      tester,
      () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('risk_0')),
      300,
      scrollable: vertical,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('risk_3')),
      200,
      scrollable: vertical,
    );
    expect(find.textContaining('Back · Tester'), findsWidgets);
    expect(find.text('1. Front · Saw'), findsOneWidget);
  });
}

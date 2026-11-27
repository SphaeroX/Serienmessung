import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late StudyRepository studies;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    studies = StudyRepository(db);
  });

  tearDown(() => db.close());

  Widget app(Widget child) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      wallClockProvider.overrideWithValue(() => DateTime(2026, 3, 1)),
      ...fakePlatformOverrides(),
    ],
    child: localizedApp(child),
  );

  /// Saw (time study), then the machine Mill in parallel to it.
  Future<({int group, int mill})> line() async {
    final g = await groups.createGroup(name: 'Line', now: DateTime(2026));
    final saw = await studies.createStudy(
      name: 'Saw',
      mode: StudyMode.timeStudy,
      steps: ['A'],
      now: DateTime(2026),
    );
    await groups.moveToGroup(saw, g);
    final mill = await MachineService(
      db,
      now: () => DateTime(2026),
    ).createMachine(name: 'Mill', groupId: g, cycleMicros: 5000000);
    await groups.setParallel(mill, true);
    return (group: g, mill: mill);
  }

  testWidgets('a machine becomes a time study in its place', (tester) async {
    final x = (await tester.runAsync(line))!;
    await tester.pumpWidget(app(GroupScreen(groupId: x.group)));
    await settle(tester);

    await tester.tap(find.byKey(Key('groupStudyMenu_${x.mill}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('changeMode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeMode')));
    await settle(tester);

    // The times are lost, so the dialog says so.
    expect(find.byKey(const Key('changeModeTimesWarning')), findsOneWidget);
    await tester.tap(find.byKey(const Key('changeMode_timeStudy')));
    await tester.pumpAndSettle();
    // Steps are required for a time study.
    await tester.tap(find.byKey(const Key('changeModeConfirm')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter at least one step'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('changeModeSteps')),
      'Load\nMill',
    );
    await tester.tap(find.byKey(const Key('changeModeConfirm')));
    // Saw and Mill are both time studies once the change is stored.
    await settleUntil(
      tester,
      () => find.textContaining('Time study').evaluate().length == 2,
    );

    expect(find.text('1b. Mill'), findsOneWidget);
    final study = (await tester.runAsync(() => studies.getStudy(x.mill)))!;
    expect(study.mode, StudyMode.timeStudy);
    expect(study.parallel, isTrue);
    final steps = (await tester.runAsync(() => studies.getSteps(x.mill)))!;
    expect(steps.map((s) => s.name), ['Load', 'Mill']);
  });

  testWidgets('cancelling changes nothing', (tester) async {
    final x = (await tester.runAsync(line))!;
    await tester.pumpWidget(app(GroupScreen(groupId: x.group)));
    await settle(tester);

    await tester.tap(find.byKey(Key('groupStudyMenu_${x.mill}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('changeMode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeMode')));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    final study = (await tester.runAsync(() => studies.getStudy(x.mill)))!;
    expect(study.mode, StudyMode.simple);
  });
}

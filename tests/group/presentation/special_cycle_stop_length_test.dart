import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/data/special_cycle_repository.dart';
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
  late int press;

  setUp(() async {
    db = await openTestDatabase();
    final groupId = await GroupRepository(db)
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

  Future<void> enterStop(
    WidgetTester tester, {
    required String hours,
    required String seconds,
  }) async {
    await tester.tap(find.byKey(const Key('addSpecialCycle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kindTime')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('specialCycleIntervalField')),
      hours,
    );
    await tester.enterText(
      find.byKey(const Key('specialCycleDurationField')),
      seconds,
    );
    await tester.tap(find.byKey(const Key('saveSpecialCycleButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('a stop as long as its interval is rejected', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(SpecialCyclesScreen(studyId: press, studyName: 'Press')),
    );
    await settle(tester);
    // Every hour a stop of two hours: the machine would never run.
    await enterStop(tester, hours: '1', seconds: '7200');
    expect(
      find.text('The stop must be shorter than the interval'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('saveSpecialCycleButton')), findsOneWidget);
    await settle(tester);
    expect(
      await tester.runAsync(() => SpecialCycleRepository(db).list(press)),
      isEmpty,
    );

    // Exactly as long is not possible either.
    await tester.enterText(
      find.byKey(const Key('specialCycleDurationField')),
      '3600',
    );
    await tester.tap(find.byKey(const Key('saveSpecialCycleButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('The stop must be shorter than the interval'),
      findsOneWidget,
    );
  });

  testWidgets('a shorter stop is saved', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(SpecialCyclesScreen(studyId: press, studyName: 'Press')),
    );
    await settle(tester);
    await enterStop(tester, hours: '1', seconds: '3599');
    await settleUntil(
      tester,
      () => find.textContaining('Every 1 h').evaluate().isNotEmpty,
    );
    expect(
      (await tester.runAsync(() => SpecialCycleRepository(db).list(press)))!
          .single
          .durationMicros,
      3599000000,
    );
  });

  testWidgets('extra time per part may be longer than any interval', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(SpecialCyclesScreen(studyId: press, studyName: 'Press')),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('addSpecialCycle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('specialCycleIntervalField')),
      '1',
    );
    await tester.enterText(
      find.byKey(const Key('specialCycleDurationField')),
      '7200',
    );
    await tester.tap(find.byKey(const Key('saveSpecialCycleButton')));
    await settleUntil(
      tester,
      () => find.textContaining('Every 1 parts').evaluate().isNotEmpty,
    );
    expect(
      await tester.runAsync(() => SpecialCycleRepository(db).list(press)),
      hasLength(1),
    );
  });
}

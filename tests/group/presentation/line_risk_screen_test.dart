import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/presentation/line_screen.dart';
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

  setUp(() async {
    db = await openTestDatabase();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line', now: DateTime(2026));
    final machines = MachineService(db, now: () => DateTime(2026));
    await machines.createMachine(
      name: 'Saw',
      groupId: groupId,
      cycleMicros: 12000000,
    );
    for (var i = 1; i <= 4; i++) {
      await machines.createMachine(
        name: 'Press $i',
        groupId: groupId,
        cycleMicros: 40000000,
        parallel: i > 1,
      );
    }
  });

  tearDown(() => db.close());

  testWidgets('parallel stations and the failure risk are shown', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(defaultUnit: TimeUnit.seconds),
          ),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(LineScreen(groupId: groupId)),
      ),
    );
    await settleUntil(
      tester,
      () => find.byKey(const Key('lineTotal')).evaluate().isNotEmpty,
    );

    String text(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(text('lineCycleTime'), '12.00 s');
    expect(text('lineLead'), '52.00 s');
    expect(text('lineBottleneck'), 'Saw');
    expect(text('lineOutput'), '300.0');

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.textContaining('4 machines in parallel'),
      200,
      scrollable: scrollable,
    );
    expect(find.textContaining('Press 3: 40.00 s'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('risk_4')),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Failure risk'), findsOneWidget);
    expect(
      find.textContaining('1 station without a spare machine'),
      findsOneWidget,
    );
    expect(find.text('Standstill'), findsOneWidget);
    expect(find.text('-10.0 %'), findsNWidgets(4));
    expect(find.textContaining('270.0 / h'), findsNWidgets(4));
  });
}

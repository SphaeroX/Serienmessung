import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/group/presentation/group_screen.dart';
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
  late GroupRepository groups;
  late int plant;
  late int first;
  late int second;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    final studies = StudyRepository(db);
    plant = await groups.createGroup(name: 'Plant', now: DateTime(2026));
    Future<int> area(String name) async {
      final id = await groups.createGroup(name: name, now: DateTime(2026));
      await groups.setParent(id, plant);
      final st = await studies.createStudy(
        name: '$name 1',
        mode: StudyMode.simple,
        steps: const [],
        now: DateTime(2026),
      );
      await groups.moveToGroup(st, id);
      return id;
    }

    first = await area('Saw');
    second = await area('Press');
  });

  tearDown(() => db.close());

  Future<void> open(WidgetTester tester) async {
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
        child: localizedApp(GroupScreen(groupId: plant)),
      ),
    );
    await settle(tester);
    await settle(tester);
  }

  testWidgets('the first area offers no buffer or conveyor', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(Key('areaMenu_$first')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('areaAddBuffer')), findsNothing);
    expect(find.byKey(const Key('areaAddConveyor')), findsNothing);
  });

  testWidgets('a buffer before an area is added, edited and removed', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(Key('areaMenu_$second')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('areaAddBuffer')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bufferCapacityField')), '50');
    await tester.enterText(find.byKey(const Key('bufferStoreField')), '20');
    await tester.enterText(find.byKey(const Key('bufferRetrieveField')), '15');
    await tester.tap(find.byKey(const Key('saveBufferButton')));
    await settleUntil(
      tester,
      () => find.byKey(Key('areaBuffer_$second')).evaluate().isNotEmpty,
    );
    var g = (await tester.runAsync<StudyGroup?>(
      () => groups.getGroup(second),
    ))!;
    expect(g.bufferCapacity, 50);
    expect(g.bufferStoreMicros, 20 * s);
    expect(g.bufferRetrieveMicros, 15 * s);

    await tester.tap(find.byKey(Key('areaBuffer_$second')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bufferCapacityField')), '80');
    await tester.tap(find.byKey(const Key('saveBufferButton')));
    await settle(tester);
    await settle(tester);
    g = (await tester.runAsync<StudyGroup?>(() => groups.getGroup(second)))!;
    expect(g.bufferCapacity, 80);

    await tester.tap(find.byKey(Key('areaBuffer_$second')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('removeBufferButton')));
    await settleUntil(
      tester,
      () => find.byKey(Key('areaBuffer_$second')).evaluate().isEmpty,
    );
    g = (await tester.runAsync<StudyGroup?>(() => groups.getGroup(second)))!;
    expect(g.hasBuffer, isFalse);
  });

  testWidgets('a conveyor before an area is added and removed', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(Key('areaMenu_$second')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('areaAddConveyor')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('conveyorTimeField')), '30');
    await tester.enterText(find.byKey(const Key('conveyorPlacesField')), '8');
    await tester.tap(find.byKey(const Key('saveConveyorButton')));
    await settleUntil(
      tester,
      () => find.byKey(Key('areaConveyor_$second')).evaluate().isNotEmpty,
    );
    final g = (await tester.runAsync<StudyGroup?>(
      () => groups.getGroup(second),
    ))!;
    expect(g.conveyorCapacity, 8);
    expect(g.conveyorTransportMicros, 30 * s);

    await tester.tap(find.byKey(Key('areaConveyor_$second')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('removeConveyorButton')));
    await settleUntil(
      tester,
      () => find.byKey(Key('areaConveyor_$second')).evaluate().isEmpty,
    );
    expect(
      (await tester.runAsync<StudyGroup?>(() => groups.getGroup(second)))!
          .hasConveyor,
      isFalse,
    );
  });
}

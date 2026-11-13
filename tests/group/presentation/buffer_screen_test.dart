import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/group/data/group_repository.dart';
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

void main() {
  late AppDatabase db;
  late int groupId;

  setUp(() async {
    db = await openTestDatabase();
    groupId = await GroupRepository(db)
        .createGroup(name: 'Line', now: DateTime(2026));
  });

  tearDown(() => db.close());

  Future<int> study(WidgetTester tester, String name) async =>
      (await tester.runAsync(() async {
        final id = await StudyRepository(db).createStudy(
          name: name,
          mode: StudyMode.timeStudy,
          steps: ['A'],
          now: DateTime(2026),
        );
        await GroupRepository(db).moveToGroup(id, groupId);
        return id;
      }))!;

  Future<void> pump(WidgetTester tester) async {
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
        child: localizedApp(GroupScreen(groupId: groupId)),
      ),
    );
    await settle(tester);
  }

  testWidgets('a buffer is inserted, shown, edited and removed', (
    tester,
  ) async {
    final saw = await study(tester, 'Saw');
    final press = await study(tester, 'Press');
    await pump(tester);

    await tester.tap(find.byKey(Key('groupStudyMenu_$saw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addBuffer')), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('groupStudyMenu_$press')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addBuffer')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bufferCapacityField')), '50');
    await tester.enterText(find.byKey(const Key('bufferStoreField')), '20');
    await tester.enterText(find.byKey(const Key('bufferRetrieveField')), '15');
    await tester.tap(find.byKey(const Key('saveBufferButton')));
    await settleUntil(
      tester,
      () => find.byKey(Key('buffer_$press')).evaluate().isNotEmpty,
    );
    expect(find.textContaining('50 places'), findsOneWidget);
    expect(find.textContaining('20.00 s'), findsOneWidget);
    Future<Study> load() async =>
        (await tester.runAsync(() => StudyRepository(db).getStudy(press)))!;
    var s = await load();
    expect(
      (s.bufferCapacity, s.bufferStoreMicros, s.bufferRetrieveMicros),
      (50, 20000000, 15000000),
    );

    // Editing.
    await tester.tap(find.byKey(Key('buffer_$press')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bufferCapacityField')), '80');
    await tester.tap(find.byKey(const Key('saveBufferButton')));
    await settleUntil(
      tester,
      () => find.textContaining('80 places').evaluate().isNotEmpty,
    );
    s = await load();
    expect(s.bufferCapacity, 80);

    // Removing.
    await tester.tap(find.byKey(Key('buffer_$press')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('removeBufferButton')));
    await settleUntil(
      tester,
      () => find.byKey(Key('buffer_$press')).evaluate().isEmpty,
    );
    s = await load();
    expect(s.hasBuffer, isFalse);
  });

  testWidgets('invalid buffer values are rejected', (tester) async {
    await study(tester, 'Saw');
    final press = await study(tester, 'Press');
    await pump(tester);
    await tester.tap(find.byKey(Key('groupStudyMenu_$press')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addBuffer')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bufferCapacityField')), '0');
    await tester.enterText(find.byKey(const Key('bufferStoreField')), 'x');
    await tester.tap(find.byKey(const Key('saveBufferButton')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number greater than 0'), findsOneWidget);
    expect(find.text('Enter a time greater than 0'), findsWidgets);
  });
}

import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/settings/presentation/settings_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_platform.dart';
import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  Future<void> showSettings(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
          wallClockProvider.overrideWithValue(() => DateTime(2026, 11, 13, 10)),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(const SettingsScreen(), locale: locale),
      ),
    );
    await settle(tester);
  }

  Future<int> groupCount(WidgetTester tester) async =>
      (await tester.runAsync(() => GroupRepository(db).listGroups()))!.length;

  testWidgets('the data section offers demo data; cancel loads nothing', (
    tester,
  ) async {
    await showSettings(tester);
    await tapVisible(tester, find.byKey(const Key('loadDemoDataTile')));
    await settle(tester);
    expect(find.text('Load demo data'), findsWidgets);
    expect(find.textContaining('parallel machines, buffers'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await groupCount(tester), 0);
  });

  testWidgets('loads the demo line after confirming', (tester) async {
    await showSettings(tester);
    await tapVisible(tester, find.byKey(const Key('loadDemoDataTile')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('loadDemoDataConfirm')));
    await settleUntil(
      tester,
      () => find.byType(SnackBar).evaluate().isNotEmpty,
    );

    expect(
      find.text('Demo data loaded: see the group “Demo: housing line”.'),
      findsOneWidget,
    );
    final groups = (await tester.runAsync(
      () => GroupRepository(db).listGroups(),
    ))!;
    expect(groups.single.group.name, 'Demo: housing line');
    expect(groups.single.studyCount, 9);
  });

  testWidgets('the demo data follows the app language', (tester) async {
    await showSettings(tester, locale: const Locale('de'));
    await tapVisible(tester, find.byKey(const Key('loadDemoDataTile')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('loadDemoDataConfirm')));
    await settleUntil(
      tester,
      () => find.byType(SnackBar).evaluate().isNotEmpty,
    );

    final studies = (await tester.runAsync(
      () => StudyRepository(db).listStudies(),
    ))!;
    final names = {for (final s in studies) s.study.name};
    expect(
      names,
      containsAll(['Säge', 'Bearbeitungszentrum 2', 'Prüfstand 3']),
    );
    expect(
      (await tester.runAsync(() => GroupRepository(db).listGroups()))!
          .single
          .group
          .name,
      'Demo: Gehäuselinie',
    );
  });
}

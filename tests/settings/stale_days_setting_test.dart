import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/settings/data/settings_repository.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_platform.dart';
import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  test('asks after 10 days by default; the value is stored', () async {
    expect((await SettingsRepository(db).load()).staleDays, 10);
    await SettingsRepository(db)
        .save(const AppSettings().copyWith(staleDays: 30));
    expect((await SettingsRepository(db).load()).staleDays, 30);
  });

  test('invalid values fall back to the default, 0 switches it off', () {
    expect(AppSettings.fromMap({'staleDays': 'x'}).staleDays, 10);
    expect(AppSettings.fromMap({'staleDays': '-4'}).staleDays, 0);
    expect(AppSettings.fromMap({'staleDays': '0'}).staleDays, 0);
  });

  testWidgets('the threshold is chosen in the settings', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(const SettingsScreen()),
      ),
    );
    await settle(tester);
    await tapVisible(tester, find.byKey(const Key('staleDaysTile')));
    await settle(tester);
    expect(find.text('After 10 days'), findsWidgets);
    await tester.tap(find.text('Never'));
    await settle(tester);
    final s = await tester.runAsync(() => SettingsRepository(db).load());
    expect(s!.staleDays, 0);
    expect(find.text('Never'), findsOneWidget);
  });
}

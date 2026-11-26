import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
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

  testWidgets('the settings show version 1.9.2', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(const SettingsScreen()),
      ),
    );
    await settle(tester);
    await tester.scrollUntilVisible(
      find.textContaining('1.9.2'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(appVersion, '1.9.2');
    expect(find.text('Version 1.9.2'), findsOneWidget);
  });
}

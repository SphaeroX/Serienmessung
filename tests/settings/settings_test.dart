import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/app.dart';
import 'package:cyclescope/core/platform.dart';
import 'package:cyclescope/core/platform_features.dart';
import 'package:cyclescope/recording/platform/recording_notifier.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/settings/data/settings_repository.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/settings/presentation/settings_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/presentation/create_study_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_platform.dart';
import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  test('defaults on first start', () async {
    final s = await SettingsRepository(db).load();
    expect(s.theme, ThemeChoice.system);
    expect(s.defaultUnit, TimeUnit.hm);
    expect(s.defaultMethod, CycleTimeMethod.median);
    expect(
      (s.vibration, s.hardwareKeys, s.keepScreenOn, s.notifications),
      (true, true, true, true),
    );
    expect(s.holdThresholdMs, 400);
  });

  test('changed settings survive a restart', () async {
    await SettingsRepository(db).save(
      const AppSettings().copyWith(
        theme: ThemeChoice.dark,
        language: LanguageChoice.de,
        defaultUnit: TimeUnit.tmu,
        defaultMethod: CycleTimeMethod.iqr,
        vibration: false,
        hardwareKeys: false,
        holdThresholdMs: 650,
      ),
    );
    final s = await SettingsRepository(db).load();
    expect(s.theme, ThemeChoice.dark);
    expect(s.language, LanguageChoice.de);
    expect(s.defaultUnit, TimeUnit.tmu);
    expect(s.defaultMethod, CycleTimeMethod.iqr);
    expect((s.vibration, s.hardwareKeys), (false, false));
    expect(s.holdThresholdMs, 650);
  });

  test('invalid stored values fall back to defaults', () {
    final s = AppSettings.fromMap({
      'theme': 'neon',
      'holdThresholdMs': '99999',
      'vibration': 'false',
    });
    expect(s.theme, ThemeChoice.system);
    expect(s.holdThresholdMs, AppSettings.maxHoldMs);
    expect(s.vibration, isFalse);
  });

  Widget app(
    Widget home, {
    AppSettings initial = const AppSettings(),
    PlatformFeatures? platformFeatures,
    FakeUrlOpener? urlOpener,
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(initial),
      ...fakePlatformOverrides(urlOpener: urlOpener),
      if (platformFeatures != null)
        platformFeaturesProvider.overrideWithValue(platformFeatures),
    ],
    child: localizedApp(home),
  );

  testWidgets('toggling a switch is saved', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(const SettingsScreen()));
    await settle(tester);
    await tester.tap(find.byKey(const Key('vibrationSwitch')));
    await settle(tester);
    final s = await tester.runAsync(() => SettingsRepository(db).load());
    expect(s!.vibration, isFalse);
  });

  const platformOnlySettings = [
    'hardwareKeysSwitch',
    'holdSlider',
    'notificationsSwitch',
  ];

  testWidgets('android offers volume keys and the notification', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(const SettingsScreen()));
    await settle(tester);
    for (final key in platformOnlySettings) {
      expect(find.byKey(Key(key), skipOffstage: false), findsOneWidget);
    }
  });

  testWidgets('iOS offers neither volume keys nor the notification', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(
        const SettingsScreen(),
        platformFeatures: PlatformFeatures.of(TargetPlatform.iOS),
      ),
    );
    await settle(tester);
    for (final key in platformOnlySettings) {
      expect(find.byKey(Key(key), skipOffstage: false), findsNothing);
    }
    expect(find.byKey(const Key('vibrationSwitch')), findsOneWidget);
  });

  testWidgets('choosing a default unit is saved', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(const SettingsScreen()));
    await settle(tester);
    await tester.tap(find.byKey(const Key('unitTile')));
    await settle(tester);
    await tester.tap(find.text('Seconds'));
    await settle(tester);
    final s = await tester.runAsync(() => SettingsRepository(db).load());
    expect(s!.defaultUnit, TimeUnit.seconds);
    expect(find.text('Seconds'), findsOneWidget);
  });

  testWidgets('new studies take the default method', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(
        const CreateStudyScreen(),
        initial: const AppSettings(defaultMethod: CycleTimeMethod.iqr),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byKey(const Key('stepsField')), 'A');
    await tapVisible(tester, find.byKey(const Key('createStudyButton')));
    await settle(tester);
    final list = await tester.runAsync(() => StudyRepository(db).listStudies());
    expect(list!.single.study.cycleTimeMethod, 'iqr');
  });

  testWidgets('language and theme are applied to the app', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(
              language: LanguageChoice.de,
              theme: ThemeChoice.dark,
            ),
          ),
          ...fakePlatformOverrides(),
        ],
        child: const CycleScopeApp(),
      ),
    );
    await settle(tester);
    expect(find.text('Studie erstellen'), findsOneWidget);
    final ctx = tester.element(find.text('Studie erstellen'));
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });

  test('notification and haptics providers follow the settings', () {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            notifications: false,
            vibration: false,
            keepScreenOn: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(recordingNotifierProvider),
      isA<SilentRecordingNotifier>(),
    );
    final fb = container.read(deviceFeedbackProvider) as SystemDeviceFeedback;
    expect((fb.vibrate, fb.keepScreenOn), (false, false));
  });

  const privacyPolicyTile = Key('privacyPolicyTile');

  testWidgets('tapping the privacy policy opens it', (tester) async {
    usePhoneSize(tester);
    final opener = FakeUrlOpener();
    await tester.pumpWidget(app(const SettingsScreen(), urlOpener: opener));
    await settle(tester);
    await tapVisible(tester, find.byKey(privacyPolicyTile));
    await settle(tester);
    expect(opener.opened, [
      Uri.parse('https://sphaerox.github.io/Serienmessung/privacy/'),
    ]);
    expect(find.text('Could not open the link.'), findsNothing);
  });

  testWidgets('tells the user when the privacy policy cannot be opened', (
    tester,
  ) async {
    usePhoneSize(tester);
    final opener = FakeUrlOpener()..result = false;
    await tester.pumpWidget(app(const SettingsScreen(), urlOpener: opener));
    await settle(tester);
    await tapVisible(tester, find.byKey(privacyPolicyTile));
    await settle(tester);
    expect(find.text('Could not open the link.'), findsOneWidget);
  });

  testWidgets('privacy policy label is translated', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ...fakePlatformOverrides(),
        ],
        child: localizedApp(const SettingsScreen(), locale: const Locale('de')),
      ),
    );
    await settle(tester);
    final tile = find.byKey(privacyPolicyTile);
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Datenschutzerklärung')),
      findsOneWidget,
    );
  });
}

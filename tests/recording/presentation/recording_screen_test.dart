import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_clock.dart';
import '../../fakes/fake_platform.dart';
import '../../helpers.dart';

import 'package:cyclescope/recording/domain/key_interpreter.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late int studyId;
  late FakeHardwareKeys keys;
  late FakeRecordingNotifier notifier;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock(1000000);
    keys = FakeHardwareKeys();
    notifier = FakeRecordingNotifier();
    studyId = await StudyRepository(db).createStudy(
      name: 'Line',
      mode: StudyMode.timeStudy,
      steps: ['Pick', 'Place', 'Press'],
      now: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(settings),
          clockProvider.overrideWithValue(clock as Clock),
          ...fakePlatformOverrides(keys: keys, notifier: notifier),
        ],
        child: localizedApp(RecordingScreen(studyId: studyId)),
      ),
    );
    await settle(tester);
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  testWidgets('overlay shows step 1 immediately after start', (tester) async {
    await pumpScreen(tester);
    expect(textOf(tester, 'currentStepName'), 'Pick');
    expect(find.text('Ready'), findsOneWidget);

    await tap(tester, 'startStopButton');
    expect(textOf(tester, 'currentStepName'), 'Pick');
    expect(textOf(tester, 'stepPosition'), 'Step 1 of 3');
    expect(textOf(tester, 'nextStepName'), 'Next: Place');
    expect(textOf(tester, 'cycleLabel'), 'Cycle 1');
  });

  testWidgets('next advances the overlay and wraps into cycle 2', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tap(tester, 'startStopButton');

    clock.advanceSeconds(2);
    await tap(tester, 'nextButton');
    expect(textOf(tester, 'currentStepName'), 'Place');

    clock.advanceSeconds(2);
    await tap(tester, 'nextButton');
    expect(textOf(tester, 'currentStepName'), 'Press');

    clock.advanceSeconds(2);
    await tap(tester, 'nextButton');
    expect(textOf(tester, 'currentStepName'), 'Pick');
    expect(textOf(tester, 'cycleLabel'), 'Cycle 2');

    final stored = await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(studyId),
    );
    expect(stored!.length, 3);
  });

  testWidgets('newest measurement appears at the top of the live list', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tap(tester, 'startStopButton');
    clock.advanceSeconds(1);
    await tap(tester, 'nextButton');
    clock.advanceSeconds(3);
    await tap(tester, 'nextButton');

    final rows = find.byKey(const Key('liveRow'));
    expect(rows, findsNWidgets(2));
    final first = find.descendant(of: rows.first, matching: find.text('Place'));
    expect(first, findsOneWidget);
  });

  testWidgets('stop pauses and continue resumes the same step', (tester) async {
    await pumpScreen(tester);
    await tap(tester, 'startStopButton');
    await tap(tester, 'startStopButton');
    expect(find.text('CONTINUE'), findsOneWidget);
    await tap(tester, 'startStopButton');
    expect(textOf(tester, 'currentStepName'), 'Pick');
    expect(find.text('STOP'), findsOneWidget);
  });

  testWidgets('volume keys control the recording', (tester) async {
    await pumpScreen(tester);
    expect(keys.capturing, isTrue);

    keys.press(VolumeKey.down, at: clock.micros);
    await settle(tester);
    expect(find.text('STOP'), findsOneWidget);

    clock.advanceSeconds(2);
    keys.press(VolumeKey.up, at: clock.micros);
    await settle(tester);
    expect(textOf(tester, 'currentStepName'), 'Place');

    final stored = await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(studyId),
    );
    expect(stored!.single.durationMicros, 2000000);
  });

  testWidgets('key capture is released when the screen closes', (tester) async {
    await pumpScreen(tester);
    await tester.pumpWidget(const SizedBox());
    expect(keys.capturing, isFalse);
  });

  testWidgets('holding volume up shows the special time and stores it', (
    tester,
  ) async {
    await pumpScreen(tester);
    keys.press(VolumeKey.down, at: clock.micros);
    await settle(tester);

    clock.advanceSeconds(2);
    keys.emit(VolumeKey.up, down: true, at: clock.micros);
    // Real hold timer (400 ms) fires while the key is held.
    await tester.pump(const Duration(milliseconds: 450));
    await settle(tester);
    expect(find.text('SPECIAL TIME'), findsOneWidget);
    expect(textOf(tester, 'currentStepName'), 'Pick');

    clock.advanceSeconds(3);
    keys.emit(VolumeKey.up, down: false, at: clock.micros);
    await settle(tester);
    expect(find.text('RECORDING'), findsOneWidget);
    expect(find.text('Special time'), findsOneWidget);

    final stored = await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(studyId),
    );
    expect(stored!.single.isSpecial, isTrue);
    expect(stored.single.durationMicros, 3000000);
  });

  testWidgets('special button records while held', (tester) async {
    await pumpScreen(tester);
    await tap(tester, 'startStopButton');
    clock.advanceSeconds(1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('specialButton'))),
    );
    await settle(tester);
    expect(find.text('SPECIAL TIME'), findsOneWidget);
    clock.advanceSeconds(4);
    await gesture.up();
    await settle(tester);
    final stored = await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(studyId),
    );
    expect(stored!.single.durationMicros, 4000000);
  });

  testWidgets('tapping a special time row edits its note', (tester) async {
    await pumpScreen(tester);
    await tap(tester, 'startStopButton');
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('specialButton'))),
    );
    await settle(tester);
    clock.advanceSeconds(1);
    await gesture.up();
    await settle(tester);

    await tester.tap(find.text('Special time'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('noteField')), 'Jam');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Special time: Jam'), findsOneWidget);
  });

  testWidgets('notification mirrors the step and its buttons work', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(notifier.shown, isNull);
    await tap(tester, 'startStopButton');
    expect(notifier.shown!.text, 'Pick · Cycle 1');
    expect(notifier.shown!.running, isTrue);

    clock.advanceSeconds(1);
    notifier.press('next');
    await settle(tester);
    expect(notifier.shown!.text, 'Place · Cycle 1');

    notifier.press('toggle');
    await settle(tester);
    expect(notifier.shown!.text, 'PAUSED – Place · Cycle 1');
    expect(notifier.shown!.running, isFalse);

    await tester.tap(find.byKey(const Key('resetButton')));
    await settle(tester);
    await tester.tap(find.text('Reset').last);
    await settle(tester);
    expect(notifier.shown, isNull);
  });

  testWidgets('hardware keys can be switched off', (tester) async {
    await pumpScreen(tester, settings: const AppSettings(hardwareKeys: false));
    expect(keys.capturing, isFalse);
    keys.press(VolumeKey.down, at: clock.micros);
    await settle(tester);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('live display uses the default unit', (tester) async {
    await pumpScreen(
      tester,
      settings: const AppSettings(defaultUnit: TimeUnit.seconds),
    );
    await tap(tester, 'startStopButton');
    clock.advanceSeconds(3);
    await tap(tester, 'nextButton');
    expect(find.text('3.0 s'), findsWidgets);
  });
}

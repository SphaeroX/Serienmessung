import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/core/clock_resume_sync.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/core/providers.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/platform/hardware_keys.dart';
import 'package:cyclescope/recording/platform/recording_notifier.dart';
import 'package:cyclescope/recording/presentation/recording_screen.dart';
import 'package:cyclescope/settings/domain/app_settings.dart';
import 'package:cyclescope/settings/presentation/settings_controller.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform.dart';
import '../../fakes/fake_platform_time.dart';
import '../../helpers.dart';

const _second = 1000000;
const _minute = 60 * _second;
const _start = 5 * _minute;

/// The device sleeps 10 minutes while a step runs: the stopwatch behind the
/// clock stands still, the platform time keeps counting.
void main() {
  late AppDatabase db;
  late FakeTicks ticks;
  late MonotonicClock clock;
  late int studyId;
  MockStreamHandlerEventSink? keySink;
  MockStreamHandlerEventSink? actionSink;

  /// The platform time: what the clock would show had it not slept.
  late int platform;

  setUp(() async {
    db = await openTestDatabase();
    ticks = FakeTicks();
    clock = MonotonicClock(offsetMicros: _start, ticks: ticks.call);
    platform = _start;
    studyId = await StudyRepository(db).createStudy(
      name: 'Line',
      mode: StudyMode.timeStudy,
      steps: ['Pick', 'Place'],
      now: DateTime(2026),
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('dev.cyclescope/keys'),
      MockStreamHandler.inline(
        onListen: (_, sink) {
          keySink = sink;
        },
      ),
    );
    messenger.setMockStreamHandler(
      const EventChannel('dev.cyclescope/notification_actions'),
      MockStreamHandler.inline(
        onListen: (_, sink) {
          actionSink = sink;
        },
      ),
    );
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('dev.cyclescope/keys'),
      null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('dev.cyclescope/notification_actions'),
      null,
    );
    await db.close();
  });

  void awake(num seconds) {
    ticks.advanceSeconds(seconds);
    platform += (seconds * _second).round();
  }

  void sleep(num minutes) => platform += (minutes * _minute).round();

  Future<void> pumpScreen(
    WidgetTester tester, {
    FakePlatformTime? platformTime,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(defaultUnit: TimeUnit.stopwatch),
          ),
          clockProvider.overrideWithValue(clock as Clock),
          deviceFeedbackProvider.overrideWithValue(FakeDeviceFeedback()),
          // The real Android implementations, over mocked channels.
          hardwareKeysProvider.overrideWithValue(AndroidHardwareKeys(clock)),
          recordingNotifierProvider.overrideWithValue(
            AndroidRecordingNotifier(clock),
          ),
          platformTimeProvider.overrideWithValue(
            platformTime ?? FakePlatformTime(),
          ),
        ],
        child: ClockResumeSync(
          child: localizedApp(RecordingScreen(studyId: studyId)),
        ),
      ),
    );
    await settle(tester);
  }

  Future<List<int>> storedDurations(WidgetTester tester) async {
    final stored = await tester.runAsync(
      () => MeasurementRepository(db).listForStudy(studyId),
    );
    return stored!.map((m) => m.durationMicros).toList();
  }

  testWidgets('a notification "next" after sleep stores the time slept', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('startStopButton')));
    await settle(tester);

    awake(2);
    sleep(10);
    actionSink!.success({'action': 'next', 'realtimeMicros': platform});
    await settle(tester);

    expect(await storedDurations(tester), [10 * _minute + 2 * _second]);
  });

  testWidgets('volume up after sleep stores the time slept', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('startStopButton')));
    await settle(tester);

    awake(3);
    sleep(10);
    for (final action in ['down', 'up']) {
      keySink!.success({
        'key': 'up',
        'action': action,
        'ageMicros': 0,
        'realtimeMicros': platform,
      });
    }
    await settle(tester);

    expect(await storedDurations(tester), [10 * _minute + 3 * _second]);
  });

  testWidgets('returning to the foreground shows the time slept', (
    tester,
  ) async {
    final platformTime = FakePlatformTime();
    await pumpScreen(tester, platformTime: platformTime);
    await tester.tap(find.byKey(const Key('startStopButton')));
    await settle(tester);

    awake(1);
    sleep(10);
    platformTime.micros = platform;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(platformTime.reads, greaterThan(0));
    expect(clock.nowMicros(), greaterThanOrEqualTo(platform));
    // Total and step time both include the 10 minutes slept.
    expect(find.text('10:01.000'), findsNWidgets(2));
  });
}

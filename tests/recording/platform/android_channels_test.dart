import 'package:cyclescope/core/clock.dart';
import 'package:cyclescope/recording/domain/key_interpreter.dart';
import 'package:cyclescope/recording/platform/hardware_keys.dart';
import 'package:cyclescope/recording/platform/recording_notifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_platform_time.dart';

const _minute = 60 * 1000000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTicks ticks;
  late MonotonicClock clock;

  setUp(() {
    ticks = FakeTicks();
    clock = MonotonicClock(offsetMicros: _minute, ticks: ticks.call);
  });

  tearDown(() {
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
  });

  /// Delivers [events] on [channel] as soon as Dart listens.
  void mockEvents(String channel, List<Object?> events) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          EventChannel(channel),
          MockStreamHandler.inline(
            onListen: (_, sink) {
              for (final e in events) {
                sink.success(e);
              }
            },
          ),
        );
  }

  test(
    'a key event after sleep syncs the clock and keeps its own time',
    () async {
      // The device slept 10 min; the stopwatch did not count meanwhile.
      final platformNow = _minute + 10 * _minute;
      mockEvents('dev.cyclescope/keys', [
        {
          'key': 'up',
          'action': 'down',
          'ageMicros': 2000,
          'realtimeMicros': platformNow,
        },
      ]);
      final keys = AndroidHardwareKeys(clock);
      final event = await keys.events.first;
      expect(event.key, VolumeKey.up);
      expect(event.down, isTrue);
      expect(event.atMicros, platformNow - 2000);
      expect(clock.nowMicros(), greaterThanOrEqualTo(platformNow));
    },
  );

  test(
    'a key event without platform time uses the clock and its age',
    () async {
      ticks.micros = 5000;
      mockEvents('dev.cyclescope/keys', [
        {'key': 'down', 'action': 'up', 'ageMicros': 1000},
      ]);
      final event = await AndroidHardwareKeys(clock).events.first;
      expect(event.key, VolumeKey.down);
      expect(event.down, isFalse);
      expect(event.atMicros, _minute + 4000);
    },
  );

  test(
    'a notification action carries its platform time and syncs the clock',
    () async {
      final platformNow = _minute + 10 * _minute;
      mockEvents('dev.cyclescope/notification_actions', [
        {'action': 'next', 'realtimeMicros': platformNow},
      ]);
      final notifier = AndroidRecordingNotifier(clock);
      final action = await notifier.timedActions.first;
      expect(action.name, 'next');
      expect(action.atMicros, platformNow);
      expect(clock.nowMicros(), greaterThanOrEqualTo(platformNow));
    },
  );

  test('a plain notification action still arrives, without a time', () async {
    mockEvents('dev.cyclescope/notification_actions', ['toggle']);
    final notifier = AndroidRecordingNotifier(clock);
    final action = await notifier.timedActions.first;
    expect(action.name, 'toggle');
    expect(action.atMicros, isNull);
  });

  test('the plain action stream delivers the names', () async {
    mockEvents('dev.cyclescope/notification_actions', [
      {'action': 'toggle', 'realtimeMicros': 5},
    ]);
    expect(await AndroidRecordingNotifier(clock).actions.first, 'toggle');
  });
}

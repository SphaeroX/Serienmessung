import 'package:flutter/services.dart';

import '../../core/clock.dart';

export '../../core/platform_time.dart' show readElapsedRealtimeMicros;

/// Content of the ongoing "recording" notification.
class RecordingNotice {
  const RecordingNotice({
    required this.title,
    required this.text,
    required this.elapsedMicros,
    required this.running,
    required this.nextLabel,
    required this.toggleLabel,
  });

  final String title;
  final String text;

  /// Time already elapsed in the current step; the notification shows a
  /// live chronometer from here while [running].
  final int elapsedMicros;
  final bool running;
  final String nextLabel;
  final String toggleLabel;
}

/// A notification button press (`next` or `toggle`).
class NotificationAction {
  const NotificationAction(this.name, {this.atMicros});

  final String name;

  /// When the button was pressed, on the monotonic clock; null when the
  /// platform did not tell (then "now" applies).
  final int? atMicros;
}

/// Implemented by notifiers that know when a button was pressed.
abstract interface class TimedNotificationActions {
  Stream<NotificationAction> get timedActions;
}

/// The notification button presses of [notifier], with their time where it
/// is known.
Stream<NotificationAction> notificationActionsOf(RecordingNotifier notifier) =>
    notifier is TimedNotificationActions
    ? (notifier as TimedNotificationActions).timedActions
    : notifier.actions.map(NotificationAction.new);

/// Ongoing notification while a recording is in progress.
abstract class RecordingNotifier {
  Future<void> show(RecordingNotice notice);
  Future<void> hide();

  /// Notification button presses: `next` or `toggle`.
  Stream<String> get actions;
}

/// Used when notifications are switched off in the settings or the platform
/// has no ongoing recording notification.
class SilentRecordingNotifier implements RecordingNotifier {
  const SilentRecordingNotifier();

  @override
  Stream<String> get actions => const Stream.empty();

  @override
  Future<void> show(RecordingNotice notice) async {}

  @override
  Future<void> hide() async {}
}

/// Android implementation (see `MainActivity.kt`).
///
/// Native code sends the platform time of each button press (it keeps
/// counting during device sleep); the notifier syncs [clock] with it, so a
/// step that ran while the device slept gets its full time.
class AndroidRecordingNotifier
    implements RecordingNotifier, TimedNotificationActions {
  AndroidRecordingNotifier([this.clock]);

  final Clock? clock;

  static const _methods = MethodChannel('dev.cyclescope/platform');
  static const _events = EventChannel('dev.cyclescope/notification_actions');

  @override
  late final Stream<NotificationAction> timedActions = _events
      .receiveBroadcastStream()
      .map(_parse)
      .handleError((Object _) {});

  NotificationAction _parse(Object? raw) {
    if (raw is! Map) return NotificationAction(raw as String);
    final name = raw['action'] as String;
    final at = (raw['realtimeMicros'] as num?)?.toInt();
    final c = clock;
    if (at == null || c == null) return NotificationAction(name);
    syncClockTo(c, at);
    return NotificationAction(name, atMicros: at);
  }

  @override
  late final Stream<String> actions = timedActions.map((a) => a.name);

  @override
  Future<void> show(RecordingNotice n) async {
    try {
      await _methods.invokeMethod<void>('showRecordingNotification', {
        'title': n.title,
        'text': n.text,
        'elapsedMs': n.elapsedMicros ~/ 1000,
        'running': n.running,
        'nextLabel': n.nextLabel,
        'toggleLabel': n.toggleLabel,
      });
    } on MissingPluginException {
      // Not on Android.
    }
  }

  @override
  Future<void> hide() async {
    try {
      await _methods.invokeMethod<void>('hideRecordingNotification');
    } on MissingPluginException {
      // Not on Android.
    }
  }
}

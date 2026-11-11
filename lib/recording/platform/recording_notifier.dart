import 'package:flutter/services.dart';

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

/// Ongoing notification while a recording is in progress.
abstract class RecordingNotifier {
  Future<void> show(RecordingNotice notice);
  Future<void> hide();

  /// Notification button presses: `next` or `toggle`.
  Stream<String> get actions;
}

/// Android implementation (see `MainActivity.kt`).
class AndroidRecordingNotifier implements RecordingNotifier {
  static const _methods = MethodChannel('dev.cyclescope/platform');
  static const _events = EventChannel('dev.cyclescope/notification_actions');

  @override
  late final Stream<String> actions = _events
      .receiveBroadcastStream()
      .map((e) => e as String)
      .handleError((Object _) {});

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

/// Reads `SystemClock.elapsedRealtime` (µs) so the monotonic clock survives
/// app restarts. Returns null where unavailable.
Future<int?> readElapsedRealtimeMicros() async {
  try {
    final v = await const MethodChannel('dev.cyclescope/platform')
        .invokeMethod<int>('elapsedRealtimeMicros');
    return v;
  } on Object {
    return null;
  }
}

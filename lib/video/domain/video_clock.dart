import '../../core/clock.dart';

/// Uses the video position as the time base of the recording engine, so
/// durations are video time – independent of playback speed or pauses.
class VideoClock implements Clock {
  VideoClock(this.position);

  /// Current video position in µs.
  final int Function() position;

  @override
  int nowMicros() => position();
}

/// Converts the monotonic time of a key press into the video position at
/// that moment, compensating for event latency while the video plays.
int videoPositionAt({
  required int keyAtMonotonic,
  required int nowMonotonic,
  required int videoNow,
  required bool playing,
  required double speed,
}) {
  if (!playing) return videoNow;
  final age = (nowMonotonic - keyAtMonotonic).clamp(0, 1 << 40);
  final back = (age * speed).round();
  return videoNow - back < 0 ? 0 : videoNow - back;
}

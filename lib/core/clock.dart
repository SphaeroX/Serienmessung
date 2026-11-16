/// Monotonic time source in microseconds.
///
/// All measurement durations are derived from this clock, never from the wall
/// clock, so time zone changes or clock corrections cannot distort results.
abstract class Clock {
  int nowMicros();
}

/// [Clock] backed by a [Stopwatch], shifted by [offsetMicros].
///
/// At startup the offset is set to the platform time that keeps counting
/// during sleep (`SystemClock.elapsedRealtime()` on Android,
/// `CLOCK_MONOTONIC_RAW` on iOS) so timestamps stay comparable across app
/// restarts (not device reboots).
class MonotonicClock implements Clock {
  MonotonicClock({this.offsetMicros = 0}) : _stopwatch = Stopwatch()..start();

  final int offsetMicros;
  final Stopwatch _stopwatch;

  @override
  int nowMicros() => offsetMicros + _stopwatch.elapsedMicroseconds;
}

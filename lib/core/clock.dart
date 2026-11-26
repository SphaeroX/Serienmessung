/// Monotonic time source in microseconds.
///
/// All measurement durations are derived from this clock, never from the wall
/// clock, so time zone changes or clock corrections cannot distort results.
abstract class Clock {
  int nowMicros();
}

/// A [Clock] that can be brought in line with the platform time that keeps
/// counting during device sleep.
abstract interface class SyncableClock implements Clock {
  /// Moves the clock forward to [platformMicros] when it lags behind; never
  /// turns it back.
  void syncTo(int platformMicros);
}

/// Syncs [clock] with [platformMicros] where it supports that (fakes in tests
/// usually do not).
void syncClockTo(Clock clock, int platformMicros) {
  if (clock is SyncableClock) clock.syncTo(platformMicros);
}

/// [Clock] backed by a [Stopwatch], shifted by an offset.
///
/// At startup the offset is set to the platform time that keeps counting
/// during sleep (`SystemClock.elapsedRealtime()` on Android,
/// `CLOCK_MONOTONIC_RAW` on iOS) so timestamps stay comparable across app
/// restarts (not device reboots). A [Stopwatch] stands still while the
/// device sleeps, so the platform layer calls [syncTo] with the platform
/// time on key and notification events and when the app returns to the
/// foreground; the clock then jumps forward by the time slept.
class MonotonicClock implements SyncableClock {
  MonotonicClock({int offsetMicros = 0, int Function()? ticks})
    : _offset = offsetMicros,
      _ticks = ticks ?? (Stopwatch()..start()).elapsedMicrosecondsGetter;

  int _offset;
  final int Function() _ticks;
  int? _last;

  @override
  int nowMicros() {
    var v = _offset + _ticks();
    final last = _last;
    if (last != null && v < last) v = last;
    _last = v;
    return v;
  }

  @override
  void syncTo(int platformMicros) {
    final now = nowMicros();
    if (platformMicros > now) {
      _offset += platformMicros - now;
      _last = platformMicros;
    }
  }
}

extension on Stopwatch {
  int Function() get elapsedMicrosecondsGetter =>
      () => elapsedMicroseconds;
}

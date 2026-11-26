import 'package:cyclescope/core/platform_time.dart';

/// Tick source for `MonotonicClock` that stands still unless the test moves
/// it, like a `Stopwatch` during device sleep.
class FakeTicks {
  int micros = 0;

  int call() => micros;

  void advanceSeconds(num s) => micros += (s * 1000000).round();
}

/// Platform time that keeps counting during sleep, driven by the test.
class FakePlatformTime implements PlatformTime {
  FakePlatformTime([this.micros]);

  int? micros;
  int reads = 0;

  @override
  Future<int?> readMicros() async {
    reads++;
    return micros;
  }
}

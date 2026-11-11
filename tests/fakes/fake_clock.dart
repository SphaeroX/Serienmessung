import 'package:cyclescope/core/clock.dart';

/// Manually advanced clock for deterministic tests.
class FakeClock implements Clock {
  FakeClock([this.micros = 0]);

  int micros;

  @override
  int nowMicros() => micros;

  void advance(Duration d) => micros += d.inMicroseconds;

  void advanceSeconds(num s) => micros += (s * 1000000).round();
}

import 'package:cyclescope/core/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tick source standing in for `Stopwatch`, which stops during device sleep.
class _Ticks {
  int micros = 0;
  int call() => micros;
}

const _minute = 60 * 1000000;

void main() {
  late _Ticks ticks;
  late MonotonicClock clock;

  setUp(() {
    ticks = _Ticks();
    clock = MonotonicClock(offsetMicros: 1000, ticks: ticks.call);
  });

  test('counts from the offset with the tick source', () {
    expect(clock.nowMicros(), 1000);
    ticks.micros = 500;
    expect(clock.nowMicros(), 1500);
  });

  test('a default clock counts forward on its own', () async {
    final real = MonotonicClock(offsetMicros: 7);
    final first = real.nowMicros();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(real.nowMicros(), greaterThan(first));
    expect(first, greaterThanOrEqualTo(7));
  });

  test(
    'a sync with a later platform time jumps forward and keeps counting',
    () {
      ticks.micros = 2 * _minute;
      final before = clock.nowMicros();
      // The device slept for 10 min: the tick source stood still meanwhile.
      clock.syncTo(before + 10 * _minute);
      expect(clock.nowMicros(), before + 10 * _minute);
      ticks.micros += 3000;
      expect(clock.nowMicros(), before + 10 * _minute + 3000);
    },
  );

  test('a sync with an earlier platform time never turns the clock back', () {
    ticks.micros = _minute;
    final before = clock.nowMicros();
    clock.syncTo(before - 5000);
    expect(clock.nowMicros(), before);
    ticks.micros += 100;
    expect(clock.nowMicros(), greaterThanOrEqualTo(before));
  });

  test('the clock never returns less than its last value', () {
    ticks.micros = 1000;
    final first = clock.nowMicros();
    ticks.micros = 400; // A tick source that jitters backwards.
    expect(clock.nowMicros(), first);
  });

  test('syncClockTo syncs a syncable clock and ignores others', () {
    syncClockTo(clock, 50 * _minute);
    expect(clock.nowMicros(), 50 * _minute);
    final plain = _PlainClock();
    syncClockTo(plain, 99); // No error.
    expect(plain.nowMicros(), 3);
  });
}

class _PlainClock implements Clock {
  @override
  int nowMicros() => 3;
}

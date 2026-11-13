import 'package:cyclescope/core/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

void main() {
  group('HM (1/100 min)', () {
    test('one minute is 100 HM', () {
      expect(formatTime(60 * s, TimeUnit.hm), '100 HM');
    });
    test('rounds to whole HM by default', () {
      expect(formatTime(126371000, TimeUnit.hm), '211 HM'); // 210.6
      expect(formatTime(4005000, TimeUnit.hm), '7 HM'); // 6.675
    });
    test('supports decimals', () {
      expect(formatTime(4005000, TimeUnit.hm, decimals: 1), '6.7 HM');
      expect(
        formatTime(4005000, TimeUnit.hm, decimals: 1, locale: 'de'),
        '6,7 HM',
      );
    });
    test('zero', () => expect(formatTime(0, TimeUnit.hm), '0 HM'));
  });

  group('stopwatch mm:ss.SSS', () {
    test('below one second', () {
      expect(formatTime(371000, TimeUnit.stopwatch), '00:00.371');
    });
    test('minutes and seconds', () {
      expect(formatTime(126371000, TimeUnit.stopwatch), '02:06.371');
    });
    test('above one hour', () {
      expect(formatTime(3726371000, TimeUnit.stopwatch), '1:02:06.371');
    });
  });

  group('seconds and TMU', () {
    test('seconds with two decimals', () {
      expect(formatTime(1234567, TimeUnit.seconds), '1.23 s');
      expect(formatTime(1234567, TimeUnit.seconds, locale: 'de'), '1,23 s');
    });
    test('1 s = 27.78 TMU, rounded to whole TMU', () {
      expect(formatTime(1 * s, TimeUnit.tmu), '28 TMU');
      expect(formatTime(36000, TimeUnit.tmu), '1 TMU');
      expect(formatTime(1 * s, TimeUnit.tmu, decimals: 2), '27.78 TMU');
    });
  });

  test('value conversion', () {
    expect(TimeUnit.hm.fromMicros(60 * s), 100);
    expect(TimeUnit.seconds.fromMicros(1500000), 1.5);
    expect(TimeUnit.tmu.fromMicros(36000), 1);
  });

  test('deviations carry a sign and a relative change', () {
    expect(formatDelta(5000000, TimeUnit.seconds), '+5.00 s');
    expect(formatDelta(-3000000, TimeUnit.seconds), '-3.00 s');
    expect(formatDelta(0, TimeUnit.seconds), '±0.00 s');
    expect(formatDelta(1500000, TimeUnit.stopwatch), '+00:01.500');
    expect(formatDelta(-600000, TimeUnit.hm, decimals: 1), '-1.0 HM');
    expect(
      formatDelta(6000, TimeUnit.hm, decimals: 2, locale: 'de'),
      '+0,01 HM',
    );
    expect(formatRatioDelta(0.05), '+5.0 %');
    expect(formatRatioDelta(-0.125, locale: 'de'), '-12,5 %');
  });
}

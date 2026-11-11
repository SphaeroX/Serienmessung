import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('median for odd and even counts', () {
    expect(Stats.of([3, 1, 2]).median, 2);
    expect(Stats.of([4, 1, 3, 2]).median, 2.5);
  });

  test('mean, min, max, sum, n', () {
    final s = Stats.of([10, 11, 12, 13, 40]);
    expect(s.n, 5);
    expect(s.sum, 86);
    expect(s.mean, closeTo(17.2, 1e-9));
    expect((s.min, s.max), (10, 40));
  });

  test('sample standard deviation and coefficient of variation', () {
    final s = Stats.of([10, 11, 12, 13, 40]);
    expect(s.stdDev, closeTo(12.79453, 1e-5));
    expect(s.cv, closeTo(12.79453 / 17.2, 1e-5));
  });

  test('quartiles use linear interpolation (Excel QUARTILE.INC)', () {
    final s = Stats.of([10, 11, 12, 13, 40]);
    expect((s.q1, s.q3, s.iqr), (11, 13, 2));
    final t = Stats.of([1, 2, 3, 4]);
    expect(t.q1, closeTo(1.75, 1e-9));
    expect(t.q3, closeTo(3.25, 1e-9));
  });

  test('IQR filter removes exactly the clear outlier', () {
    final f = iqrFilter([10, 11, 12, 13, 40]);
    expect(f.kept, [10, 11, 12, 13]);
    expect(f.removed, [40]);
  });

  test('cycle time per method', () {
    final v = [10, 11, 12, 13, 40];
    expect(CycleTimeMethod.mean.apply(v), closeTo(17.2, 1e-9));
    expect(CycleTimeMethod.median.apply(v), 12);
    expect(CycleTimeMethod.iqr.apply(v), 11.5);
  });

  test('edge cases: empty, one and two values', () {
    final e = Stats.of([]);
    expect((e.n, e.mean, e.median, e.stdDev), (0, 0, 0, 0));
    final one = Stats.of([5]);
    expect((one.mean, one.median, one.stdDev, one.iqr), (5, 5, 0, 0));
    final two = Stats.of([4, 6]);
    expect(two.median, 5);
    expect(two.stdDev, closeTo(1.41421, 1e-5));
    expect(CycleTimeMethod.iqr.apply([]), 0);
  });
}

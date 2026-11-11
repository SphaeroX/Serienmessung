import 'dart:math' as math;

/// Descriptive statistics of a list of values (e.g. durations in µs).
class Stats {
  const Stats._({
    required this.n,
    required this.sum,
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    required this.stdDev,
    required this.q1,
    required this.q3,
  });

  /// Computes all figures. Empty input yields zeros.
  factory Stats.of(Iterable<num> values) {
    final v = values.map((e) => e.toDouble()).toList()..sort();
    if (v.isEmpty) {
      return const Stats._(
        n: 0,
        sum: 0,
        mean: 0,
        median: 0,
        min: 0,
        max: 0,
        stdDev: 0,
        q1: 0,
        q3: 0,
      );
    }
    final n = v.length;
    final sum = v.fold<double>(0, (a, b) => a + b);
    final mean = sum / n;
    final variance = n < 2
        ? 0.0
        : v.fold<double>(0, (a, b) => a + (b - mean) * (b - mean)) / (n - 1);
    return Stats._(
      n: n,
      sum: sum,
      mean: mean,
      median: quantile(v, 0.5),
      min: v.first,
      max: v.last,
      stdDev: math.sqrt(variance),
      q1: quantile(v, 0.25),
      q3: quantile(v, 0.75),
    );
  }

  final int n;
  final double sum;
  final double mean;
  final double median;
  final double min;
  final double max;

  /// Sample standard deviation (n − 1).
  final double stdDev;
  final double q1;
  final double q3;

  double get iqr => q3 - q1;

  /// Coefficient of variation (stdDev / mean), 0 if mean is 0.
  double get cv => mean == 0 ? 0 : stdDev / mean;
}

/// Quantile with linear interpolation between closest ranks
/// (same as Excel `QUARTILE.INC` / `PERCENTILE.INC`). [sorted] must be sorted.
double quantile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final pos = (sorted.length - 1) * p;
  final lo = pos.floor();
  final hi = pos.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

/// Values split into kept and removed by the 1.5 × IQR rule.
class IqrFilterResult<T extends num> {
  const IqrFilterResult(this.kept, this.removed);

  final List<T> kept;
  final List<T> removed;
}

/// Removes values outside [Q1 − 1.5·IQR, Q3 + 1.5·IQR]. Order is preserved.
IqrFilterResult<T> iqrFilter<T extends num>(List<T> values) {
  if (values.length < 4) return IqrFilterResult([...values], <T>[]);
  final s = Stats.of(values);
  final lo = s.q1 - 1.5 * s.iqr;
  final hi = s.q3 + 1.5 * s.iqr;
  final kept = <T>[];
  final removed = <T>[];
  for (final v in values) {
    (v < lo || v > hi ? removed : kept).add(v);
  }
  return IqrFilterResult(kept, removed);
}

/// How the "real" cycle time is derived from the recorded cycles.
enum CycleTimeMethod {
  /// Arithmetic mean of all complete cycles.
  mean,

  /// Median – robust against single disturbed cycles.
  median,

  /// Mean after removing outliers by the 1.5 × IQR rule.
  iqr;

  double apply(List<num> values) => switch (this) {
    CycleTimeMethod.mean => Stats.of(values).mean,
    CycleTimeMethod.median => Stats.of(values).median,
    CycleTimeMethod.iqr => Stats.of(iqrFilter(values).kept).mean,
  };

  static CycleTimeMethod parse(String? v) => CycleTimeMethod.values.firstWhere(
    (m) => m.name == v,
    orElse: () => CycleTimeMethod.median,
  );
}

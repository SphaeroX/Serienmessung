import 'package:intl/intl.dart';

/// Display units for times. Times are always stored in microseconds.
enum TimeUnit {
  /// Hundredths of a minute (REFA). 1 HM = 0.6 s.
  hm,

  /// Seconds.
  seconds,

  /// Stopwatch format mm:ss.SSS.
  stopwatch,

  /// MTM time measurement unit. 1 TMU = 0.036 s.
  tmu;

  /// Numeric value in this unit (stopwatch → seconds).
  double fromMicros(int micros) => switch (this) {
    TimeUnit.hm => micros / 600000,
    TimeUnit.seconds || TimeUnit.stopwatch => micros / 1000000,
    TimeUnit.tmu => micros / 36000,
  };

  /// Short unit label used in exports and table headers.
  String get label => switch (this) {
    TimeUnit.hm => 'HM',
    TimeUnit.seconds => 's',
    TimeUnit.stopwatch => 'mm:ss.SSS',
    TimeUnit.tmu => 'TMU',
  };

  static TimeUnit parse(String? v) =>
      TimeUnit.values.firstWhere((u) => u.name == v, orElse: () => TimeUnit.hm);
}

/// Formats [micros] for display in [unit].
///
/// [decimals] defaults to 0 for HM/TMU and 2 for seconds; ignored for the
/// stopwatch format. [locale] controls the decimal separator.
String formatTime(
  int micros,
  TimeUnit unit, {
  int? decimals,
  String locale = 'en',
}) {
  if (unit == TimeUnit.stopwatch) return _stopwatch(micros);
  final d = decimals ?? (unit == TimeUnit.seconds ? 2 : 0);
  final value = unit.fromMicros(micros);
  final number = formatNumber(value, d, locale: locale);
  return '$number ${unit.label}';
}

/// Formats a deviation with its sign ("+5.00 s", "-3.00 s", "±0.00 s").
String formatDelta(
  num micros,
  TimeUnit unit, {
  int? decimals,
  String locale = 'en',
}) {
  final rounded = micros.round();
  final body = formatTime(
    rounded.abs(),
    unit,
    decimals: decimals,
    locale: locale,
  );
  final sign = rounded > 0
      ? '+'
      : rounded < 0
      ? '-'
      : '±';
  return '$sign$body';
}

/// Formats a relative change (0.05 → "+5.0 %").
String formatRatioDelta(double ratio, {String locale = 'en'}) {
  final sign = ratio > 0
      ? '+'
      : ratio < 0
      ? '-'
      : '±';
  return '$sign${formatNumber(ratio.abs() * 100, 1, locale: locale)} %';
}

/// Long durations for people: "45 s", "12 min 30 s", "5 h 50 min" (the two
/// largest parts, rounded down to whole seconds).
String formatDuration(int micros) {
  final total = micros ~/ 1000000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final sec = total % 60;
  if (h > 0) return m == 0 ? '$h h' : '$h h $m min';
  if (m > 0) return sec == 0 ? '$m min' : '$m min $sec s';
  return '$sec s';
}

/// Parses a typed time (decimal point or comma) in [unit] to microseconds;
/// the stopwatch format is typed as seconds. Null unless it is a number of
/// at least one microsecond.
int? parseTimeInput(String text, TimeUnit unit) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value.isNaN || value <= 0) return null;
  final perUnit = switch (unit) {
    TimeUnit.hm => 600000,
    TimeUnit.tmu => 36000,
    TimeUnit.seconds || TimeUnit.stopwatch => 1000000,
  };
  final micros = (value * perUnit).round();
  return micros <= 0 ? null : micros;
}

/// Unit label for typed times (the stopwatch format is typed as seconds).
String inputUnitLabel(TimeUnit unit) =>
    unit == TimeUnit.stopwatch ? TimeUnit.seconds.label : unit.label;

/// Formats a plain number with fixed [decimals] for [locale].
String formatNumber(double value, int decimals, {String locale = 'en'}) {
  final f = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: decimals,
  )..turnOffGrouping();
  return f.format(value);
}

String _stopwatch(int micros) {
  final negative = micros < 0;
  var ms = (micros.abs() / 1000).round();
  final h = ms ~/ 3600000;
  ms -= h * 3600000;
  final m = ms ~/ 60000;
  ms -= m * 60000;
  final sec = ms ~/ 1000;
  ms -= sec * 1000;
  String two(int v) => v.toString().padLeft(2, '0');
  final body = '${two(m)}:${two(sec)}.${ms.toString().padLeft(3, '0')}';
  return '${negative ? '-' : ''}${h > 0 ? '$h:' : ''}$body';
}

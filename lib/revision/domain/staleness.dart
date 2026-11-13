/// Whether the last measurement is older than [days] days (strictly), so a
/// new measurement should be offered. [days] 0 switches the check off;
/// without a measurement nothing is stale.
bool isMeasurementStale({
  required DateTime? lastMeasured,
  required DateTime now,
  required int days,
}) =>
    days > 0 &&
    lastMeasured != null &&
    now.difference(lastMeasured) > Duration(days: days);

/// Whole days between [from] and [now].
int daysSince(DateTime from, DateTime now) => now.difference(from).inDays;

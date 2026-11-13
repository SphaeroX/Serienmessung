import 'package:cyclescope/revision/domain/staleness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 3, 20, 12);

  test('older than the threshold is stale', () {
    expect(
      isMeasurementStale(
        lastMeasured: DateTime(2026, 3, 10, 11),
        now: now,
        days: 10,
      ),
      isTrue,
    );
  });

  test('exactly at or below the threshold is not stale', () {
    expect(
      isMeasurementStale(
        lastMeasured: DateTime(2026, 3, 10, 12),
        now: now,
        days: 10,
      ),
      isFalse,
    );
    expect(
      isMeasurementStale(
        lastMeasured: DateTime(2026, 3, 19),
        now: now,
        days: 10,
      ),
      isFalse,
    );
  });

  test('without times or with the check switched off nothing is stale', () {
    expect(isMeasurementStale(lastMeasured: null, now: now, days: 10), isFalse);
    expect(
      isMeasurementStale(lastMeasured: DateTime(2020), now: now, days: 0),
      isFalse,
    );
  });

  test('whole days since the last measurement', () {
    expect(daysSince(DateTime(2026, 3, 10, 13), now), 9);
    expect(daysSince(DateTime(2025, 3, 20, 12), now), 365);
  });
}

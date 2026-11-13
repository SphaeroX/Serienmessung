import 'package:cyclescope/core/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a typed time below one microsecond is no valid time', () {
    expect(parseTimeInput('0.0000001', TimeUnit.seconds), isNull);
    expect(parseTimeInput('0.0000004', TimeUnit.hm), isNull);
    expect(parseTimeInput('0.00001', TimeUnit.tmu), isNull);
  });

  test('the smallest valid time is one microsecond', () {
    expect(parseTimeInput('0.000001', TimeUnit.seconds), 1);
  });
}

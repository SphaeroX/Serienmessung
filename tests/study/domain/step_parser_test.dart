import 'package:cyclescope/study/domain/step_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one line is one step', () {
    expect(parseSteps('Pick part\nInsert\nPress'), [
      'Pick part',
      'Insert',
      'Press',
    ]);
  });

  test('ignores empty lines and trims whitespace', () {
    expect(parseSteps('  Pick part  \n\n   \nInsert\n'), [
      'Pick part',
      'Insert',
    ]);
  });

  test('handles windows line breaks', () {
    expect(parseSteps('A\r\nB\r\n'), ['A', 'B']);
  });

  test('empty input gives empty list', () {
    expect(parseSteps(''), isEmpty);
    expect(parseSteps('  \n \n'), isEmpty);
  });

  test('stepsToText joins steps with newlines', () {
    expect(stepsToText(['A', 'B']), 'A\nB');
  });
}

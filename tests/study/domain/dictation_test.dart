import 'package:cyclescope/study/domain/dictation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty text area gets the dictated line', () {
    final e = insertDictatedLine('', 0, ' Teil einlegen ');
    expect(e.text, 'Teil einlegen');
    expect(e.cursor, 13);
  });

  test('cursor at the end of the last line starts a new line', () {
    final e = insertDictatedLine('Pick', 4, 'Place');
    expect(e.text, 'Pick\nPlace');
    expect(e.cursor, 10);
  });

  test('cursor after a trailing line break needs no extra break', () {
    expect(insertDictatedLine('Pick\n', 5, 'Place').text, 'Pick\nPlace');
  });

  test('cursor in the middle of a line splits it into own lines', () {
    final e = insertDictatedLine('AB', 1, 'X');
    expect(e.text, 'A\nX\nB');
    expect(e.cursor, 3);
  });

  test('cursor between lines inserts a line in between', () {
    expect(insertDictatedLine('A\nB', 2, 'X').text, 'A\nX\nB');
  });

  test('invalid cursor appends; empty dictation changes nothing', () {
    expect(insertDictatedLine('A', -1, 'B').text, 'A\nB');
    expect(insertDictatedLine('A', 1, '   ').text, 'A');
  });

  test('single-line fields get the words appended', () {
    expect(appendDictatedWords('', 'Press').text, 'Press');
    expect(appendDictatedWords('Press ', 'part').text, 'Press part');
  });
}

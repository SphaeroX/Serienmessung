import 'package:cyclescope/group/domain/group_member.dart';
import 'package:cyclescope/group/domain/group_tree.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

var _id = 0;

StudyMember study(
  String name, {
  bool parallel = false,
  bool loader = false,
  bool wait = false,
}) => StudyMember(
  Study(
    id: ++_id,
    name: name,
    description: '',
    mode: StudyMode.simple,
    createdAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
    parallel: parallel,
    cellLoader: loader,
    waitForSlowest: wait,
    bufferCapacity: name.startsWith('Buf') ? 3 : 0,
  ),
);

StudyGroup group(int id, String name) =>
    StudyGroup(id: id, name: name, description: '', createdAt: DateTime(2026));

AreaMember area(int id, String name) => AreaMember(group(id, name));

void main() {
  test('study, area, study in line order with the area path', () {
    final line = flattenGroup(1, {
      1: [study('A'), area(2, 'Press'), study('C')],
      2: [study('P1'), study('P2', parallel: true)],
    });
    expect(
      [for (final e in line.entries) e.study.name],
      ['A', 'P1', 'P2', 'C'],
    );
    expect(
      [for (final e in line.entries) e.path.map((g) => g.name)],
      [
        <String>[],
        ['Press'],
        ['Press'],
        <String>[],
      ],
    );
    expect(line.entries[2].study.parallel, isTrue);
    expect(
      [for (final a in line.areas) (a.group.name, a.start, a.end)],
      [('Press', 1, 3)],
    );
  });

  test('an area inside an area is one area of the opened group', () {
    final line = flattenGroup(1, {
      1: [area(2, 'Hall'), study('Z')],
      2: [study('H'), area(3, 'Cell')],
      3: [study('C1'), study('C2')],
    });
    expect(
      [for (final e in line.entries) e.study.name],
      ['H', 'C1', 'C2', 'Z'],
    );
    expect(line.entries[1].path.map((g) => g.name), ['Hall', 'Cell']);
    expect(
      [for (final a in line.areas) (a.group.name, a.start, a.end)],
      [('Hall', 0, 3)],
    );
  });

  test('an empty area adds nothing but is listed', () {
    final line = flattenGroup(1, {
      1: [study('A'), area(2, 'Empty'), study('B')],
      2: [],
    });
    expect([for (final e in line.entries) e.study.name], ['A', 'B']);
    expect(
      [for (final a in line.areas) (a.group.name, a.start, a.end)],
      [('Empty', 1, 1)],
    );
  });

  test('a parallel study at the start of an area or behind one is a station '
      'of its own', () {
    final line = flattenGroup(1, {
      1: [study('A'), area(2, 'X'), study('B', parallel: true, loader: true)],
      2: [study('X1', parallel: true, loader: true), study('X2')],
    });
    expect(
      [for (final e in line.entries) e.study.parallel],
      [false, false, false, false],
    );
    expect(
      [for (final e in line.entries) e.study.cellLoader],
      [false, false, false, false],
    );
  });

  test('the other line fields stay as they are', () {
    final line = flattenGroup(1, {
      1: [study('A', wait: true), study('A2', parallel: true), study('Buf')],
    });
    expect(line.entries[0].study.waitForSlowest, isTrue);
    expect(line.entries[1].study.parallel, isTrue);
    expect(line.entries[2].study.bufferCapacity, 3);
  });

  test('a cycle in the tree is an error, not an endless loop', () {
    expect(
      () => flattenGroup(1, {
        1: [area(2, 'X')],
        2: [area(1, 'Root')],
      }),
      throwsA(isA<GroupCycleException>()),
    );
  });

  test('a group without members is an empty line', () {
    final line = flattenGroup(1, {1: []});
    expect(line.entries, isEmpty);
    expect(line.areas, isEmpty);
  });
}

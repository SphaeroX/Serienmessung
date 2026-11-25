import 'package:cyclescope/group/domain/area_selection.dart';
import 'package:cyclescope/group/domain/group_member.dart';
import 'package:flutter_test/flutter_test.dart';

const t = true;
const f = false;

MemberKey st(int id) => MemberKey.study(id);
MemberKey ar(int id) => MemberKey.area(id);

void main() {
  // 1, 2a/2b (parallel), [X], 3, 4a/4b (loader cell: 4b is a loader)
  final order = [st(1), st(2), st(3), ar(9), st(4), st(5), st(6)];
  final flags = [f, f, t, f, f, f, t];

  test('a machine of a parallel station takes its whole station', () {
    expect(expandToStations(order, flags, {st(3)}), {st(2), st(3)});
  });

  test('a loader takes its whole cell', () {
    expect(expandToStations(order, flags, {st(6)}), {st(5), st(6)});
  });

  test('areas and single stations stay as they are', () {
    expect(expandToStations(order, flags, {ar(9), st(4)}), {ar(9), st(4)});
  });

  test('contiguous selections', () {
    expect(isContiguous(order, {st(2), st(3), ar(9)}), isTrue);
    expect(isContiguous(order, {st(1)}), isTrue);
    expect(isContiguous(order, {st(1), ar(9)}), isFalse);
    expect(isContiguous(order, const {}), isFalse);
  });

  test('a gap after expanding is still a gap', () {
    final picked = expandToStations(order, flags, {st(1), st(5)});
    expect(picked, {st(1), st(5), st(6)});
    expect(isContiguous(order, picked), isFalse);
  });
}

import 'package:cyclescope/group/domain/stations.dart';
import 'package:flutter_test/flutter_test.dart';

const t = true;
const f = false;

void main() {
  group('stationFlags', () {
    test('an area is never parallel and nobody is parallel to it', () {
      // A, [area](par), B(par), C(par)
      expect(stationFlags([f, t, t, t], [f, t, f, f]), [f, f, f, t]);
    });

    test('without areas the flags stay, except for the first member', () {
      expect(stationFlags([t, t, f, t], [f, f, f, f]), [f, t, f, t]);
    });

    test('an area is a station of its own in stationGroups', () {
      final flags = stationFlags([f, t, f, t], [f, f, t, f]);
      expect(stationGroups(flags), [
        [0, 1],
        [2],
        [3],
      ]);
    });
  });

  group('parallelAfterMove with areas', () {
    test('an area dropped inside a station splits it', () {
      // A, B(par), [X] -> A, [X], B
      final r = parallelAfterMove([f, t, f], 2, 1, isArea: [f, f, t]);
      expect(r.parallel, [f, f, f]);
      expect(r.newHead, isNull);
      expect(r.split, 2);
    });

    test('an area dropped inside a long station splits it there', () {
      // A, B(par), C(par), [X] -> A, B, [X], C
      final r = parallelAfterMove([f, t, t, f], 3, 2, isArea: [f, f, f, t]);
      expect(r.parallel, [f, t, f, f]);
      expect(r.split, 3);
    });

    test('an area moved between stations splits nothing', () {
      // A, B, [X] -> A, [X], B
      final r = parallelAfterMove([f, f, f], 2, 1, isArea: [f, f, t]);
      expect(r.parallel, [f, f, f]);
      expect(r.split, isNull);
      expect(r.newHead, isNull);
    });

    test('a study dropped right behind an area is a station of its own', () {
      // [X], A, B(par), C -> [X], C, A, B: C is behind the area.
      final r = parallelAfterMove([f, f, t, f], 3, 1, isArea: [t, f, f, f]);
      expect(r.parallel, [f, f, f, t]);
      expect(r.newHead, isNull);
    });

    test('a study dropped between an area and a station keeps it apart', () {
      // A, [X], B, C(par) -> [X], A, B, C: A lands before B (head), so it
      // is a station of its own and B keeps its station.
      final r = parallelAfterMove([f, f, f, t], 0, 1, isArea: [f, t, f, f]);
      expect(r.parallel, [f, f, f, t]);
    });

    test('a head behind an area moving away hands its station over', () {
      // [X], A, B(par), C -> [X], B, C, A
      final r = parallelAfterMove([f, f, t, f], 1, 3, isArea: [t, f, f, f]);
      expect(r.parallel, [f, f, f, f]);
      expect(r.newHead, 1);
    });

    test('moving a study over an area keeps the other stations', () {
      // A, B(par), [X], C, D(par), E -> A, B(par), [X], C, D(par), E with
      // E moved to the front: E, A, B(par), [X], C, D(par)
      final r = parallelAfterMove(
        [f, t, f, f, t, f],
        5,
        0,
        isArea: [f, f, t, f, f, f],
      );
      expect(r.parallel, [f, f, t, f, f, t]);
      expect(r.newHead, isNull);
      expect(r.split, isNull);
    });

    test('without isArea the result has no split', () {
      final r = parallelAfterMove([f, f, t], 1, 0);
      expect(r.split, isNull);
    });
  });
}

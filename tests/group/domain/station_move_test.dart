import 'package:cyclescope/group/domain/stations.dart';
import 'package:flutter_test/flutter_test.dart';

const t = true;
const f = false;

void main() {
  group('parallelAfterMove', () {
    test('a head that moves away leaves its station to the next machine', () {
      // A, B, C(par) -> B, A, C: C must not become parallel to A.
      final r = parallelAfterMove([f, f, t], 1, 0);
      expect(r.parallel, [f, f, f]);
      expect(r.newHead, 2);
    });

    test('a machine dropped inside a station joins it', () {
      // A, B, C(par), D -> A, B, D, C
      final r = parallelAfterMove([f, f, t, f], 3, 2);
      expect(r.parallel, [f, f, t, t]);
      expect(r.newHead, isNull);
    });

    test('a machine moved to the edge of its station leaves it', () {
      // A, B, D(par), C(par) -> A, D, B, C
      expect(parallelAfterMove([f, f, t, t], 2, 1).parallel, [f, f, f, t]);
      // A, B, C(par), D -> A, B, D, C
      expect(parallelAfterMove([f, f, t, f], 2, 3).parallel, [f, f, f, f]);
    });

    test('a head moved inside its own station stays in it', () {
      // A, B, C(par), D(par) -> A, C, B, D
      final r = parallelAfterMove([f, f, t, t], 1, 2);
      expect(r.parallel, [f, f, t, t]);
      expect(r.newHead, 1);
    });

    test('the first member moved into the station behind it joins', () {
      // A, B, C(par) -> B, A, C
      final r = parallelAfterMove([f, f, t], 0, 1);
      expect(r.parallel, [f, t, t]);
      expect(r.newHead, isNull);
    });

    test('the first member with parallel machines moved to the end', () {
      // A, B(par), C -> B, C, A
      final r = parallelAfterMove([f, t, f], 0, 2);
      expect(r.parallel, [f, f, f]);
      expect(r.newHead, 0);
    });

    test('a stale flag of the first member is dropped', () {
      expect(parallelAfterMove([t, f], 1, 0).parallel, [f, f]);
    });

    test('not moving keeps the stations', () {
      final r = parallelAfterMove([f, f, t], 2, 2);
      expect(r.parallel, [f, f, t]);
      expect(r.newHead, isNull);
    });

    test('serial members just change places', () {
      expect(parallelAfterMove([f, f, f], 0, 2).parallel, [f, f, f]);
    });
  });
}

import 'package:cyclescope/group/domain/stations.dart';
import 'package:flutter_test/flutter_test.dart';

const t = true;
const f = false;

void main() {
  group('stationMoveOrder', () {
    test('a head dragged before the station above takes its station', () {
      // A, B, C(par), D(par) -> B, C, D, A (B dragged to the top)
      expect(stationMoveOrder([f, f, t, t], 1, 0), [1, 2, 3, 0]);
    });

    test('a head dragged below the station after takes its station', () {
      // A, B, C(par), D -> A, D, B, C (B dropped behind D)
      expect(stationMoveOrder([f, f, t, f], 1, 3), [0, 3, 1, 2]);
    });

    test('a drop inside another station snaps to its edge', () {
      // A, B(par), C, D(par): C dragged between A and B -> C, D, A, B
      expect(stationMoveOrder([f, t, f, t], 2, 1), [2, 3, 0, 1]);
      // A, B(par), C, D(par), E: A dragged between C and D -> C, D, A, B, E
      expect(stationMoveOrder([f, t, f, t, f], 0, 2), [2, 3, 0, 1, 4]);
    });

    test('a head moved inside its own station is no station move', () {
      expect(stationMoveOrder([f, f, t, t], 1, 2), isNull);
      expect(stationMoveOrder([f, f, t, t], 1, 3), isNull);
    });

    test('a single machine or a parallel machine is no station move', () {
      expect(stationMoveOrder([f, f, t], 0, 2), isNull);
      expect(stationMoveOrder([f, f, t], 2, 0), isNull);
    });
  });
}

import 'package:cyclescope/group/domain/failure_risk.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parallel_line_test.dart' show machine, s;

/// A machine; [waits] on the first machine of a station makes the station
/// wait for its slowest machine.
LineStationInput m(
  String name,
  double seconds, {
  bool parallel = false,
  bool waits = false,
  double? previous,
}) => LineStationInput(
  name: name,
  mode: StudyMode.simple,
  current: machine(seconds),
  previous: previous == null ? null : machine(previous),
  parallel: parallel,
  waitForSlowest: waits,
);

void main() {
  group('station that waits for its slowest machine', () {
    test('its cycle time is the slowest machine, not the added rates', () {
      // Five parts are made in parallel and joined to one afterwards.
      final line = LineAnalysis.of([
        m('Saw', 12),
        m('Part 1', 30, waits: true),
        m('Part 2', 40, parallel: true),
        m('Part 3', 50, parallel: true),
        m('Part 4', 35, parallel: true),
        m('Part 5', 45, parallel: true),
      ]);
      expect(line.stations, hasLength(2));
      final parts = line.stations[1];
      expect(parts.isParallel, isTrue);
      expect(parts.waitsForSlowest, isTrue);
      expect(parts.cycleTime, closeTo(50 * s, 1));
      // A part is done when the slowest machine is done.
      expect(parts.leadTime, closeTo(50 * s, 1));
      expect(parts.isBottleneck, isTrue);
      expect(line.lineCycleTime, closeTo(50 * s, 1));
      expect(line.totalTime, closeTo(62 * s, 1));
      expect(line.leadTime, closeTo(62 * s, 1));
      expect(line.outputPerHour, closeTo(72, 1e-6));
      expect(line.stations[0].waitsForSlowest, isFalse);
    });

    test('without the option the same machines add their rates', () {
      final line = LineAnalysis.of([m('A', 20), m('B', 30, parallel: true)]);
      expect(line.stations.single.waitsForSlowest, isFalse);
      expect(line.stations.single.cycleTime, closeTo(12 * s, 1));
    });

    test('the option counts on the first machine of the station only', () {
      final line = LineAnalysis.of([
        m('A', 20),
        m('B', 30, parallel: true, waits: true),
      ]);
      expect(line.stations.single.waitsForSlowest, isFalse);
      expect(line.stations.single.cycleTime, closeTo(12 * s, 1));
    });

    test('a single machine has nothing to wait for', () {
      final line = LineAnalysis.of([m('A', 20, waits: true), m('B', 30)]);
      expect(line.stations[0].waitsForSlowest, isFalse);
      expect(line.stations[0].cycleTime, closeTo(20 * s, 1));
    });

    test('a loader cell is no waiting station', () {
      final line = LineAnalysis.of([
        m('Lathe', 60, waits: true),
        LineStationInput(
          name: 'Loader',
          mode: StudyMode.simple,
          current: machine(20),
          parallel: true,
          cellLoader: true,
        ),
      ]);
      expect(line.stations.single.isCell, isTrue);
      expect(line.stations.single.waitsForSlowest, isFalse);
    });

    test('the previous time is the slowest previous machine', () {
      final line = LineAnalysis.of([
        m('A', 20, waits: true, previous: 18),
        m('B', 30, parallel: true, previous: 33),
        m('C', 10, waits: true, previous: 9),
        m('D', 10, parallel: true),
      ]);
      expect(line.stations[0].previousCycleTime, closeTo(33 * s, 1));
      expect(line.stations[1].previousCycleTime, isNull);
    });
  });

  group('failure risk of a waiting station', () {
    test('every machine stops the line', () {
      final line = LineAnalysis.of([
        m('Part 1', 30, waits: true),
        m('Part 2', 40, parallel: true),
        m('Press 1', 80),
        m('Press 2', 80, parallel: true),
      ]);
      // The waiting station needs 40 s, the presses 40 s together.
      final risk = FailureRisk.of(line);
      expect(risk.baseOutput, closeTo(90, 1e-6));
      for (final name in ['Part 1', 'Part 2']) {
        final f = risk.failures.firstWhere((x) => x.machine == name);
        expect(f.standstill, isTrue, reason: name);
        expect(f.loss, 1, reason: name);
      }
      final press = risk.failures.firstWhere((x) => x.machine == 'Press 1');
      expect(press.standstill, isFalse);
      expect(press.outputAfter, closeTo(45, 1e-6));
      // The waiting station has no spare machine; it is listed once.
      expect(risk.singlePoints.map((st) => st.name), ['Part 1 / Part 2']);
    });

    test('another failure leaves the waiting station at its slowest pace', () {
      final line = LineAnalysis.of([
        m('Part 1', 30, waits: true),
        m('Part 2', 40, parallel: true),
        m('Press 1', 30),
        m('Press 2', 30, parallel: true),
      ]);
      final press = FailureRisk.of(line).failures
          .firstWhere((x) => x.machine == 'Press 1');
      // One press left (30 s) is faster than the waiting station (40 s).
      expect(press.loss, 0);
      expect(press.outputAfter, closeTo(90, 1e-6));
    });
  });
}

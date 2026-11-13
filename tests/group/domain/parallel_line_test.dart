import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/group/domain/failure_risk.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

var _id = 0;

/// A machine measured as a simple study: one lap of [seconds].
StudyAnalysis machine(double seconds) => StudyAnalysis.compute(
  measurements: [
    Measurement(
      id: ++_id,
      studyId: 1,
      cycle: 1,
      stepId: null,
      kind: MeasurementKind.normal,
      startMicros: 0,
      endMicros: (seconds * s).round(),
      durationMicros: (seconds * s).round(),
    ),
  ],
  steps: const [],
  mode: StudyMode.simple,
  method: CycleTimeMethod.median,
);

LineStationInput m(
  String name,
  double seconds, {
  bool parallel = false,
  double? previous,
}) => LineStationInput(
  name: name,
  mode: StudyMode.simple,
  current: machine(seconds),
  previous: previous == null ? null : machine(previous),
  parallel: parallel,
);

void main() {
  group('line with parallel machines', () {
    test('parallel machines form one station with their capacities added', () {
      final line = LineAnalysis.of([
        m('Saw', 12),
        m('Press 1', 40),
        m('Press 2', 40, parallel: true),
        m('Press 3', 40, parallel: true),
        m('Press 4', 40, parallel: true),
      ]);
      expect(line.stations, hasLength(2));
      final press = line.stations[1];
      expect(press.position, 1);
      expect(press.machines.map((x) => x.name), [
        'Press 1',
        'Press 2',
        'Press 3',
        'Press 4',
      ]);
      expect(press.cycleTime, closeTo(10 * s, 1));
      // A part passes one press: 40 s.
      expect(press.leadTime, closeTo(40 * s, 1));
      expect(press.isParallel, isTrue);
      expect(line.stations[0].isParallel, isFalse);
      expect(line.lineCycleTime, closeTo(12 * s, 1));
      expect(line.bottleneck!.name, 'Saw');
      expect(line.totalTime, closeTo(22 * s, 1));
      expect(line.leadTime, closeTo(52 * s, 1));
      expect(line.outputPerHour, closeTo(300, 1e-6));
    });

    test('different machines add their rates', () {
      final line = LineAnalysis.of([m('A', 20), m('B', 30, parallel: true)]);
      // 1 / (1/20 + 1/30) = 12 s.
      expect(line.stations.single.cycleTime, closeTo(12 * s, 1));
    });

    test('the parallel flag of the first member is ignored', () {
      final line = LineAnalysis.of([m('A', 20, parallel: true), m('B', 10)]);
      expect(line.stations, hasLength(2));
    });

    test('previous station time only when every machine has one', () {
      final line = LineAnalysis.of([
        m('A', 20, previous: 18),
        m('B', 20, parallel: true, previous: 22),
        m('C', 10, previous: 9),
        m('D', 10, parallel: true),
      ]);
      expect(
        line.stations[0].previousCycleTime,
        closeTo(1 / (1 / 18 + 1 / 22) * s, 1),
      );
      expect(line.stations[1].previousCycleTime, isNull);
    });
  });

  group('failure risk', () {
    test(
      'a single machine station stops the line, parallel ones cost less',
      () {
        final line = LineAnalysis.of([
          m('Saw', 12),
          m('Press 1', 40),
          m('Press 2', 40, parallel: true),
          m('Press 3', 40, parallel: true),
          m('Press 4', 40, parallel: true),
        ]);
        final risk = FailureRisk.of(line);
        expect(risk.baseOutput, closeTo(300, 1e-6));
        final saw = risk.failures.first;
        expect(saw.machine, 'Saw');
        expect(saw.standstill, isTrue);
        expect(saw.outputAfter, 0);
        expect(saw.loss, 1);
        final press = risk.failures[1];
        expect(press.machine, 'Press 1');
        expect(press.standstill, isFalse);
        // Three presses left: 13.33 s → 270 parts per hour.
        expect(press.outputAfter, closeTo(270, 1e-6));
        expect(press.loss, closeTo(0.1, 1e-9));
        expect(risk.failures, hasLength(5));
        expect(risk.singlePoints.map((st) => st.name), ['Saw']);
      },
    );

    test('a spare capacity station loses nothing', () {
      final line = LineAnalysis.of([
        m('Press 1', 40),
        m('Press 2', 40, parallel: true),
        m('Press 3', 40, parallel: true),
        m('Press 4', 40, parallel: true),
        m('Oven', 20),
      ]);
      final risk = FailureRisk.of(line);
      final press = risk.failures.firstWhere((f) => f.machine == 'Press 2');
      expect(press.loss, 0);
      expect(press.outputAfter, closeTo(180, 1e-6));
      expect(risk.failures.first.machine, 'Oven');
    });

    test('without measured stations there is no risk', () {
      final risk = FailureRisk.of(LineAnalysis.of(const []));
      expect(risk.baseOutput, isNull);
      expect(risk.failures, isEmpty);
    });
  });
}

import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

var _id = 0;

/// Station with two steps; one complete cycle of [a] + [b] seconds.
StudyAnalysis station(
  int a,
  int b, {
  StudyMode mode = StudyMode.timeStudy,
  bool complete = true,
}) {
  final steps = [
    const StepDefinition(id: 1, studyId: 1, position: 0, name: 'Load'),
    const StepDefinition(id: 2, studyId: 1, position: 1, name: 'Cut'),
  ];
  Measurement m(int step, int sec) => Measurement(
    id: ++_id,
    studyId: 1,
    cycle: mode == StudyMode.stepTimer ? 0 : 1,
    stepId: step,
    kind: MeasurementKind.normal,
    startMicros: 0,
    endMicros: sec * s,
    durationMicros: sec * s,
  );
  return StudyAnalysis.compute(
    measurements: [m(1, a), if (complete) m(2, b)],
    steps: steps,
    mode: mode,
    method: CycleTimeMethod.mean,
  );
}

void main() {
  test('line figures: total, bottleneck, balance, output, idle, shares', () {
    final line = LineAnalysis.of([
      LineStationInput(
        name: 'Saw',
        mode: StudyMode.timeStudy,
        current: station(10, 20),
      ),
      LineStationInput(
        name: 'Drill',
        mode: StudyMode.timeStudy,
        current: station(30, 30),
      ),
      LineStationInput(
        name: 'Pack',
        mode: StudyMode.timeStudy,
        current: station(5, 25),
      ),
    ]);
    expect(line.totalTime, 120 * s);
    expect(line.lineCycleTime, 60 * s);
    expect(line.bottleneck!.name, 'Drill');
    expect(line.stations[1].isBottleneck, isTrue);
    expect(line.stations[0].isBottleneck, isFalse);
    // 120 / (3 × 60)
    expect(line.balance, closeTo(2 / 3, 1e-9));
    expect(line.outputPerHour, closeTo(60, 1e-9));
    expect(line.stations.map((st) => st.idle), [30 * s, 0, 30 * s]);
    expect(line.stations.map((st) => st.share), [0.25, 0.5, 0.25]);
    expect(line.stations.map((st) => st.position), [0, 1, 2]);
  });

  test('step segments are scaled to the station cycle time', () {
    final line = LineAnalysis.of([
      LineStationInput(
        name: 'Saw',
        mode: StudyMode.timeStudy,
        current: station(10, 30),
      ),
    ]);
    final seg = line.stations.single.segments;
    expect(seg.map((x) => x.name), ['Load', 'Cut']);
    expect(seg.map((x) => x.micros), [10 * s, 30 * s]);
    expect(
      seg.fold<double>(0, (a, x) => a + x.micros),
      line.stations.single.cycleTime,
    );
  });

  test('stations without cycles are listed but not counted', () {
    final line = LineAnalysis.of([
      LineStationInput(
        name: 'Saw',
        mode: StudyMode.timeStudy,
        current: station(10, 20),
      ),
      LineStationInput(
        name: 'Set-up',
        mode: StudyMode.stepTimer,
        current: station(5, 5, mode: StudyMode.stepTimer),
      ),
      LineStationInput(
        name: 'New',
        mode: StudyMode.timeStudy,
        current: station(5, 5, complete: false),
      ),
    ]);
    expect(line.stations, hasLength(3));
    expect(line.measuredCount, 1);
    expect(line.stations[1].cycleTime, isNull);
    expect(line.stations[2].cycleTime, isNull);
    expect(line.stations[1].idle, isNull);
    expect(line.totalTime, 30 * s);
    expect(line.balance, 1);
  });

  test('an empty line has no bottleneck', () {
    final line = LineAnalysis.of(const []);
    expect(line.totalTime, 0);
    expect(line.lineCycleTime, isNull);
    expect(line.bottleneck, isNull);
    expect(line.balance, isNull);
    expect(line.outputPerHour, isNull);
  });

  test('comparison with the previous revisions of all stations', () {
    final line = LineAnalysis.of([
      LineStationInput(
        name: 'Saw',
        mode: StudyMode.timeStudy,
        current: station(10, 20),
        previous: station(10, 10),
      ),
      LineStationInput(
        name: 'Drill',
        mode: StudyMode.timeStudy,
        current: station(30, 30),
        previous: station(25, 25),
      ),
    ]);
    expect(line.previousTotalTime, 70 * s);
    expect(line.totalDelta, 20 * s);
    expect(line.totalDeltaRatio, closeTo(20 / 70, 1e-9));
    expect(line.previousLineCycleTime, 50 * s);
    expect(line.lineCycleDelta, 10 * s);
    expect(line.stations.first.previousCycleTime, 20 * s);
  });

  test(
    'no line comparison when a measured station has no previous revision',
    () {
      final line = LineAnalysis.of([
        LineStationInput(
          name: 'Saw',
          mode: StudyMode.timeStudy,
          current: station(10, 20),
          previous: station(10, 10),
        ),
        LineStationInput(
          name: 'Drill',
          mode: StudyMode.timeStudy,
          current: station(30, 30),
        ),
      ]);
      expect(line.previousTotalTime, isNull);
      expect(line.totalDelta, isNull);
      expect(line.previousLineCycleTime, isNull);
      expect(line.stations.first.previousCycleTime, 20 * s);
    },
  );
}

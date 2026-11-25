import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/group/domain/area_analysis.dart';
import 'package:cyclescope/group/domain/group_tree.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

var _id = 0;

/// One complete cycle of [seconds] in one step; null = not measured.
StudyAnalysis analysis(int? seconds) {
  const steps = [StepDefinition(id: 1, studyId: 1, position: 0, name: 'Work')];
  return StudyAnalysis.compute(
    measurements: [
      if (seconds != null)
        Measurement(
          id: ++_id,
          studyId: 1,
          cycle: 1,
          stepId: 1,
          kind: MeasurementKind.normal,
          startMicros: 0,
          endMicros: seconds * s,
          durationMicros: seconds * s,
        ),
    ],
    steps: steps,
    mode: StudyMode.timeStudy,
    method: CycleTimeMethod.mean,
  );
}

LineStationInput input(
  String name,
  int? seconds, {
  bool parallel = false,
  bool wait = false,
  bool loader = false,
}) => LineStationInput(
  name: name,
  mode: StudyMode.timeStudy,
  current: analysis(seconds),
  parallel: parallel,
  waitForSlowest: wait,
  cellLoader: loader,
);

LineArea area(String name, int start, int end) => LineArea(
  group: StudyGroup(
    id: start + 100,
    name: name,
    description: '',
    createdAt: DateTime(2026),
  ),
  start: start,
  end: end,
);

List<AreaFigures> figures(List<LineStationInput> inputs, List<LineArea> a) =>
    analyseAreas(LineAnalysis.of(inputs), [
      for (final i in inputs) i.parallel,
    ], a);

void main() {
  // A | Press: P1, P2 (parallel, waits), Q | Cell: M, L (loader) | C
  final inputs = [
    input('A', 30),
    input('P1', 50, wait: true),
    input('P2', 40, parallel: true),
    input('Q', 20),
    input('M', 80),
    input('L', 10, parallel: true, loader: true),
    input('C', 45),
  ];
  final areas = [area('Press', 1, 4), area('Cell', 4, 6)];

  test('an area in the line has the cycle time it has alone', () {
    final result = figures(inputs, areas);
    for (final f in result) {
      final alone = LineAnalysis.of(inputs.sublist(f.area.start, f.area.end));
      expect(f.cycleTime, alone.lineCycleTime, reason: f.area.group.name);
      expect(f.totalTime, alone.totalTime, reason: f.area.group.name);
      expect(f.leadTime, alone.leadTime, reason: f.area.group.name);
    }
  });

  test('the line cycle time is the maximum of areas and direct stations', () {
    final line = LineAnalysis.of(inputs);
    final result = figures(inputs, areas);
    final direct = [line.stations.first, line.stations.last];
    final max = [
      for (final f in result) ?f.cycleTime,
      for (final st in direct) ?st.cycleTime,
    ].reduce((a, b) => a > b ? a : b);
    expect(line.lineCycleTime, max);
  });

  test('stations from to, output alone, waiting and the bottleneck', () {
    final line = LineAnalysis.of(inputs);
    final result = figures(inputs, areas);
    final press = result[0];
    expect((press.firstStation, press.lastStation), (1, 2));
    // P1/P2 wait for the slowest machine: 50 s.
    expect(press.cycleTime, 50 * s);
    expect(press.outputPerHour, closeTo(72, 1e-9));
    expect(press.waiting, line.lineCycleTime! - 50 * s);
    final cell = result[1];
    expect((cell.firstStation, cell.lastStation), (3, 3));
    expect(cell.cycleTime, line.stations[3].cycleTime);
    expect(cell.isBottleneck, line.bottleneck!.position == 3);
    expect(press.isBottleneck, isFalse);
  });

  test('a bottleneck in a direct study marks no area', () {
    final slowStart = [input('A', 500), ...inputs.skip(1)];
    final result = figures(slowStart, areas);
    expect(result.any((f) => f.isBottleneck), isFalse);
  });

  test('the bottleneck area is the one holding the bottleneck station', () {
    final slowPress = [...inputs]..[3] = input('Q', 900);
    final result = figures(slowPress, areas);
    expect([for (final f in result) f.isBottleneck], [true, false]);
  });

  test('an area without measured station is listed but does not count', () {
    final unmeasured = [
      input('A', 30),
      input('X1', null),
      input('X2', null),
      input('C', 45),
    ];
    final result = figures(unmeasured, [area('X', 1, 3)]);
    expect(result.single.cycleTime, isNull);
    expect(result.single.outputPerHour, isNull);
    expect(result.single.waiting, isNull);
    expect(result.single.isBottleneck, isFalse);
    expect((result.single.firstStation, result.single.lastStation), (1, 2));
  });

  test('an empty area has no stations', () {
    final result = figures([input('A', 30)], [area('E', 1, 1)]);
    expect(result.single.firstStation, isNull);
    expect(result.single.lastStation, isNull);
    expect(result.single.cycleTime, isNull);
  });
}

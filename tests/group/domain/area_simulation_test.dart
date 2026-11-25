import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/group/domain/area_analysis.dart';
import 'package:cyclescope/group/domain/area_simulation.dart';
import 'package:cyclescope/group/domain/group_member.dart';
import 'package:cyclescope/group/domain/group_tree.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;
const day = 24 * 3600 * s;

var _id = 0;
final _seconds = <int, int>{};

StudyMember study(String name, int seconds, {bool parallel = false}) {
  final id = ++_id;
  _seconds[id] = seconds;
  return StudyMember(
    Study(
      id: id,
      name: name,
      description: '',
      mode: StudyMode.timeStudy,
      createdAt: DateTime(2026),
      lastActiveAt: DateTime(2026),
      parallel: parallel,
    ),
  );
}

AreaMember area(int id, String name, {int buffer = 0}) => AreaMember(
  StudyGroup(
    id: id,
    name: name,
    description: '',
    createdAt: DateTime(2026),
    bufferCapacity: buffer,
    bufferStoreMicros: buffer > 0 ? 2 * s : 0,
    bufferRetrieveMicros: buffer > 0 ? 2 * s : 0,
  ),
);

StudyAnalysis analysis(int seconds) {
  const steps = [StepDefinition(id: 1, studyId: 1, position: 0, name: 'W')];
  return StudyAnalysis.compute(
    measurements: [
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

/// Line, simulation and area figures of the plant [root] in [tree].
({LineAnalysis line, LineSimulation sim, List<AreaFigures> areas}) plant(
  int root,
  Map<int, List<GroupMember>> tree,
) {
  final flat = flattenGroup(root, tree);
  final studies = [for (final e in flat.entries) e.study];
  final line = LineAnalysis.of([
    for (final st in studies)
      LineStationInput(
        name: st.name,
        mode: st.mode,
        current: analysis(_seconds[st.id]!),
        parallel: st.parallel,
        waitForSlowest: st.waitForSlowest,
        buffer: st.hasBuffer
            ? LineBuffer(
                capacity: st.bufferCapacity,
                storeMicros: st.bufferStoreMicros,
                retrieveMicros: st.bufferRetrieveMicros,
              )
            : null,
        conveyor: st.hasConveyor
            ? LineConveyor(
                capacity: st.conveyorCapacity,
                transportMicros: st.conveyorTransportMicros,
              )
            : null,
      ),
  ]);
  return (
    line: line,
    sim: LineSimulation.fromLine(line),
    areas: analyseAreas(line, [
      for (final st in studies) st.parallel,
    ], flat.areas),
  );
}

List<AreaSimFigures> summary(
  ({LineAnalysis line, LineSimulation sim, List<AreaFigures> areas}) p,
  SimResult result,
) => areaSimulation(result, [
  for (final st in p.line.stations)
    if (st.measured) st.position,
], p.areas);

void main() {
  test('area figures are the sums of their stations and never exceed the '
      'available time', () {
    final p = plant(1, {
      1: [area(2, 'Front'), study('Mid', 50), area(3, 'Back', buffer: 5)],
      2: [study('F1', 40), study('F2', 45), study('F3', 45, parallel: true)],
      3: [study('B1', 60), study('B2', 30)],
    });
    final r = p.sim.run(horizonMicros: day);
    final areas = summary(p, r);
    expect(areas, hasLength(2));
    final front = areas[0];
    // Front: stations 0 and 1 of the simulation (F1, F2/F3).
    expect(front.machines, 3);
    expect(
      front.busyMicros,
      r.stations[0].busyMicros + r.stations[1].busyMicros,
    );
    expect(
      front.blockedMicros,
      r.stations[0].blockedMicros + r.stations[1].blockedMicros,
    );
    for (final a in areas) {
      expect(
        a.busyMicros + a.blockedMicros + a.downMicros,
        lessThanOrEqualTo(a.machines * day),
      );
      expect(a.utilization, inInclusiveRange(0, 1));
    }
  });

  test('a bottleneck behind blocks the front area; one in front starves '
      'the back', () {
    final slowBack = plant(1, {
      1: [area(2, 'Front'), area(3, 'Back')],
      2: [study('F1', 30), study('F2', 30)],
      3: [study('B1', 60)],
    });
    var areas = summary(slowBack, slowBack.sim.run(horizonMicros: day));
    expect(areas[0].blockedMicros, greaterThan(0));

    final slowFront = plant(1, {
      1: [area(2, 'Front'), area(3, 'Back')],
      2: [study('F1', 60)],
      3: [study('B1', 30), study('B2', 30)],
    });
    areas = summary(slowFront, slowFront.sim.run(horizonMicros: day));
    expect(areas[1].utilization, lessThan(areas[0].utilization));
    expect(areas[1].utilization, lessThan(0.6));
  });

  test('a failure in one area is standstill only there', () {
    final p = plant(1, {
      1: [area(2, 'Front'), area(3, 'Back', buffer: 10)],
      2: [study('F1', 40)],
      3: [study('B1', 41), study('B2', 38)],
    });
    final r = p.sim.run(
      horizonMicros: day,
      failure: const SimFailure(
        station: 2,
        machine: 0,
        startMicros: 3600 * s,
        durationMicros: 1800 * s,
      ),
    );
    final areas = summary(p, r);
    expect(areas[0].downMicros, 0);
    expect(areas[1].downMicros, 1800 * s);
  });

  test('buffer levels inside an area are summed up', () {
    final p = plant(1, {
      1: [study('A', 30), area(2, 'Back', buffer: 7)],
      2: [study('B1', 60)],
    });
    final areas = summary(p, p.sim.run(horizonMicros: day));
    // The buffer before the area belongs to it (it stands at its entry).
    expect(areas.single.bufferCapacity, 7);
    expect(areas.single.bufferMaxLevel, greaterThan(0));
  });

  test('a large plant finishes in time and keeps the invariants', () {
    // 12 areas × 5 stations = 60 stations, 100 machines: parallel
    // stations, a waiting station, buffers and conveyors.
    final tree = <int, List<GroupMember>>{1: []};
    for (var a = 0; a < 12; a++) {
      final id = 10 + a;
      tree[1]!.add(area(id, 'Area $a', buffer: a.isEven ? 8 : 0));
      final members = <GroupMember>[];
      for (var k = 0; k < 5; k++) {
        final seconds = 40 + (a * 7 + k * 13) % 30;
        members.add(study('S$a.$k', seconds));
        // Stations 1 and 3 of each area get parallel machines.
        if (k == 1 || k == 3) {
          members.add(study('S$a.${k}b', seconds + 20, parallel: true));
        }
        if (k == 3 && a.isOdd) {
          members.add(study('S$a.${k}c', seconds + 10, parallel: true));
        }
      }
      tree[id] = members;
    }
    // One waiting station and one conveyor.
    final first = tree[10]![1] as StudyMember;
    tree[10]![1] = StudyMember(first.study.copyWith(waitForSlowest: true));
    final third = tree[11]![0] as StudyMember;
    tree[11]![0] = StudyMember(
      third.study.copyWith(
        conveyorCapacity: 4,
        conveyorTransportMicros: 20 * s,
      ),
    );
    final p = plant(1, tree);
    expect(p.line.stations, hasLength(60));
    expect(
      [for (final st in p.line.stations) st.machines.length]
          .reduce((a, b) => a + b),
      greaterThanOrEqualTo(90),
    );
    final watch = Stopwatch()..start();
    final r = p.sim.run(horizonMicros: day);
    final simMs = watch.elapsedMilliseconds;
    watch.reset();
    final scenarios = p.sim.failureScenarios(
      horizonMicros: 8 * 3600 * s,
      durationMicros: 30 * 60 * s,
      startMicros: 2 * 3600 * s,
    );
    final scenarioMs = watch.elapsedMilliseconds;
    // ignore: avoid_print
    print('LARGE_PLANT sim24h=${simMs}ms scenarios=${scenarioMs}ms');
    final bottleneck = p.line.lineCycleTime!;
    expect(r.output, lessThanOrEqualTo(day ~/ bottleneck + 1));
    final plain = p.sim.withoutBuffers().run(horizonMicros: day).output;
    expect(r.output, greaterThanOrEqualTo(plain - 2));
    expect(scenarios, isNotEmpty);
    // Guard with a generous margin (see the task notes for measured
    // times).
    expect(simMs, lessThan(5000));
    expect(scenarioMs, lessThan(240000));
  }, timeout: const Timeout(Duration(minutes: 5)));
}

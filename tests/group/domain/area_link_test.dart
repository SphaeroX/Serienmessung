import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
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

/// Seconds per study name: one complete cycle each.
final _seconds = <String, int>{};

StudyMember study(
  String name,
  int seconds, {
  int buffer = 0,
  int conveyor = 0,
}) {
  _seconds[name] = seconds;
  return StudyMember(
    Study(
      id: ++_id,
      name: name,
      description: '',
      mode: StudyMode.timeStudy,
      createdAt: DateTime(2026),
      lastActiveAt: DateTime(2026),
      bufferCapacity: buffer,
      bufferStoreMicros: buffer > 0 ? 2 * s : 0,
      bufferRetrieveMicros: buffer > 0 ? 2 * s : 0,
      conveyorCapacity: conveyor,
      conveyorTransportMicros: conveyor > 0 ? 30 * s : 0,
    ),
  );
}

AreaMember area(
  int id,
  String name, {
  int buffer = 0,
  int conveyor = 0,
  int transport = 30,
}) => AreaMember(
  StudyGroup(
    id: id,
    name: name,
    description: '',
    createdAt: DateTime(2026),
    bufferCapacity: buffer,
    bufferStoreMicros: buffer > 0 ? 3 * s : 0,
    bufferRetrieveMicros: buffer > 0 ? 4 * s : 0,
    conveyorCapacity: conveyor,
    conveyorTransportMicros: conveyor > 0 ? transport * s : 0,
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

/// The line analysis of [studies], like `GroupReportInput.line`.
LineAnalysis lineOf(List<Study> studies) => LineAnalysis.of([
  for (final st in studies)
    LineStationInput(
      name: st.name,
      mode: st.mode,
      current: analysis(_seconds[st.name]!),
      parallel: st.parallel,
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

LineAnalysis flatLine(int root, Map<int, List<GroupMember>> tree) =>
    lineOf([for (final e in flattenGroup(root, tree).entries) e.study]);

void main() {
  test('a buffer before area B sits before its first station in the plant, '
      'not in B alone', () {
    final tree = {
      1: [area(2, 'A'), area(3, 'B', buffer: 6)],
      2: [study('A1', 40), study('A2', 45)],
      3: [study('B1', 50), study('B2', 30)],
    };
    final plant = flatLine(1, tree);
    expect(plant.stations[2].bufferBefore?.capacity, 6);
    expect(plant.stations[2].bufferBefore?.storeMicros, 3 * s);
    expect(plant.stations[2].bufferBefore?.retrieveMicros, 4 * s);
    final alone = flatLine(3, tree);
    expect(alone.stations.first.bufferBefore, isNull);
  });

  test('a conveyor before an area counts in the plant lead time', () {
    final tree = {
      1: [area(2, 'A'), area(3, 'B', conveyor: 4)],
      2: [study('A1', 40)],
      3: [study('B1', 50)],
    };
    final plant = flatLine(1, tree);
    expect(plant.stations[1].conveyorBefore?.transportMicros, 30 * s);
    expect(plant.leadTime, (40 + 50 + 30) * s);
    expect(flatLine(3, tree).leadTime, 50 * s);
  });

  test("the link replaces the first study's own buffer and conveyor", () {
    final tree = {
      1: [study('X', 40), area(3, 'B', buffer: 6)],
      3: [study('B1', 50, buffer: 99, conveyor: 9)],
    };
    final first = flattenGroup(1, tree).entries[1].study;
    expect(first.bufferCapacity, 6);
    expect(first.conveyorCapacity, 0);
  });

  test('the outer link wins over the one of an area at the same place', () {
    final tree = {
      1: [study('X', 40), area(2, 'Outer', buffer: 6)],
      2: [area(3, 'Inner', buffer: 2), study('O1', 30)],
      3: [study('I1', 50)],
    };
    expect(flattenGroup(1, tree).entries[1].study.bufferCapacity, 6);
    // Without an outer link the inner one works.
    final inner = {
      1: [study('X', 40), area(2, 'Outer')],
      2: [area(3, 'Inner', buffer: 2), study('O1', 30)],
      3: [study('I1', 50)],
    };
    expect(flattenGroup(1, inner).entries[1].study.bufferCapacity, 2);
    // An inner area later in the outer one keeps its own link.
    final later = {
      1: [study('X', 40), area(2, 'Outer', buffer: 6)],
      2: [study('O1', 30), area(3, 'Inner', buffer: 2)],
      3: [study('I1', 50)],
    };
    final entries = flattenGroup(1, later).entries;
    expect([for (final e in entries) e.study.bufferCapacity], [0, 6, 2]);
  });

  test('an area as the first member: the link has no effect', () {
    final tree = {
      1: [area(2, 'A', buffer: 6, conveyor: 3), study('X', 40)],
      2: [study('A1', 50)],
    };
    final first = flattenGroup(1, tree).entries.first.study;
    expect(first.hasBuffer, isFalse);
    expect(first.hasConveyor, isFalse);
    // Behind an empty area it still has none: nothing stands before it.
    final empty = {
      1: [area(4, 'E'), area(2, 'A', buffer: 6), study('X', 40)],
      2: [study('A1', 50)],
      4: <GroupMember>[],
    };
    expect(flattenGroup(1, empty).entries.first.study.hasBuffer, isFalse);
  });

  test('a link before an empty area is not passed on', () {
    final tree = {
      1: [study('X', 40), area(4, 'E', buffer: 6), study('Y', 30)],
      4: <GroupMember>[],
    };
    expect(flattenGroup(1, tree).entries.last.study.hasBuffer, isFalse);
  });

  test('two areas compute like the same studies in one flat group', () {
    final tree = {
      1: [area(2, 'A'), area(3, 'B', buffer: 8, conveyor: 3)],
      2: [study('A1', 40), study('A2', 55)],
      3: [study('B1', 50), study('B2', 35)],
    };
    final flat = {
      9: [
        study('A1', 40),
        study('A2', 55),
        study('B1', 50, buffer: 8, conveyor: 3),
        study('B2', 35),
      ],
    };
    // Same buffer and conveyor times as the area link.
    final plantStudies = [
      for (final e in flattenGroup(1, tree).entries) e.study,
    ];
    final flatStudies = [
      for (final e in flattenGroup(9, flat).entries)
        e.study.name == 'B1'
            ? e.study.copyWith(
                bufferStoreMicros: 3 * s,
                bufferRetrieveMicros: 4 * s,
              )
            : e.study,
    ];
    final a = lineOf(plantStudies);
    final b = lineOf(flatStudies);
    expect(a.lineCycleTime, b.lineCycleTime);
    expect(a.leadTime, b.leadTime);
    final simA = LineSimulation.fromLine(a).run(horizonMicros: day);
    final simB = LineSimulation.fromLine(b).run(horizonMicros: day);
    expect(simA.output, simB.output);
  });

  test('a buffer between areas never costs output and keeps the front area '
      'running during a failure behind', () {
    final tree = {
      1: [area(2, 'A'), area(3, 'B', buffer: 20)],
      2: [study('A1', 40), study('A2', 42)],
      3: [study('B1', 41), study('B2', 39)],
    };
    final sim = LineSimulation.fromLine(flatLine(1, tree));
    final withBuffer = sim.run(horizonMicros: day).output;
    final without = sim.withoutBuffers().run(horizonMicros: day).output;
    expect(withBuffer, greaterThanOrEqualTo(without - 1));
    const failure = SimFailure(
      station: 3,
      machine: 0,
      startMicros: 3600 * s,
      durationMicros: 1800 * s,
    );
    final failedWith = sim.run(horizonMicros: day, failure: failure);
    final failedWithout = sim.withoutBuffers().run(
      horizonMicros: day,
      failure: failure,
    );
    expect(failedWith.output, greaterThan(failedWithout.output));
  });
}

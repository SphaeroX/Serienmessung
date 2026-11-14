import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/demo/data/demo_data_service.dart';
import 'package:cyclescope/demo/domain/demo_texts.dart';
import 'package:cyclescope/demo/presentation/demo_data_tile.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/special_cycle_repository.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
import 'package:cyclescope/l10n/app_localizations.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/revision/data/revision_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _s = 1000000;
final _now = DateTime(2026, 11, 13, 10);

void main() {
  late AppDatabase db;
  late DemoTexts t;
  late DemoDataService demo;

  setUp(() async {
    db = await openTestDatabase();
    t = demoTextsOf(lookupAppLocalizations(const Locale('en')));
    demo = DemoDataService(db, now: () => _now);
  });

  tearDown(() => db.close());

  Future<List<Study>> members(int groupId) async => [
    for (final m in await StudyRepository(db).listStudies(groupId: groupId))
      m.study,
  ];

  /// The group as a line, built like the line screen does.
  Future<LineAnalysis> lineOf(int groupId) async {
    final studies = StudyRepository(db);
    final times = MeasurementRepository(db);
    final rules = SpecialCycleRepository(db);
    return LineAnalysis.of([
      for (final s in await members(groupId))
        LineStationInput(
          name: s.name,
          mode: s.mode,
          current: StudyAnalysis.compute(
            measurements: await times.listForStudy(s.id),
            steps: await studies.getSteps(s.id),
            mode: s.mode,
            method: s.cycleTimeMethod == null
                ? CycleTimeMethod.median
                : CycleTimeMethod.parse(s.cycleTimeMethod!),
          ),
          parallel: s.parallel,
          buffer: s.hasBuffer
              ? LineBuffer(
                  capacity: s.bufferCapacity,
                  storeMicros: s.bufferStoreMicros,
                  retrieveMicros: s.bufferRetrieveMicros,
                )
              : null,
          conveyor: s.hasConveyor
              ? LineConveyor(
                  capacity: s.conveyorCapacity,
                  transportMicros: s.conveyorTransportMicros,
                )
              : null,
          specialCycles: await rules.list(s.id),
        ),
    ]);
  }

  test('creates the demo line as a group with its stations in order', () async {
    final groupId = await demo.load(t);

    final groups = await GroupRepository(db).listGroups();
    expect(groups, hasLength(1));
    expect(groups.single.group.id, groupId);
    expect(groups.single.group.name, t.groupName);
    expect(groups.single.group.description, t.groupDescription);

    final line = await members(groupId);
    expect(
      [for (final s in line) s.name],
      [
        t.saw,
        t.millingCentre(1),
        t.millingCentre(2),
        t.washer,
        t.assembly,
        t.testBench(1),
        t.testBench(2),
        t.testBench(3),
        t.packing,
      ],
    );
    expect(
      [for (final s in line) s.parallel],
      [false, false, true, false, false, false, true, true, false],
    );
    expect(
      [for (final s in line) s.mode],
      [
        StudyMode.simple,
        StudyMode.timeStudy,
        StudyMode.simple,
        StudyMode.simple,
        StudyMode.timeStudy,
        StudyMode.simple,
        StudyMode.simple,
        StudyMode.simple,
        StudyMode.simple,
      ],
    );
    expect([
      for (final st in await StudyRepository(db).getSteps(line[1].id)) st.name,
    ], t.millingSteps);
    expect([
      for (final st in await StudyRepository(db).getSteps(line[4].id)) st.name,
    ], t.assemblySteps);

    // Buffers before the milling centres and the test benches.
    expect(line[1].bufferCapacity, 30);
    expect(line[1].bufferStoreMicros, 15 * _s);
    expect(line[1].bufferRetrieveMicros, 12 * _s);
    expect(line[5].bufferCapacity, 40);
    expect(line[5].bufferStoreMicros, 20 * _s);
    expect(line[5].bufferRetrieveMicros, 15 * _s);
    // Conveyors before the washer and the packing.
    expect(line[3].conveyorCapacity, 8);
    expect(line[3].conveyorTransportMicros, 60 * _s);
    expect(line[8].conveyorCapacity, 10);
    expect(line[8].conveyorTransportMicros, 30 * _s);
    expect(
      [for (final s in line) s.hasBuffer || s.hasConveyor],
      [false, true, false, true, false, true, false, false, true],
    );
  });

  test(
    'special cycles, special times, revisions and a changeover study',
    () async {
      final groupId = await demo.load(t);
      final line = await members(groupId);
      final rules = SpecialCycleRepository(db);

      final saw = await rules.list(line[0].id);
      expect(saw.single.name, t.bladeChange);
      expect(saw.single.kind, SpecialCycleKind.time);
      expect(saw.single.interval, 8 * 3600 * _s);
      expect(saw.single.durationMicros, 600 * _s);

      final milling = await rules.list(line[1].id);
      expect([for (final c in milling) c.name], [t.measurePart, t.toolChange]);
      expect(
        [for (final c in milling) c.kind],
        [SpecialCycleKind.parts, SpecialCycleKind.time],
      );
      expect(milling[0].interval, 50);
      expect(milling[0].durationMicros, 120 * _s);
      expect(milling[1].interval, 24 * 3600 * _s);
      expect(milling[1].durationMicros, 300 * _s);

      final bench = await rules.list(line[5].id);
      expect(bench.single.name, t.calibration);
      expect(bench.single.kind, SpecialCycleKind.parts);
      expect(bench.single.interval, 200);

      // The milling centre and the assembly were measured before.
      final revisions = RevisionRepository(db);
      for (final i in [1, 4]) {
        expect(line[i].revision, 2);
        expect(await revisions.listRevisions(line[i].id), hasLength(1));
      }
      expect(line[0].revision, 1);

      // One unforeseen interruption each.
      final times = MeasurementRepository(db);
      List<Measurement> special(List<Measurement> m) => [
        for (final x in m)
          if (x.kind == MeasurementKind.special) x,
      ];
      final millingTimes = await times.listForStudy(line[1].id);
      expect(special(millingTimes).single.note, t.chipJam);
      expect(
        special(await times.listForStudy(line[4].id)).single.note,
        t.materialMissing,
      );
      // Twelve complete milling cycles; the packing has its laps.
      expect({for (final m in millingTimes) m.cycle}, hasLength(12));
      expect(await times.listForStudy(line[8].id), hasLength(15));

      // Current times are recent: opening a study does not ask for a new
      // measurement.
      for (final s in line) {
        for (final m in await times.listForStudy(s.id)) {
          expect(
            _now.difference(m.recordedAt!).inDays,
            lessThan(10),
            reason: s.name,
          );
        }
      }

      // The changeover study is outside the group.
      final all = await StudyRepository(db).listStudies();
      final changeover = all.singleWhere((x) => x.study.name == t.changeover);
      expect(changeover.study.mode, StudyMode.stepTimer);
      expect(changeover.study.groupId, isNull);
      final changeoverTimes = await times.listForStudy(changeover.study.id);
      expect(changeoverTimes, hasLength(8));
      expect({for (final m in changeoverTimes) m.cycle}, {0});
      expect([
        for (final st in await StudyRepository(
          db,
        ).getSteps(changeover.study.id))
          st.name,
      ], t.changeoverSteps);
    },
  );

  test('the milling centres pace the line; the simulation runs', () async {
    final groupId = await demo.load(t);
    final line = await lineOf(groupId);

    // Saw, milling centres, washer, assembly, test benches, packing.
    expect(line.stations, hasLength(6));
    expect(
      [for (final st in line.stations) st.machines.length],
      [1, 2, 1, 1, 3, 1],
    );
    expect(line.stations.every((st) => st.measured), isTrue);
    final bottleneck = line.stations.singleWhere((st) => st.isBottleneck);
    expect(bottleneck.position, 1);
    // About 1000 parts in 24 hours at the pace of the milling centres.
    expect(line.outputPerHour! * 24, closeTo(1000, 10));
    expect(
      [for (final st in line.stations) st.bufferBefore != null],
      [false, true, false, false, true, false],
    );
    expect(
      [for (final st in line.stations) st.conveyorBefore != null],
      [false, false, true, false, false, true],
    );
    // The special cycles make the milling centre slower than measured.
    final milling = line.stations[1].machines.first;
    expect(milling.cycleTime!, greaterThan(milling.baseCycleTime!));

    const shift = 8 * 3600 * _s;
    final result = LineSimulation.fromLine(line).run(horizonMicros: shift);
    expect(result.output, greaterThan(0));
    expect(result.output, lessThanOrEqualTo(shift ~/ line.lineCycleTime!));
  });

  test('the line makes 1000 parts in 24 hours when nothing fails', () async {
    final line = await lineOf(await demo.load(t));
    final sim = LineSimulation.fromLine(line);

    const day = 24 * 3600 * _s;
    final result = sim.run(horizonMicros: day);
    expect(result.output, 1000);
    // The milling centres work all the time, every other station waits.
    expect(result.stations[1].utilization, greaterThan(0.98));
    for (final i in [0, 2, 3, 4, 5]) {
      expect(result.stations[i].utilization, lessThan(0.95), reason: '$i');
    }
    // Without the buffers the blade changes of the saw cost parts.
    expect(sim.withoutBuffers().run(horizonMicros: day).output, lessThan(990));
  });

  test('own data stays; loading twice adds a second demo line', () async {
    final own = await StudyRepository(db).createStudy(
      name: 'My study',
      mode: StudyMode.simple,
      steps: const [],
      now: _now,
    );
    await demo.load(t);
    await demo.load(t);

    expect(await StudyRepository(db).getStudy(own), isNotNull);
    expect(await GroupRepository(db).listGroups(), hasLength(2));
    // 9 line members + 1 changeover study per load.
    expect(await StudyRepository(db).listStudies(), hasLength(1 + 2 * 10));
  });
}

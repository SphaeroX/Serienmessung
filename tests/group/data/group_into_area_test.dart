import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/demo/data/demo_data_service.dart';
import 'package:cyclescope/demo/presentation/demo_data_tile.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/machine_service.dart';
import 'package:cyclescope/group/data/special_cycle_repository.dart';
import 'package:cyclescope/group/domain/group_member.dart';
import 'package:cyclescope/group/domain/group_tree.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/l10n/app_localizations.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

const s = 1000000;

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late MachineService machines;
  late int line;

  setUp(() async {
    db = await openTestDatabase();
    groups = GroupRepository(db);
    machines = MachineService(db, now: () => DateTime(2026));
    line = await groups.createGroup(name: 'Line', now: DateTime(2026));
  });

  tearDown(() => db.close());

  Future<int> machine(String name, int seconds, {bool parallel = false}) =>
      machines.createMachine(
        name: name,
        groupId: line,
        cycleMicros: seconds * s,
        parallel: parallel,
      );

  /// What every analysis of the line reads: the flattened studies with
  /// their line fields.
  Future<List<String>> flat(int groupId) async => [
    for (final e in flattenGroup(
      groupId,
      await groups.loadTree(groupId),
    ).entries)
      [
        e.study.name,
        e.study.parallel,
        e.study.cellLoader,
        e.study.waitForSlowest,
        e.study.bufferCapacity,
        e.study.bufferStoreMicros,
        e.study.bufferRetrieveMicros,
        e.study.conveyorCapacity,
        e.study.conveyorTransportMicros,
      ].join('|'),
  ];

  /// The line as the line screen computes it.
  Future<LineAnalysis> analysis(int groupId) async {
    final studies = StudyRepository(db);
    final times = MeasurementRepository(db);
    final rules = SpecialCycleRepository(db);
    final entries = flattenGroup(
      groupId,
      await groups.loadTree(groupId),
    ).entries;
    return LineAnalysis.of([
      for (final e in entries)
        LineStationInput(
          name: e.study.name,
          mode: e.study.mode,
          current: StudyAnalysis.compute(
            measurements: await times.listForStudy(e.study.id),
            steps: await studies.getSteps(e.study.id),
            mode: e.study.mode,
            method: e.study.cycleTimeMethod == null
                ? CycleTimeMethod.median
                : CycleTimeMethod.parse(e.study.cycleTimeMethod!),
          ),
          parallel: e.study.parallel,
          waitForSlowest: e.study.waitForSlowest,
          cellLoader: e.study.isCellLoader,
          cellParts: e.study.cellParts,
          cellMachines: e.study.cellMachines,
          buffer: e.study.hasBuffer
              ? LineBuffer(
                  capacity: e.study.bufferCapacity,
                  storeMicros: e.study.bufferStoreMicros,
                  retrieveMicros: e.study.bufferRetrieveMicros,
                )
              : null,
          conveyor: e.study.hasConveyor
              ? LineConveyor(
                  capacity: e.study.conveyorCapacity,
                  transportMicros: e.study.conveyorTransportMicros,
                )
              : null,
          specialCycles: await rules.list(e.study.id),
        ),
    ]);
  }

  Future<String> members(int groupId) async => [
    for (final m in await groups.listMembers(groupId))
      switch (m) {
        StudyMember(:final study) => study.name,
        AreaMember(:final group) => '[${group.name}]',
      },
  ].join(' ');

  /// Eight stations: 1 S1, 2 S2/S2b (waits), 3 S3 (buffer), 4 S4 (buffer),
  /// 5 S5 (conveyor), 6 S6, 7 S7, 8 S8.
  Future<Map<String, int>> eight() async {
    final ids = <String, int>{};
    ids['S1'] = await machine('S1', 40);
    ids['S2'] = await machine('S2', 70);
    ids['S2b'] = await machine('S2b', 65, parallel: true);
    await groups.setWaitForSlowest(ids['S2']!, true);
    ids['S3'] = await machine('S3', 45);
    await groups.setBuffer(
      ids['S3']!,
      capacity: 5,
      storeMicros: 2 * s,
      retrieveMicros: 3 * s,
    );
    ids['S4'] = await machine('S4', 50);
    await groups.setBuffer(
      ids['S4']!,
      capacity: 4,
      storeMicros: s,
      retrieveMicros: s,
    );
    ids['S5'] = await machine('S5', 55);
    await groups.setConveyor(ids['S5']!, capacity: 3, transportMicros: 20 * s);
    for (final n in ['S6', 'S7', 'S8']) {
      ids[n] = await machine(n, 30 + n.codeUnitAt(1));
    }
    return ids;
  }

  test('stations 3 to 5 become an area; the line stays the same', () async {
    final ids = await eight();
    final before = await flat(line);
    final lineBefore = await analysis(line);
    final simBefore = LineSimulation.fromLine(lineBefore)
        .run(horizonMicros: 24 * 3600 * s);

    final area = await groups.groupIntoArea(
      line,
      [
        MemberKey.study(ids['S3']!),
        MemberKey.study(ids['S4']!),
        MemberKey.study(ids['S5']!),
      ],
      name: 'Middle',
      now: DateTime(2026),
    );

    expect(await members(line), 'S1 S2 S2b [Middle] S6 S7 S8');
    expect(await members(area), 'S3 S4 S5');
    expect(await flat(line), before);
    // The buffer before station 3 is now the link before the area; the
    // one before station 4 stays at station 4.
    final g = (await groups.getGroup(area))!;
    expect(g.bufferCapacity, 5);
    expect(
      (await StudyRepository(db).getStudy(ids['S3']!))!.hasBuffer,
      isFalse,
    );
    expect((await StudyRepository(db).getStudy(ids['S4']!))!.bufferCapacity, 4);

    final lineAfter = await analysis(line);
    expect(lineAfter.lineCycleTime, lineBefore.lineCycleTime);
    expect(lineAfter.bottleneck?.name, lineBefore.bottleneck?.name);
    expect(lineAfter.balance, lineBefore.balance);
    expect(lineAfter.outputPerHour, lineBefore.outputPerHour);
    final simAfter = LineSimulation.fromLine(lineAfter)
        .run(horizonMicros: 24 * 3600 * s);
    expect(simAfter.output, simBefore.output);

    // Dissolving restores the members, stations, buffers and conveyors.
    await groups.dissolveArea(area);
    expect(await members(line), 'S1 S2 S2b S3 S4 S5 S6 S7 S8');
    expect(await flat(line), before);
    expect((await StudyRepository(db).getStudy(ids['S3']!))!.bufferCapacity, 5);
    expect(await groups.getGroup(area), isNull);
  });

  test('grouping at the start of the group takes no link', () async {
    final ids = await eight();
    final before = await flat(line);
    final area = await groups.groupIntoArea(
      line,
      [
        MemberKey.study(ids['S1']!),
        MemberKey.study(ids['S2']!),
        MemberKey.study(ids['S2b']!),
      ],
      name: 'Front',
      now: DateTime(2026),
    );
    expect(await members(line), startsWith('[Front] S3'));
    expect((await groups.getGroup(area))!.hasLink, isFalse);
    expect(await flat(line), before);
  });

  test('a selection that splits a station or has a gap is refused', () async {
    final ids = await eight();
    await expectLater(
      groups.groupIntoArea(
        line,
        [MemberKey.study(ids['S2b']!)],
        name: 'X',
        now: DateTime(2026),
      ),
      throwsArgumentError,
    );
    await expectLater(
      groups.groupIntoArea(
        line,
        [MemberKey.study(ids['S1']!), MemberKey.study(ids['S3']!)],
        name: 'X',
        now: DateTime(2026),
      ),
      throwsArgumentError,
    );
    expect(await members(line), 'S1 S2 S2b S3 S4 S5 S6 S7 S8');
  });

  test('areas in the selection become sub-areas; dissolving lifts them '
      'one level', () async {
    final ids = await eight();
    final before = await flat(line);
    final inner = await groups.groupIntoArea(
      line,
      [MemberKey.study(ids['S4']!)],
      name: 'Inner',
      now: DateTime(2026),
    );
    final outer = await groups.groupIntoArea(
      line,
      [
        MemberKey.study(ids['S3']!),
        MemberKey.area(inner),
        MemberKey.study(ids['S5']!),
      ],
      name: 'Outer',
      now: DateTime(2026),
    );
    expect(await members(outer), 'S3 [Inner] S5');
    expect(await flat(line), before);
    await groups.dissolveArea(outer);
    expect(await members(line), 'S1 S2 S2b S3 [Inner] S5 S6 S7 S8');
    expect(await flat(line), before);
    // An area starting with a sub-area hands its link on to it.
    final front = await groups.groupIntoArea(
      line,
      [MemberKey.area(inner), MemberKey.study(ids['S5']!)],
      name: 'Front',
      now: DateTime(2026),
    );
    expect((await groups.getGroup(front))!.bufferCapacity, 4);
    await groups.dissolveArea(front);
    expect((await groups.getGroup(inner))!.bufferCapacity, 4);
    expect(await flat(line), before);
  });

  test(
    'the demo line split into areas still makes 1000 parts in 24 h',
    () async {
      final t = demoTextsOf(lookupAppLocalizations(const Locale('en')));
      final demo = DemoDataService(db, now: () => DateTime(2026, 11, 13, 10));
      final plant = await demo.load(t);
      final order = [for (final m in await groups.listMembers(plant)) m.key];
      final flags = StudyRepository.memberStationFlags(
        await StudyRepository.memberRows(db.db, plant),
      );
      // Cut after the fourth station into two areas.
      var station = 0;
      var cut = order.length;
      for (var k = 0; k < order.length; k++) {
        if (!flags[k] && ++station == 5) {
          cut = k;
          break;
        }
      }
      await groups.groupIntoArea(
        plant,
        order.sublist(0, cut),
        name: 'Front',
        now: DateTime(2026),
      );
      final rest = [
        for (final m in await groups.listMembers(plant))
          if (m is StudyMember) m.key,
      ];
      await groups.groupIntoArea(
        plant,
        rest,
        name: 'Back',
        now: DateTime(2026),
      );
      expect(await members(plant), '[Front] [Back]');
      final result = LineSimulation.fromLine(await analysis(plant))
          .run(horizonMicros: 24 * 3600 * s);
      expect(result.output, 1000);
    },
  );
}

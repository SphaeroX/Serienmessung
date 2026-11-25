import 'package:cyclescope/analysis/domain/analysis.dart';
import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/database.dart';
import 'package:cyclescope/demo/data/demo_data_service.dart';
import 'package:cyclescope/demo/domain/demo_texts.dart';
import 'package:cyclescope/demo/presentation/demo_data_tile.dart';
import 'package:cyclescope/group/data/group_repository.dart';
import 'package:cyclescope/group/data/special_cycle_repository.dart';
import 'package:cyclescope/group/domain/area_analysis.dart';
import 'package:cyclescope/group/domain/group_member.dart';
import 'package:cyclescope/group/domain/group_tree.dart';
import 'package:cyclescope/group/domain/line_analysis.dart';
import 'package:cyclescope/group/domain/line_simulation.dart';
import 'package:cyclescope/l10n/app_localizations.dart';
import 'package:cyclescope/recording/data/measurement_repository.dart';
import 'package:cyclescope/study/data/study_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _s = 1000000;

void main() {
  late AppDatabase db;
  late DemoTexts t;
  late DemoDataService demo;
  late GroupRepository groups;

  setUp(() async {
    db = await openTestDatabase();
    t = demoTextsOf(lookupAppLocalizations(const Locale('en')));
    demo = DemoDataService(db, now: () => DateTime(2026, 11, 13, 10));
    groups = GroupRepository(db);
  });

  tearDown(() => db.close());

  /// The plant as one line, built like the line screen does.
  Future<({LineAnalysis line, List<AreaFigures> areas})> plantLine(
    int plant,
  ) async {
    final studies = StudyRepository(db);
    final times = MeasurementRepository(db);
    final rules = SpecialCycleRepository(db);
    final flat = flattenGroup(plant, await groups.loadTree(plant));
    final line = LineAnalysis.of([
      for (final e in flat.entries)
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
    return (
      line: line,
      areas: analyseAreas(line, [
        for (final e in flat.entries) e.study.parallel,
      ], flat.areas),
    );
  }

  test('the demo is a plant of the housing line and a shipping area', () async {
    final lineId = await demo.load(t);
    final line = (await groups.getGroup(lineId))!;
    expect(line.name, t.groupName);
    final plant = (await groups.getGroup(line.parentId!))!;
    expect(plant.name, t.plantName);
    expect(plant.parentId, isNull);
    final areas = [
      for (final m in await groups.listMembers(plant.id))
        (m as AreaMember).group,
    ];
    expect([for (final a in areas) a.name], [t.groupName, t.shippingName]);
    // A conveyor connects the two areas.
    final shipping = areas.last;
    expect(shipping.conveyorCapacity, 6);
    expect(shipping.conveyorTransportMicros, 45 * _s);
    expect(
      [
        for (final m in await groups.listMembers(shipping.id))
          (m as StudyMember).study.name,
      ],
      [t.labeler, t.palletizer],
    );
  });

  test('the housing line is the bottleneck area of the plant', () async {
    final lineId = await demo.load(t);
    final plant = (await groups.getGroup(lineId))!.parentId!;
    final p = await plantLine(plant);
    expect(p.areas.first.area.group.id, lineId);
    expect(p.areas.first.isBottleneck, isTrue);
    expect(p.areas.last.isBottleneck, isFalse);
    expect(p.line.lineCycleTime, p.areas.first.cycleTime);
    // The conveyor between the areas is before the first shipping station.
    final first = p.areas.last.firstStation!;
    expect(p.line.stations[first].conveyorBefore?.capacity, 6);
  });

  test('the plant makes 998 parts in 24 hours when nothing fails', () async {
    final lineId = await demo.load(t);
    final plant = (await groups.getGroup(lineId))!.parentId!;
    final result = LineSimulation.fromLine((await plantLine(plant)).line)
        .run(horizonMicros: 24 * 3600 * _s);
    expect(result.output, 998);
  });

  test('every load adds a plant of its own', () async {
    await demo.load(t);
    await demo.load(t);
    final top = [
      for (final g in await groups.listGroups())
        if (g.group.parentId == null) g,
    ];
    expect(top, hasLength(2));
    expect(top.every((g) => g.areaCount == 2), isTrue);
  });
}

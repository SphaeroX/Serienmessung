import '../../core/time_format.dart';
import '../../group/domain/area_analysis.dart';
import '../../group/domain/group_tree.dart';
import '../../group/domain/line_analysis.dart';
import '../../group/domain/line_simulation.dart';
import '../../group/domain/loader_cell.dart';
import '../../group/domain/special_cycle.dart';
import '../../group/domain/study_group.dart';
import 'export_data.dart';

/// Texts only the group report needs.
class GroupReportLabels {
  const GroupReportLabels({
    required this.title,
    required this.overview,
    required this.group,
    required this.position,
    required this.cycles,
    required this.previous,
    required this.total,
    this.area,
  });

  /// Overview column with the area of each study; the column is only
  /// written when it is set and the group has areas.
  final String? area;

  final String title;

  /// Overview section and sheet name.
  final String overview;
  final String group;
  final String position;

  /// Column with the number of (complete) cycles.
  final String cycles;

  /// Column with the real cycle time of the previous revision.
  final String previous;
  final String total;
}

/// Texts of the full group report (contents, line analysis, links).
class LineReportLabels {
  const LineReportLabels({
    required this.contents,
    required this.lineAnalysis,
    required this.station,
    required this.totalTime,
    required this.lineCycleTime,
    required this.bottleneck,
    required this.balance,
    required this.outputPerHour,
    required this.waiting,
    required this.share,
    required this.sheet,
    required this.backToContents,
    required this.studies,
    this.risk,
    this.buffers,
    this.specials,
    this.cells,
    this.waitsForSlowest,
    this.areas,
  });

  LineReportLabels _with({
    RiskReportLabels? risk,
    BufferReportLabels? buffers,
    SpecialReportLabels? specials,
    CellReportLabels? cells,
    String? waitsForSlowest,
    AreaReportLabels? areas,
  }) => LineReportLabels(
    contents: contents,
    lineAnalysis: lineAnalysis,
    station: station,
    totalTime: totalTime,
    lineCycleTime: lineCycleTime,
    bottleneck: bottleneck,
    balance: balance,
    outputPerHour: outputPerHour,
    waiting: waiting,
    share: share,
    sheet: sheet,
    backToContents: backToContents,
    studies: studies,
    risk: risk ?? this.risk,
    buffers: buffers ?? this.buffers,
    specials: specials ?? this.specials,
    cells: cells ?? this.cells,
    waitsForSlowest: waitsForSlowest ?? this.waitsForSlowest,
    areas: areas ?? this.areas,
  );

  /// Texts of the plant's areas (area columns, areas section, contents by
  /// area); without them, or for a group without areas, the report looks
  /// as for a single line.
  final AreaReportLabels? areas;

  LineReportLabels withAreas(AreaReportLabels areas) => _with(areas: areas);

  /// Texts of the loader cell sections; without them they are left out.
  final CellReportLabels? cells;

  LineReportLabels withCells(CellReportLabels cells) => _with(cells: cells);

  /// Marks a station of parallel machines that waits for its slowest
  /// machine ("waits for the slowest"); without it such a station is only
  /// marked in the Excel report ("3→1").
  final String? waitsForSlowest;

  LineReportLabels withWaitsForSlowest(String waitsForSlowest) =>
      _with(waitsForSlowest: waitsForSlowest);

  /// Texts of the special cycles table; without them it is left out.
  final SpecialReportLabels? specials;

  LineReportLabels withSpecials(SpecialReportLabels specials) =>
      _with(specials: specials);

  /// Texts of the buffer table; without them it is left out.
  final BufferReportLabels? buffers;

  LineReportLabels withBuffers(BufferReportLabels buffers) =>
      _with(buffers: buffers);

  /// Texts of the failure risk chapter/sheet; without them it is left out.
  final RiskReportLabels? risk;

  LineReportLabels withRisk(RiskReportLabels risk) => _with(risk: risk);

  final String contents;
  final String lineAnalysis;
  final String station;
  final String totalTime;
  final String lineCycleTime;
  final String bottleneck;
  final String balance;
  final String outputPerHour;
  final String waiting;
  final String share;

  /// Overview column with the link to the study sheet.
  final String sheet;
  final String backToContents;
  final String studies;
}

/// Texts of a plant's areas in the full report.
class AreaReportLabels {
  const AreaReportLabels({
    required this.area,
    required this.title,
    required this.stations,
    required this.bottleneck,
  });

  /// Column with the area of a station or study.
  final String area;

  /// Section with one row per area.
  final String title;

  /// Column with the stations of an area ("2–4").
  final String stations;

  /// Marks the area the line's bottleneck lies in.
  final String bottleneck;
}

/// Texts of the failure risk chapter (PDF) and sheet (Excel).
class RiskReportLabels {
  const RiskReportLabels({
    required this.title,
    required this.hint,
    required this.machine,
    required this.outputDuring,
    required this.loss,
    required this.standstill,
    required this.noLoss,
    required this.singlePoints,
    this.lostWithoutBuffers,
    this.lostWithBuffers,
    this.simulationNote,
  });

  /// Columns with the simulated lost parts (only with buffers).
  final String? lostWithoutBuffers;
  final String? lostWithBuffers;

  /// Note above the table, e.g. "Simulated: 30 min failure in 8 h".
  final String Function(String period, int minutes)? simulationNote;

  RiskReportLabels withSimulation({
    required String lostWithoutBuffers,
    required String lostWithBuffers,
    required String Function(String period, int minutes) note,
  }) => RiskReportLabels(
    title: title,
    hint: hint,
    machine: machine,
    outputDuring: outputDuring,
    loss: loss,
    standstill: standstill,
    noLoss: noLoss,
    singlePoints: singlePoints,
    lostWithoutBuffers: lostWithoutBuffers,
    lostWithBuffers: lostWithBuffers,
    simulationNote: note,
  );

  final String title;
  final String hint;
  final String machine;

  /// Column: output of the line while the machine is down (per hour).
  final String outputDuring;
  final String loss;
  final String standstill;
  final String noLoss;

  /// Summary of the stations without a spare machine.
  final String Function(int count) singlePoints;
}

/// Texts of the loader cell sections (one per cell of the line).
class CellReportLabels {
  const CellReportLabels({
    required this.title,
    required this.hint,
    required this.resource,
    required this.perPart,
    required this.utilization,
    required this.waiting,
    required this.machines,
    required this.cycleTime,
    required this.optionsTitle,
    required this.notMeasured,
    required this.machineCount,
    required this.loaderParts,
    required this.best,
  });

  final String title;

  /// How the cell is measured and computed.
  final String hint;
  final String resource;

  /// Columns: time per part, utilization and waiting time per own cycle.
  final String perPart;
  final String utilization;
  final String waiting;

  /// Column "number of machines" and name of the machines as bottleneck.
  final String machines;
  final String cycleTime;
  final String optionsTitle;
  final String notMeasured;

  /// "Machine ×3".
  final String Function(String name, int count) machineCount;

  /// "Loader (2 parts per cycle)".
  final String Function(String name, int count) loaderParts;

  /// From how many machines on another machine brings nothing.
  final String Function(int count, String loader) best;

  /// Name of a resource with its count.
  String resourceName(CellResource r) => r.factor == 1
      ? r.name
      : (r.isMachine ? machineCount : loaderParts)(r.name, r.factor);
}

/// Texts of the special cycles table.
class SpecialReportLabels {
  const SpecialReportLabels({
    required this.title,
    required this.machine,
    required this.name,
    required this.rule,
    required this.time,
    required this.measured,
    required this.effective,
    required this.everyParts,
    required this.everyHours,
  });

  final String title;
  final String machine;
  final String name;
  final String rule;

  /// Extra time or stop duration.
  final String time;

  /// Measured and effective cycle time of the machine.
  final String measured;
  final String effective;
  final String Function(int parts) everyParts;
  final String Function(String hours) everyHours;
}

/// Texts of the buffer table.
class BufferReportLabels {
  const BufferReportLabels({
    required this.title,
    required this.before,
    required this.places,
    required this.store,
    required this.retrieve,
    this.conveyorPlaces,
    this.conveyorTime,
  });

  /// Conveyor columns; without them conveyors are left out.
  final String? conveyorPlaces;
  final String? conveyorTime;

  bool get withConveyors => conveyorPlaces != null && conveyorTime != null;

  final String title;

  /// Column: the station the buffer is in front of.
  final String before;
  final String places;
  final String store;
  final String retrieve;
}

/// Everything a group report needs; one [ExportInput] per study in group
/// order. Independent of Flutter.
class GroupReportInput {
  const GroupReportInput({
    required this.group,
    required this.entries,
    required this.unit,
    required this.locale,
    required this.exportedAt,
    required this.labels,
    required this.exportLabels,
    this.simulationHorizonMicros,
    this.simulationFailureMicros,
    this.specialCycles = const {},
    this.areas = const [],
    this.precomputedScenarios,
  });

  /// Failure scenarios computed beforehand (e.g. in a background isolate
  /// for a large plant); [failureScenarios] returns them instead of
  /// simulating.
  final List<FailureScenario>? precomputedScenarios;

  /// This input with [scenarios] as [precomputedScenarios].
  GroupReportInput withFailureScenarios(List<FailureScenario>? scenarios) =>
      GroupReportInput(
        group: group,
        entries: entries,
        unit: unit,
        locale: locale,
        exportedAt: exportedAt,
        labels: labels,
        exportLabels: exportLabels,
        simulationHorizonMicros: simulationHorizonMicros,
        simulationFailureMicros: simulationFailureMicros,
        specialCycles: specialCycles,
        areas: areas,
        precomputedScenarios: scenarios,
      );

  /// The direct areas of the group as spans of [entries] (empty for a
  /// group without areas). The entries of a plant are the flattened studies
  /// of all its areas, see `flattenGroup`.
  final List<LineArea> areas;

  /// The area of every entry (null for a direct study of the group).
  List<String?> get entryAreas => [
    for (var k = 0; k < entries.length; k++)
      areas
          .where((a) => k >= a.start && k < a.end)
          .map((a) => a.group.name)
          .firstOrNull,
  ];

  /// The area of every station of [line] by position (null for a direct
  /// station).
  List<String?> stationAreas(List<AreaFigures> figures, int stations) => [
    for (var p = 0; p < stations; p++)
      figures
          .where(
            (f) =>
                f.firstStation != null &&
                p >= f.firstStation! &&
                p <= f.lastStation!,
          )
          .map((f) => f.area.group.name)
          .firstOrNull,
  ];

  /// Figures of [areas] within the whole line.
  List<AreaFigures> get areaFigures =>
      analyseAreas(line, [for (final x in entries) x.study.parallel], areas);

  /// Special cycles and planned stops per study id.
  final Map<int, List<SpecialCycle>> specialCycles;

  /// Period and failure duration for the simulated failure scenarios
  /// (both needed; only used when the line has buffers).
  final int? simulationHorizonMicros;
  final int? simulationFailureMicros;

  /// Simulated lost parts per machine failure, with and without buffers;
  /// null without simulation settings or without buffers. The failure
  /// starts after a quarter of the period.
  List<FailureScenario>? get failureScenarios {
    if (precomputedScenarios != null) return precomputedScenarios;
    final horizon = simulationHorizonMicros;
    final failure = simulationFailureMicros;
    if (horizon == null || failure == null) return null;
    final sim = LineSimulation.fromLine(line);
    if (!sim.hasBuffers) return null;
    return sim.failureScenarios(
      horizonMicros: horizon,
      durationMicros: failure,
      startMicros: horizon ~/ 4,
    );
  }

  final StudyGroup group;
  final List<ExportInput> entries;
  final TimeUnit unit;
  final String locale;
  final DateTime exportedAt;
  final GroupReportLabels labels;

  /// Generic export texts for the overview (study, mode, real cycle time,
  /// revision ...).
  final ExportLabels exportLabels;

  /// The studies looked at as one line (stations in group order).
  LineAnalysis get line => LineAnalysis.of([
    for (final x in entries)
      LineStationInput(
        name: x.study.name,
        mode: x.study.mode,
        current: x.analysis,
        previous: x.previousAnalysis,
        parallel: x.study.parallel,
        cellLoader: x.study.isCellLoader,
        cellParts: x.study.cellParts,
        cellMachines: x.study.cellMachines,
        waitForSlowest: x.study.waitForSlowest,
        buffer: x.study.hasBuffer
            ? LineBuffer(
                capacity: x.study.bufferCapacity,
                storeMicros: x.study.bufferStoreMicros,
                retrieveMicros: x.study.bufferRetrieveMicros,
              )
            : null,
        specialCycles: specialCycles[x.study.id] ?? const [],
        conveyor: x.study.hasConveyor
            ? LineConveyor(
                capacity: x.study.conveyorCapacity,
                transportMicros: x.study.conveyorTransportMicros,
              )
            : null,
      ),
  ]);
}

/// Excel sheet names: at most 31 characters, none of `[]:*?/\`, unique
/// (case-insensitive). Each name is the position and the study name.
List<String> studySheetNames(
  List<String> studyNames, {
  String reserved = '',
  List<String> alsoReserved = const [],
}) {
  final used = <String>{
    reserved.toLowerCase(),
    for (final r in alsoReserved) r.toLowerCase(),
  };
  final result = <String>[];
  for (var i = 0; i < studyNames.length; i++) {
    final clean = '${i + 1} ${studyNames[i]}'
        .replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    var name = clean.length > 31 ? clean.substring(0, 31).trimRight() : clean;
    var n = 2;
    while (used.contains(name.toLowerCase())) {
      final suffix = ' ($n)';
      final base = clean.length + suffix.length > 31
          ? clean.substring(0, 31 - suffix.length).trimRight()
          : clean;
      name = '$base$suffix';
      n++;
    }
    used.add(name.toLowerCase());
    result.add(name);
  }
  return result;
}

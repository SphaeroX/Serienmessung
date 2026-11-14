import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../core/time_format.dart';
import '../../group/domain/line_analysis.dart';
import '../../group/domain/line_simulation.dart';
import '../../group/domain/special_cycle.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import '../../group/domain/failure_risk.dart';
import '../../group/domain/stations.dart';
import 'group_report.dart';
import 'xlsx_layout.dart';

/// Builds the compact group workbook: an overview sheet (all studies in
/// group order with revision, last measurement, real cycle time and the
/// deviation from the previous revision) and one sheet per study (key
/// figures, steps with deviation, cycle matrix). Times are numeric cells in
/// the report unit; [SheetLayout] gives the sheets their look and column
/// widths.
List<int> buildGroupXlsx(GroupReportInput g) => _build(g, null);

/// Builds the full, linked group workbook: a contents sheet with links to
/// every sheet, a line analysis sheet whose figures are formulas on the
/// study sheets (station cycle times, sum, bottleneck, balance, output per
/// hour), the overview with a link column and the study sheets with a link
/// back to the contents. Excel recalculates the formulas when the file is
/// opened.
List<int> buildGroupReportXlsx(GroupReportInput g, LineReportLabels labels) =>
    _build(g, labels);

/// Column letter of a 0-based column index (A-Z is enough here).
String _col(int index) => String.fromCharCode('A'.codeUnitAt(0) + index);

int _decimalsOf(TimeUnit unit) => switch (unit) {
  TimeUnit.hm => 2,
  TimeUnit.tmu => 1,
  _ => 3,
};

List<int> _build(GroupReportInput g, LineReportLabels? ll) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  final gl = g.labels;
  final el = g.exportLabels;
  final rl = el.revision;
  final numericUnit = g.unit == TimeUnit.stopwatch ? TimeUnit.seconds : g.unit;
  final decimals = _decimalsOf(numericUnit);
  final unit = numericUnit.label;
  CellValue t(String s) => TextCellValue(s);
  CellValue? d(num? micros) => micros == null
      ? null
      : fixed(
          DoubleCellValue(
            _round(numericUnit.fromMicros(micros.round()), decimals),
          ),
          decimals,
        );
  CellValue? pct(double? ratio) =>
      ratio == null ? null : fixed(DoubleCellValue(_round(ratio * 100, 1)), 1);
  CellValue i(int v) => IntCellValue(v);

  // Sheets are created in their final order; contents and line are filled
  // last because they refer to the study sheets.
  final contents = ll == null ? null : excel[ll.contents];
  final lineSheet = ll == null ? null : excel[ll.lineAnalysis];
  final riskSheet = ll?.risk == null ? null : excel[ll!.risk!.title];
  final names = studySheetNames(
    [for (final x in g.entries) x.study.name],
    reserved: gl.overview,
    alsoReserved: ll == null
        ? const []
        : [ll.contents, ll.lineAnalysis, ?ll.risk?.title],
  );

  // Overview.
  final ov = SheetLayout(excel[gl.overview]);
  ov.title(gl.overview);
  ov.keyValue(gl.group, t(g.group.name));
  if (g.group.description.isNotEmpty) {
    ov.keyValue(el.description, t(g.group.description));
  }
  ov.keyValue(el.date, t(DateFormat('yyyy-MM-dd HH:mm').format(g.exportedAt)));
  ov.keyValue(el.unit, t(unit));
  ov.gap();
  ov.header([
    gl.position,
    el.study,
    el.mode,
    rl?.revision ?? '',
    rl?.lastMeasured ?? '',
    gl.cycles,
    '${el.realCycleTime} [$unit]',
    '${gl.previous} [$unit]',
    '${rl?.delta ?? 'Δ'} [$unit]',
    '${rl?.delta ?? 'Δ'} [%]',
    ?ll?.sheet,
  ]);
  var total = 0.0;
  for (var k = 0; k < g.entries.length; k++) {
    final x = g.entries[k];
    final a = x.analysis;
    final c = x.comparison;
    final hasCycles = x.study.mode != StudyMode.stepTimer && a.cycleStats.n > 0;
    if (hasCycles) total += a.realCycleTime;
    ov.row([
      i(k + 1),
      t(x.study.name),
      t(x.labels.modeName),
      i(x.study.revision),
      x.lastMeasuredText == null ? null : t(x.lastMeasuredText!),
      i(a.cycleStats.n),
      hasCycles ? d(a.realCycleTime) : null,
      d(c?.previousCycleTime),
      d(c?.cycleDelta),
      pct(c?.cycleDeltaRatio),
      if (ll != null) sheetLink(names[k], names[k]),
    ]);
  }
  ov.row([t(gl.total), null, null, null, null, null, d(total)], total: true);
  ov.finish();

  // One sheet per study. In the linked workbook the row of the real cycle
  // time (1-based) is remembered for the line formulas.
  final cycleRows = <int, int>{};
  for (var k = 0; k < g.entries.length; k++) {
    final x = g.entries[k];
    final l = x.labels;
    final a = x.analysis;
    final c = x.comparison;
    final sh = SheetLayout(excel[names[k]]);
    if (ll != null) sh.cells([sheetLink(ll.contents, ll.backToContents)]);
    sh.title(x.study.name);
    sh.keyValue(l.study, t(x.study.name));
    if (x.study.description.isNotEmpty) {
      sh.keyValue(l.description, t(x.study.description));
    }
    if (x.study.notes.isNotEmpty) sh.keyValue(l.notes, t(x.study.notes));
    sh.keyValue(l.mode, t(l.modeName));
    if (rl != null) {
      sh.keyValue(rl.revision, i(x.study.revision));
      if (x.lastMeasuredText != null) {
        sh.keyValue(rl.lastMeasured, t(x.lastMeasuredText!));
      }
    }
    sh.keyValue(l.unit, t(unit));
    sh.keyValue(l.method, t(l.methodName));
    sh.gap();
    if (x.study.mode != StudyMode.stepTimer && a.cycleStats.n > 0) {
      cycleRows[k] = sh.keyValue(l.realCycleTime, d(a.realCycleTime));
      if (c?.previousCycleTime != null) {
        sh.keyValue(gl.previous, d(c!.previousCycleTime));
        sh.keyValue('${rl?.delta ?? 'Δ'} [$unit]', d(c.cycleDelta));
        sh.keyValue('${rl?.delta ?? 'Δ'} [%]', pct(c.cycleDeltaRatio));
      }
      sh.keyValue(l.n, i(a.cycleStats.n));
      sh.keyValue(l.mean, d(a.cycleStats.mean));
      sh.keyValue(l.median, d(a.cycleStats.median));
      sh.keyValue(l.min, d(a.cycleStats.min));
      sh.keyValue(l.max, d(a.cycleStats.max));
      sh.keyValue(l.stdDev, d(a.cycleStats.stdDev));
      sh.keyValue('${l.cv} [%]', pct(a.cycleStats.cv));
      sh.keyValue(l.outliersRemoved, i(a.removedCycles));
    }
    sh.keyValue(l.specialTotal, d(a.specialTotal));

    if (a.steps.isNotEmpty) {
      sh.gap();
      sh.header([
        l.stepNo,
        l.step,
        l.n,
        l.mean,
        l.median,
        l.min,
        l.max,
        l.stdDev,
        l.realTime,
        '${l.share} [%]',
        if (c != null) ...[
          '${rl?.then ?? gl.previous} [$unit]',
          '${rl?.delta ?? 'Δ'} [$unit]',
          '${rl?.delta ?? 'Δ'} [%]',
        ],
      ]);
      for (var s = 0; s < a.steps.length; s++) {
        final st = a.steps[s];
        final dev = c?.steps[s];
        sh.row([
          i(st.step.position + 1),
          t(st.step.name),
          i(st.stats.n),
          d(st.stats.mean),
          d(st.stats.median),
          d(st.stats.min),
          d(st.stats.max),
          d(st.stats.stdDev),
          d(st.realTime),
          pct(st.share),
          if (c != null) ...[
            d(dev?.previous),
            d(dev?.delta),
            pct(dev?.deltaRatio),
          ],
        ]);
      }
    }

    if (x.study.mode != StudyMode.stepTimer && x.cycles.isNotEmpty) {
      final steps = x.study.mode.usesSteps ? x.steps : const <StepDefinition>[];
      sh.gap();
      sh.header([
        l.cycle,
        for (final st in steps) '${st.position + 1}. ${st.name} [$unit]',
        '${l.total} [$unit]',
        '${l.specialTotal} [$unit]',
        l.complete,
      ]);
      for (final cy in x.cycles) {
        sh.row([
          i(cy.cycle),
          for (final st in steps)
            () {
              final times = cy.items.where(
                (m) => m.kind == MeasurementKind.normal && m.stepId == st.id,
              );
              return times.isEmpty
                  ? null
                  : d(times.fold<int>(0, (a, m) => a + m.durationMicros));
            }(),
          d(cy.normalTotal),
          d(cy.specialTotal),
          t(cy.isComplete ? l.yes : l.no),
        ]);
      }
    }
    sh.finish();
  }

  if (ll != null) {
    _writeLine(SheetLayout(lineSheet!), g, ll, names, cycleRows, numericUnit);
    if (riskSheet != null) _writeRisk(SheetLayout(riskSheet), g, ll);
    _writeContents(SheetLayout(contents!), g, ll, names);
  }

  excel.setDefaultSheet(ll?.contents ?? gl.overview);
  excel.delete(defaultSheet);
  return excel.encode()!;
}

void _writeContents(
  SheetLayout sh,
  GroupReportInput g,
  LineReportLabels ll,
  List<String> names,
) {
  CellValue t(String s) => TextCellValue(s);
  sh.title(g.labels.title);
  sh.keyValue(g.labels.group, t(g.group.name));
  if (g.group.description.isNotEmpty) {
    sh.keyValue(g.exportLabels.description, t(g.group.description));
  }
  sh.keyValue(
    g.exportLabels.date,
    t(DateFormat('yyyy-MM-dd HH:mm').format(g.exportedAt)),
  );
  sh.gap();
  sh.section(ll.contents);
  sh.cells([sheetLink(ll.lineAnalysis, ll.lineAnalysis)]);
  if (ll.risk != null) {
    sh.cells([sheetLink(ll.risk!.title, ll.risk!.title)]);
  }
  sh.cells([sheetLink(g.labels.overview, g.labels.overview)]);
  sh.gap();
  sh.section(ll.studies);
  for (var k = 0; k < names.length; k++) {
    sh.cells([sheetLink(names[k], names[k]), t(g.entries[k].study.name)]);
  }
  sh.finish();
}

/// Line analysis with formulas: station cycle times refer to the real cycle
/// time cell of each study sheet, the line figures are computed from them.
void _writeLine(
  SheetLayout sh,
  GroupReportInput g,
  LineReportLabels ll,
  List<String> names,
  Map<int, int> cycleRows,
  TimeUnit unit,
) {
  CellValue t(String s) => TextCellValue(s);
  final el = g.exportLabels;
  final gl = g.labels;
  final decimals = _decimalsOf(unit);
  CellValue number(String formula, [int? digits]) =>
      fixed(FormulaCellValue(formula), digits ?? decimals);
  CellValue time(num micros) => fixed(
    DoubleCellValue(
      double.parse(unit.fromMicros(micros.round()).toStringAsFixed(decimals)),
    ),
    decimals,
  );
  // Seconds per unit, for the output per hour.
  final secondsPerUnit = 1 / unit.fromMicros(1000000);
  sh.title(ll.lineAnalysis);
  sh.keyValue(gl.group, t(g.group.name));
  sh.keyValue(el.unit, t(unit.label));
  sh.gap();
  sh.header([
    gl.position,
    ll.station,
    '${el.realCycleTime} [${unit.label}]',
    '${ll.share} [%]',
    '${ll.waiting} [${unit.label}]',
    '${gl.previous} [${unit.label}]',
    '${el.revision?.delta ?? 'Δ'} [${unit.label}]',
  ]);
  final line = g.line;
  final groups = stationGroups([for (final x in g.entries) x.study.parallel]);
  final first = sh.nextRow; // 1-based row of the first station
  final last = first + line.stations.length - 1;
  String range(int col) => '${_col(col)}$first:${_col(col)}$last';
  // Sum and maximum follow the stations after one empty row; their values
  // are in column B.
  final sumCell = '\$B\$${last + 2}';
  final maxCell = '\$B\$${last + 3}';
  for (var k = 0; k < line.stations.length; k++) {
    final row = first + k;
    final station = line.stations[k];
    // Members of the station whose sheet holds a real cycle time, as the
    // effective cycle time of the machine (special cycles included, like
    // the line analysis in the app).
    final refs = [
      for (var j = 0; j < groups[k].length; j++)
        if (cycleRows[groups[k][j]] != null && station.machines[j].measured)
          _effective(
            '${sheetRef(names[groups[k][j]])}!B${cycleRows[groups[k][j]]}',
            station.machines[j].specialCycles,
            unit,
          ),
    ];
    final measured = refs.isNotEmpty && station.cycleTime != null;
    final prev = station.previousCycleTime;
    // Parallel machines add their capacities: 1 / (1/t1 + 1/t2 + ...).
    final cycleFormula = refs.length == 1
        ? refs.single
        : '1/(${[for (final r in refs) '1/${r.contains('/') ? '($r)' : r}'].join('+')})';
    sh.row([
      IntCellValue(k + 1),
      groups[k].length == 1
          ? sheetLink(
              names[groups[k].single],
              g.entries[groups[k].single].study.name,
            )
          : t(_stationName(station, groups[k].length)),
      measured ? number(cycleFormula) : null,
      measured ? number('ROUND(C$row/$sumCell*100,1)', 1) : null,
      measured ? number('ROUND($maxCell-C$row,$decimals)') : null,
      prev == null ? null : time(prev),
      prev == null || !measured ? null : number('ROUND(C$row-F$row,$decimals)'),
    ]);
  }
  sh.gap();
  final sumRow = sh.keyValue(ll.totalTime, number('SUM(${range(2)})'));
  assert(sumRow == last + 2, 'the station formulas point at the sum row');
  sh.keyValue(ll.lineCycleTime, number('MAX(${range(2)})'));
  sh.keyValue(
    ll.bottleneck,
    FormulaCellValue(
      'INDEX(\$B\$$first:\$B\$$last,MATCH($maxCell,${range(2)},0))',
    ),
  );
  sh.keyValue(
    '${ll.balance} [%]',
    number('ROUND($sumCell/(COUNT(${range(2)})*$maxCell)*100,1)', 1),
  );
  sh.keyValue(
    ll.outputPerHour,
    number('ROUND(3600/($maxCell*$secondsPerUnit),1)', 1),
  );
  final bl = ll.buffers;
  final conveyors = bl != null && bl.withConveyors;
  bool listed(LineStation st) =>
      st.bufferBefore != null || (conveyors && st.conveyorBefore != null);
  if (bl != null && line.stations.any(listed)) {
    sh.gap();
    sh.section(bl.title);
    sh.header([
      gl.position,
      bl.before,
      bl.places,
      '${bl.store} [${unit.label}]',
      '${bl.retrieve} [${unit.label}]',
      if (conveyors) ...[
        bl.conveyorPlaces!,
        '${bl.conveyorTime} [${unit.label}]',
      ],
    ]);
    for (final st in line.stations.where(listed)) {
      final b = st.bufferBefore;
      final c = st.conveyorBefore;
      sh.row([
        IntCellValue(st.position + 1),
        t(_stationName(st, groups[st.position].length)),
        b == null ? null : IntCellValue(b.capacity),
        b == null ? null : time(b.storeMicros),
        b == null ? null : time(b.retrieveMicros),
        if (conveyors) ...[
          c == null ? null : IntCellValue(c.capacity),
          c == null ? null : time(c.transportMicros),
        ],
      ]);
    }
  }
  final sl = ll.specials;
  final machines = [
    for (final st in line.stations)
      for (final m in st.machines)
        if (m.specialCycles.isNotEmpty) m,
  ];
  if (sl != null && machines.isNotEmpty) {
    sh.gap();
    sh.section(sl.title);
    sh.header([
      sl.machine,
      sl.name,
      sl.rule,
      '${sl.time} [${unit.label}]',
      '${sl.measured} [${unit.label}]',
      '${sl.effective} [${unit.label}]',
    ]);
    for (final m in machines) {
      final measured = m.baseCycleTime;
      final effective = m.cycleTime;
      for (final c in m.specialCycles) {
        sh.row([
          t(m.name),
          t(c.name),
          t(_rule(sl, c)),
          time(c.durationMicros),
          measured == null ? null : time(measured),
          effective == null ? null : time(effective),
        ]);
      }
    }
  }
  sh.finish();
}

/// Name of a station of [machines] machines: parallel machines get their
/// number (`A / B (×2)`).
String _stationName(LineStation station, int machines) =>
    machines == 1 ? station.name : '${station.name} (×$machines)';

/// Formula of a machine's effective cycle time: `(ref + extra time per
/// part) / availability`, with [ref] the cell of its measured cycle time.
/// Without rules it is just [ref].
String _effective(String ref, List<SpecialCycle> cycles, TimeUnit unit) {
  final extra = extraPerPart(cycles) * unit.fromMicros(1000000) / 1000000;
  final available = availability(cycles);
  var formula = ref;
  if (extra > 0) formula = '($formula+${_plain(extra)})';
  if (available < 1) formula = '$formula/${_plain(available)}';
  return formula;
}

/// Number for a formula: plain decimal notation without trailing zeros.
String _plain(double v) => v
    .toStringAsFixed(9)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

/// Failure scenarios: line output while each machine is down.
void _writeRisk(SheetLayout sh, GroupReportInput g, LineReportLabels ll) {
  CellValue t(String s) => TextCellValue(s);
  CellValue one(double v) => fixed(DoubleCellValue(_round(v, 1)), 1);
  final rl = ll.risk!;
  final risk = FailureRisk.of(g.line);
  final gl = g.labels;
  sh.title(rl.title);
  sh.note(rl.hint);
  sh.keyValue(gl.group, t(g.group.name));
  final base = risk.baseOutput;
  if (base != null) sh.keyValue(ll.outputPerHour, one(base));
  if (risk.singlePoints.isNotEmpty) {
    sh.note(rl.singlePoints(risk.singlePoints.length));
  }
  final simulated = simulatedLosses(g);
  final withSim = simulated != null && rl.lostWithBuffers != null;
  if (withSim && rl.simulationNote != null) {
    sh.note(
      rl.simulationNote!(
        formatDuration(g.simulationHorizonMicros!),
        g.simulationFailureMicros! ~/ 60000000,
      ),
    );
  }
  sh.gap();
  sh.header([
    gl.position,
    rl.machine,
    '${rl.outputDuring} [1/h]',
    '${rl.loss} [%]',
    rl.standstill,
    if (withSim) ...[rl.lostWithoutBuffers!, rl.lostWithBuffers!],
  ]);
  for (final f in risk.failures) {
    final lost = withSim ? simulated[(f.station.position, f.machine)] : null;
    final state = f.standstill ? rl.standstill : (f.loss == 0 ? rl.noLoss : '');
    sh.row([
      IntCellValue(f.station.position + 1),
      t(f.machine),
      one(f.outputAfter),
      one(f.loss * 100),
      state.isEmpty ? null : t(state),
      if (withSim) ...[
        lost == null ? null : IntCellValue(lost.lostWithoutBuffers),
        lost == null ? null : IntCellValue(lost.lostWithBuffers),
      ],
    ]);
  }
  sh.finish();
}

/// Simulated failure scenarios by (station position, machine name); null
/// when the report has no simulation.
Map<(int, String), FailureScenario>? simulatedLosses(GroupReportInput g) {
  final scenarios = g.failureScenarios;
  if (scenarios == null) return null;
  final measured = [
    for (final st in g.line.stations)
      if (st.measured) st.position,
  ];
  return {for (final x in scenarios) (measured[x.station], x.machine): x};
}

/// "every 50 parts" / "every 24 h".
String _rule(SpecialReportLabels sl, SpecialCycle c) =>
    c.kind == SpecialCycleKind.parts
    ? sl.everyParts(c.interval)
    : sl.everyHours(_hours(c.interval));

String _hours(int micros) {
  final h = micros / 3600000000;
  return h == h.roundToDouble() ? '${h.round()}' : h.toStringAsFixed(1);
}

/// Shared with the PDF report.
String specialRule(SpecialReportLabels sl, SpecialCycle c) => _rule(sl, c);

double _round(double v, int decimals) {
  var f = 1.0;
  for (var k = 0; k < decimals; k++) {
    f *= 10;
  }
  return (v * f).roundToDouble() / f;
}

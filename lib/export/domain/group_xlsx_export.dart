import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../core/time_format.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import '../../group/domain/failure_risk.dart';
import '../../group/domain/stations.dart';
import 'group_report.dart';

/// Builds the compact group workbook: an overview sheet (all studies in
/// group order with revision, last measurement, real cycle time and the
/// deviation from the previous revision) and one sheet per study (key
/// figures, steps with deviation, cycle matrix). Times are numeric cells in
/// the report unit.
List<int> buildGroupXlsx(GroupReportInput g) => _build(g, null);

/// Builds the full, linked group workbook: a contents sheet with links to
/// every sheet, a line analysis sheet whose figures are formulas on the
/// study sheets (station cycle times, sum, bottleneck, balance, output per
/// hour), the overview with a link column and the study sheets with a link
/// back to the contents. Excel recalculates the formulas when the file is
/// opened.
List<int> buildGroupReportXlsx(GroupReportInput g, LineReportLabels labels) =>
    _build(g, labels);

/// Quotes a sheet name for formulas (`'name'`).
String _ref(String sheet) => "'${sheet.replaceAll("'", "''")}'";

/// `HYPERLINK` formula to cell A1 of [sheet].
String _link(String sheet, String text) =>
    'HYPERLINK("#${_ref(sheet).replaceAll('"', '""')}!A1",'
    '"${text.replaceAll('"', '""')}")';

/// Column letter of a 0-based column index (A-Z is enough here).
String _col(int index) => String.fromCharCode('A'.codeUnitAt(0) + index);

List<int> _build(GroupReportInput g, LineReportLabels? ll) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  final gl = g.labels;
  final el = g.exportLabels;
  final rl = el.revision;
  final numericUnit = g.unit == TimeUnit.stopwatch ? TimeUnit.seconds : g.unit;
  final decimals = switch (numericUnit) {
    TimeUnit.hm => 2,
    TimeUnit.tmu => 1,
    _ => 3,
  };
  final unit = numericUnit.label;
  CellValue t(String s) => TextCellValue(s);
  CellValue? d(num? micros) => micros == null
      ? null
      : DoubleCellValue(
          _round(numericUnit.fromMicros(micros.round()), decimals),
        );
  CellValue? pct(double? ratio) =>
      ratio == null ? null : DoubleCellValue(_round(ratio * 100, 1));
  CellValue i(int v) => IntCellValue(v);
  final bold = CellStyle(bold: true);
  void header(Sheet sheet, List<String> titles) {
    sheet.appendRow([for (final s in titles) t(s)]);
    final row = sheet.maxRows - 1;
    for (var c = 0; c < titles.length; c++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
              .cellStyle =
          bold;
    }
  }

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
  final ov = excel[gl.overview];
  void kv(Sheet sheet, String k, CellValue? v) => sheet.appendRow([t(k), v]);
  kv(ov, gl.group, t(g.group.name));
  if (g.group.description.isNotEmpty) {
    kv(ov, el.description, t(g.group.description));
  }
  kv(ov, el.date, t(DateFormat('yyyy-MM-dd HH:mm').format(g.exportedAt)));
  kv(ov, el.unit, t(unit));
  ov.appendRow([]);
  header(ov, [
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
    ov.appendRow([
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
      if (ll != null) FormulaCellValue(_link(names[k], names[k])),
    ]);
  }
  ov.appendRow([t(gl.total), null, null, null, null, null, d(total)]);

  // One sheet per study. In the linked workbook the row of the real cycle
  // time (1-based) is remembered for the line formulas.
  final cycleRows = <int, int>{};
  for (var k = 0; k < g.entries.length; k++) {
    final x = g.entries[k];
    final l = x.labels;
    final a = x.analysis;
    final c = x.comparison;
    final sh = excel[names[k]];
    if (ll != null) {
      sh.appendRow([FormulaCellValue(_link(ll.contents, ll.backToContents))]);
    }
    kv(sh, l.study, t(x.study.name));
    if (x.study.description.isNotEmpty) {
      kv(sh, l.description, t(x.study.description));
    }
    if (x.study.notes.isNotEmpty) kv(sh, l.notes, t(x.study.notes));
    kv(sh, l.mode, t(l.modeName));
    if (rl != null) {
      kv(sh, rl.revision, i(x.study.revision));
      if (x.lastMeasuredText != null) {
        kv(sh, rl.lastMeasured, t(x.lastMeasuredText!));
      }
    }
    kv(sh, l.unit, t(unit));
    kv(sh, l.method, t(l.methodName));
    sh.appendRow([]);
    if (x.study.mode != StudyMode.stepTimer && a.cycleStats.n > 0) {
      kv(sh, l.realCycleTime, d(a.realCycleTime));
      cycleRows[k] = sh.maxRows;
      if (c?.previousCycleTime != null) {
        kv(sh, gl.previous, d(c!.previousCycleTime));
        kv(sh, '${rl?.delta ?? 'Δ'} [$unit]', d(c.cycleDelta));
        kv(sh, '${rl?.delta ?? 'Δ'} [%]', pct(c.cycleDeltaRatio));
      }
      kv(sh, l.n, i(a.cycleStats.n));
      kv(sh, l.mean, d(a.cycleStats.mean));
      kv(sh, l.median, d(a.cycleStats.median));
      kv(sh, l.min, d(a.cycleStats.min));
      kv(sh, l.max, d(a.cycleStats.max));
      kv(sh, l.stdDev, d(a.cycleStats.stdDev));
      kv(sh, '${l.cv} [%]', pct(a.cycleStats.cv));
      kv(sh, l.outliersRemoved, i(a.removedCycles));
    }
    kv(sh, l.specialTotal, d(a.specialTotal));

    if (a.steps.isNotEmpty) {
      sh.appendRow([]);
      header(sh, [
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
        sh.appendRow([
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
      sh.appendRow([]);
      header(sh, [
        l.cycle,
        for (final st in steps) '${st.position + 1}. ${st.name} [$unit]',
        '${l.total} [$unit]',
        '${l.specialTotal} [$unit]',
        l.complete,
      ]);
      for (final cy in x.cycles) {
        sh.appendRow([
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
  }

  if (ll != null) {
    _writeLine(lineSheet!, g, ll, names, cycleRows, numericUnit, header, kv);
    if (riskSheet != null) _writeRisk(riskSheet, g, ll, header, kv);
    _writeContents(contents!, g, ll, names, kv);
  }

  excel.setDefaultSheet(ll?.contents ?? gl.overview);
  excel.delete(defaultSheet);
  return excel.encode()!;
}

void _writeContents(
  Sheet sh,
  GroupReportInput g,
  LineReportLabels ll,
  List<String> names,
  void Function(Sheet, String, CellValue?) kv,
) {
  CellValue t(String s) => TextCellValue(s);
  sh.appendRow([t(g.labels.title)]);
  sh.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle =
      CellStyle(bold: true, fontSize: 14);
  kv(sh, g.labels.group, t(g.group.name));
  if (g.group.description.isNotEmpty) {
    kv(sh, g.exportLabels.description, t(g.group.description));
  }
  kv(
    sh,
    g.exportLabels.date,
    t(DateFormat('yyyy-MM-dd HH:mm').format(g.exportedAt)),
  );
  sh.appendRow([]);
  sh.appendRow([t(ll.contents)]);
  sh.appendRow([FormulaCellValue(_link(ll.lineAnalysis, ll.lineAnalysis))]);
  if (ll.risk != null) {
    sh.appendRow([FormulaCellValue(_link(ll.risk!.title, ll.risk!.title))]);
  }
  sh.appendRow([FormulaCellValue(_link(g.labels.overview, g.labels.overview))]);
  sh.appendRow([]);
  sh.appendRow([t(ll.studies)]);
  for (var k = 0; k < names.length; k++) {
    sh.appendRow([
      FormulaCellValue(_link(names[k], names[k])),
      t(g.entries[k].study.name),
    ]);
  }
}

/// Line analysis with formulas: station cycle times refer to the real cycle
/// time cell of each study sheet, the line figures are computed from them.
void _writeLine(
  Sheet sh,
  GroupReportInput g,
  LineReportLabels ll,
  List<String> names,
  Map<int, int> cycleRows,
  TimeUnit unit,
  void Function(Sheet, List<String>) header,
  void Function(Sheet, String, CellValue?) kv,
) {
  CellValue t(String s) => TextCellValue(s);
  final el = g.exportLabels;
  final gl = g.labels;
  final decimals = switch (unit) {
    TimeUnit.hm => 2,
    TimeUnit.tmu => 1,
    _ => 3,
  };
  // Seconds per unit, for the output per hour.
  final secondsPerUnit = 1 / unit.fromMicros(1000000);
  kv(sh, gl.group, t(g.group.name));
  kv(sh, el.unit, t(unit.label));
  sh.appendRow([]);
  header(sh, [
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
  final first = sh.maxRows + 1; // 1-based row of the first station
  final last = first + line.stations.length - 1;
  String range(int col) => '${_col(col)}$first:${_col(col)}$last';
  // Sum and maximum follow directly behind the stations (the excel package
  // does not write empty rows); their values are in column B.
  final sumCell = '\$B\$${last + 1}';
  final maxCell = '\$B\$${last + 2}';
  for (var k = 0; k < line.stations.length; k++) {
    final row = first + k;
    final station = line.stations[k];
    // Members of the station whose sheet holds a real cycle time.
    final refs = [
      for (final e in groups[k])
        if (cycleRows[e] != null &&
            station.machines[groups[k].indexOf(e)].measured)
          '${_ref(names[e])}!B${cycleRows[e]}',
    ];
    final measured = refs.isNotEmpty && station.cycleTime != null;
    final prev = station.previousCycleTime;
    // Parallel machines add their capacities: 1 / (1/t1 + 1/t2 + ...).
    final cycleFormula = refs.length == 1
        ? refs.single
        : '1/(${[for (final r in refs) '1/$r'].join('+')})';
    sh.appendRow([
      IntCellValue(k + 1),
      groups[k].length == 1
          ? FormulaCellValue(
              _link(
                names[groups[k].single],
                g.entries[groups[k].single].study.name,
              ),
            )
          : t('${station.name} (×${groups[k].length})'),
      measured ? FormulaCellValue(cycleFormula) : null,
      measured ? FormulaCellValue('ROUND(C$row/$sumCell*100,1)') : null,
      measured ? FormulaCellValue('ROUND($maxCell-C$row,$decimals)') : null,
      prev == null
          ? null
          : DoubleCellValue(
              double.parse(
                unit.fromMicros(prev.round()).toStringAsFixed(decimals),
              ),
            ),
      prev == null || !measured
          ? null
          : FormulaCellValue('ROUND(C$row-F$row,$decimals)'),
    ]);
  }
  kv(sh, ll.totalTime, FormulaCellValue('SUM(${range(2)})'));
  kv(sh, ll.lineCycleTime, FormulaCellValue('MAX(${range(2)})'));
  kv(
    sh,
    ll.bottleneck,
    FormulaCellValue(
      'INDEX(\$B\$$first:\$B\$$last,MATCH($maxCell,${range(2)},0))',
    ),
  );
  kv(
    sh,
    '${ll.balance} [%]',
    FormulaCellValue('ROUND($sumCell/(COUNT(${range(2)})*$maxCell)*100,1)'),
  );
  kv(
    sh,
    ll.outputPerHour,
    FormulaCellValue('ROUND(3600/($maxCell*$secondsPerUnit),1)'),
  );
}

/// Failure scenarios: line output while each machine is down.
void _writeRisk(
  Sheet sh,
  GroupReportInput g,
  LineReportLabels ll,
  void Function(Sheet, List<String>) header,
  void Function(Sheet, String, CellValue?) kv,
) {
  CellValue t(String s) => TextCellValue(s);
  final rl = ll.risk!;
  final risk = FailureRisk.of(g.line);
  final gl = g.labels;
  kv(sh, gl.group, t(g.group.name));
  kv(sh, rl.title, t(rl.hint));
  final base = risk.baseOutput;
  if (base != null) {
    kv(sh, ll.outputPerHour, DoubleCellValue(_round(base, 1)));
  }
  if (risk.singlePoints.isNotEmpty) {
    sh.appendRow([t(rl.singlePoints(risk.singlePoints.length))]);
  }
  header(sh, [
    gl.position,
    rl.machine,
    '${rl.outputDuring} [1/h]',
    '${rl.loss} [%]',
    rl.standstill,
  ]);
  for (final f in risk.failures) {
    sh.appendRow([
      IntCellValue(f.station.position + 1),
      t(f.machine),
      DoubleCellValue(_round(f.outputAfter, 1)),
      DoubleCellValue(_round(f.loss * 100, 1)),
      t(f.standstill ? rl.standstill : (f.loss == 0 ? rl.noLoss : '')),
    ]);
  }
}

double _round(double v, int decimals) {
  var f = 1.0;
  for (var k = 0; k < decimals; k++) {
    f *= 10;
  }
  return (v * f).roundToDouble() / f;
}

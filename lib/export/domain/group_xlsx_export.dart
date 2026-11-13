import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../core/time_format.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import 'group_report.dart';

/// Builds the group workbook: an overview sheet (all studies in group order
/// with revision, last measurement, real cycle time and the deviation from
/// the previous revision) and one sheet per study (key figures, steps with
/// deviation, cycle matrix). Times are numeric cells in the report unit.
List<int> buildGroupXlsx(GroupReportInput g) {
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
    ]);
  }
  ov.appendRow([t(gl.total), null, null, null, null, null, d(total)]);

  // One sheet per study.
  final names = studySheetNames([
    for (final x in g.entries) x.study.name,
  ], reserved: gl.overview);
  for (var k = 0; k < g.entries.length; k++) {
    final x = g.entries[k];
    final l = x.labels;
    final a = x.analysis;
    final c = x.comparison;
    final sh = excel[names[k]];
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

  excel.setDefaultSheet(gl.overview);
  excel.delete(defaultSheet);
  return excel.encode()!;
}

double _round(double v, int decimals) {
  var f = 1.0;
  for (var k = 0; k < decimals; k++) {
    f *= 10;
  }
  return (v * f).roundToDouble() / f;
}

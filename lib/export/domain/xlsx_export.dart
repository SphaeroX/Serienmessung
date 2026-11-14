import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import 'export_data.dart';
import 'xlsx_layout.dart';

/// Builds an Excel workbook with the sheets Measurements, Cycles (not for
/// the step timer) and Analysis. Times are numeric cells in the export unit
/// (the stopwatch format is exported as seconds). [SheetLayout] gives the
/// sheets their look and column widths.
List<int> buildXlsx(ExportInput x) {
  final l = x.labels;
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  final unit = x.numericUnit.label;
  CellValue t(String s) => TextCellValue(s);
  CellValue d(num micros) =>
      fixed(DoubleCellValue(_round(x.value(micros), x.decimals)), x.decimals);
  CellValue pct(double ratio) =>
      fixed(DoubleCellValue(_round(ratio * 100, 1)), 1);
  CellValue i(int v) => IntCellValue(v);

  // Measurements.
  final ms = SheetLayout(excel[l.measurementsSheet]);
  ms.header([
    l.cycle,
    l.stepNo,
    l.step,
    '${l.start} [$unit]',
    '${l.end} [$unit]',
    '${l.duration} [$unit]',
    l.type,
    l.note,
  ]);
  final base = x.timeBase;
  for (final m in x.measurements) {
    final no = x.stepNumber(m);
    ms.row([
      i(m.cycle),
      no.isEmpty ? null : i(int.parse(no)),
      t(x.stepName(m)),
      d(m.startMicros - base),
      d(m.endMicros - base),
      d(m.durationMicros),
      t(m.kind == MeasurementKind.special ? l.special : l.normal),
      m.note.isEmpty ? null : t(m.note),
    ]);
  }
  ms.finish();

  // Cycle matrix: one row per cycle, one column per step.
  if (x.study.mode != StudyMode.stepTimer) {
    final cs = SheetLayout(excel[l.cyclesSheet]);
    final steps = x.study.mode.usesSteps ? x.steps : const <StepDefinition>[];
    cs.header([
      l.cycle,
      for (final s in steps) '${s.position + 1}. ${s.name} [$unit]',
      '${l.total} [$unit]',
      '${l.specialTotal} [$unit]',
      l.complete,
    ]);
    for (final g in x.cycles) {
      cs.row([
        i(g.cycle),
        for (final s in steps)
          () {
            final times = g.items.where(
              (m) => m.kind == MeasurementKind.normal && m.stepId == s.id,
            );
            if (times.isEmpty) return null;
            return d(times.fold<int>(0, (a, m) => a + m.durationMicros));
          }(),
        d(g.normalTotal),
        d(g.specialTotal),
        t(g.isComplete ? l.yes : l.no),
      ]);
    }
    cs.finish();
  }

  // Analysis: title, study information, key figures, steps.
  final a = x.analysis;
  final an = SheetLayout(excel[l.analysisSheet]);
  an.title(l.analysisSheet);
  an.keyValue(l.study, t(x.study.name));
  if (x.study.description.isNotEmpty) {
    an.keyValue(l.description, t(x.study.description));
  }
  if (x.study.notes.isNotEmpty) an.keyValue(l.notes, t(x.study.notes));
  an.keyValue(l.mode, t(l.modeName));
  final r = l.revision;
  if (r != null) {
    an.keyValue(r.revision, t('${x.study.revision}'));
    if (x.lastMeasuredText != null) {
      an.keyValue(r.lastMeasured, t(x.lastMeasuredText!));
    }
  }
  an.keyValue(l.date, t(DateFormat('yyyy-MM-dd HH:mm').format(x.exportedAt)));
  an.keyValue(l.unit, t(unit));
  an.keyValue(l.method, t(l.methodName));
  an.gap();
  if (x.study.mode != StudyMode.stepTimer && a.cycleStats.n > 0) {
    an.keyValue(l.realCycleTime, d(a.realCycleTime));
    an.keyValue(l.n, i(a.cycleStats.n));
    an.keyValue(l.mean, d(a.cycleStats.mean));
    an.keyValue(l.median, d(a.cycleStats.median));
    an.keyValue(l.min, d(a.cycleStats.min));
    an.keyValue(l.max, d(a.cycleStats.max));
    an.keyValue(l.stdDev, d(a.cycleStats.stdDev));
    an.keyValue('${l.cv} [%]', pct(a.cycleStats.cv));
    an.keyValue(l.outliersRemoved, i(a.removedCycles));
  }
  an.keyValue(l.specialTotal, d(a.specialTotal));
  if (a.steps.isNotEmpty) {
    an.gap();
    an.header([
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
    ]);
    for (final s in a.steps) {
      an.row([
        i(s.step.position + 1),
        t(s.step.name),
        i(s.stats.n),
        d(s.stats.mean),
        d(s.stats.median),
        d(s.stats.min),
        d(s.stats.max),
        d(s.stats.stdDev),
        d(s.realTime),
        pct(s.share),
      ]);
    }
  }
  an.finish();

  excel.setDefaultSheet(l.analysisSheet);
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

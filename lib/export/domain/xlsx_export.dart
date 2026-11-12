import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import 'export_data.dart';

/// Builds an Excel workbook with the sheets Measurements, Cycles (not for
/// the step timer) and Analysis. Times are numeric cells in the export unit
/// (the stopwatch format is exported as seconds).
List<int> buildXlsx(ExportInput x) {
  final l = x.labels;
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  final unit = x.numericUnit.label;
  CellValue t(String s) => TextCellValue(s);
  CellValue d(num micros) =>
      DoubleCellValue(_round(x.value(micros), x.decimals));
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

  // Measurements.
  final ms = excel[l.measurementsSheet];
  header(ms, [
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
    ms.appendRow([
      i(m.cycle),
      no.isEmpty ? null : i(int.parse(no)),
      t(x.stepName(m)),
      d(m.startMicros - base),
      d(m.endMicros - base),
      d(m.durationMicros),
      t(m.kind == MeasurementKind.special ? l.special : l.normal),
      t(m.note),
    ]);
  }

  // Cycle matrix: one row per cycle, one column per step.
  if (x.study.mode != StudyMode.stepTimer) {
    final cs = excel[l.cyclesSheet];
    final steps = x.study.mode.usesSteps ? x.steps : const <StepDefinition>[];
    header(cs, [
      l.cycle,
      for (final s in steps) '${s.position + 1}. ${s.name} [$unit]',
      '${l.total} [$unit]',
      '${l.specialTotal} [$unit]',
      l.complete,
    ]);
    for (final g in x.cycles) {
      cs.appendRow([
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
  }

  // Analysis with header information.
  final a = x.analysis;
  final an = excel[l.analysisSheet];
  void kv(String k, CellValue? v) => an.appendRow([t(k), v]);
  kv(l.study, t(x.study.name));
  if (x.study.description.isNotEmpty) kv(l.description, t(x.study.description));
  if (x.study.notes.isNotEmpty) kv(l.notes, t(x.study.notes));
  kv(l.mode, t(l.modeName));
  kv(l.date, t(DateFormat('yyyy-MM-dd HH:mm').format(x.exportedAt)));
  kv(l.unit, t(unit));
  kv(l.method, t(l.methodName));
  an.appendRow([]);
  if (x.study.mode != StudyMode.stepTimer && a.cycleStats.n > 0) {
    kv(l.realCycleTime, d(a.realCycleTime));
    kv(l.n, i(a.cycleStats.n));
    kv(l.mean, d(a.cycleStats.mean));
    kv(l.median, d(a.cycleStats.median));
    kv(l.min, d(a.cycleStats.min));
    kv(l.max, d(a.cycleStats.max));
    kv(l.stdDev, d(a.cycleStats.stdDev));
    kv('${l.cv} [%]', DoubleCellValue(_round(a.cycleStats.cv * 100, 1)));
    kv(l.outliersRemoved, i(a.removedCycles));
  }
  kv(l.specialTotal, d(a.specialTotal));
  if (a.steps.isNotEmpty) {
    an.appendRow([]);
    header(an, [
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
      an.appendRow([
        i(s.step.position + 1),
        t(s.step.name),
        i(s.stats.n),
        d(s.stats.mean),
        d(s.stats.median),
        d(s.stats.min),
        d(s.stats.max),
        d(s.stats.stdDev),
        d(s.realTime),
        DoubleCellValue(_round(s.share * 100, 1)),
      ]);
    }
  }

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

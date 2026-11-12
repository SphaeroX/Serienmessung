import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/time_format.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import 'export_data.dart';

/// Texts only the PDF report needs.
class PdfLabels {
  const PdfLabels({
    required this.title,
    required this.keyFigures,
    required this.steps,
    required this.cycles,
    required this.specialTimes,
    required this.pageOf,
    required this.noData,
  });

  final String title;
  final String keyFigures;
  final String steps;
  final String cycles;
  final String specialTimes;
  final String Function(int page, int pages) pageOf;
  final String noData;
}

/// Matrix layout up to this many steps; more steps are listed per cycle.
const maxMatrixSteps = 8;

/// Builds a printable A4 report. [compress] can be switched off in tests to
/// inspect the text.
Future<Uint8List> buildPdfReport(
  ExportInput x,
  PdfLabels p, {
  bool compress = true,
}) async {
  final l = x.labels;
  final a = x.analysis;
  final unit = x.unit;
  final doc = pw.Document(compress: compress, title: x.study.name);
  String t(num micros) => _latin1(
    formatTime(
      micros.round(),
      unit,
      decimals: switch (unit) {
        TimeUnit.hm => 1,
        TimeUnit.seconds => 2,
        _ => 0,
      },
      locale: x.locale,
    ),
  );
  String s(String v) => _latin1(v);
  final date = DateFormat('yyyy-MM-dd HH:mm').format(x.exportedAt);
  const small = pw.TextStyle(fontSize: 8);
  final header = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
  final hasCycles = x.study.mode != StudyMode.stepTimer;

  pw.Widget section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
    child: pw.Text(
      s(title),
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget table(List<String> head, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: head.map(s).toList(),
        data: rows.map((r) => r.map(s).toList()).toList(),
        headerStyle: header,
        cellStyle: small,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignment: pw.Alignment.centerLeft,
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(s('${p.title} · $date'), style: small),
          pw.Text(s(p.pageOf(ctx.pageNumber, ctx.pagesCount)), style: small),
        ],
      ),
      build: (ctx) => [
        pw.Text(
          s(p.title),
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          s(x.study.name),
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        if (x.study.description.isNotEmpty)
          pw.Text(
            s(x.study.description),
            style: const pw.TextStyle(fontSize: 10),
          ),
        if (x.study.notes.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            s(l.notes),
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(s(x.study.notes), style: const pw.TextStyle(fontSize: 10)),
        ],
        pw.SizedBox(height: 6),
        pw.Text(
          s(
            '${l.mode}: ${l.modeName}   ${l.date}: $date   '
            '${l.unit}: ${unit.label}   ${l.method}: ${l.methodName}',
          ),
          style: small,
        ),
        section(p.keyFigures),
        if (x.measurements.isEmpty)
          pw.Text(s(p.noData), style: small)
        else
          table(
            ['', ''],
            [
              if (hasCycles && a.cycleStats.n > 0) ...[
                [l.realCycleTime, t(a.realCycleTime)],
                [l.n, '${a.cycleStats.n}'],
                [l.mean, t(a.cycleStats.mean)],
                [l.median, t(a.cycleStats.median)],
                [l.min, t(a.cycleStats.min)],
                [l.max, t(a.cycleStats.max)],
                [l.stdDev, t(a.cycleStats.stdDev)],
                [
                  l.cv,
                  '${formatNumber(a.cycleStats.cv * 100, 1, locale: x.locale)} %',
                ],
                [l.outliersRemoved, '${a.removedCycles}'],
              ],
              [l.specialTotal, '${t(a.specialTotal)} (${a.specialCount})'],
            ],
          ),
        if (a.steps.isNotEmpty) ...[
          section(p.steps),
          table(
            [
              l.stepNo,
              l.step,
              l.n,
              l.mean,
              l.median,
              l.min,
              l.max,
              l.realTime,
              l.share,
            ],
            [
              for (final st in a.steps)
                [
                  '${st.step.position + 1}',
                  st.step.name,
                  '${st.stats.n}',
                  t(st.stats.mean),
                  t(st.stats.median),
                  t(st.stats.min),
                  t(st.stats.max),
                  t(st.realTime),
                  '${formatNumber(st.share * 100, 1, locale: x.locale)} %',
                ],
            ],
          ),
        ],
        if (hasCycles && x.cycles.isNotEmpty) ...[
          section(p.cycles),
          _cycleTable(x, table, t),
        ],
        if (x.measurements.any((m) => m.kind == MeasurementKind.special)) ...[
          section(p.specialTimes),
          table(
            [l.cycle, l.step, l.duration, l.note],
            [
              for (final m in x.measurements.where(
                (m) => m.kind == MeasurementKind.special,
              ))
                [
                  '${m.cycle}',
                  x.stepById(m.stepId)?.name ?? '',
                  t(m.durationMicros),
                  m.note,
                ],
            ],
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

pw.Widget _cycleTable(
  ExportInput x,
  pw.Widget Function(List<String>, List<List<String>>) table,
  String Function(num) t,
) {
  final l = x.labels;
  final steps = x.study.mode.usesSteps ? x.steps : const <StepDefinition>[];
  final matrix = steps.length <= maxMatrixSteps;
  return table(
    [
      l.cycle,
      if (matrix)
        for (final st in steps) '${st.position + 1}',
      l.total,
      l.specialTotal,
      l.complete,
    ],
    [
      for (final g in x.cycles)
        [
          '${g.cycle}',
          if (matrix)
            for (final st in steps)
              () {
                final times = g.items.where(
                  (m) => m.kind == MeasurementKind.normal && m.stepId == st.id,
                );
                return times.isEmpty
                    ? '–'
                    : t(times.fold<int>(0, (a, m) => a + m.durationMicros));
              }(),
          t(g.normalTotal),
          g.specialTotal == 0 ? '' : t(g.specialTotal),
          g.isComplete ? l.yes : l.no,
        ],
    ],
  );
}

/// The built-in PDF fonts cover Latin-1 only; replace common typographic
/// characters and drop anything else that cannot be drawn.
String _latin1(String v) {
  final mapped = v
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('·', '·')
      .replaceAll(RegExp('[„“”]'), '"')
      .replaceAll(RegExp('[‚‘’]'), "'")
      .replaceAll('…', '...')
      .replaceAll('×', 'x');
  return String.fromCharCodes(
    mapped.runes.map((r) => r <= 0xFF ? r : 0x3F), // '?'
  );
}

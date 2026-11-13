import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/time_format.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import '../../revision/domain/revision_comparison.dart';
import 'export_data.dart';
import 'group_report.dart';

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
  final doc = pw.Document(compress: compress, title: x.study.name);
  final date = DateFormat('yyyy-MM-dd HH:mm').format(x.exportedAt);
  doc.addPage(_page(_footer(p, p.title, date), _studyWidgets(x, p)));
  return doc.save();
}

/// Builds the group report: an overview page with all studies in group
/// order, then every study from a new page. Page numbers run through the
/// whole document.
Future<Uint8List> buildGroupPdf(
  GroupReportInput g,
  PdfLabels p, {
  bool compress = true,
}) async {
  final doc = pw.Document(compress: compress, title: g.group.name);
  final date = DateFormat('yyyy-MM-dd HH:mm').format(g.exportedAt);
  final footer = _footer(p, g.labels.title, date);
  doc.addPage(_page(footer, _groupOverview(g, p, date)));
  for (final x in g.entries) {
    doc.addPage(_page(footer, _studyWidgets(x, p)));
  }
  return doc.save();
}

const _small = pw.TextStyle(fontSize: 8);

pw.Widget Function(pw.Context) _footer(
  PdfLabels p,
  String title,
  String date,
) =>
    (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(_latin1('$title · $date'), style: _small),
        pw.Text(
          _latin1(p.pageOf(ctx.pageNumber, ctx.pagesCount)),
          style: _small,
        ),
      ],
    );

pw.MultiPage _page(
  pw.Widget Function(pw.Context) footer,
  List<pw.Widget> content,
) => pw.MultiPage(
  pageFormat: PdfPageFormat.a4,
  margin: const pw.EdgeInsets.all(32),
  footer: footer,
  build: (ctx) => content,
);

pw.Widget _section(String title) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
  child: pw.Text(
    _latin1(title),
    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
  ),
);

pw.Widget _table(
  List<String> head,
  List<List<String>> rows, {
  Map<int, pw.TableColumnWidth>? columnWidths,
}) => pw.TableHelper.fromTextArray(
  columnWidths: columnWidths,
  headers: head.map(_latin1).toList(),
  data: rows.map((r) => r.map(_latin1).toList()).toList(),
  headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
  cellStyle: _small,
  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
  cellAlignment: pw.Alignment.centerLeft,
  border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
);

int _decimals(TimeUnit unit) => switch (unit) {
  TimeUnit.hm => 1,
  TimeUnit.seconds => 2,
  _ => 0,
};

/// Overview page of the group report.
List<pw.Widget> _groupOverview(GroupReportInput g, PdfLabels p, String date) {
  final gl = g.labels;
  final el = g.exportLabels;
  final rl = el.revision;
  final unit = g.unit;
  String t(num? micros) => micros == null
      ? ''
      : formatTime(
          micros.round(),
          unit,
          decimals: _decimals(unit),
          locale: g.locale,
        );
  var total = 0.0;
  final rows = <List<String>>[];
  for (var k = 0; k < g.entries.length; k++) {
    final x = g.entries[k];
    final a = x.analysis;
    final c = x.comparison;
    final hasCycles = x.study.mode != StudyMode.stepTimer && a.cycleStats.n > 0;
    if (hasCycles) total += a.realCycleTime;
    rows.add([
      '${k + 1}',
      x.study.name,
      x.labels.modeName,
      '${x.study.revision}',
      x.lastMeasuredText ?? '',
      '${a.cycleStats.n}',
      hasCycles ? t(a.realCycleTime) : '',
      t(c?.previousCycleTime),
      c?.cycleDelta == null
          ? ''
          : '${formatDelta(c!.cycleDelta!, unit, decimals: _decimals(unit), locale: g.locale)}'
                ' (${formatRatioDelta(c.cycleDeltaRatio ?? 0, locale: g.locale)})',
    ]);
  }
  return [
    pw.Text(
      _latin1(gl.title),
      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
    ),
    pw.Text(
      _latin1(g.group.name),
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    ),
    if (g.group.description.isNotEmpty)
      pw.Text(
        _latin1(g.group.description),
        style: const pw.TextStyle(fontSize: 10),
      ),
    pw.SizedBox(height: 6),
    pw.Text(
      _latin1('${el.date}: $date   ${el.unit}: ${unit.label}'),
      style: _small,
    ),
    _section(gl.overview),
    if (g.entries.isEmpty)
      pw.Text(_latin1(p.noData), style: _small)
    else
      _table(
        [
          gl.position,
          el.study,
          el.mode,
          rl?.revision ?? '',
          rl?.lastMeasured ?? '',
          gl.cycles,
          el.realCycleTime,
          gl.previous,
          rl?.delta ?? '',
        ],
        [
          ...rows,
          ['', gl.total, '', '', '', '', t(total), '', ''],
        ],
        columnWidths: const {
          0: pw.FixedColumnWidth(26),
          1: pw.FlexColumnWidth(3),
          2: pw.FlexColumnWidth(1.6),
          3: pw.FixedColumnWidth(44),
          4: pw.FixedColumnWidth(66),
          5: pw.FixedColumnWidth(36),
          6: pw.FlexColumnWidth(1.4),
          7: pw.FlexColumnWidth(1.4),
          8: pw.FlexColumnWidth(2),
        },
      ),
  ];
}

/// Header, key figures, steps, deviation, cycles and special times of one
/// study.
List<pw.Widget> _studyWidgets(ExportInput x, PdfLabels p) {
  final l = x.labels;
  final rl = l.revision;
  final a = x.analysis;
  final c = x.comparison;
  final unit = x.unit;
  String t(num micros) => formatTime(
    micros.round(),
    unit,
    decimals: _decimals(unit),
    locale: x.locale,
  );
  String s(String v) => _latin1(v);
  final date = DateFormat('yyyy-MM-dd HH:mm').format(x.exportedAt);
  final hasCycles = x.study.mode != StudyMode.stepTimer;
  final table = _table;
  final section = _section;
  const small = _small;
  return [
    pw.Text(
      s(p.title),
      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
    ),
    pw.Text(
      s(x.study.name),
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    ),
    if (x.study.description.isNotEmpty)
      pw.Text(s(x.study.description), style: const pw.TextStyle(fontSize: 10)),
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
    if (rl != null)
      pw.Text(
        s(
          '${rl.revision}: ${x.study.revision}'
          '${x.lastMeasuredText == null ? '' : '   ${rl.lastMeasured}: ${x.lastMeasuredText}'}',
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
    if (c != null && rl != null) ...[
      section(rl.deviationFrom(x.previous!.number)),
      _deviationTable(x, c, rl, t),
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
  ];
}

pw.Widget _deviationTable(
  ExportInput x,
  RevisionComparison c,
  RevisionLabels rl,
  String Function(num) t,
) {
  final l = x.labels;
  String opt(double? v) => v == null ? '-' : t(v);
  String delta(double? d, double? ratio) => d == null
      ? '-'
      : '${formatDelta(d, x.unit, decimals: _decimals(x.unit), locale: x.locale)}'
            '${ratio == null ? '' : ' (${formatRatioDelta(ratio, locale: x.locale)})'}';
  final hasCycles = x.study.mode != StudyMode.stepTimer;
  return _table(
    [l.step, rl.then, rl.now, rl.delta],
    [
      if (hasCycles)
        [
          l.realCycleTime,
          opt(c.previousCycleTime),
          opt(c.currentCycleTime),
          delta(c.cycleDelta, c.cycleDeltaRatio),
        ],
      for (final st in c.steps)
        [
          st.name,
          opt(st.previous),
          opt(st.current),
          delta(st.delta, st.deltaRatio),
        ],
    ],
  );
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
      .replaceAll('×', 'x')
      .replaceAll('Δ', 'Delta')
      .replaceAll('±', '±');
  return String.fromCharCodes(
    mapped.runes.map((r) => r <= 0xFF ? r : 0x3F), // '?'
  );
}

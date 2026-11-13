import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/time_format.dart';
import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import '../../revision/domain/revision_comparison.dart';
import 'export_data.dart';
import '../../group/domain/failure_risk.dart';
import '../../group/domain/line_analysis.dart';
import 'group_report.dart';
import 'group_xlsx_export.dart' show simulatedLosses;

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

/// Builds the full group report: a cover with the line key figures and a
/// clickable table of contents (with page numbers and PDF bookmarks), the
/// line analysis (bar chart and station table), the overview and every
/// study from a new page.
///
/// The document is laid out twice: the first pass finds the page of every
/// section, the second prints these numbers in the contents. [onSections]
/// receives the section pages (`line`, `overview`, `study0` ...).
Future<Uint8List> buildGroupReportPdf(
  GroupReportInput g,
  PdfLabels p,
  LineReportLabels ll, {
  bool compress = true,
  void Function(Map<String, int> sections)? onSections,
}) async {
  final date = DateFormat('yyyy-MM-dd HH:mm').format(g.exportedAt);
  final footer = _footer(p, g.labels.title, date);
  final line = g.line;

  (pw.Document, Map<String, int>) build(Map<String, int> pages) {
    final doc = pw.Document(compress: compress, title: g.group.name);
    final found = <String, int>{};
    int next() => doc.document.pdfPageList.pages.length + 1;
    doc.addPage(_page(footer, _cover(g, p, ll, line, pages, date)));
    found['line'] = next();
    doc.addPage(_page(footer, _lineSection(g, ll, line)));
    if (ll.risk != null) {
      found['risk'] = next();
      doc.addPage(_page(footer, _riskSection(g, ll, line)));
    }
    found['overview'] = next();
    doc.addPage(
      _page(footer, [
        ..._groupOverview(g, p, date).skipWhile((w) => w is! _Marker),
      ]),
    );
    for (var k = 0; k < g.entries.length; k++) {
      found['study$k'] = next();
      doc.addPage(
        _page(footer, [
          pw.Outline(
            name: 'study$k',
            title: _latin1('${k + 1}. ${g.entries[k].study.name}'),
            level: 1,
            child: pw.SizedBox(),
          ),
          ..._studyWidgets(g.entries[k], p),
        ]),
      );
    }
    return (doc, found);
  }

  final (_, pages) = build(const {});
  final (doc, found) = build(pages);
  onSections?.call(found);
  return doc.save();
}

/// Marks where the overview section starts in [_groupOverview], so the full
/// report can use the overview without the group header.
class _Marker extends pw.StatelessWidget {
  _Marker(this.child);

  final pw.Widget child;

  @override
  pw.Widget build(pw.Context context) => child;
}

String _fmt(GroupReportInput g, num micros) => formatTime(
  micros.round(),
  g.unit,
  decimals: _decimals(g.unit),
  locale: g.locale,
);

/// Line key figures as label/value rows.
List<List<String>> _lineFigures(
  GroupReportInput g,
  LineReportLabels ll,
  LineAnalysis line,
) {
  String delta(double? d, double? ratio) => d == null
      ? ''
      : '  (${formatDelta(d, g.unit, decimals: _decimals(g.unit), locale: g.locale)}'
            '${ratio == null ? '' : ', ${formatRatioDelta(ratio, locale: g.locale)}'})';
  return [
    [
      ll.totalTime,
      '${_fmt(g, line.totalTime)}${delta(line.totalDelta, line.totalDeltaRatio)}',
    ],
    [
      ll.lineCycleTime,
      line.lineCycleTime == null
          ? '-'
          : '${_fmt(g, line.lineCycleTime!)}${delta(line.lineCycleDelta, null)}',
    ],
    [ll.bottleneck, line.bottleneck?.name ?? '-'],
    [
      ll.balance,
      line.balance == null
          ? '-'
          : '${formatNumber(line.balance! * 100, 1, locale: g.locale)} %',
    ],
    [
      ll.outputPerHour,
      line.outputPerHour == null
          ? '-'
          : formatNumber(line.outputPerHour!, 1, locale: g.locale),
    ],
  ];
}

List<pw.Widget> _cover(
  GroupReportInput g,
  PdfLabels p,
  LineReportLabels ll,
  LineAnalysis line,
  Map<String, int> pages,
  String date,
) {
  final gl = g.labels;
  final el = g.exportLabels;
  pw.Widget entry(String key, String title, {int level = 0}) => pw.Link(
    destination: key,
    child: pw.Padding(
      padding: pw.EdgeInsets.only(left: 14.0 * level, bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            _latin1(title),
            style: pw.TextStyle(
              fontSize: level == 0 ? 11 : 10,
              fontWeight: level == 0 ? pw.FontWeight.bold : null,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Divider(
              borderStyle: pw.BorderStyle.dotted,
              thickness: 0.5,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            '${pages[key] ?? 0}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );
  return [
    pw.SizedBox(height: 60),
    pw.Text(
      _latin1(gl.title),
      style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
    ),
    pw.SizedBox(height: 6),
    pw.Text(
      _latin1(g.group.name),
      style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
    ),
    if (g.group.description.isNotEmpty) ...[
      pw.SizedBox(height: 6),
      pw.Text(
        _latin1(g.group.description),
        style: const pw.TextStyle(fontSize: 13),
      ),
    ],
    pw.SizedBox(height: 10),
    pw.Container(height: 2, color: PdfColors.blueGrey700),
    pw.SizedBox(height: 10),
    pw.Text(
      _latin1(
        '${el.date}: $date   ${el.unit}: ${g.unit.label}   '
        '${ll.studies}: ${g.entries.length}',
      ),
      style: const pw.TextStyle(fontSize: 10),
    ),
    pw.SizedBox(height: 24),
    if (line.measuredCount > 0)
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _latin1(ll.lineAnalysis),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            for (final f in _lineFigures(g, ll, line))
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 180,
                      child: pw.Text(
                        _latin1(f[0]),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Text(
                      _latin1(f[1]),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    pw.SizedBox(height: 28),
    pw.Text(
      _latin1(ll.contents),
      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 10),
    entry('line', ll.lineAnalysis),
    if (ll.risk != null) entry('risk', ll.risk!.title),
    entry('overview', gl.overview),
    pw.SizedBox(height: 4),
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        _latin1(ll.studies),
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
    ),
    for (var k = 0; k < g.entries.length; k++)
      entry('study$k', '${k + 1}. ${g.entries[k].study.name}', level: 1),
  ];
}

const _barColors = [
  PdfColors.blueGrey700,
  PdfColors.teal400,
  PdfColors.indigo300,
  PdfColors.blueGrey400,
  PdfColors.teal200,
  PdfColors.indigo100,
];

/// Failure scenarios: line output while each machine is down.
List<pw.Widget> _riskSection(
  GroupReportInput g,
  LineReportLabels ll,
  LineAnalysis line,
) {
  final rl = ll.risk!;
  final risk = FailureRisk.of(line);
  final simulated = simulatedLosses(g);
  final withSim = simulated != null && rl.lostWithBuffers != null;
  final singles = risk.singlePoints.length;
  String number(double v) => formatNumber(v, 1, locale: g.locale);
  return [
    pw.Outline(
      name: 'risk',
      title: _latin1(rl.title),
      child: pw.Text(
        _latin1(rl.title),
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
    ),
    pw.Text(
      _latin1(g.group.name),
      style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
    ),
    pw.SizedBox(height: 6),
    pw.Text(_latin1(rl.hint), style: const pw.TextStyle(fontSize: 9)),
    if (risk.baseOutput != null)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
          _latin1('${ll.outputPerHour}: ${number(risk.baseOutput!)}'),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    if (withSim && rl.simulationNote != null)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(
          _latin1(
            rl.simulationNote!(
              formatDuration(g.simulationHorizonMicros!),
              g.simulationFailureMicros! ~/ 60000000,
            ),
          ),
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
    if (singles > 0)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(
          _latin1(rl.singlePoints(singles)),
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.red,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    pw.SizedBox(height: 8),
    if (risk.failures.isEmpty)
      pw.Text(_latin1(ll.lineAnalysis), style: _small)
    else
      _table(
        [
          g.labels.position,
          rl.machine,
          '${rl.outputDuring} / h',
          rl.loss,
          if (withSim) ...[rl.lostWithoutBuffers!, rl.lostWithBuffers!],
        ],
        [
          for (final f in risk.failures)
            [
              '${f.station.position + 1}',
              f.machine,
              number(f.outputAfter),
              f.standstill
                  ? '100 % – ${rl.standstill}'
                  : f.loss == 0
                  ? rl.noLoss
                  : '${number(f.loss * 100)} %',
              if (withSim) ...[
                '${simulated[(f.station.position, f.machine)]?.lostWithoutBuffers ?? ''}',
                '${simulated[(f.station.position, f.machine)]?.lostWithBuffers ?? ''}',
              ],
            ],
        ],
      ),
  ];
}

List<pw.Widget> _lineSection(
  GroupReportInput g,
  LineReportLabels ll,
  LineAnalysis line,
) {
  final gl = g.labels;
  final el = g.exportLabels;
  final max = line.lineCycleTime;
  const barWidth = 260.0;
  String opt(double? v) => v == null ? '' : _fmt(g, v);
  final conveyors = ll.buffers?.withConveyors ?? false;
  bool listed(LineStation st) =>
      st.bufferBefore != null || (conveyors && st.conveyorBefore != null);
  return [
    pw.Outline(
      name: 'line',
      title: _latin1(ll.lineAnalysis),
      child: pw.Text(
        _latin1(ll.lineAnalysis),
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
    ),
    pw.Text(
      _latin1(g.group.name),
      style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
    ),
    pw.SizedBox(height: 8),
    _table(['', ''], _lineFigures(g, ll, line)),
    if (max != null && max > 0) ...[
      _section(el.realCycleTime),
      for (final st in line.stations)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 150,
                child: pw.Text(
                  _latin1('${st.position + 1}. ${st.name}'),
                  style: _small,
                  maxLines: 1,
                ),
              ),
              pw.Container(
                decoration: st.isBottleneck
                    ? pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.red, width: 1.2),
                      )
                    : null,
                child: pw.Row(
                  children: [
                    for (var k = 0; k < st.segments.length; k++)
                      pw.Container(
                        width: barWidth * st.segments[k].micros / max,
                        height: 12,
                        color: _barColors[k % _barColors.length],
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                _latin1(st.cycleTime == null ? '-' : _fmt(g, st.cycleTime!)),
                style: pw.TextStyle(
                  fontSize: 8,
                  color: st.isBottleneck ? PdfColors.red : null,
                  fontWeight: st.isBottleneck ? pw.FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
    ],
    _section(ll.station),
    _table(
      [
        gl.position,
        ll.station,
        el.realCycleTime,
        ll.share,
        ll.waiting,
        gl.previous,
        el.revision?.delta ?? '',
      ],
      [
        for (final st in line.stations)
          [
            '${st.position + 1}',
            st.isBottleneck ? '${st.name} (${ll.bottleneck})' : st.name,
            opt(st.cycleTime),
            st.cycleTime == null
                ? ''
                : '${formatNumber(st.share * 100, 1, locale: g.locale)} %',
            opt(st.idle),
            opt(st.previousCycleTime),
            st.cycleTime == null || st.previousCycleTime == null
                ? ''
                : formatDelta(
                    st.cycleTime! - st.previousCycleTime!,
                    g.unit,
                    decimals: _decimals(g.unit),
                    locale: g.locale,
                  ),
          ],
      ],
    ),
    if (ll.buffers != null && line.stations.any(listed)) ...[
      _section(ll.buffers!.title),
      _table(
        [
          gl.position,
          ll.buffers!.before,
          ll.buffers!.places,
          ll.buffers!.store,
          ll.buffers!.retrieve,
          if (conveyors) ...[
            ll.buffers!.conveyorPlaces!,
            ll.buffers!.conveyorTime!,
          ],
        ],
        [
          for (final st in line.stations.where(listed))
            [
              '${st.position + 1}',
              st.name,
              '${st.bufferBefore?.capacity ?? ''}',
              st.bufferBefore == null
                  ? ''
                  : _fmt(g, st.bufferBefore!.storeMicros),
              st.bufferBefore == null
                  ? ''
                  : _fmt(g, st.bufferBefore!.retrieveMicros),
              if (conveyors) ...[
                '${st.conveyorBefore?.capacity ?? ''}',
                st.conveyorBefore == null
                    ? ''
                    : _fmt(g, st.conveyorBefore!.transportMicros),
              ],
            ],
        ],
      ),
    ],
  ];
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
    ..._overviewTable(
      g,
      p,
      rows,
      total,
      t,
      _Marker(
        pw.Outline(
          name: 'overview',
          title: _latin1(gl.overview),
          child: _section(gl.overview),
        ),
      ),
    ),
  ];
}

/// Overview heading and table (studies in group order and their total).
List<pw.Widget> _overviewTable(
  GroupReportInput g,
  PdfLabels p,
  List<List<String>> rows,
  double total,
  String Function(num?) t,
  pw.Widget heading,
) {
  final gl = g.labels;
  final el = g.exportLabels;
  final rl = el.revision;
  return [
    heading,
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

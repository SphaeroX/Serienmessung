import 'dart:convert';

import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/group_report.dart';
import 'package:cyclescope/export/domain/group_xlsx_export.dart';
import 'package:cyclescope/export/domain/pdf_report.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'group_report_full_test.dart' show formulaOf, lineLabels;
import 'group_report_test.dart' show fullLabels, groupLabels;
import 'pdf_report_test.dart' show pdfLabels;

const s = 1000000;

final riskLabels = RiskReportLabels(
  title: 'Failure risk',
  hint: 'Output while one machine is down.',
  machine: 'Machine',
  outputDuring: 'Output during failure',
  loss: 'Loss',
  standstill: 'Standstill',
  noLoss: 'No loss',
  singlePoints: (n) => '$n station(s) without a spare machine',
);

final labels = lineLabels.withRisk(riskLabels);

/// Machine with one lap of [seconds] (a simple study).
ExportInput machine(
  int id,
  String name,
  int seconds, {
  bool parallel = false,
}) => ExportInput(
  study: Study(
    id: id,
    name: name,
    description: '',
    mode: StudyMode.simple,
    createdAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
    parallel: parallel,
  ),
  steps: const [],
  measurements: [
    Measurement(
      id: id,
      studyId: id,
      cycle: 1,
      stepId: null,
      kind: MeasurementKind.normal,
      startMicros: 0,
      endMicros: seconds * s,
      durationMicros: seconds * s,
    ),
  ],
  unit: TimeUnit.seconds,
  method: CycleTimeMethod.median,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20),
  labels: fullLabels,
);

GroupReportInput report() => GroupReportInput(
  group: StudyGroup(
    id: 1,
    name: 'Press shop',
    description: '',
    createdAt: DateTime(2026),
  ),
  entries: [
    machine(1, 'Saw', 12),
    machine(2, 'Press 1', 40),
    machine(3, 'Press 2', 40, parallel: true),
    machine(4, 'Press 3', 40, parallel: true),
    machine(5, 'Press 4', 40, parallel: true),
  ],
  unit: TimeUnit.seconds,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20),
  labels: groupLabels,
  exportLabels: fullLabels,
);

void main() {
  test('Excel: a parallel station is one row with a combined formula', () {
    final book = Excel.decodeBytes(buildGroupReportXlsx(report(), labels));
    final line = book.tables['Line analysis']!;
    final header = line.rows.indexWhere(
      (r) => r.isNotEmpty && r[0]?.value.toString() == 'Pos.',
    );
    final stations = [
      for (var i = header + 1; i < line.rows.length; i++)
        if (line.rows[i].isNotEmpty &&
            int.tryParse(line.rows[i][0]?.value.toString() ?? '') != null)
          line.rows[i],
    ];
    expect(stations, hasLength(2));
    final press = formulaOf(stations[1][2])!;
    expect(press, startsWith('1/('));
    for (final n in ['2 Press 1', '3 Press 2', '4 Press 3', '5 Press 4']) {
      expect(press, contains("'$n'!B"));
    }
    expect(stations[1][1]!.value.toString(), contains('Press 4'));
  });

  test('Excel: failure risk sheet, linked from the contents', () {
    final book = Excel.decodeBytes(buildGroupReportXlsx(report(), labels));
    expect(book.tables.keys.take(4), [
      'Contents',
      'Line analysis',
      'Failure risk',
      'Overview',
    ]);
    final risk = book.tables['Failure risk']!;
    final rows = [
      for (final r in risk.rows) [for (final c in r) c?.value.toString()],
    ];
    final saw = rows.firstWhere((r) => r.contains('Saw'));
    expect(saw, contains('Standstill'));
    final press = rows.firstWhere((r) => r.contains('Press 2'));
    expect(press, contains('270'));
    expect(press, contains('10'));
    final contents = [
      for (final r in book.tables['Contents']!.rows)
        for (final c in r) formulaOf(c) ?? '',
    ].join();
    expect(contents, contains("#'Failure risk'!A1"));
  });

  test('PDF: failure risk chapter in the contents', () async {
    Map<String, int>? sections;
    final bytes = await buildGroupReportPdf(
      report(),
      pdfLabels,
      labels,
      compress: false,
      onSections: (x) => sections = x,
    );
    final text = latin1.decode(bytes);
    bool has(String words) =>
        words.split(' ').every((w) => text.contains('[($w)]TJ'));
    expect(has('Failure risk'), isTrue);
    expect(has('Standstill'), isTrue);
    expect(has('without a spare machine'), isTrue);
    expect(sections!['risk'], 3);
    expect(sections!['overview'], 4);
  });

  test('without risk labels the complete report stays as before', () {
    final book = Excel.decodeBytes(buildGroupReportXlsx(report(), lineLabels));
    expect(book.tables.keys.contains('Failure risk'), isFalse);
  });
}

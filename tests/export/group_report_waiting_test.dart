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
import 'group_report_parallel_test.dart' show riskLabels;
import 'group_report_test.dart' show fullLabels, groupLabels;
import 'pdf_report_test.dart' show pdfLabels;

const s = 1000000;

final labels = lineLabels
    .withRisk(riskLabels)
    .withWaitsForSlowest('waits for the slowest');

/// Machine with one lap of [seconds] (a simple study).
ExportInput machine(
  int id,
  String name,
  int seconds, {
  bool parallel = false,
  bool waits = false,
}) => ExportInput(
  study: Study(
    id: id,
    name: name,
    description: '',
    mode: StudyMode.simple,
    createdAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
    parallel: parallel,
    waitForSlowest: waits,
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

/// Saw, then three parts made in parallel and joined afterwards.
GroupReportInput report() => GroupReportInput(
  group: StudyGroup(
    id: 1,
    name: 'Assembly',
    description: '',
    createdAt: DateTime(2026),
  ),
  entries: [
    machine(1, 'Saw', 12),
    machine(2, 'Part 1', 30, waits: true),
    machine(3, 'Part 2', 40, parallel: true),
    machine(4, 'Part 3', 50, parallel: true),
  ],
  unit: TimeUnit.seconds,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20),
  labels: groupLabels,
  exportLabels: fullLabels,
);

List<List<Data?>> stationRows(Excel book) {
  final line = book.tables['Line analysis']!;
  final header = line.rows.indexWhere(
    (r) => r.isNotEmpty && r[0]?.value.toString() == 'Pos.',
  );
  return [
    for (var i = header + 1; i < line.rows.length; i++)
      if (line.rows[i].isNotEmpty &&
          int.tryParse(line.rows[i][0]?.value.toString() ?? '') != null)
        line.rows[i],
  ];
}

void main() {
  test('the report line runs at the slowest machine of the station', () {
    final line = report().line;
    expect(line.stations[1].waitsForSlowest, isTrue);
    expect(line.lineCycleTime, closeTo(50 * s, 1));
  });

  test('Excel: a waiting station is one row with the maximum', () {
    final book = Excel.decodeBytes(buildGroupReportXlsx(report(), labels));
    final stations = stationRows(book);
    expect(stations, hasLength(2));
    final parts = formulaOf(stations[1][2])!;
    expect(parts, startsWith('MAX('));
    for (final n in ['2 Part 1', '3 Part 2', '4 Part 3']) {
      expect(parts, contains("'$n'!B"));
    }
    expect(
      stations[1][1]!.value.toString(),
      'Part 1 / Part 2 / Part 3 (3, waits for the slowest)',
    );
  });

  test('Excel: without the text the station is marked "3→1"', () {
    final book = Excel.decodeBytes(
      buildGroupReportXlsx(report(), lineLabels.withRisk(riskLabels)),
    );
    final stations = stationRows(book);
    expect(formulaOf(stations[1][2]), startsWith('MAX('));
    expect(stations[1][1]!.value.toString(), 'Part 1 / Part 2 / Part 3 (3→1)');
  });

  test('Excel: every machine of the waiting station is a standstill', () {
    final book = Excel.decodeBytes(buildGroupReportXlsx(report(), labels));
    final rows = [
      for (final r in book.tables['Failure risk']!.rows)
        [for (final c in r) c?.value.toString()],
    ];
    for (final name in ['Saw', 'Part 1', 'Part 2', 'Part 3']) {
      expect(
        rows.firstWhere((r) => r.contains(name)),
        contains('Standstill'),
        reason: name,
      );
    }
    expect(
      rows.any((r) => r.contains('2 station(s) without a spare machine')),
      isTrue,
    );
  });

  test('PDF: the waiting station is named in the line chapter', () async {
    final bytes = await buildGroupReportPdf(
      report(),
      pdfLabels,
      labels,
      compress: false,
    );
    final text = latin1.decode(bytes);
    expect(text, contains('waits'));
    expect(text, contains('slowest'));
  });

  test('PDF: without the text nothing is added', () async {
    final bytes = await buildGroupReportPdf(
      report(),
      pdfLabels,
      lineLabels.withRisk(riskLabels),
      compress: false,
    );
    expect(latin1.decode(bytes), isNot(contains('slowest')));
  });
}

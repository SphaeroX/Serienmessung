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

import 'export_test.dart' show numOf;
import 'group_report_full_test.dart' show lineLabels;
import 'group_report_test.dart' show fullLabels, groupLabels;
import 'pdf_report_test.dart' show pdfLabels;

const s = 1000000;

final labels = lineLabels.withBuffers(
  const BufferReportLabels(
    title: 'Connections',
    before: 'Before station',
    places: 'Places',
    store: 'Store time',
    retrieve: 'Retrieve time',
    conveyorPlaces: 'Conveyor places',
    conveyorTime: 'Transport time',
  ),
);

ExportInput machine(
  int id,
  String name,
  int seconds, {
  bool conveyor = false,
}) => ExportInput(
  study: Study(
    id: id,
    name: name,
    description: '',
    mode: StudyMode.simple,
    createdAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
    conveyorCapacity: conveyor ? 8 : 0,
    conveyorTransportMicros: conveyor ? 30 * s : 0,
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
    name: 'Conveyor line',
    description: '',
    createdAt: DateTime(2026),
  ),
  entries: [machine(1, 'A', 10), machine(2, 'B', 20, conveyor: true)],
  unit: TimeUnit.seconds,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20),
  labels: groupLabels,
  exportLabels: fullLabels,
);

void main() {
  test('Excel: the conveyor is listed with places and transport time', () {
    final sheet = Excel.decodeBytes(buildGroupReportXlsx(report(), labels))
        .tables['Line analysis']!;
    final header = sheet.rows.indexWhere(
      (r) => r.any((c) => c?.value.toString() == 'Conveyor places'),
    );
    expect(header, greaterThan(0));
    final cols = [for (final c in sheet.rows[header]) c?.value.toString()];
    final row = sheet.rows[header + 1];
    expect(numOf(row[cols.indexOf('Conveyor places')]!.value), 8);
    expect(numOf(row[cols.indexOf('Transport time [s]')]!.value), 30);
    expect(row[cols.indexOf('Places')]?.value, isNull);
  });

  test('PDF: the conveyor is listed', () async {
    final text = latin1.decode(
      await buildGroupReportPdf(report(), pdfLabels, labels, compress: false),
    );
    bool has(String words) =>
        words.split(' ').every((w) => text.contains('[($w)]TJ'));
    expect(has('Connections'), isTrue);
    expect(has('Conveyor places'), isTrue);
    expect(has('30.00 s'), isTrue);
  });
}

import 'dart:convert';

import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/group_report.dart';
import 'package:cyclescope/export/domain/group_xlsx_export.dart';
import 'package:cyclescope/export/domain/pdf_report.dart';
import 'package:cyclescope/group/domain/special_cycle.dart';
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

final labels = lineLabels.withSpecials(
  SpecialReportLabels(
    title: 'Special cycles',
    machine: 'Machine',
    name: 'Special cycle',
    rule: 'Rule',
    time: 'Time',
    measured: 'Measured',
    effective: 'Effective',
    everyParts: (n) => 'every $n parts',
    everyHours: (h) => 'every $h h',
  ),
);

ExportInput machine(int id, String name, int seconds) => ExportInput(
  study: Study(
    id: id,
    name: name,
    description: '',
    mode: StudyMode.simple,
    createdAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
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
    name: 'Line',
    description: '',
    createdAt: DateTime(2026),
  ),
  entries: [machine(1, 'Saw', 30), machine(2, 'Press', 40)],
  unit: TimeUnit.seconds,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20),
  labels: groupLabels,
  exportLabels: fullLabels,
  specialCycles: const {
    2: [
      SpecialCycle(
        id: 1,
        studyId: 2,
        name: 'Measure part',
        kind: SpecialCycleKind.parts,
        interval: 50,
        durationMicros: 120 * s,
      ),
      SpecialCycle(
        id: 2,
        studyId: 2,
        name: 'Tool change',
        kind: SpecialCycleKind.time,
        interval: 24 * 3600 * s,
        durationMicros: 300 * s,
      ),
    ],
  },
);

void main() {
  test('the line uses the effective cycle time', () {
    expect(
      report().line.lineCycleTime,
      closeTo(42.4 * s / (1 - 300 / 86400), 1),
    );
  });

  test('Excel lists the special cycles with measured and effective time', () {
    final sheet = Excel.decodeBytes(buildGroupReportXlsx(report(), labels))
        .tables['Line analysis']!;
    final header = sheet.rows.indexWhere(
      (r) => r.any((c) => c?.value.toString() == 'Special cycle'),
    );
    expect(header, greaterThan(0));
    final cols = [for (final c in sheet.rows[header]) c?.value.toString()];
    final first = sheet.rows[header + 1];
    expect(first[cols.indexOf('Machine')]!.value.toString(), 'Press');
    expect(first[cols.indexOf('Rule')]!.value.toString(), 'every 50 parts');
    expect(numOf(first[cols.indexOf('Time [s]')]!.value), 120);
    expect(numOf(first[cols.indexOf('Measured [s]')]!.value), 40);
    expect(
      numOf(first[cols.indexOf('Effective [s]')]!.value),
      closeTo(42.548, 0.0005),
    );
    final second = sheet.rows[header + 2];
    expect(second[cols.indexOf('Rule')]!.value.toString(), 'every 24 h');
  });

  test('the PDF lists the special cycles', () async {
    final text = latin1.decode(
      await buildGroupReportPdf(report(), pdfLabels, labels, compress: false),
    );
    bool has(String words) =>
        words.split(' ').every((w) => text.contains('[($w)]TJ'));
    expect(has('Special cycles'), isTrue);
    expect(has('Measure part'), isTrue);
    expect(has('every 24 h'), isTrue);
  });
}

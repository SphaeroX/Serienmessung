import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/csv_export.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/xlsx_export.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 1000000;

const labels = ExportLabels(
  study: 'Study',
  description: 'Description',
  notes: 'Notes',
  mode: 'Mode',
  modeName: 'Time study',
  date: 'Date',
  unit: 'Unit',
  method: 'Method',
  methodName: 'Median',
  cycle: 'Cycle',
  stepNo: 'Step no.',
  step: 'Step',
  start: 'Start',
  end: 'End',
  duration: 'Duration',
  type: 'Type',
  note: 'Note',
  normal: 'Step',
  special: 'Special time',
  measurementsSheet: 'Measurements',
  cyclesSheet: 'Cycles',
  analysisSheet: 'Analysis',
  total: 'Total',
  complete: 'Complete',
  yes: 'yes',
  no: 'no',
  n: 'n',
  mean: 'Mean',
  median: 'Median',
  min: 'Min',
  max: 'Max',
  stdDev: 'Std. dev.',
  cv: 'CV',
  realCycleTime: 'Real cycle time',
  realTime: 'Real time',
  specialTotal: 'Special times',
  share: 'Share',
  outliersRemoved: 'Outliers removed',
);

Measurement m(
  int id,
  int cycle,
  int? step,
  int start,
  int dur, {
  bool special = false,
  String note = '',
}) => Measurement(
  id: id,
  studyId: 1,
  cycle: cycle,
  stepId: step,
  kind: special ? MeasurementKind.special : MeasurementKind.normal,
  startMicros: start,
  endMicros: start + dur,
  durationMicros: dur,
  note: note,
);

ExportInput input({
  String locale = 'en',
  TimeUnit unit = TimeUnit.seconds,
  String notes = '',
}) => ExportInput(
  study: Study(
    id: 1,
    name: 'Line; "200"',
    description: 'Früh',
    notes: notes,
    mode: StudyMode.timeStudy,
    createdAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
  ),
  steps: const [
    StepDefinition(id: 1, studyId: 1, position: 0, name: 'Pick'),
    StepDefinition(id: 2, studyId: 1, position: 1, name: 'Place; fast'),
  ],
  measurements: [
    m(1, 1, 1, 100 * s, 1500000),
    m(2, 1, 2, 101500000, 2 * s),
    m(3, 2, 1, 103500000, 1 * s),
    m(4, 2, 1, 104 * s, 3 * s, special: true, note: 'Jam'),
    m(5, 2, 2, 104500000, 2500000),
  ],
  unit: unit,
  method: CycleTimeMethod.median,
  locale: locale,
  exportedAt: DateTime(2026, 11, 11, 10, 30),
  labels: labels,
);

/// Numeric value of a decoded cell (whole numbers come back as int cells).
num? numOf(CellValue? v) => switch (v) {
  DoubleCellValue(:final value) => value,
  IntCellValue(:final value) => value,
  _ => null,
};

void main() {
  group('CSV', () {
    test('starts with a BOM, header block, then one row per time', () {
      final csv = buildCsv(input());
      expect(csv.startsWith('﻿'), isTrue);
      final lines = csv.substring(1).trimRight().split('\r\n');
      expect(lines.first, 'Study,"Line; ""200"""');
      final header = lines.indexWhere((l) => l.startsWith('Cycle,'));
      expect(
        lines[header],
        'Cycle,Step no.,Step,Start [s],End [s],Duration [s],Type,Note',
      );
      expect(lines.length - header - 1, 5);
      expect(lines[header + 1], '1,1,Pick,0.000,1.500,1.500,Step,');
    });

    test('German: semicolon and decimal comma, fields with ; are quoted', () {
      final csv = buildCsv(input(locale: 'de'));
      final lines = csv.substring(1).trimRight().split('\r\n');
      expect(lines.first, 'Study;"Line; ""200"""');
      expect(lines, contains('1;2;"Place; fast";1,500;3,500;2,000;Step;'));
      expect(lines, contains('2;1;Pick;4,000;7,000;3,000;Special time;Jam'));
    });

    test('stopwatch unit adds a formatted duration column', () {
      final csv = buildCsv(input(unit: TimeUnit.stopwatch));
      expect(csv, contains('Duration [mm:ss.SSS]'));
      expect(csv, contains('00:01.500'));
    });
  });

  group('Excel', () {
    test('workbook has the three sheets with correct values', () {
      final bytes = buildXlsx(input());
      final book = Excel.decodeBytes(bytes);
      expect(book.tables.keys.toSet(), {'Measurements', 'Cycles', 'Analysis'});

      final ms = book.tables['Measurements']!;
      expect(ms.maxRows, 6);
      expect(numOf(ms.rows[1][5]!.value), 1.5);
      expect(ms.rows[4][6]!.value.toString(), 'Special time');

      final cy = book.tables['Cycles']!;
      expect(cy.rows[0][1]!.value.toString(), '1. Pick [s]');
      // Cycle 2: Pick 1 s, Place 2.5 s, total 3.5 s, special 3 s.
      expect(numOf(cy.rows[2][3]!.value), 3.5);
      expect(numOf(cy.rows[2][4]!.value), 3);

      final an = book.tables['Analysis']!;
      final real = an.rows.firstWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Real cycle time',
      );
      // Cycles 3.5 s and 3.5 s → median 3.5 s.
      expect(numOf(real[1]!.value), 3.5);
    });
  });

  group('study notes', () {
    test('CSV lists the notes in the header block', () {
      final csv = buildCsv(input(notes: 'Night shift, new fixture'));
      final lines = csv.substring(1).trimRight().split('\r\n');
      expect(lines, contains('Notes,"Night shift, new fixture"'));
      expect(buildCsv(input()), isNot(contains('Notes,')));
    });

    test('Excel lists the notes on the analysis sheet', () {
      final book = Excel.decodeBytes(buildXlsx(input(notes: 'Night shift')));
      final row = book.tables['Analysis']!.rows.firstWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Notes',
      );
      expect(row[1]!.value.toString(), 'Night shift');
    });
  });
}

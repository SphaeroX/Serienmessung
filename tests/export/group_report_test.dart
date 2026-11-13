import 'dart:convert';

import 'package:cyclescope/analysis/domain/statistics.dart';
import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/csv_export.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/group_report.dart';
import 'package:cyclescope/export/domain/group_xlsx_export.dart';
import 'package:cyclescope/export/domain/pdf_report.dart';
import 'package:cyclescope/export/domain/xlsx_export.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:cyclescope/recording/domain/measurement.dart';
import 'package:cyclescope/revision/domain/revision.dart';
import 'package:cyclescope/study/domain/study.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_test.dart' show labels, numOf;
import 'pdf_report_test.dart' show pdfLabels;

const s = 1000000;

final revisionLabels = RevisionLabels(
  revision: 'Revision',
  lastMeasured: 'Last measurement',
  deviationFrom: (n) => 'Deviation from revision $n',
  then: 'Then',
  now: 'Now',
  delta: 'Δ',
);

const groupLabels = GroupReportLabels(
  title: 'Group report',
  overview: 'Overview',
  group: 'Group',
  position: 'Pos.',
  cycles: 'Cycles',
  previous: 'Previous revision',
  total: 'Total',
);

final fullLabels = labels.withRevision(revisionLabels);

var _id = 0;

/// One study with two steps; every cycle takes [a] + [b] seconds.
ExportInput study(
  int id,
  String name, {
  required int cycles,
  required int a,
  required int b,
  DateTime? recordedAt,
  Revision? previous,
  int revision = 1,
}) {
  final steps = [
    StepDefinition(id: id * 10 + 1, studyId: id, position: 0, name: 'Load'),
    StepDefinition(id: id * 10 + 2, studyId: id, position: 1, name: 'Cut'),
  ];
  return ExportInput(
    study: Study(
      id: id,
      name: name,
      description: '',
      mode: StudyMode.timeStudy,
      createdAt: DateTime(2025),
      lastActiveAt: DateTime(2025, 6),
      revision: revision,
    ),
    steps: steps,
    measurements: [
      for (var c = 1; c <= cycles; c++)
        for (final (step, sec) in [(steps[0], a), (steps[1], b)])
          Measurement(
            id: ++_id,
            studyId: id,
            cycle: c,
            stepId: step.id,
            kind: MeasurementKind.normal,
            startMicros: 0,
            endMicros: sec * s,
            durationMicros: sec * s,
            recordedAt: recordedAt,
          ),
    ],
    unit: TimeUnit.seconds,
    method: CycleTimeMethod.mean,
    locale: 'en',
    exportedAt: DateTime(2026, 3, 20, 10),
    labels: fullLabels,
    previous: previous,
  );
}

/// Revision 1 of study [id] with cycles of [a] + [b] seconds.
Revision revision(int id, {required int a, required int b}) {
  final old = study(id, 'x', cycles: 2, a: a, b: b);
  return Revision(
    id: 1,
    studyId: id,
    number: 1,
    closedAt: DateTime(2026),
    firstRecordedAt: DateTime(2025, 2, 1),
    lastRecordedAt: DateTime(2025, 2, 2),
    cycleTimeMethod: null,
    notes: '',
    steps: old.steps,
    measurements: old.measurements,
  );
}

GroupReportInput lineReport() => GroupReportInput(
  group: StudyGroup(
    id: 1,
    name: 'Line 4',
    description: 'Assembly',
    createdAt: DateTime(2025),
  ),
  entries: [
    study(
      1,
      'Saw: front/back [A]',
      cycles: 3,
      a: 10,
      b: 30,
      recordedAt: DateTime(2026, 3, 2, 9, 15),
      previous: revision(1, a: 10, b: 20),
      revision: 2,
    ),
    study(2, 'Drill', cycles: 2, a: 5, b: 5, recordedAt: DateTime(2026, 3, 3)),
    study(3, 'Saw: front/back [A] long name continues', cycles: 1, a: 1, b: 1),
  ],
  unit: TimeUnit.seconds,
  locale: 'en',
  exportedAt: DateTime(2026, 3, 20, 10),
  labels: groupLabels,
  exportLabels: fullLabels,
);

int indexOfRow(Sheet sheet, String first) => sheet.rows.indexWhere(
  (r) => r.isNotEmpty && r[0]?.value.toString() == first,
);

List<Data?> rowWith(Sheet sheet, String first) =>
    sheet.rows[indexOfRow(sheet, first)];

void main() {
  group('export input', () {
    test('last measurement is the newest recorded time', () {
      final x = study(
        1,
        'Saw',
        cycles: 1,
        a: 1,
        b: 1,
        recordedAt: DateTime(2026, 3, 2),
      );
      expect(x.lastMeasuredAt, DateTime(2026, 3, 2));
    });

    test('old times without timestamp fall back to the last activity', () {
      final x = study(1, 'Saw', cycles: 1, a: 1, b: 1);
      expect(x.lastMeasuredAt, DateTime(2025, 6));
      expect(study(1, 'Saw', cycles: 0, a: 1, b: 1).lastMeasuredAt, isNull);
    });

    test('comparison with the previous revision', () {
      final x = lineReport().entries.first;
      expect(x.comparison!.previousCycleTime, 30 * s);
      expect(x.comparison!.currentCycleTime, 40 * s);
      expect(lineReport().entries[1].comparison, isNull);
    });
  });

  group('single study exports', () {
    test('CSV and Excel name revision and last measurement', () {
      final x = lineReport().entries.first;
      final csv = buildCsv(x);
      expect(csv, contains('Revision,2'));
      expect(csv, contains('Last measurement,2026-03-02 09:15'));
      final an = Excel.decodeBytes(buildXlsx(x)).tables['Analysis']!;
      expect(rowWith(an, 'Revision')[1]!.value.toString(), '2');
      expect(
        rowWith(an, 'Last measurement')[1]!.value.toString(),
        '2026-03-02 09:15',
      );
    });

    test(
      'the PDF report shows the deviation from the previous revision',
      () async {
        final bytes = await buildPdfReport(
          lineReport().entries.first,
          pdfLabels,
          compress: false,
        );
        final text = latin1.decode(bytes);
        bool has(String words) =>
            words.split(' ').every((w) => text.contains('[($w)]TJ'));
        expect(has('Last measurement: 2026-03-02 09:15'), isTrue);
        expect(has('Deviation from revision 1'), isTrue);
        expect(has('+10.00 s'), isTrue);
      },
    );
  });

  group('Excel group report', () {
    test('overview plus one sheet per study in group order', () {
      final book = Excel.decodeBytes(buildGroupXlsx(lineReport()));
      final names = book.tables.keys.toList();
      expect(names.first, 'Overview');
      expect(names.length, 4);
      for (final n in names) {
        expect(n.length, lessThanOrEqualTo(31));
        expect(n, isNot(contains(RegExp(r'[\[\]:*?/\\]'))));
      }
      expect(names[1], startsWith('1 Saw'));
      expect(names[2], '2 Drill');
      expect(names[3], startsWith('3 Saw'));
      expect(names.toSet().length, 4);
    });

    test('overview lists revision, last measurement, cycle time and delta', () {
      final ov = Excel.decodeBytes(buildGroupXlsx(lineReport()))
          .tables['Overview']!;
      expect(rowWith(ov, 'Group')[1]!.value.toString(), 'Line 4');
      final header = rowWith(ov, 'Pos.');
      final cols = [for (final c in header) c?.value.toString()];
      int col(String start) => cols.indexWhere((c) => c!.startsWith(start));
      final saw = ov.rows[indexOfRow(ov, 'Pos.') + 1];
      expect(saw[col('Study')]!.value.toString(), 'Saw: front/back [A]');
      expect(numOf(saw[col('Revision')]!.value), 2);
      expect(
        saw[col('Last measurement')]!.value.toString(),
        '2026-03-02 09:15',
      );
      expect(numOf(saw[col('Cycles')]!.value), 3);
      expect(numOf(saw[col('Real cycle time')]!.value), 40);
      expect(numOf(saw[col('Previous revision')]!.value), 30);
      expect(numOf(saw[col('Δ [')]!.value), 10);
      expect(numOf(saw[col('Δ [%]')]!.value), closeTo(33.3, 0.05));
      final drill = ov.rows[indexOfRow(ov, 'Pos.') + 2];
      expect(drill[col('Previous revision')]?.value, isNull);
      final total = rowWith(ov, 'Total');
      expect(numOf(total[col('Real cycle time')]!.value), 40 + 10 + 2);
    });

    test('study sheet has key figures, steps with deviation and cycles', () {
      final book = Excel.decodeBytes(buildGroupXlsx(lineReport()));
      final sheet = book.tables[book.tables.keys.elementAt(1)]!;
      expect(
        rowWith(sheet, 'Study')[1]!.value.toString(),
        'Saw: front/back [A]',
      );
      expect(numOf(rowWith(sheet, 'Real cycle time')[1]!.value), 40);
      final steps = rowWith(sheet, 'Step no.');
      final cols = [for (final c in steps) c?.value.toString()];
      final cut = sheet.rows[indexOfRow(sheet, 'Step no.') + 2];
      expect(cut[1]!.value.toString(), 'Cut');
      expect(numOf(cut[cols.indexOf('Then [s]')]!.value), 20);
      expect(numOf(cut[cols.indexOf('Δ [s]')]!.value), 10);
      expect(rowWith(sheet, 'Cycle'), isNotEmpty);
    });
  });

  group('PDF group report', () {
    test('overview and every study, over several pages', () async {
      final bytes = await buildGroupPdf(
        lineReport(),
        pdfLabels,
        compress: false,
      );
      final text = latin1.decode(bytes);
      bool has(String words) =>
          words.split(' ').every((w) => text.contains('[($w)]TJ'));
      expect(has('Group report'), isTrue);
      expect(has('Line 4'), isTrue);
      expect(has('Overview'), isTrue);
      expect(has('Drill'), isTrue);
      expect(has('Saw: front/back [A]'), isTrue);
      expect(has('Page 4 of 4'), isTrue);
    });

    test('an empty group still gives a report', () async {
      final empty = GroupReportInput(
        group: StudyGroup(
          id: 1,
          name: 'Empty',
          description: '',
          createdAt: DateTime(2025),
        ),
        entries: const [],
        unit: TimeUnit.hm,
        locale: 'de',
        exportedAt: DateTime(2026),
        labels: groupLabels,
        exportLabels: fullLabels,
      );
      final bytes = await buildGroupPdf(empty, pdfLabels);
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(Excel.decodeBytes(buildGroupXlsx(empty)).tables.keys, [
        'Overview',
      ]);
    });
  });
}

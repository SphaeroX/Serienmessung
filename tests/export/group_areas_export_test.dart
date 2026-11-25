import 'dart:convert';

import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/export_data.dart';
import 'package:cyclescope/export/domain/group_report.dart';
import 'package:cyclescope/export/domain/group_xlsx_export.dart';
import 'package:cyclescope/export/domain/pdf_report.dart';
import 'package:cyclescope/group/domain/group_tree.dart';
import 'package:cyclescope/group/domain/study_group.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_test.dart' show numOf;
import 'group_report_full_test.dart' show lineLabels, formulaOf, resolve;
import 'group_report_test.dart' show fullLabels, study;
import 'pdf_report_test.dart' show pdfLabels;

const s = 1000000;

const areaGroupLabels = GroupReportLabels(
  title: 'Group report',
  overview: 'Overview',
  group: 'Group',
  position: 'Pos.',
  cycles: 'Cycles',
  previous: 'Previous revision',
  total: 'Total',
  area: 'Area',
);

final areaLineLabels = lineLabels
    .withAreas(
      const AreaReportLabels(
        area: 'Area',
        title: 'Areas',
        stations: 'Stations',
        bottleneck: 'Bottleneck area',
      ),
    )
    .withBuffers(
      const BufferReportLabels(
        title: 'Buffers',
        before: 'Before station',
        places: 'Places',
        store: 'Store',
        retrieve: 'Retrieve',
      ),
    );

StudyGroup areaGroup(int id, String name) =>
    StudyGroup(id: id, name: name, description: '', createdAt: DateTime(2025));

/// Plant: Saw (direct) | Press: Punch, Check | Paint: Check (buffer before
/// the area), Dry.
GroupReportInput plant({String name = 'Plant'}) {
  final paintFirst = study(4, 'Check', cycles: 2, a: 20, b: 25);
  return GroupReportInput(
    group: StudyGroup(
      id: 1,
      name: name,
      description: '',
      createdAt: DateTime(2025),
    ),
    entries: [
      study(1, 'Saw', cycles: 2, a: 20, b: 20),
      study(2, 'Punch', cycles: 2, a: 30, b: 30),
      study(3, 'Check', cycles: 2, a: 10, b: 10),
      ExportInput(
        study: paintFirst.study.copyWith(
          bufferCapacity: 6,
          bufferStoreMicros: 2 * s,
          bufferRetrieveMicros: 3 * s,
        ),
        steps: paintFirst.steps,
        measurements: paintFirst.measurements,
        unit: paintFirst.unit,
        method: paintFirst.method,
        locale: paintFirst.locale,
        exportedAt: paintFirst.exportedAt,
        labels: paintFirst.labels,
      ),
      study(5, 'Dry', cycles: 2, a: 15, b: 15),
    ],
    unit: TimeUnit.seconds,
    locale: 'en',
    exportedAt: DateTime(2026, 3, 20, 10),
    labels: areaGroupLabels,
    exportLabels: fullLabels,
    areas: [
      LineArea(group: areaGroup(2, 'Press'), start: 1, end: 3),
      LineArea(group: areaGroup(3, 'Paint'), start: 3, end: 5),
    ],
  );
}

List<String?> texts(List<Data?> row) => [
  for (final c in row) c?.value?.toString(),
];

void main() {
  group('Excel, full report', () {
    late Excel book;
    late GroupReportInput input;

    setUp(() {
      input = plant();
      book = Excel.decodeBytes(buildGroupReportXlsx(input, areaLineLabels));
    });

    test('contents list the studies under their areas', () {
      final rows = [for (final r in book.tables['Contents']!.rows) texts(r)];
      final firstCells = [for (final r in rows) r.isEmpty ? null : r.first];
      final press = firstCells.indexOf('Press');
      final paint = firstCells.indexOf('Paint');
      expect(press, greaterThan(0));
      expect(paint, greaterThan(press));
      // Punch and the first Check stand between the two headings.
      final between = rows.sublist(press + 1, paint);
      expect(between.map((r) => r.length > 1 ? r[1] : null), [
        'Punch',
        'Check',
      ]);
    });

    test('the overview has an area column', () {
      final ov = book.tables['Overview']!;
      final header = ov.rows.indexWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Pos.',
      );
      final cols = texts(ov.rows[header]);
      final area = cols.indexOf('Area');
      expect(area, greaterThan(0));
      expect(
        [
          for (var k = 1; k <= 5; k++)
            ov.rows[header + k][area]?.value?.toString(),
        ],
        [null, 'Press', 'Press', 'Paint', 'Paint'],
      );
    });

    test('line sheet: area column and areas section with MAX formulas', () {
      final line = book.tables['Line analysis']!;
      final header = line.rows.indexWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Pos.',
      );
      final cols = texts(line.rows[header]);
      final area = cols.indexOf('Area');
      expect(area, greaterThan(0));
      expect(line.rows[header + 2][area]?.value.toString(), 'Press');
      expect(line.rows[header + 1][area]?.value, isNull);

      final section = line.rows.indexWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Areas',
      );
      expect(section, greaterThan(header));
      final pressRow = line.rows.indexWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Press',
      );
      final press = line.rows[pressRow];
      expect(press[1]?.value.toString(), '2–3');
      final f = formulaOf(press[2])!;
      // Excel rows of Punch and the first Check (1-based).
      expect(f, 'MAX(C${header + 3}:C${header + 4})');
      // Recomputed from the study sheets it is the app's area cycle time.
      double station(int excelRow) {
        final formula = formulaOf(line.rows[excelRow - 1][2])!;
        return numOf(resolve(book, formula)!.value)!.toDouble();
      }

      final max = [
        station(header + 3),
        station(header + 4),
      ].reduce((a, b) => a > b ? a : b);
      expect(max * s, input.areaFigures.first.cycleTime);
      expect(formulaOf(press[3]), contains('3600'));
      expect(press[4]?.value.toString(), 'Bottleneck area');
      final paint = line.rows.firstWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Paint',
      );
      expect(paint[4]?.value, isNull);
      // The line figures still cover all stations.
      final sum = line.rows.firstWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Sum of cycle times',
      );
      expect(formulaOf(sum[1]), 'SUM(C${header + 2}:C${header + 6})');
    });

    test('the buffer between the areas names the area', () {
      final line = book.tables['Line analysis']!;
      final buffers = line.rows.indexWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Buffers',
      );
      final header = texts(line.rows[buffers + 1]);
      final area = header.indexOf('Area');
      expect(area, greaterThan(0));
      final row = line.rows[buffers + 2];
      expect(row[0]?.value.toString(), '4');
      expect(row[area]?.value.toString(), 'Paint');
    });

    test('studies of the same name in two areas get their own sheets', () {
      expect(book.tables.keys, containsAll(['3 Check', '4 Check']));
    });
  });

  test('without area labels the line sheet has no area column', () {
    final book = Excel.decodeBytes(buildGroupReportXlsx(plant(), lineLabels));
    final line = book.tables['Line analysis']!;
    final header = line.rows.indexWhere(
      (r) => r.isNotEmpty && r[0]?.value.toString() == 'Pos.',
    );
    expect(texts(line.rows[header]), isNot(contains('Area')));
    expect(
      line.rows.any((r) => r.isNotEmpty && r[0]?.value.toString() == 'Areas'),
      isFalse,
    );
  });

  test('the compact workbook has the area column in the overview', () {
    final book = Excel.decodeBytes(buildGroupXlsx(plant()));
    final ov = book.tables['Overview']!;
    final header = ov.rows.indexWhere(
      (r) => r.isNotEmpty && r[0]?.value.toString() == 'Pos.',
    );
    expect(texts(ov.rows[header]), contains('Area'));
  });

  group('PDF', () {
    bool has(String text, String words) =>
        words.split(' ').every((w) => text.contains('($w)'));

    test(
      'full report: areas in contents, bookmarks and line chapter',
      () async {
        final bytes = await buildGroupReportPdf(
          plant(name: 'Site › Plant'),
          pdfLabels,
          areaLineLabels,
          compress: false,
        );
        final text = latin1.decode(bytes);
        expect(has(text, 'Press'), isTrue);
        expect(has(text, 'Paint'), isTrue);
        expect(has(text, 'Areas'), isTrue);
        expect(has(text, 'Bottleneck area'), isTrue);
        expect(text, contains('/Outlines'));
        // The path separator is no Latin-1 character.
        expect(has(text, 'Site / Plant'), isTrue);
        expect(text, isNot(contains('(?)')));
      },
    );

    test('compact report: area column in the overview', () async {
      final bytes = await buildGroupPdf(plant(), pdfLabels, compress: false);
      final text = latin1.decode(bytes);
      expect(has(text, 'Area'), isTrue);
      expect(has(text, 'Press'), isTrue);
    });
  });
}

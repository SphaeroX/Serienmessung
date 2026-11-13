import 'dart:convert';

import 'package:cyclescope/export/domain/group_report.dart';
import 'package:cyclescope/export/domain/group_xlsx_export.dart';
import 'package:cyclescope/export/domain/pdf_report.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_test.dart' show numOf;
import 'group_report_test.dart' show lineReport;
import 'pdf_report_test.dart' show pdfLabels;

const lineLabels = LineReportLabels(
  contents: 'Contents',
  lineAnalysis: 'Line analysis',
  station: 'Station',
  totalTime: 'Sum of cycle times',
  lineCycleTime: 'Line cycle time',
  bottleneck: 'Bottleneck',
  balance: 'Line balance',
  outputPerHour: 'Output per hour',
  waiting: 'Waiting',
  share: 'Share',
  sheet: 'Sheet',
  backToContents: 'Back to contents',
  studies: 'Studies',
);

/// Resolves a formula like `='1 Saw'!B12` or `'1 Saw'!B12` to its cell.
Data? resolve(Excel book, String formula) {
  final m = RegExp(r"'((?:[^']|'')+)'!([A-Z]+)(\d+)").firstMatch(formula)!;
  final sheet = book.tables[m.group(1)!.replaceAll("''", "'")]!;
  final col = m.group(2)!.codeUnitAt(0) - 'A'.codeUnitAt(0);
  final row = int.parse(m.group(3)!) - 1;
  return sheet.rows[row][col];
}

String? formulaOf(Data? cell) => switch (cell?.value) {
  FormulaCellValue(:final formula) => formula,
  _ => null,
};

void main() {
  group('PDF', () {
    test('cover with contents, line analysis, overview, studies', () async {
      Map<String, int>? sections;
      final bytes = await buildGroupReportPdf(
        lineReport(),
        pdfLabels,
        lineLabels,
        compress: false,
        onSections: (s) => sections = s,
      );
      final text = latin1.decode(bytes);
      bool has(String words) =>
          words.split(' ').every((w) => text.contains('[($w)]TJ'));
      expect(has('Contents'), isTrue);
      expect(has('Line analysis'), isTrue);
      expect(has('Bottleneck'), isTrue);
      expect(has('Line balance'), isTrue);
      expect(has('Overview'), isTrue);
      // Cover, line analysis, overview and one page per study.
      expect(has('Page 6 of 6'), isTrue);
      expect(sections, {
        'line': 2,
        'overview': 3,
        'study0': 4,
        'study1': 5,
        'study2': 6,
      });
      // Clickable contents and bookmarks.
      expect(text, contains('/Link'));
      expect(text, contains('/Outlines'));
    });
  });

  group('Excel', () {
    late Excel book;

    setUp(
      () => book = Excel.decodeBytes(
        buildGroupReportXlsx(lineReport(), lineLabels),
      ),
    );

    test('contents, line, overview and the study sheets', () {
      final names = book.tables.keys.toList();
      expect(names.take(3), ['Contents', 'Line analysis', 'Overview']);
      expect(names, hasLength(6));
      final links = [
        for (final r in book.tables['Contents']!.rows)
          for (final c in r)
            if (formulaOf(c)?.startsWith('HYPERLINK') ?? false) formulaOf(c)!,
      ];
      expect(links, hasLength(5));
      expect(links.first, contains("#'Line analysis'!A1"));
      expect(links.last, contains("#'${names.last}'!A1"));
    });

    test('line sheet links the station cycle times to the study sheets', () {
      final line = book.tables['Line analysis']!;
      final header = line.rows.indexWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Pos.',
      );
      final cols = [for (final c in line.rows[header]) c?.value.toString()];
      final ct = cols.indexWhere((c) => c!.startsWith('Real cycle time'));
      final saw = line.rows[header + 1];
      final f = formulaOf(saw[ct])!;
      expect(f, contains("'1 Saw front back A'!"));
      expect(numOf(resolve(book, f)!.value), 40);
      final drill = formulaOf(line.rows[header + 2][ct])!;
      expect(numOf(resolve(book, drill)!.value), 10);

      String? summary(String label) => formulaOf(
        line.rows.firstWhere(
          (r) => r.isNotEmpty && r[0]?.value.toString() == label,
        )[1],
      );
      expect(summary('Sum of cycle times'), startsWith('SUM('));
      expect(summary('Line cycle time'), startsWith('MAX('));
      expect(summary('Bottleneck'), contains('MATCH('));
      expect(summary('Line balance [%]'), contains('COUNT('));
      expect(summary('Output per hour'), contains('3600'));
    });

    test('overview and study sheets link back', () {
      final ov = book.tables['Overview']!;
      final header = ov.rows.indexWhere(
        (r) => r.isNotEmpty && r[0]?.value.toString() == 'Pos.',
      );
      final cols = [for (final c in ov.rows[header]) c?.value.toString()];
      final sheet = cols.indexOf('Sheet');
      expect(formulaOf(ov.rows[header + 2][sheet]), contains("#'2 Drill'!A1"));
      final drill = book.tables['2 Drill']!;
      expect(formulaOf(drill.rows.first.first), contains("#'Contents'!A1"));
      // The key figures stay where the compact report has them.
      expect(
        drill.rows.any(
          (r) => r.isNotEmpty && r[0]?.value.toString() == 'Real cycle time',
        ),
        isTrue,
      );
    });
  });

  test('line formulas point at the sum and bottleneck rows', () {
    final book = Excel.decodeBytes(
      buildGroupReportXlsx(lineReport(), lineLabels),
    );
    final line = book.tables['Line analysis']!;
    int rowOf(String label) =>
        line.rows.indexWhere(
          (r) => r.isNotEmpty && r[0]?.value.toString() == label,
        ) +
        1;
    final sum = rowOf('Sum of cycle times');
    final max = rowOf('Line cycle time');
    final header = rowOf('Pos.');
    final share = formulaOf(line.rows[header][3])!;
    final waiting = formulaOf(line.rows[header][4])!;
    // The sum and maximum values are in column B, next to their labels.
    expect(share, contains('\$B\$$sum'));
    expect(waiting, contains('\$B\$$max'));
    expect(
      formulaOf(line.rows[rowOf('Bottleneck') - 1][1]),
      contains('MATCH(\$B\$$max,'),
    );
    expect(formulaOf(line.rows[rowOf('Sum of cycle times') - 1][1]), isNotNull);
  });
}

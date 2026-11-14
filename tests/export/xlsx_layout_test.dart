import 'package:cyclescope/core/time_format.dart';
import 'package:cyclescope/export/domain/group_xlsx_export.dart';
import 'package:cyclescope/export/domain/xlsx_export.dart';
import 'package:cyclescope/export/domain/xlsx_layout.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_test.dart' show input;
import 'group_report_full_test.dart' show formulaOf, lineLabels;
import 'group_report_parallel_test.dart' as parallel show labels, report;
import 'group_report_test.dart' show indexOfRow, lineReport, rowWith;

const brand = 'FF0B6B8A';
const white = 'FFFFFFFF';
const linkBlue = 'FF0563C1';

CellStyle styleOf(Data? cell) => cell!.cellStyle!;

bool isBlank(List<Data?> row) => row.every((c) => c?.value == null);

/// Table header cells: white bold text on the brand colour.
void expectHeader(List<Data?> row) {
  final cells = row.where((c) => c?.value != null).toList();
  expect(cells, isNotEmpty);
  for (final c in cells) {
    final s = styleOf(c);
    expect(s.isBold, isTrue, reason: '${c!.value} is not bold');
    expect(s.fontColor.colorHex, white);
    expect(s.backgroundColor.colorHex, brand);
  }
}

/// Every column of the table below [header] fits its header and its texts.
void expectFits(Sheet sheet, int header, {int max = 50}) {
  final titles = sheet.rows[header];
  // The table ends at the first row without a value in its first column.
  var end = header + 1;
  while (end < sheet.rows.length && sheet.rows[end][0]?.value != null) {
    end++;
  }
  for (var c = 0; c < titles.length; c++) {
    if (titles[c]?.value == null) continue;
    var chars = titles[c]!.value.toString().length;
    for (var r = header + 1; r < end; r++) {
      final v = sheet.rows[r][c]?.value;
      if (v is TextCellValue && v.toString().length > chars) {
        chars = v.toString().length;
      }
    }
    expect(
      sheet.getColumnWidth(c),
      greaterThanOrEqualTo(chars > max ? max : chars),
      reason: 'column $c of ${sheet.sheetName} is too narrow',
    );
  }
}

void main() {
  group('SheetLayout', () {
    test('headers of number columns are right-aligned like the numbers', () {
      // Checked before encoding: the decoder of the excel package does not
      // read the horizontal alignment back.
      final sheet = Excel.createExcel()['Table'];
      SheetLayout(sheet)
        ..header(['Name', 'Time', 'Mixed'])
        ..row([
          TextCellValue('a'),
          fixed(DoubleCellValue(1.5), 3),
          IntCellValue(1),
        ])
        ..row([
          TextCellValue('b'),
          fixed(DoubleCellValue(2), 3),
          TextCellValue('x'),
        ])
        ..finish();
      HorizontalAlign align(int column) => sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .cellStyle!
          .horizontalAlignment;
      expect(align(0), HorizontalAlign.Left);
      expect(align(1), HorizontalAlign.Right);
      expect(align(2), HorizontalAlign.Left);
    });

    test('a total label and empty unit columns keep the number alignment', () {
      final sheet = Excel.createExcel()['Table'];
      SheetLayout(sheet)
        ..header(['Pos.', 'Name', 'Previous [s]', 'Note'])
        ..row([IntCellValue(1), TextCellValue('a'), null, null])
        ..row([TextCellValue('Total'), null, null, null], total: true)
        ..finish();
      HorizontalAlign align(int column) => sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .cellStyle!
          .horizontalAlignment;
      // The label of the total row does not turn the numbers into texts.
      expect(align(0), HorizontalAlign.Right);
      expect(align(1), HorizontalAlign.Left);
      // Without values the unit in the title marks a number column.
      expect(align(2), HorizontalAlign.Right);
      expect(align(3), HorizontalAlign.Left);
    });

    test('links are blue and underlined', () {
      // Checked before encoding: the decoder of the excel package drops the
      // underline.
      final sheet = Excel.createExcel()['Table'];
      SheetLayout(sheet)
        ..cells([sheetLink("It's", 'Back')])
        ..header(['Sheet'])
        ..row([sheetLink('Other', 'Other')])
        ..finish();
      for (final row in [0, 2]) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        );
        expect(cell.cellStyle!.underline, Underline.Single);
        expect(cell.cellStyle!.fontColor.colorHex, linkBlue);
      }
      expect(
        formulaOf(sheet.rows.first.first),
        '''HYPERLINK("#'It''s'!A1","Back")''',
      );
    });

    test('an empty row is a real gap and row numbers count it', () {
      final sheet = Excel.createExcel()['Table'];
      final layout = SheetLayout(sheet)..title('Title');
      expect(layout.keyValue('a', IntCellValue(1)), 2);
      layout.gap();
      expect(layout.nextRow, 4);
      expect(layout.keyValue('b', IntCellValue(2)), 4);
      expect(sheet.rows[2].every((c) => c?.value == null), isTrue);
    });

    test('long texts wrap inside a table and make the row higher', () {
      final sheet = Excel.createExcel()['Table'];
      SheetLayout(sheet)
        ..header(['Note'])
        ..row([TextCellValue('short')])
        ..row([TextCellValue('A long remark. ' * 12)])
        ..finish();
      final long = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
      );
      expect(long.cellStyle!.wrap, TextWrapping.WrapText);
      expect(sheet.getRowHeight(2), greaterThan(sheet.getRowHeight(1) * 2));
      expect(sheet.getColumnWidth(0), lessThanOrEqualTo(50));
    });
  });

  group('single study workbook', () {
    late Excel book;
    late Sheet ms;
    late Sheet cy;
    late Sheet an;

    setUp(() {
      book = Excel.decodeBytes(buildXlsx(input(notes: 'Long note. ' * 30)));
      ms = book.tables['Measurements']!;
      cy = book.tables['Cycles']!;
      an = book.tables['Analysis']!;
    });

    test('table headers are white bold text on the brand colour', () {
      expectHeader(ms.rows.first);
      expectHeader(cy.rows.first);
      expectHeader(rowWith(an, 'Step no.'));
    });

    test('columns fit their header and content', () {
      expectFits(ms, 0);
      expectFits(cy, 0);
      expectFits(an, indexOfRow(an, 'Step no.'));
      // A column is as wide as it needs to be, not one size for all.
      expect(ms.getColumnWidth(2), greaterThan(ms.getColumnWidth(0)));
      // Labels of the key figures are readable in full.
      expect(
        an.getColumnWidth(0),
        greaterThanOrEqualTo('Real cycle time'.length),
      );
    });

    test('long free text does not stretch its column', () {
      expect(
        rowWith(an, 'Notes')[1]!.value.toString().length,
        greaterThan(300),
      );
      expect(an.getColumnWidth(1), lessThanOrEqualTo(50));
    });

    test('times are shown with the decimals of the unit', () {
      String format(Data? c) => styleOf(c).numberFormat.formatCode;
      expect(format(ms.rows[1][3]), '0.000');
      expect(format(ms.rows[1][5]), '0.000');
      expect(format(cy.rows[1][1]), '0.000');
      // Key figures: the trailing fill keeps the number at the left edge.
      expect(format(rowWith(an, 'Real cycle time')[1]), '0.000* ');
      expect(format(rowWith(an, 'CV [%]')[1]), '0.0* ');
      expect(format(rowWith(an, 'n')[1]), '0* ');
      final steps = indexOfRow(an, 'Step no.');
      expect(format(an.rows[steps + 1][3]), '0.000');
      expect(format(an.rows[steps + 1][9]), '0.0');

      final hm = Excel.decodeBytes(buildXlsx(input(unit: TimeUnit.hm)));
      expect(format(hm.tables['Measurements']!.rows[1][5]), '0.00');
    });

    test('data rows have fine borders and alternating shading', () {
      final first = styleOf(ms.rows[1][0]);
      final second = styleOf(ms.rows[2][0]);
      expect(first.bottomBorder.borderStyle, BorderStyle.Thin);
      expect(second.bottomBorder.borderStyle, BorderStyle.Thin);
      expect(
        first.backgroundColor.colorHex,
        isNot(second.backgroundColor.colorHex),
      );
      expect(
        styleOf(ms.rows[1][4]).backgroundColor.colorHex,
        first.backgroundColor.colorHex,
      );
    });

    test('rows are higher than the Excel default', () {
      expect(ms.getRowHeight(0), greaterThan(18));
      expect(ms.getRowHeight(1), greaterThan(15));
    });

    test('the analysis sheet starts with a title', () {
      final title = an.rows.first.first;
      expect(title!.value.toString(), 'Analysis');
      expect(styleOf(title).isBold, isTrue);
      expect(styleOf(title).fontSize, greaterThanOrEqualTo(14));
      expect(styleOf(title).fontColor.colorHex, brand);
    });

    test('labels of the key figures are bold', () {
      expect(styleOf(rowWith(an, 'Study')[0]).isBold, isTrue);
      expect(styleOf(rowWith(an, 'Real cycle time')[0]).isBold, isTrue);
      expect(styleOf(rowWith(an, 'Study')[1]).isBold, isFalse);
    });

    test('blocks of the analysis sheet are separated by an empty row', () {
      expect(isBlank(an.rows[indexOfRow(an, 'Real cycle time') - 1]), isTrue);
      expect(isBlank(an.rows[indexOfRow(an, 'Step no.') - 1]), isTrue);
      // No gap inside a block.
      expect(isBlank(an.rows[indexOfRow(an, 'Mode') - 1]), isFalse);
      expect(isBlank(an.rows[indexOfRow(an, 'Median') - 1]), isFalse);
    });
  });

  group('group workbook', () {
    late Excel book;

    setUp(
      () => book = Excel.decodeBytes(
        buildGroupReportXlsx(lineReport(), lineLabels),
      ),
    );

    test('overview: title, styled table, bold total, fitting columns', () {
      final ov = book.tables['Overview']!;
      expect(ov.rows.first.first!.value.toString(), 'Overview');
      expect(styleOf(ov.rows.first.first).fontColor.colorHex, brand);
      final header = indexOfRow(ov, 'Pos.');
      expect(isBlank(ov.rows[header - 1]), isTrue);
      expectHeader(ov.rows[header]);
      expectFits(ov, header);
      // The longest study name has 39 characters.
      expect(ov.getColumnWidth(1), greaterThanOrEqualTo(39));
      final total = rowWith(ov, 'Total');
      expect(styleOf(total[0]).isBold, isTrue);
      expect(styleOf(total[6]).isBold, isTrue);
      expect(styleOf(total[6]).numberFormat.formatCode, '0.000');
    });

    test('links are blue', () {
      void expectLink(Data? cell) {
        expect(formulaOf(cell), startsWith('HYPERLINK'));
        expect(styleOf(cell).fontColor.colorHex, linkBlue);
      }

      final ov = book.tables['Overview']!;
      final header = indexOfRow(ov, 'Pos.');
      expectLink(ov.rows[header + 1].last);
      expectLink(book.tables['2 Drill']!.rows.first.first);
      final contents = book.tables['Contents']!;
      final links = [
        for (final r in contents.rows)
          if (r.isNotEmpty && formulaOf(r[0]) != null) r[0],
      ];
      expect(links, hasLength(5));
      links.forEach(expectLink);
      final line = book.tables['Line analysis']!;
      expectLink(line.rows[indexOfRow(line, 'Pos.') + 1][1]);
    });

    test('contents: section headings and room for the sheet names', () {
      final contents = book.tables['Contents']!;
      expect(
        styleOf(contents.rows.first.first).fontSize,
        greaterThanOrEqualTo(14),
      );
      final studies = indexOfRow(contents, 'Studies');
      expect(styleOf(contents.rows[studies][0]).isBold, isTrue);
      expect(styleOf(contents.rows[studies][0]).fontColor.colorHex, brand);
      expect(isBlank(contents.rows[studies - 1]), isTrue);
      final longest = book.tables.keys
          .map((n) => n.length)
          .reduce((a, b) => a > b ? a : b);
      expect(contents.getColumnWidth(0), greaterThanOrEqualTo(longest));
      expect(contents.getColumnWidth(1), greaterThanOrEqualTo(39));
    });

    test('study sheet: back link, title, separated and styled tables', () {
      final sheet = book.tables['2 Drill']!;
      final title = sheet.rows[1].first;
      expect(title!.value.toString(), 'Drill');
      expect(styleOf(title).fontColor.colorHex, brand);
      final steps = indexOfRow(sheet, 'Step no.');
      final cycles = indexOfRow(sheet, 'Cycle');
      expect(
        isBlank(sheet.rows[indexOfRow(sheet, 'Real cycle time') - 1]),
        isTrue,
      );
      expect(isBlank(sheet.rows[steps - 1]), isTrue);
      expect(isBlank(sheet.rows[cycles - 1]), isTrue);
      expectHeader(sheet.rows[steps]);
      expectHeader(sheet.rows[cycles]);
      expectFits(sheet, steps);
      expect(
        styleOf(sheet.rows[cycles + 1][1]).numberFormat.formatCode,
        '0.000',
      );
    });

    test('line sheet: title, styled station table, formatted formulas', () {
      final line = book.tables['Line analysis']!;
      expect(line.rows.first.first!.value.toString(), 'Line analysis');
      final header = indexOfRow(line, 'Pos.');
      expect(isBlank(line.rows[header - 1]), isTrue);
      expectHeader(line.rows[header]);
      final station = line.rows[header + 1];
      expect(styleOf(station[2]).numberFormat.formatCode, '0.000');
      expect(styleOf(station[3]).numberFormat.formatCode, '0.0');
      expect(styleOf(station[2]).bottomBorder.borderStyle, BorderStyle.Thin);
      // Station names are links; the column still fits the longest name.
      expect(line.getColumnWidth(1), greaterThanOrEqualTo(39));
      expect(
        line.getColumnWidth(2),
        greaterThanOrEqualTo('Real cycle time [s]'.length),
      );
      final sum = indexOfRow(line, 'Sum of cycle times');
      expect(isBlank(line.rows[sum - 1]), isTrue);
      expect(styleOf(line.rows[sum][0]).isBold, isTrue);
      expect(styleOf(line.rows[sum][1]).numberFormat.formatCode, '0.000* ');
    });

    test('compact workbook: the study sheet starts with its title', () {
      final compact = Excel.decodeBytes(buildGroupXlsx(lineReport()));
      final sheet = compact.tables['2 Drill']!;
      expect(sheet.rows.first.first!.value.toString(), 'Drill');
      expect(
        styleOf(sheet.rows.first.first).fontSize,
        greaterThanOrEqualTo(14),
      );
      expectHeader(rowWith(compact.tables['Overview']!, 'Pos.'));
    });

    test('failure risk: explanations do not stretch the first column', () {
      final risk = Excel.decodeBytes(
        buildGroupReportXlsx(parallel.report(), parallel.labels),
      ).tables['Failure risk']!;
      expect(risk.rows.first.first!.value.toString(), 'Failure risk');
      final header = indexOfRow(risk, 'Pos.');
      expectHeader(risk.rows[header]);
      expect(isBlank(risk.rows[header - 1]), isTrue);
      expect(risk.getColumnWidth(0), lessThanOrEqualTo(30));
      expectFits(risk, header);
    });
  });
}
